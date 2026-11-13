import AppKit
import SwiftUI
import Testing
@testable import NotchMaster

@Suite(.serialized)
@MainActor
struct NowPlayingViewTests {
    private let track = NowPlayingTrack(title: "A Long Song Title That Must Truncate Gracefully", artist: "An Artist With A Long Name", artwork: nil)
    private let size = CGSize(width: 640, height: 328)

    @Test(arguments: [(0.0, "0:00"), (65.0, "1:05"), (3605.0, "1:00:05")])
    func formatsElapsedAndRemainingTime(seconds: Double, expected: String) {
        #expect(NowPlayingProgressView.timeLabel(seconds) == expected)
        #expect(NowPlayingProgressView.timeLabel(nil) == "–:––")
        #expect(NowPlayingProgressView.timeLabel(.nan) == "–:––")
    }

    @Test
    func progressUsesClampedTimingAndUnknownTimingHasNoFilledBar() throws {
        let date = Date(timeIntervalSince1970: 1000)
        let timing = try #require(NowPlayingTiming(position: 60, duration: 240, sampledAt: date))
        let paused = try snapshot(NowPlayingProgressView(timing: timing, isPlaying: false, date: date.addingTimeInterval(60)).padding(10).background(.black), size: CGSize(width: 400, height: 60))
        let playing = try snapshot(NowPlayingProgressView(timing: timing, isPlaying: true, date: date.addingTimeInterval(60)).padding(10).background(.black), size: CGSize(width: 400, height: 60))
        let unknown = try snapshot(NowPlayingProgressView(timing: nil, isPlaying: false, date: date).padding(10).background(.black), size: CGSize(width: 400, height: 60))
        #expect(paused.tiffRepresentation != playing.tiffRepresentation && unknown.tiffRepresentation != paused.tiffRepresentation)
        Attachment.record(try #require(playing.representation(using: .png, properties: [:])), named: "playback-progress.png")
    }

    @Test
    func recordsDesignedHeroAndFallbackAtExpandedSize() throws {
        let cover = ImageRenderer(content: ZStack {
            Color(red: 0.13, green: 0.22, blue: 0.3)
            Circle().fill(Color(red: 0.9, green: 0.48, blue: 0.26)).frame(width: 90, height: 90).offset(x: 32, y: -28)
            Circle().stroke(.white.opacity(0.5), lineWidth: 1).frame(width: 140, height: 140).offset(x: -20, y: 45)
        }.frame(width: 176, height: 176))
        let coverImage = try #require(cover.cgImage)
        let artwork = try #require(NSBitmapImageRep(cgImage: coverImage).representation(using: .png, properties: [:]))
        let track = NowPlayingTrack(title: "Night Drive", artist: "The Midnight", artwork: artwork, identifier: "preview", timing: NowPlayingTiming(position: 68, duration: 244))
        let provider = TestNowPlayingProvider()
        let service = NowPlayingService(provider: provider)
        service.start()
        defer { service.stop() }
        provider.onChange?(.paused(track))
        for (name, state) in [("expanded-media", NowPlayingState.paused(track)), ("expanded-clock", .unavailable)] {
            let image = try snapshot(expanded(state, service: service), size: size)
            Attachment.record(try #require(image.representation(using: .png, properties: [:])), named: "\(name).png")
        }
    }

    @Test(arguments: [false, true])
    func metadataAndMissingArtworkFitBelowCamera(paused: Bool) throws {
        let state: NowPlayingState = paused ? .paused(track) : .playing(track)
        let image = try snapshot(expanded(state), size: size)
        let baseline = try snapshot(expanded(.unavailable), size: size)
        #expect(image.tiffRepresentation != baseline.tiffRepresentation)
        let bounds = try #require(brightBounds(image))
        #expect(bounds.minY >= 54 && bounds.maxY <= 314)
        #expect(bounds.minX >= 24 && bounds.maxX <= 616)
        Attachment.record(try #require(image.representation(using: .png, properties: [:])), named: "now-playing-\(paused).png")
    }

    @Test
    func unavailableComponentHasNoSizeAndNarrowLayoutRetainsClock() throws {
        let unavailable = NSHostingView(rootView: NotchNowPlayingView(state: .unavailable)).fittingSize
        #expect(unavailable == .zero)
        for narrow in [CGSize(width: 280, height: 328), CGSize(width: 640, height: 152)] {
            #expect(try snapshot(expanded(.playing(track), size: narrow), size: narrow).tiffRepresentation == snapshot(expanded(.unavailable, size: narrow), size: narrow).tiffRepresentation)
        }
    }

    @Test
    func suppliedArtworkReplacesPlaceholderAndInvalidArtworkUsesFallback() throws {
        let renderer = ImageRenderer(content: Color.orange.frame(width: 128, height: 128))
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let withArtwork = NowPlayingTrack(title: track.title, artist: track.artist, artwork: data)
        let invalidArtwork = NowPlayingTrack(title: track.title, artist: track.artist, artwork: Data([1, 2, 3]))
        let image = try snapshot(expanded(.playing(withArtwork)), size: size)
        let placeholder = try snapshot(expanded(.playing(track)), size: size)
        #expect(image.tiffRepresentation != placeholder.tiffRepresentation)
        #expect(try snapshot(expanded(.playing(invalidArtwork)), size: size).tiffRepresentation == placeholder.tiffRepresentation)
        Attachment.record(try #require(image.representation(using: .png, properties: [:])), named: "now-playing-artwork.png")
    }

    @Test
    func liveChangesReusePanelAndHostingViewAndCompactPixelsStayUnchanged() async throws {
        let provider = TestNowPlayingProvider()
        let service = NowPlayingService(provider: provider)
        service.start()
        defer { service.stop() }
        let suite = "NotchMasterNowPlayingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(defaults: defaults)
        let battery = BatteryInformationService(provider: TestBatteryInformationProvider(information: BatteryInformation(percentage: 62, isCharging: false)))
        let display = DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry
        let controller = NotchWindowController(displays: { [display] }, reduceMotion: { true }, cursorPosition: { .zero }) { cameraHeight in
            NSHostingView(rootView: NotchView(cameraHeight: cameraHeight, batteryService: battery, preferences: preferences, nowPlayingService: service))
        }
        controller.start()
        defer { controller.stop() }
        let panel = try #require(controller.window)
        let content = try #require(panel.contentView)
        let compact = try await capture(content)
        provider.onChange?(.playing(track))
        for showNowPlaying in [false, true, false, true] {
            preferences.showNowPlaying = showNowPlaying
            #expect(try await capture(content).tiffRepresentation == compact.tiffRepresentation)
        }
        controller.toggleExpansion()
        let frame = panel.frame
        let playing = try await capture(content)
        provider.onChange?(.paused(NowPlayingTrack(title: "Next Song", artist: "Another Artist", artwork: nil)))
        #expect(try await capture(content).tiffRepresentation != playing.tiffRepresentation)
        provider.onChange?(.unavailable)
        #expect(try await capture(content).tiffRepresentation != playing.tiffRepresentation)
        #expect(controller.window === panel && panel.contentView === content && panel.frame == frame)
        #expect(controller.frameAnimation == nil && controller.isExpanded)
    }

    @Test(arguments: [false, true], [false, true])
    func settingsBindingImmediatelyRestoresClockAndBattery(showBatteryStatus: Bool, paused: Bool) async throws {
        let suite = "NotchMasterNowPlayingPreferenceViewTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let provider = TestNowPlayingProvider()
        let service = NowPlayingService(provider: provider)
        let preferences = PreferencesStore(defaults: defaults) { service.setEnabled($0) }
        preferences.showBatteryStatus = showBatteryStatus
        let batteryProvider = TestBatteryInformationProvider(information: BatteryInformation(percentage: 62, isCharging: false))
        let battery = BatteryInformationService(provider: batteryProvider)
        let controller = NotchWindowController(
            displays: { [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry] },
            reduceMotion: { true }, cursorPosition: { .zero }
        ) { cameraHeight in
            NSHostingView(rootView: NotchView(cameraHeight: cameraHeight, batteryService: battery, preferences: preferences, nowPlayingService: service))
        }
        service.start()
        controller.start()
        defer {
            controller.stop()
            service.stop()
        }
        let settings = FeaturesSettingsView(preferences: preferences, notchWindowController: controller)
        controller.toggleExpansion()
        let panel = try #require(controller.window)
        let content = try #require(panel.contentView)
        let frame = panel.frame
        let normal = try await capture(content)
        let state: NowPlayingState = paused ? .paused(track) : .playing(track)

        for _ in 0..<3 {
            provider.onChange?(state)
            #expect(try await capture(content).tiffRepresentation != normal.tiffRepresentation)
            settings.$preferences.showNowPlaying.wrappedValue = false
            #expect(!service.isObserving && service.state == .unavailable)
            #expect(try await capture(content).tiffRepresentation == normal.tiffRepresentation)
            settings.$preferences.showNowPlaying.wrappedValue = true
            #expect(service.isObserving && service.state == .unavailable)
            #expect(try await capture(content).tiffRepresentation == normal.tiffRepresentation)
        }
        #expect(provider.starts == 4 && provider.stops == 3)
        #expect(batteryProvider.observationStarts == 1 && batteryProvider.observationStops == 0)
        #expect(preferences.showBatteryStatus == showBatteryStatus)
        #expect(controller.window === panel && panel.contentView === content && panel.frame == frame)
        #expect(controller.isExpanded && controller.frameAnimation == nil)
    }

    @Test(arguments: [false, true])
    func rapidTrackTransitionsSettleOnLatestSongWithoutResizing(reduceMotion: Bool) async throws {
        let provider = TestNowPlayingProvider()
        let service = NowPlayingService(provider: provider)
        let controller = NotchWindowController(
            displays: { [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry] },
            reduceMotion: { true }, cursorPosition: { .zero }
        ) { height in
            NSHostingView(rootView: MediaTransitionTestView(service: service, cameraHeight: height, reduceMotion: reduceMotion))
        }
        service.start()
        controller.start()
        defer {
            service.stop()
            controller.stop()
        }
        provider.onChange?(.playing(track))
        let panel = try #require(controller.window)
        let content = try #require(panel.contentView)
        let compact = try await capture(content)
        controller.toggleExpansion()
        let frame = panel.frame
        let first = try await capture(content)
        let second = NowPlayingTrack(title: "Second Song", artist: "Second Artist", artwork: nil, identifier: "second")
        let latest = NowPlayingTrack(title: "Latest Song", artist: "Latest Artist", artwork: nil, identifier: "latest")
        provider.onChange?(.playing(second))
        let intermediate = try await capture(content)
        try await Task.sleep(for: .milliseconds(350))
        let secondSettled = try await capture(content)
        #expect(reduceMotion
            ? intermediate.tiffRepresentation == secondSettled.tiffRepresentation
            : intermediate.tiffRepresentation != secondSettled.tiffRepresentation)
        Attachment.record(try #require(intermediate.representation(using: .png, properties: [:])), named: "track-transition-intermediate-\(reduceMotion).png")
        provider.onChange?(.playing(track))
        try await Task.sleep(for: .milliseconds(35))
        provider.onChange?(.playing(latest))
        try await Task.sleep(for: .milliseconds(400))
        let settled = try await capture(content)
        #expect(settled.tiffRepresentation != first.tiffRepresentation)
        let scale = CGFloat(settled.pixelsWide) / content.bounds.width
        #expect(brightBounds(settled, within: CGRect(x: 220 * scale, y: 200 * scale, width: 200 * scale, height: 60 * scale)) != nil)
        #expect(brightBounds(settled, within: CGRect(x: 36 * scale, y: 278 * scale, width: 568 * scale, height: 34 * scale)) != nil)
        provider.onChange?(.playing(second))
        provider.onChange?(.playing(latest))
        try await Task.sleep(for: .milliseconds(400))
        #expect(try await capture(content).tiffRepresentation == settled.tiffRepresentation)
        #expect(service.state.track?.identity == "latest")
        #expect(controller.window === panel && panel.contentView === content && panel.frame == frame)
        #expect(controller.frameAnimation == nil && controller.isExpanded)
        Attachment.record(try #require(settled.representation(using: .png, properties: [:])), named: "latest-track-reduce-motion-\(reduceMotion).png")
        controller.toggleExpansion()
        #expect(try await capture(content).tiffRepresentation == compact.tiffRepresentation)
        #expect(provider.starts == 1 && provider.stops == 0)
    }

    private func expanded(_ state: NowPlayingState, size: CGSize? = nil, service: NowPlayingService? = nil) -> some View {
        let size = size ?? self.size
        return NotchExpandedContentView(
            date: Date(timeIntervalSince1970: 1_795_651_140), batteryInformation: BatteryInformation(percentage: 62, isCharging: false),
            panelSize: size, cameraHeight: 40, nowPlayingState: state, nowPlayingService: service
        )
        .environment(\.locale, Locale(identifier: "en_GB"))
        .environment(\.timeZone, .gmt)
        .frame(width: size.width, height: size.height - 40)
        .padding(.top, 40)
        .background(.black)
    }

    private func snapshot(_ view: some View, size: CGSize) throws -> NSBitmapImageRep {
        let image = try #require(ImageRenderer(content: view.frame(width: size.width, height: size.height)).cgImage)
        return NSBitmapImageRep(cgImage: image)
    }

    private func capture(_ view: NSView) async throws -> NSBitmapImageRep {
        try await Task.sleep(for: .milliseconds(30))
        view.layoutSubtreeIfNeeded()
        let image = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: image)
        return image
    }

    private func brightBounds(_ image: NSBitmapImageRep, within region: CGRect? = nil) -> CGRect? {
        let region = region ?? CGRect(x: 0, y: 0, width: image.pixelsWide, height: image.pixelsHigh)
        var bounds = CGRect.null
        for y in Int(region.minY)..<min(image.pixelsHigh, Int(region.maxY)) {
            for x in Int(region.minX)..<min(image.pixelsWide, Int(region.maxX)) {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.redComponent > 0.05 else { continue }
                bounds = bounds.union(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        return bounds.isNull ? nil : bounds
    }
}

@MainActor
private struct MediaTransitionTestView: View {
    let service: NowPlayingService
    let cameraHeight: CGFloat
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            NotchSurface(cameraHeight: cameraHeight).fill(.black)
            if geometry.size.height > cameraHeight {
                NotchExpandedContentView(
                    date: Date(timeIntervalSince1970: 1_795_651_140), batteryInformation: nil,
                    panelSize: geometry.size, cameraHeight: cameraHeight, nowPlayingState: service.state,
                    nowPlayingService: service, reduceMotion: reduceMotion
                )
                .frame(width: geometry.size.width, height: geometry.size.height - cameraHeight)
                .offset(y: cameraHeight)
            }
        }
        .ignoresSafeArea()
    }
}
