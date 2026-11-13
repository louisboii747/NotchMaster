import AppKit
import Carbon
import ImageIO
import Observation
import Testing
@testable import NotchMaster

@MainActor
final class TestNowPlayingProvider: NowPlayingProvider {
    private(set) var starts = 0
    private(set) var stops = 0
    var onChange: (@MainActor (NowPlayingState) -> Void)?
    private(set) var commands: [NowPlayingCommand] = []
    var commandDelay: Duration = .zero
    var rejectsCommands = false

    func startObserving(_ onChange: @escaping @MainActor (NowPlayingState) -> Void) {
        starts += 1
        self.onChange = onChange
    }

    func stopObserving() {
        stops += 1
        onChange = nil
    }

    func perform(_ command: NowPlayingCommand) async throws {
        commands.append(command)
        try await Task.sleep(for: commandDelay)
        if rejectsCommands { throw NSError(domain: NSOSStatusErrorDomain, code: -1743) }
    }
}

@MainActor
final class TestMusicProcess {
    var identifier: pid_t?
}

actor TestMusicReader: MusicNowPlayingReading {
    var state: NowPlayingState = .unavailable
    private(set) var reads: [pid_t] = []
    private(set) var resets = 0
    private(set) var commands: [NowPlayingCommand] = []
    private var continuation: CheckedContinuation<NowPlayingState, Never>?
    var suspends = false

    func read(processIdentifier: pid_t) async -> NowPlayingState {
        reads.append(processIdentifier)
        if suspends {
            return await withCheckedContinuation { continuation = $0 }
        }
        return state
    }

    func setState(_ state: NowPlayingState) { self.state = state }
    func suspendReads() { suspends = true }
    func finishRead(_ state: NowPlayingState) {
        continuation?.resume(returning: state)
        continuation = nil
    }
    func reset() { resets += 1 }
    func perform(_ command: NowPlayingCommand, processIdentifier: pid_t) { commands.append(command) }
}

final class TestMusicAppleEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [OSType: NSAppleEventDescriptor] = [
        0x70506C53: NSAppleEventDescriptor(enumCode: 0x6B505350),
        0x70504953: NSAppleEventDescriptor(string: "track-1"),
        0x706E616D: NSAppleEventDescriptor(string: "First Song"),
        0x70417274: NSAppleEventDescriptor(string: "Artist")
    ]
    private var requests: [OSType] = []

    func set(_ code: OSType, value: NSAppleEventDescriptor?) {
        lock.withLock { values[code] = value }
    }

    func count(_ code: OSType) -> Int {
        lock.withLock { requests.filter { $0 == code }.count }
    }

    func send(_ event: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
        try lock.withLock {
            if event.eventClass == 0x686F6F6B {
                requests.append(event.eventID)
                return .record()
            }
            let object = try #require(event.paramDescriptor(forKeyword: UInt32(keyDirectObject)))
            let code = try #require(object.forKeyword(UInt32(keyAEKeyData))).typeCodeValue
            requests.append(code)
            let reply = NSAppleEventDescriptor.record()
            if let value = values[code] {
                reply.setParam(value, forKeyword: UInt32(keyAEResult))
            } else {
                reply.setParam(NSAppleEventDescriptor(int32: -1728), forKeyword: UInt32(keyErrorNumber))
            }
            return reply
        }
    }
}

final class TestMusicPermission: @unchecked Sendable {
    private let condition = NSCondition()
    private var status: OSStatus
    private let promptStatus: OSStatus
    private var waitsForResponse: Bool
    private var requests: [Bool] = []

    init(status: OSStatus = noErr, promptStatus: OSStatus = noErr, waitsForResponse: Bool = false) {
        self.status = status
        self.promptStatus = promptStatus
        self.waitsForResponse = waitsForResponse
    }

    var promptCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return requests.filter { $0 }.count
    }

    var checkCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return requests.count
    }

    func determine(_ target: NSAppleEventDescriptor, askUserIfNeeded: Bool) -> OSStatus {
        condition.lock()
        defer { condition.unlock() }
        requests.append(askUserIfNeeded)
        if askUserIfNeeded {
            if waitsForResponse {
                while waitsForResponse { condition.wait() }
            } else {
                status = promptStatus
            }
        }
        return status
    }

    func respond(_ status: OSStatus) {
        condition.lock()
        defer { condition.unlock() }
        self.status = status
        waitsForResponse = false
        condition.broadcast()
    }
}

@Suite
@MainActor
struct NowPlayingServiceTests {
    private let track = NowPlayingTrack(title: "Song", artist: "Artist", artwork: nil)

    @Test(arguments: [(Double.nan, 240.0), (1.0, Double.infinity), (-1.0, 240.0), (10.0, 0.0), (1.0, 31_536_000.0)])
    func rejectsInvalidTiming(position: Double, duration: Double) {
        #expect(NowPlayingTiming(position: position, duration: duration) == nil)
        #expect(NowPlayingTiming(position: nil, duration: duration) == nil)
    }

    @Test
    func timingInterpolatesPlayingFreezesPausedAndClampsAtTrackEnd() throws {
        let date = Date(timeIntervalSince1970: 1000)
        let timing = try #require(NowPlayingTiming(position: 60, duration: 240, sampledAt: date))
        #expect(timing.elapsed(at: date.addingTimeInterval(5), isPlaying: true) == 65)
        #expect(timing.elapsed(at: date.addingTimeInterval(5), isPlaying: false) == 60)
        #expect(timing.elapsed(at: date.addingTimeInterval(-5), isPlaying: true) == 60)
        #expect(timing.fraction(at: date.addingTimeInterval(500), isPlaying: true) == 1)
        #expect(NowPlayingTiming(position: 500, duration: 240)?.position == 240)
        var updated = track
        updated.identifier = "stable-track"
        let identity = updated.identity
        updated.timing = timing
        #expect(updated.identity == identity)
        #expect(NowPlayingTrack(title: updated.title, artist: updated.artist, artwork: Data([1]), identifier: updated.identifier).identity == identity)
        let state = NowPlayingState.playing(updated)
        #expect(MusicNowPlayingProvider.refreshDelay(for: state, interval: .seconds(5), now: date.addingTimeInterval(179)) == .seconds(1.15))
        #expect(MusicNowPlayingProvider.refreshDelay(for: .paused(updated), interval: .seconds(5), now: date) == .seconds(5))
        #expect(MusicNowPlayingProvider.refreshDelay(for: state, interval: .seconds(5), now: date.addingTimeInterval(500)) == .seconds(5))
    }

    @Test
    func readerProvidesOptionalTimingAndStableIdentity() async throws {
        let events = TestMusicAppleEvents()
        events.set(0x70447572, value: NSAppleEventDescriptor(double: 240))
        events.set(0x70506F73, value: NSAppleEventDescriptor(double: 42))
        let reader = MusicNowPlayingReader(determinePermission: { _, _ in noErr }, send: events.send)
        let first = await reader.read(processIdentifier: 123)
        let timing = try #require(first.track?.timing)
        #expect(timing.duration == 240 && timing.position == 42)
        events.set(0x70506F73, value: NSAppleEventDescriptor(double: 84))
        let second = await reader.read(processIdentifier: 123)
        #expect(second.track?.identity == first.track?.identity && second.track?.timing?.position == 84)
        events.set(0x70447572, value: nil)
        let unknown = await reader.read(processIdentifier: 123)
        #expect(unknown.track?.timing == nil && unknown.track?.title == "First Song")
    }

    @Test
    func trackChangeDuringMetadataReadRetriesOnceWithCoherentLatestMetadata() async {
        let events = TestMusicAppleEvents()
        let reader = MusicNowPlayingReader(determinePermission: { _, _ in noErr }, send: { event in
            let reply = try events.send(event)
            if events.count(0x70504953) == 1 {
                events.set(0x70504953, value: NSAppleEventDescriptor(string: "track-2"))
                events.set(0x706E616D, value: NSAppleEventDescriptor(string: "Next Song"))
            }
            return reply
        })
        let state = await reader.read(processIdentifier: 123)
        #expect(state.track?.title == "Next Song" && state.track?.identity == "123|track-2")
        #expect(events.count(0x70504953) == 4 && events.count(0x70506C53) == 2)

        let unstable = TestMusicAppleEvents()
        let unstableReader = MusicNowPlayingReader(determinePermission: { _, _ in noErr }, send: { event in
            let reply = try unstable.send(event)
            unstable.set(0x70504953, value: NSAppleEventDescriptor(string: "track-\(unstable.count(0x70504953))"))
            return reply
        })
        #expect(await unstableReader.read(processIdentifier: 123) == .unavailable)
        #expect(unstable.count(0x70504953) == 4 && unstable.count(0x70506C53) == 2)
    }

    @Test(arguments: NowPlayingCommand.allCases)
    func transportSendsOnlyTheRequestedMusicCommandWithoutPrompting(command: NowPlayingCommand) async throws {
        let events = TestMusicAppleEvents()
        let permission = TestMusicPermission()
        let reader = MusicNowPlayingReader(determinePermission: permission.determine, send: events.send)
        try await reader.perform(command, processIdentifier: 123)
        let code: OSType = switch command {
        case .previous: 0x50726576
        case .togglePlayback: 0x506C5073
        case .next: 0x4E657874
        }
        #expect(events.count(code) == 1 && events.count(0x70506C53) == 0)
        #expect(permission.promptCount == 0)
        let denied = TestMusicPermission(status: OSStatus(errAEEventNotPermitted))
        let deniedReader = MusicNowPlayingReader(determinePermission: denied.determine, send: events.send)
        await #expect(throws: (any Error).self) { try await deniedReader.perform(command, processIdentifier: 123) }
        #expect(events.count(code) == 1 && denied.promptCount == 0)
    }

    @Test
    func transportRejectsDuplicateActionsAndCancelsOnDisable() async throws {
        let provider = TestNowPlayingProvider()
        provider.commandDelay = .seconds(1)
        let service = NowPlayingService(provider: provider)
        service.perform(.next)
        #expect(provider.commands.isEmpty)
        service.start()
        provider.onChange?(.playing(track))
        service.perform(.next)
        service.perform(.next)
        try await eventually { provider.commands.count == 1 }
        #expect(service.isPerformingCommand)
        service.setEnabled(false)
        #expect(!service.isPerformingCommand && service.controlError == nil)
        service.setEnabled(true)
        provider.onChange?(.paused(track))
        provider.commandDelay = .zero
        provider.rejectsCommands = true
        service.perform(.togglePlayback)
        try await eventually { service.controlError != nil }
        #expect(!service.isPerformingCommand && service.state == .paused(track))
        provider.rejectsCommands = false
        service.perform(.previous)
        try await eventually { !service.isPerformingCommand }
        #expect(service.controlError == nil && provider.commands == [.next, .togglePlayback, .previous])
        service.stop()
    }

    @Test
    func providerRefreshesAfterTransportAndDoesNotSendWhileStoppedOrSleeping() async throws {
        let reader = TestMusicReader()
        await reader.setState(.playing(track))
        let center = NotificationCenter()
        let provider = MusicNowPlayingProvider(reader: reader, notificationCenter: center, interval: .seconds(60), runningMusic: { 123 })
        var state: NowPlayingState = .unavailable
        provider.startObserving { state = $0 }
        defer { provider.stopObserving() }
        try await eventually { state == .playing(track) }
        await reader.setState(.paused(track))
        try await provider.perform(.togglePlayback)
        try await eventually { state == .paused(track) }
        #expect(await reader.commands == [.togglePlayback])
        center.post(name: NSWorkspace.willSleepNotification, object: nil)
        await #expect(throws: CancellationError.self) { try await provider.perform(.next) }
        provider.stopObserving()
        await #expect(throws: CancellationError.self) { try await provider.perform(.previous) }
        #expect(await reader.commands == [.togglePlayback])
    }

    @Test(arguments: [UInt32(0x6B505350), 0x6B505370, 0x6B505353, 0, 0x6B505346])
    func mapsMusicStatesAndTrimsMetadata(code: UInt32) {
        let state = NowPlayingState.music(playerState: code, title: " Song \n", artist: " Artist ", artwork: nil)
        if code == 0x6B505350 {
            #expect(state == .playing(track))
        } else if code == 0x6B505370 {
            #expect(state == .paused(track))
        } else {
            #expect(state == .unavailable)
        }
    }

    @Test(arguments: [nil, "", " \n"])
    func missingTitleIsUnavailable(title: String?) {
        #expect(NowPlayingState.music(playerState: 0x6B505350, title: title, artist: nil, artwork: nil) == .unavailable)
    }

    @Test
    func missingArtistAndArtworkStillProduceATrack() {
        let state = NowPlayingState.music(playerState: 0x6B505350, title: "Song", artist: nil, artwork: nil)
        #expect(state.track == NowPlayingTrack(title: "Song", artist: "", artwork: nil))
    }

    @Test
    func serviceTracksChangesAndIgnoresLateEventsAfterStop() throws {
        let provider = TestNowPlayingProvider()
        let service = NowPlayingService(provider: provider)
        #expect(service.state == .unavailable && !service.isObserving && provider.starts == 0)
        service.start()
        service.start()
        #expect(provider.starts == 1 && service.isObserving)
        let callback = try #require(provider.onChange)
        callback(.playing(track))
        #expect(service.state == .playing(track))
        let next = NowPlayingTrack(title: "Next", artist: "Next Artist", artwork: Data([1]))
        callback(.playing(next))
        #expect(service.state.track == next)
        callback(.paused(next))
        #expect(service.state == .paused(next))
        callback(.unavailable)
        #expect(service.state.track == nil)
        service.stop()
        service.stop()
        callback(.playing(track))
        #expect(provider.stops == 1 && service.state == .unavailable && !service.isObserving)
        service.start()
        #expect(provider.starts == 2)
        callback(.playing(track))
        #expect(service.state == .unavailable)
    }

    @Test
    func unchangedSnapshotsDoNotInvalidatePresentationAndTeardownReleasesService() {
        let provider = TestNowPlayingProvider()
        var service: NowPlayingService? = NowPlayingService(provider: provider)
        weak let weakService = service
        service?.start()
        provider.onChange?(.playing(track))
        var changed = false
        withObservationTracking {
            _ = service?.state
        } onChange: {
            MainActor.assumeIsolated { changed = true }
        }
        provider.onChange?(.playing(track))
        #expect(!changed)
        service = nil
        #expect(weakService == nil && provider.stops == 1 && provider.onChange == nil)
    }

    @Test
    func preferenceStopsPollingAndPermissionChecksAndRestartsWithoutDuplicateObservers() async throws {
        let suite = "NotchMasterNowPlayingLifecycleTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: PreferencesStore.showNowPlayingKey)
        let permission = TestMusicPermission(status: OSStatus(errAEEventWouldRequireUserConsent))
        let events = TestMusicAppleEvents()
        let center = NotificationCenter()
        var processQueries = 0
        let provider = MusicNowPlayingProvider(
            reader: MusicNowPlayingReader(determinePermission: permission.determine, send: events.send),
            notificationCenter: center, interval: .milliseconds(10), runningMusic: {
                processQueries += 1
                return 123
            }
        )
        let dependencies = AppDependencies(defaults: defaults, nowPlayingProvider: provider)
        let service = dependencies.nowPlayingService
        let preferences = dependencies.preferences
        service.start()
        defer { service.stop() }
        try await Task.sleep(for: .milliseconds(35))
        #expect(!service.isObserving && processQueries == 0 && permission.checkCount == 0)

        for _ in 0..<3 {
            preferences.showNowPlaying = true
            preferences.showNowPlaying = true
            try await eventually { service.state.track?.title == "First Song" }
            let queries = processQueries
            center.post(name: NSWorkspace.didWakeNotification, object: nil)
            #expect(processQueries == queries + 1)
            try await Task.sleep(for: .milliseconds(35))
            preferences.showNowPlaying = false
            #expect(!service.isObserving && service.state == .unavailable)
            try await Task.sleep(for: .milliseconds(25))
            let checks = permission.checkCount
            let reads = events.count(0x70506C53)
            let stoppedQueries = processQueries
            for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                         NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification] {
                center.post(name: name, object: nil)
            }
            try await Task.sleep(for: .milliseconds(35))
            #expect(permission.checkCount == checks && events.count(0x70506C53) == reads && processQueries == stoppedQueries)
        }
        #expect(permission.promptCount == 1)
        #expect(events.count(0x70506C53) > 3)
    }

    @Test
    func readerMapsTrackChangesAndClearsArtworkOnMissingOrInvalidMetadata() async {
        let events = TestMusicAppleEvents()
        let reader = MusicNowPlayingReader(determinePermission: { _, _ in noErr }, send: events.send)
        let first = await reader.read(processIdentifier: 123)
        #expect(first == .playing(NowPlayingTrack(title: "First Song", artist: "Artist", artwork: nil, identifier: "123|track-1")))
        events.set(0x706E616D, value: NSAppleEventDescriptor(string: "Next Song"))
        events.set(0x70504953, value: NSAppleEventDescriptor(string: "track-2"))
        events.set(0x70506C53, value: NSAppleEventDescriptor(enumCode: 0x6B505370))
        #expect(await reader.read(processIdentifier: 123) == .paused(NowPlayingTrack(title: "Next Song", artist: "Artist", artwork: nil, identifier: "123|track-2")))
        events.set(0x70506C53, value: nil)
        #expect(await reader.read(processIdentifier: 123) == .unavailable)
    }

    @Test
    func readerToleratesUnavailableArtistAndTreatsDeniedAutomationAsUnavailable() async {
        let events = TestMusicAppleEvents()
        events.set(0x70417274, value: nil)
        let reader = MusicNowPlayingReader(determinePermission: { _, _ in noErr }, send: events.send)
        #expect(await reader.read(processIdentifier: 123).track?.artist == "")
        let denied = MusicNowPlayingReader(determinePermission: { _, _ in noErr }, send: { _ in
            throw NSError(domain: NSOSStatusErrorDomain, code: -1743)
        })
        #expect(await denied.read(processIdentifier: 123) == .unavailable)
    }

    @Test
    func readerCachesSmallArtworkAndResetReleasesIt() async throws {
        let raw = try makeArtwork()
        let events = TestMusicAppleEvents()
        events.set(0x70526177, value: NSAppleEventDescriptor(descriptorType: UInt32(typeData), data: raw))
        let reader = MusicNowPlayingReader(determinePermission: { _, _ in noErr }, send: events.send)
        let state = await reader.read(processIdentifier: 123)
        let artwork = try #require(state.track?.artwork)
        let source = try #require(CGImageSourceCreateWithData(artwork as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 256 && image.height == 128)
        #expect(await reader.read(processIdentifier: 123) == state)
        #expect(events.count(0x70526177) == 1)
        await reader.reset()
        events.set(0x70526177, value: nil)
        #expect(await reader.read(processIdentifier: 123).track?.artwork == nil)
        #expect(events.count(0x70526177) == 2)
        #expect(MusicNowPlayingReader.thumbnail(Data([1, 2, 3])) == nil)
        #expect(MusicNowPlayingReader.thumbnail(Data(count: 10 * 1024 * 1024 + 1)) == nil)
    }

    @Test
    func permissionWaitsForTheUserWithoutMetadataTimeoutsOrDuplicatePrompts() async throws {
        let permission = TestMusicPermission(status: OSStatus(errAEEventWouldRequireUserConsent), waitsForResponse: true)
        defer { permission.respond(OSStatus(errAEEventNotPermitted)) }
        let events = TestMusicAppleEvents()
        let reader = MusicNowPlayingReader(determinePermission: permission.determine, send: events.send)
        let first = Task { await reader.read(processIdentifier: 123) }
        defer { first.cancel() }
        try await eventually { permission.promptCount == 1 }
        let second = Task { await reader.read(processIdentifier: 123) }
        defer { second.cancel() }
        try await Task.sleep(for: .milliseconds(1100))
        #expect(permission.promptCount == 1)
        #expect(events.count(0x70506C53) == 0)
        permission.respond(noErr)
        #expect(await first.value.track?.title == "First Song")
        #expect(await second.value.track?.title == "First Song")
        #expect(permission.promptCount == 1)
        #expect(MusicNowPlayingReader.metadataSendOptions.rawValue & UInt(kAEDoNotPromptForUserConsent) != 0)
    }

    @Test(arguments: [OSStatus(errAEEventNotPermitted), OSStatus(errAEEventWouldRequireUserConsent)])
    func unansweredOrDeniedPermissionDoesNotPromptAgainAfterRefreshOrReset(status: OSStatus) async {
        let permission = TestMusicPermission(status: OSStatus(errAEEventWouldRequireUserConsent), promptStatus: status)
        let events = TestMusicAppleEvents()
        let reader = MusicNowPlayingReader(determinePermission: permission.determine, send: events.send)
        #expect(await reader.read(processIdentifier: 123) == .unavailable)
        await reader.reset()
        #expect(await reader.read(processIdentifier: 123) == .unavailable)
        #expect(permission.promptCount == 1 && events.count(0x70506C53) == 0)
        permission.respond(noErr)
        #expect(await reader.read(processIdentifier: 123).track?.title == "First Song")
        #expect(permission.promptCount == 1)
    }

    @Test
    func cancellingWhilePermissionIsPendingDiscardsApprovalWithoutSendingMetadata() async throws {
        let permission = TestMusicPermission(status: OSStatus(errAEEventWouldRequireUserConsent), waitsForResponse: true)
        defer { permission.respond(OSStatus(errAEEventNotPermitted)) }
        let events = TestMusicAppleEvents()
        let reader = MusicNowPlayingReader(determinePermission: permission.determine, send: events.send)
        let pending = Task { await reader.read(processIdentifier: 123) }
        defer { pending.cancel() }
        try await eventually { permission.promptCount == 1 }
        pending.cancel()
        permission.respond(noErr)
        #expect(await pending.value == .unavailable)
        #expect(events.count(0x70506C53) == 0)
    }

    @Test
    func providerObservesOnlyWhileMusicRunsAndSuspendsDuringSleep() async throws {
        let reader = TestMusicReader()
        await reader.setState(.playing(track))
        let center = NotificationCenter()
        let process = TestMusicProcess()
        let provider = MusicNowPlayingProvider(reader: reader, notificationCenter: center, interval: .milliseconds(10), runningMusic: { process.identifier })
        var states: [NowPlayingState] = []
        provider.startObserving { states.append($0) }
        #expect(states == [.unavailable])
        #expect(await reader.reads.isEmpty)
        process.identifier = 123
        center.post(name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        try await eventually { !states.isEmpty && states.last == .playing(track) }
        await reader.setState(.paused(track))
        try await eventually { states.last == .paused(track) }
        center.post(name: NSWorkspace.willSleepNotification, object: nil)
        #expect(states.last == .unavailable)
        let reads = await reader.reads.count
        try await Task.sleep(for: .milliseconds(35))
        #expect(await reader.reads.count == reads)
        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await eventually { states.last == .paused(track) }
        process.identifier = nil
        center.post(name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        #expect(states.last == .unavailable)
        provider.stopObserving()
        let stoppedCount = states.count
        process.identifier = 456
        center.post(name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        try await Task.sleep(for: .milliseconds(35))
        #expect(states.count == stoppedCount)
        #expect(await reader.reads.allSatisfy { $0 == 123 })
    }

    @Test
    func stoppingDuringAReadDiscardsItsResultAndReleasesProvider() async throws {
        let reader = TestMusicReader()
        await reader.suspendReads()
        var provider: MusicNowPlayingProvider? = MusicNowPlayingProvider(reader: reader, notificationCenter: NotificationCenter(), runningMusic: { 123 })
        weak let weakProvider = provider
        var states: [NowPlayingState] = []
        provider?.startObserving { states.append($0) }
        for _ in 0..<100 {
            if await reader.reads.count == 1 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(await reader.reads.count == 1)
        provider?.stopObserving()
        provider = nil
        #expect(weakProvider == nil)
        await reader.finishRead(.playing(track))
        try await Task.sleep(for: .milliseconds(25))
        #expect(states.isEmpty)
        #expect(await reader.resets > 0)
    }

    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition())
    }

    private func makeArtwork() throws -> Data {
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 512, pixelsHigh: 256, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }
}
