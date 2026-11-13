import AppKit
import Carbon
import ImageIO
import UniformTypeIdentifiers

protocol MusicNowPlayingReading: Sendable {
    func read(processIdentifier: pid_t) async -> NowPlayingState
    func reset() async
    func perform(_ command: NowPlayingCommand, processIdentifier: pid_t) async throws
}

actor MusicNowPlayingReader: MusicNowPlayingReading {
    static let metadataSendOptions: NSAppleEventDescriptor.SendOptions = [
        .waitForReply, .neverInteract, .dontRecord,
        NSAppleEventDescriptor.SendOptions(rawValue: UInt(kAEDoNotPromptForUserConsent))
    ]

    private let determinePermission: @Sendable (NSAppleEventDescriptor, Bool) -> OSStatus
    private let send: @Sendable (NSAppleEventDescriptor) throws -> NSAppleEventDescriptor
    private var hasRequestedPermission = false
    private var artworkKey: String?
    private var artwork: Data?
    private var artworkReadDate: Date?

    init(
        determinePermission: @escaping @Sendable (NSAppleEventDescriptor, Bool) -> OSStatus = {
            AEDeterminePermissionToAutomateTarget($0.aeDesc, UInt32(kAECoreSuite), UInt32(kAEGetData), $1)
        },
        send: @escaping @Sendable (NSAppleEventDescriptor) throws -> NSAppleEventDescriptor = {
            try $0.sendEvent(options: MusicNowPlayingReader.metadataSendOptions, timeout: 1)
        }
    ) {
        self.determinePermission = determinePermission
        self.send = send
    }

    func reset() {
        artworkKey = nil
        artwork = nil
        artworkReadDate = nil
    }

    func read(processIdentifier: pid_t) -> NowPlayingState {
        readSnapshot(processIdentifier: processIdentifier, canRetry: true)
    }

    private func readSnapshot(processIdentifier: pid_t, canRetry: Bool) -> NowPlayingState {
        autoreleasepool {
            do {
                try Task.checkCancellation()
                let target = NSAppleEventDescriptor(processIdentifier: processIdentifier)
                var permission = determinePermission(target, false)
                try Task.checkCancellation()
                if permission == errAEEventWouldRequireUserConsent, !hasRequestedPermission {
                    hasRequestedPermission = true
                    permission = determinePermission(target, true)
                }
                guard permission == noErr else {
                    reset()
                    return .unavailable
                }
                try Task.checkCancellation()
                let state = try get(property(0x70506C53), from: target).enumCodeValue
                guard state == 0x6B505350 || state == 0x6B505370 else {
                    reset()
                    return .unavailable
                }
                let track = try property(0x7054726B)
                let identifier = try get(property(0x70504953, of: track), from: target).stringValue ?? ""
                let title = try get(property(0x706E616D, of: track), from: target).stringValue
                let artist = try? get(property(0x70417274, of: track), from: target).stringValue
                let duration = try? get(property(0x70447572, of: track), from: target).doubleValue
                let position = try? get(property(0x70506F73), from: target).doubleValue
                let timing = NowPlayingTiming(position: position, duration: duration)
                let key = "\(processIdentifier)|\(identifier)|\(title ?? "")|\(artist ?? "")"
                if artworkKey != key || (artwork == nil && Date().timeIntervalSince(artworkReadDate ?? .distantPast) >= 30) {
                    artworkKey = key
                    artwork = nil
                    artworkReadDate = Date()
                    if let specifier = try? firstArtwork(of: track),
                       let raw = try? get(property(0x70526177, of: specifier), from: target) {
                        artwork = Self.thumbnail(raw.data)
                    }
                }
                let finalIdentifier = try get(property(0x70504953, of: track), from: target).stringValue ?? ""
                if identifier != finalIdentifier, canRetry {
                    return readSnapshot(processIdentifier: processIdentifier, canRetry: false)
                }
                guard identifier == finalIdentifier, !Task.isCancelled else { return .unavailable }
                return .music(playerState: state, title: title, artist: artist, artwork: artwork, identifier: identifier.isEmpty ? nil : "\(processIdentifier)|\(identifier)", timing: timing)
            } catch {
                reset()
                return .unavailable
            }
        }
    }

    func perform(_ command: NowPlayingCommand, processIdentifier: pid_t) throws {
        try Task.checkCancellation()
        let target = NSAppleEventDescriptor(processIdentifier: processIdentifier)
        let permission = determinePermission(target, false)
        try Task.checkCancellation()
        guard permission == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(permission)) }
        let code: AEEventID = switch command {
        case .previous: 0x50726576
        case .togglePlayback: 0x506C5073
        case .next: 0x4E657874
        }
        let event = NSAppleEventDescriptor(
            eventClass: 0x686F6F6B, eventID: code, targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
        )
        let reply = try send(event)
        let error = reply.paramDescriptor(forKeyword: UInt32(keyErrorNumber))?.int32Value ?? 0
        guard error == 0 else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(error)) }
        try Task.checkCancellation()
    }

    nonisolated static func thumbnail(_ data: Data) -> Data? {
        guard data.count <= 10 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 256,
                  kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return result as Data
    }

    private func property(_ code: OSType, of container: NSAppleEventDescriptor = .null()) throws -> NSAppleEventDescriptor {
        try specifier(desiredClass: UInt32(typeProperty), form: UInt32(formPropertyID), selection: NSAppleEventDescriptor(typeCode: code), container: container)
    }

    private func firstArtwork(of track: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
        try specifier(desiredClass: 0x63417274, form: UInt32(formAbsolutePosition), selection: NSAppleEventDescriptor(int32: 1), container: track)
    }

    private func specifier(
        desiredClass: OSType, form: OSType, selection: NSAppleEventDescriptor, container: NSAppleEventDescriptor
    ) throws -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode: desiredClass), forKeyword: UInt32(keyAEDesiredClass))
        record.setDescriptor(NSAppleEventDescriptor(enumCode: form), forKeyword: UInt32(keyAEKeyForm))
        record.setDescriptor(selection, forKeyword: UInt32(keyAEKeyData))
        record.setDescriptor(container, forKeyword: UInt32(keyAEContainer))
        guard let result = record.coerce(toDescriptorType: UInt32(typeObjectSpecifier)) else { throw CancellationError() }
        return result
    }

    private func get(_ object: NSAppleEventDescriptor, from target: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
        try Task.checkCancellation()
        let event = NSAppleEventDescriptor(
            eventClass: UInt32(kAECoreSuite), eventID: UInt32(kAEGetData), targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
        )
        event.setParam(object, forKeyword: UInt32(keyDirectObject))
        let reply = try send(event)
        let error = reply.paramDescriptor(forKeyword: UInt32(keyErrorNumber))?.int32Value ?? 0
        guard error == 0, let result = reply.paramDescriptor(forKeyword: UInt32(keyAEResult)) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(error))
        }
        return result
    }
}

@MainActor
final class MusicNowPlayingProvider: NowPlayingProvider {
    private let reader: any MusicNowPlayingReading
    private let notificationCenter: NotificationCenter
    private let runningMusic: @MainActor () -> pid_t?
    private let interval: Duration
    private var observers: [NSObjectProtocol] = []
    private var task: Task<Void, Never>?
    private var onChange: (@MainActor (NowPlayingState) -> Void)?
    private var isSleeping = false
    private var generation = 0

    init(
        reader: any MusicNowPlayingReading = MusicNowPlayingReader(),
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        interval: Duration = .seconds(5),
        runningMusic: @escaping @MainActor () -> pid_t? = {
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first?.processIdentifier
        }
    ) {
        self.reader = reader
        self.notificationCenter = notificationCenter
        self.interval = interval
        self.runningMusic = runningMusic
    }

    func startObserving(_ onChange: @escaping @MainActor (NowPlayingState) -> Void) {
        stopObserving()
        self.onChange = onChange
        isSleeping = false
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification] {
            observers.append(notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   application.bundleIdentifier != "com.apple.Music" { return }
                let name = notification.name
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if name == NSWorkspace.willSleepNotification { self.isSleeping = true }
                    if name == NSWorkspace.didWakeNotification { self.isSleeping = false }
                    self.reconcile()
                }
            })
        }
        reconcile()
    }

    func perform(_ command: NowPlayingCommand) async throws {
        guard onChange != nil, !isSleeping, let pid = runningMusic() else { throw CancellationError() }
        let generation = generation
        try await reader.perform(command, processIdentifier: pid)
        try Task.checkCancellation()
        guard self.generation == generation, onChange != nil, !isSleeping, runningMusic() == pid else { throw CancellationError() }
        reconcile()
    }

    private func reconcile() {
        generation += 1
        task?.cancel()
        task = nil
        let reader = reader
        guard !isSleeping, let pid = runningMusic() else {
            onChange?(.unavailable)
            Task { await reader.reset() }
            return
        }
        let generation = generation
        let interval = interval
        task = Task { [weak self] in
            while !Task.isCancelled {
                let state = await reader.read(processIdentifier: pid)
                guard !Task.isCancelled, self?.publish(state, processIdentifier: pid, generation: generation) == true else { return }
                do { try await Task.sleep(for: Self.refreshDelay(for: state, interval: interval)) } catch { return }
            }
        }
    }

    static func refreshDelay(for state: NowPlayingState, interval: Duration, now: Date = .now) -> Duration {
        guard state.isPlaying, let timing = state.track?.timing else { return interval }
        let remaining = timing.duration - timing.elapsed(at: now, isPlaying: true)
        guard remaining > 0 else { return interval }
        return min(interval, .seconds(max(1, remaining + 0.15)))
    }

    private func publish(_ state: NowPlayingState, processIdentifier: pid_t, generation: Int) -> Bool {
        guard self.generation == generation else { return false }
        guard runningMusic() == processIdentifier else {
            reconcile()
            return false
        }
        onChange?(state)
        return true
    }

    func stopObserving() {
        generation += 1
        task?.cancel()
        task = nil
        observers.forEach(notificationCenter.removeObserver)
        observers.removeAll()
        onChange = nil
        let reader = reader
        Task { await reader.reset() }
    }

    isolated deinit {
        stopObserving()
    }
}
