import AppKit
import SwiftUI
import Testing
@testable import NotchMaster

@Suite(.serialized)
@MainActor
struct NowPlayingViewTests {
    private let track = NowPlayingTrack(title: "A Long Song Title That Must Truncate Gracefully", artist: "An Artist With A Long Name", artwork: nil)
    private let size = CGSize(width: 600, height: 260)

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
        #expect(bounds.minY >= 44 && bounds.maxY <= 256)
        #expect(bounds.minX >= 24 && bounds.maxX <= 576)
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

    @Test(arguments: [CGFloat(32), CGFloat(37.5), CGFloat(40)])
    func mediaFitsReferenceIslandBelowCamera(cameraHeight: CGFloat) throws {
        let image = try snapshot(
            NotchExpandedContentView(
                date: Date(timeIntervalSince1970: 1_795_651_140),
                batteryInformation: BatteryInformation(percentage: 62, isCharging: false),
                panelSize: size, cameraHeight: cameraHeight, nowPlayingState: .paused(track)
            )
            .frame(width: size.width, height: size.height - cameraHeight)
            .padding(.top, cameraHeight)
            .background(.black), size: size
        )
        let bounds = try #require(brightBounds(image))
        #expect(bounds.minY >= cameraHeight + 4 && bounds.maxY <= size.height - 4)
        #expect(brightBounds(image, within: CGRect(x: 190, y: 140, width: 220, height: 48)) != nil)
        #expect(brightBounds(image, within: CGRect(x: 36, y: 230, width: 528, height: 26)) != nil)
        Attachment.record(try #require(image.representation(using: .png, properties: [:])), named: "reference-island-camera-\(cameraHeight).png")
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
            NSHostingView(rootView: NotchView(
                cameraHeight: cameraHeight, batteryService: battery, preferences: preferences,
                nowPlayingService: service, date: Date(timeIntervalSince1970: 1_795_651_140)
            ))
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
        #expect(brightBounds(settled, within: CGRect(x: 200 * scale, y: 134 * scale, width: 200 * scale, height: 60 * scale)) != nil)
        #expect(brightBounds(settled, within: CGRect(x: 36 * scale, y: 224 * scale, width: 528 * scale, height: 30 * scale)) != nil)
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

    @Test(arguments: NowPlayingCommand.allCases, [false, true])
    func pendingTransportPreservesHitTargetsAndFooterUntilSuccess(command: NowPlayingCommand, reduceMotion: Bool) async throws {
        try await withTransport(reduceMotion: reduceMotion, isPlaying: true) { provider, service, panel, content in
            let initial = try await transportSnapshot(content)
            let frame = panel.frame
            let buttons = try NowPlayingCommand.allCases.map { try element("now-playing-\($0)", in: content) }
            #expect(buttons.map { $0.accessibilityLabel() } == ["Previous track", "Pause", "Next track"])
            let buttonFrames = buttons.map { $0.accessibilityFrame() }
            let footerFrames = try footerFrames(in: content)
            let button = try element("now-playing-\(command)", in: content)
            #expect(button.isAccessibilityEnabled())
            #expect(button.accessibilityPerformPress())
            try await eventually { provider.commands == [command] }
            #expect(service.isPerformingCommand)
            try await Task.sleep(for: .milliseconds(150))
            let pending = try await transportSnapshot(content)
            #expect(pending.tiffRepresentation != initial.tiffRepresentation)
            let controls = CGRect(x: 200, y: 134, width: 200, height: 56)
            #expect(try pixels(pending, within: controls) != pixels(initial, within: controls))
            #expect(try footerPixels(pending) == footerPixels(initial))
            #expect(try self.footerFrames(in: content) == footerFrames)
            #expect(buttons.map { $0.accessibilityFrame() } == buttonFrames)
            #expect(buttonFrames.map(\.size) == [CGSize(width: 44, height: 48), CGSize(width: 48, height: 48), CGSize(width: 44, height: 48)])
            for button in buttons {
                #expect(!button.isAccessibilityEnabled())
                #expect(button.accessibilityValue() as? String == "Updating Music")
                _ = button.accessibilityPerformPress()
            }
            #expect(try element("now-playing-command-status", in: content).accessibilityLabel()?.contains("Updating Music") == true)
            service.perform(command)
            await Task.yield()
            #expect(provider.commands == [command])
            provider.finishCommand()
            try await eventually { !service.isPerformingCommand }
            try await Task.sleep(for: .milliseconds(150))
            #expect(service.controlError == nil)
            #expect(try await transportSnapshot(content).tiffRepresentation == initial.tiffRepresentation)
            #expect(buttons.allSatisfy { $0.isAccessibilityEnabled() })
            #expect(panel.frame == frame && panel.contentView === content)
            #expect(!panel.canBecomeKey && !panel.canBecomeMain)
            Attachment.record(try #require(pending.representation(using: .png, properties: [:])), named: "transport-pending-\(command)-\(reduceMotion).png")
        }
    }

    @Test(arguments: NowPlayingCommand.allCases, [false, true])
    func failedTransportPreservesFooterAndRecoversOnRetry(command: NowPlayingCommand, reduceMotion: Bool) async throws {
        try await withTransport(reduceMotion: reduceMotion) { provider, service, panel, content in
            let initial = try await transportSnapshot(content)
            let frame = panel.frame
            let footerFrames = try footerFrames(in: content)
            let button = try element("now-playing-\(command)", in: content)
            let buttonFrame = button.accessibilityFrame()
            provider.rejectsCommands = true
            #expect(button.accessibilityPerformPress())
            try await eventually { provider.commands == [command] }
            provider.finishCommand()
            try await eventually { !service.isPerformingCommand }
            try await Task.sleep(for: .milliseconds(150))
            let failed = try await transportSnapshot(content)
            let error = try #require(service.controlError)
            #expect(failed.tiffRepresentation != initial.tiffRepresentation)
            #expect(try footerPixels(failed) == footerPixels(initial))
            #expect(try self.footerFrames(in: content) == footerFrames)
            let status = try element("now-playing-command-status", in: content)
            #expect(status.accessibilityLabel()?.contains(error) == true)
            #expect(status.accessibilityFrame().maxY <= button.accessibilityFrame().minY)
            #expect(button.accessibilityFrame() == buttonFrame && button.isAccessibilityEnabled())
            provider.rejectsCommands = false
            #expect(button.accessibilityPerformPress())
            try await eventually { provider.commands.count == 2 }
            #expect(service.controlError == nil && service.isPerformingCommand)
            let retry = try await transportSnapshot(content)
            #expect(try footerPixels(retry) == footerPixels(initial))
            #expect(try element("now-playing-command-status", in: content).accessibilityLabel()?.contains("Updating Music") == true)
            provider.finishCommand()
            try await eventually { !service.isPerformingCommand }
            try await Task.sleep(for: .milliseconds(150))
            #expect(try await transportSnapshot(content).tiffRepresentation == initial.tiffRepresentation)
            #expect(service.controlError == nil && provider.commands == [command, command])
            #expect(panel.frame == frame && panel.contentView === content)
            Attachment.record(try #require(failed.representation(using: .png, properties: [:])), named: "transport-failed-\(command)-\(reduceMotion).png")
        }
    }

    private func withTransport(
        reduceMotion: Bool,
        isPlaying: Bool = false,
        body: (TestNowPlayingProvider, NowPlayingService, NSWindow, NSView) async throws -> Void
    ) async throws {
        let provider = TestNowPlayingProvider()
        provider.suspendsCommands = true
        let service = NowPlayingService(provider: provider)
        let controller = NotchWindowController(
            displays: { [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry] },
            reduceMotion: { true }, cursorPosition: { .zero }
        ) { height in
            NSHostingView(rootView: MediaTransitionTestView(
                service: service, cameraHeight: height, reduceMotion: reduceMotion,
                batteryInformation: BatteryInformation(percentage: 62, isCharging: false)
            ))
        }
        service.start()
        provider.onChange?(isPlaying ? .playing(track) : .paused(track))
        controller.start()
        controller.toggleExpansion()
        defer {
            provider.finishCommand()
            service.stop()
            controller.stop()
        }
        let panel = try #require(controller.window)
        try await body(provider, service, panel, try #require(panel.contentView))
    }

    private func element(_ identifier: String, in view: NSView) throws -> NativeAccessibilityElement {
        try #require(accessibilityElements(NativeAccessibilityElement(object: view)).first { $0.accessibilityIdentifier() == identifier }, "Missing \(identifier)")
    }

    private func accessibilityElements(_ element: NativeAccessibilityElement) -> [NativeAccessibilityElement] {
        [element] + element.children.flatMap { accessibilityElements($0) }
    }

    private func footerFrames(in view: NSView) throws -> [CGRect] {
        try ["now-playing-clock", "now-playing-date", "now-playing-battery"].map {
            let frame = try element($0, in: view).accessibilityFrame()
            #expect(frame.width > 0 && frame.height > 0)
            return frame
        }
    }

    private func footerPixels(_ image: NSBitmapImageRep) throws -> Data {
        let rect = CGRect(x: 24, y: DisplayGeometry.expandedSize.height - 40, width: DisplayGeometry.expandedSize.width - 48, height: 32)
        return try pixels(image, within: rect)
    }

    private func pixels(_ image: NSBitmapImageRep, within rect: CGRect) throws -> Data {
        let scale = CGFloat(image.pixelsWide) / DisplayGeometry.expandedSize.width
        let crop = try #require(image.cgImage?.cropping(to: CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)))
        #expect(brightBounds(NSBitmapImageRep(cgImage: crop)) != nil)
        return try #require(NSBitmapImageRep(cgImage: crop).tiffRepresentation)
    }

    private func transportSnapshot(_ view: NSView) async throws -> NSBitmapImageRep {
        try await Task.sleep(for: .milliseconds(30))
        view.layoutSubtreeIfNeeded()
        let host = try #require(view as? NSHostingView<MediaTransitionTestView>)
        return try snapshot(host.rootView, size: host.bounds.size)
    }

    private func eventually(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(condition())
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
private struct NativeAccessibilityElement {
    let object: AnyObject

    var children: [Self] {
        (object.accessibilityChildren?() ?? []).map { Self(object: $0 as AnyObject) }
    }

    func accessibilityIdentifier() -> String? { object.accessibilityIdentifier?() }
    func accessibilityLabel() -> String? { object.accessibilityLabel?() }
    func accessibilityValue() -> Any? { object.accessibilityValue?() }
    func accessibilityFrame() -> CGRect { object.accessibilityFrame?() ?? .zero }
    func isAccessibilityEnabled() -> Bool { object.isAccessibilityEnabled?() ?? false }
    func accessibilityPerformPress() -> Bool { object.accessibilityPerformPress?() ?? false }
}

@MainActor
private struct MediaTransitionTestView: View {
    let service: NowPlayingService
    let cameraHeight: CGFloat
    let reduceMotion: Bool
    var batteryInformation: BatteryInformation? = nil

    var body: some View {
        GeometryReader { geometry in
            NotchSurface(cameraHeight: cameraHeight).fill(.black)
            if geometry.size.height > cameraHeight {
                NotchExpandedContentView(
                    date: Date(timeIntervalSince1970: 1_795_651_140), batteryInformation: batteryInformation,
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
