import Foundation
import Observation

struct NowPlayingTrack: Equatable, Sendable {
    let title: String
    let artist: String
    let artwork: Data?
    var identifier: String? = nil
    var timing: NowPlayingTiming? = nil

    var identity: String { identifier ?? "\(title)\u{1F}\(artist)" }
}

struct NowPlayingTiming: Equatable, Sendable {
    let position: TimeInterval
    let duration: TimeInterval
    let sampledAt: Date

    init?(position: TimeInterval?, duration: TimeInterval?, sampledAt: Date = .now) {
        guard let position, let duration, position.isFinite, duration.isFinite,
              position >= 0, duration > 0, duration < 31_536_000,
              sampledAt.timeIntervalSinceReferenceDate.isFinite else { return nil }
        self.position = min(position, duration)
        self.duration = duration
        self.sampledAt = sampledAt
    }

    func elapsed(at date: Date, isPlaying: Bool) -> TimeInterval {
        let delta = isPlaying ? max(0, date.timeIntervalSince(sampledAt)) : 0
        return min(duration, position + (delta.isFinite ? delta : 0))
    }

    func fraction(at date: Date, isPlaying: Bool) -> Double {
        elapsed(at: date, isPlaying: isPlaying) / duration
    }
}

enum NowPlayingCommand: CaseIterable, Sendable {
    case previous, togglePlayback, next
}

enum NowPlayingState: Equatable, Sendable {
    case unavailable
    case playing(NowPlayingTrack)
    case paused(NowPlayingTrack)

    var track: NowPlayingTrack? {
        switch self {
        case .unavailable: nil
        case let .playing(track), let .paused(track): track
        }
    }

    var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    static func music(
        playerState: UInt32, title: String?, artist: String?, artwork: Data?,
        identifier: String? = nil, timing: NowPlayingTiming? = nil
    ) -> Self {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return .unavailable
        }
        let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let track = NowPlayingTrack(title: title, artist: artist, artwork: artwork, identifier: identifier, timing: timing)
        switch playerState {
        case 0x6B505350: return .playing(track)
        case 0x6B505370: return .paused(track)
        default: return .unavailable
        }
    }
}

@MainActor
protocol NowPlayingProvider: AnyObject {
    func startObserving(_ onChange: @escaping @MainActor (NowPlayingState) -> Void)
    func stopObserving()
    func perform(_ command: NowPlayingCommand) async throws
}

@MainActor
@Observable
final class NowPlayingService {
    private let provider: any NowPlayingProvider
    private var generation = 0
    private var isStarted = false
    private var isEnabled = true
    private(set) var state: NowPlayingState = .unavailable
    private(set) var isObserving = false
    private(set) var isPerformingCommand = false
    private(set) var controlError: String?
    @ObservationIgnored private var commandTask: Task<Void, Never>?

    init(provider: any NowPlayingProvider = MusicNowPlayingProvider()) {
        self.provider = provider
    }

    func start() {
        isStarted = true
        guard isEnabled, !isObserving else { return }
        isObserving = true
        generation += 1
        let generation = generation
        provider.startObserving { [weak self] state in
            guard let self, self.isObserving, self.generation == generation, self.state != state else { return }
            self.state = state
        }
    }

    func stop() {
        isStarted = false
        stopObserving()
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        guard isStarted else { return }
        if enabled { start() } else { stopObserving() }
    }

    func perform(_ command: NowPlayingCommand) {
        guard isObserving, state.track != nil, !isPerformingCommand else { return }
        isPerformingCommand = true
        controlError = nil
        let generation = generation
        let provider = provider
        commandTask = Task { [weak self] in
            do {
                try await provider.perform(command)
                try Task.checkCancellation()
            } catch {
                guard !Task.isCancelled, let self, self.isObserving, self.generation == generation else { return }
                self.controlError = String(localized: "Music couldn’t complete that action. Try again.")
            }
            guard let self, self.generation == generation else { return }
            self.isPerformingCommand = false
            self.commandTask = nil
        }
    }

    private func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        generation += 1
        commandTask?.cancel()
        commandTask = nil
        isPerformingCommand = false
        controlError = nil
        provider.stopObserving()
        state = .unavailable
    }

    isolated deinit {
        commandTask?.cancel()
        if isObserving { provider.stopObserving() }
    }
}
