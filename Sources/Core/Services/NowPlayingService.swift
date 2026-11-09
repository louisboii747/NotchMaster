import Foundation
import Observation

struct NowPlayingTrack: Equatable, Sendable {
    let title: String
    let artist: String
    let artwork: Data?
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

    static func music(playerState: UInt32, title: String?, artist: String?, artwork: Data?) -> Self {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return .unavailable
        }
        let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let track = NowPlayingTrack(title: title, artist: artist, artwork: artwork)
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
}

@MainActor
@Observable
final class NowPlayingService {
    private let provider: any NowPlayingProvider
    private var generation = 0
    private(set) var state: NowPlayingState = .unavailable
    private(set) var isObserving = false

    init(provider: any NowPlayingProvider = MusicNowPlayingProvider()) {
        self.provider = provider
    }

    func start() {
        guard !isObserving else { return }
        isObserving = true
        generation += 1
        let generation = generation
        provider.startObserving { [weak self] state in
            guard let self, self.isObserving, self.generation == generation, self.state != state else { return }
            self.state = state
        }
    }

    func stop() {
        guard isObserving else { return }
        isObserving = false
        generation += 1
        provider.stopObserving()
        state = .unavailable
    }

    isolated deinit {
        if isObserving { provider.stopObserving() }
    }
}
