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

    func startObserving(_ onChange: @escaping @MainActor (NowPlayingState) -> Void) {
        starts += 1
        self.onChange = onChange
    }

    func stopObserving() {
        stops += 1
        onChange = nil
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

@Suite
@MainActor
struct NowPlayingServiceTests {
    private let track = NowPlayingTrack(title: "Song", artist: "Artist", artwork: nil)

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
    func readerMapsTrackChangesAndClearsArtworkOnMissingOrInvalidMetadata() async {
        let events = TestMusicAppleEvents()
        let reader = MusicNowPlayingReader(send: events.send)
        let first = await reader.read(processIdentifier: 123)
        #expect(first == .playing(NowPlayingTrack(title: "First Song", artist: "Artist", artwork: nil)))
        events.set(0x706E616D, value: NSAppleEventDescriptor(string: "Next Song"))
        events.set(0x70504953, value: NSAppleEventDescriptor(string: "track-2"))
        events.set(0x70506C53, value: NSAppleEventDescriptor(enumCode: 0x6B505370))
        #expect(await reader.read(processIdentifier: 123) == .paused(NowPlayingTrack(title: "Next Song", artist: "Artist", artwork: nil)))
        events.set(0x70506C53, value: nil)
        #expect(await reader.read(processIdentifier: 123) == .unavailable)
    }

    @Test
    func readerToleratesUnavailableArtistAndTreatsDeniedAutomationAsUnavailable() async {
        let events = TestMusicAppleEvents()
        events.set(0x70417274, value: nil)
        let reader = MusicNowPlayingReader(send: events.send)
        #expect(await reader.read(processIdentifier: 123).track?.artist == "")
        let denied = MusicNowPlayingReader(send: { _ in
            throw NSError(domain: NSOSStatusErrorDomain, code: -1743)
        })
        #expect(await denied.read(processIdentifier: 123) == .unavailable)
    }

    @Test
    func readerCachesSmallArtworkAndResetReleasesIt() async throws {
        let raw = try makeArtwork()
        let events = TestMusicAppleEvents()
        events.set(0x70526177, value: NSAppleEventDescriptor(descriptorType: UInt32(typeData), data: raw))
        let reader = MusicNowPlayingReader(send: events.send)
        let state = await reader.read(processIdentifier: 123)
        let artwork = try #require(state.track?.artwork)
        let source = try #require(CGImageSourceCreateWithData(artwork as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 128 && image.height == 64)
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
