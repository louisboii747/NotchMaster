import AppKit
import SwiftUI
import Testing
@testable import NotchMaster

@Suite(.serialized)
@MainActor
struct NotchViewTests {
    private let expandedSize = CGSize(width: 480, height: 152)
    private let preferencesSuiteName = "NotchMasterNotchViewTests.\(UUID().uuidString)"

    @Test(arguments: [false, true])
    func batteryFitsBesideClockWithoutMovingIt(isCharging: Bool) throws {
        let size = expandedSize
        let clock = try snapshot(expandedContent(information: nil, size: size), size: size)
        let clockBounds = try #require(brightBounds(in: clock))
        let image = try snapshot(expandedContent(
            information: BatteryInformation(percentage: 62, isCharging: isCharging), size: size
        ), size: size)
        let bounds = try #require(brightBounds(in: image))
        let batteryBounds = try #require(brightBounds(in: image, startingAtX: Int(clockBounds.maxX)))
        let originalClock = try #require(clock.cgImage?.cropping(to: clockBounds))
        let retainedClock = try #require(image.cgImage?.cropping(to: clockBounds))

        #expect(NSBitmapImageRep(cgImage: originalClock).tiffRepresentation == NSBitmapImageRep(cgImage: retainedClock).tiffRepresentation)
        #expect(bounds.minX == clockBounds.minX && bounds.maxX > clockBounds.maxX)
        #expect(batteryBounds.minX - clockBounds.maxX >= 24)
        #expect(bounds.minY >= 54 && bounds.maxY <= 138)
        #expect(bounds.maxX <= 456)
        Attachment.record(try #require(image.representation(using: .png, properties: [:])), named: "battery-\(isCharging).png")
    }

    @Test
    func constrainedWidthOmitsBatteryWithoutHidingClock() throws {
        let clockView = NotchClockView(date: Date(timeIntervalSince1970: 1_795_651_140))
            .environment(\.locale, Locale(identifier: "en_GB"))
            .environment(\.timeZone, .gmt)
        let size = CGSize(width: ceil(NSHostingView(rootView: clockView).fittingSize.width) + 56, height: expandedSize.height)
        let clock = try snapshot(expandedContent(information: nil, size: size), size: size)
        let image = try snapshot(expandedContent(
            information: BatteryInformation(percentage: 100, isCharging: true), size: size
        ), size: size)
        #expect(brightBounds(in: clock) != nil)
        #expect(image.tiffRepresentation == clock.tiffRepresentation)
    }

    @Test(arguments: [0, 25, 50, 75, 100], [false, true])
    func usesAvailableBatterySymbols(percentage: Int, isCharging: Bool) {
        let view = NotchBatteryView(information: BatteryInformation(percentage: percentage, isCharging: isCharging))
        #expect(NSImage(systemSymbolName: view.symbolName, accessibilityDescription: nil) != nil)
    }

    @Test(arguments: [CGFloat(32), CGFloat(40), CGFloat(80)], [false, true])
    func compactRenderingMatchesTheOriginalSurface(cameraHeight: CGFloat, isCharging: Bool) throws {
        let preferences = try makePreferences()
        defer { clearPreferences() }
        let size = CGSize(width: 180, height: cameraHeight)
        let provider = TestBatteryInformationProvider(information: BatteryInformation(percentage: 62, isCharging: isCharging))
        let service = BatteryInformationService(provider: provider)
        let original = try snapshot(
            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous)
                .fill(.black)
                .ignoresSafeArea(),
            size: size
        )

        for showBatteryStatus in [false, true] {
            preferences.showBatteryStatus = showBatteryStatus
            let compact = try snapshot(NotchView(
                cameraHeight: cameraHeight, batteryService: service, preferences: preferences
            ), size: size)
            #expect(compact.tiffRepresentation == original.tiffRepresentation)
            #expect(brightBounds(in: compact) == nil)
        }
    }

    @Test(arguments: [CGSize(width: 480, height: 152), CGSize(width: 300, height: 112), CGSize(width: 220, height: 80)])
    func expandedSurfaceJoinsTheTopWithInwardShouldersAndRoundedBottomCorners(size: CGSize) throws {
        let preferences = try makePreferences()
        defer { clearPreferences() }
        let service = BatteryInformationService(provider: TestBatteryInformationProvider())
        let image = try snapshot(NotchView(cameraHeight: 40, batteryService: service, preferences: preferences), size: size)

        for x in [8, image.pixelsWide - 9] {
            #expect(try #require(image.colorAt(x: x, y: 0)).alphaComponent > 0.95)
            #expect(try #require(image.colorAt(x: x, y: 24)).alphaComponent < 0.05)
        }
        for x in [16, image.pixelsWide - 17] {
            #expect(try #require(image.colorAt(x: x, y: 32)).alphaComponent > 0.95)
            #expect(try #require(image.colorAt(x: x, y: image.pixelsHigh - 3)).alphaComponent < 0.05)
        }
        #expect(image.colorAt(x: image.pixelsWide / 2, y: 2)?.alphaComponent == 1)
        Attachment.record(
            try #require(image.representation(using: .png, properties: [:])),
            named: "surface-\(Int(size.width))x\(Int(size.height)).png"
        )
    }

    @Test
    func contentFadesOnlyAfterItFitsAndReversesAtTheSameSize() {
        let contentSize = CGSize(width: 240, height: 52)
        var increasing: [Double] = []
        for height in 32...Int(expandedSize.height) {
            let opacity = NotchView.contentOpacity(
                panelSize: CGSize(width: Int(expandedSize.width), height: height),
                contentSize: contentSize,
                cameraHeight: 32
            )
            increasing.append(opacity)
            if height <= 112 { #expect(opacity == 0) }
            if height >= 120 { #expect(opacity == 1) }
        }

        #expect(increasing == increasing.sorted())
        #expect(increasing.contains { $0 > 0 && $0 < 1 })
        let decreasing = (32...Int(expandedSize.height)).reversed().map { height in
            NotchView.contentOpacity(
                panelSize: CGSize(width: Int(expandedSize.width), height: height),
                contentSize: contentSize,
                cameraHeight: 32
            )
        }
        #expect(decreasing == increasing.reversed())
        #expect(NotchView.contentOpacity(
            panelSize: CGSize(width: 280, height: expandedSize.height),
            contentSize: contentSize,
            cameraHeight: 32
        ) == 0)
    }

    @Test(arguments: ["en_US", "en_GB", "de_DE", "fr_FR", "ja_JP", "ar_SA"])
    func localizedContentFitsBelowTheCamera(localeIdentifier: String) throws {
        let preferences = try makePreferences()
        defer { clearPreferences() }
        let locale = Locale(identifier: localeIdentifier)
        let clock = NotchClockView(date: Date(timeIntervalSince1970: 1_795_651_140))
            .environment(\.locale, locale)
            .environment(\.timeZone, try #require(TimeZone(secondsFromGMT: 0)))
        let size = NSHostingView(rootView: clock).fittingSize

        #expect(NotchView.contentOpacity(
            panelSize: expandedSize,
            contentSize: size,
            cameraHeight: 40
        ) == 1)

        let image = try snapshot(
            NotchView(
                cameraHeight: 40,
                batteryService: BatteryInformationService(provider: TestBatteryInformationProvider()),
                preferences: preferences
            )
                .environment(\.locale, locale),
            size: expandedSize
        )
        Attachment.record(try #require(image.representation(using: .png, properties: [:])), named: "clock-\(localeIdentifier).png")
        let bounds = try #require(brightBounds(in: image))
        #expect(bounds.minY >= 54)
        #expect(bounds.maxY <= 138)
        #expect(bounds.minX >= 24)
        #expect(bounds.maxX <= 456)
    }

    @Test
    func hostingViewTracksAnimatedPanelResizingAndReversal() async throws {
        let preferences = try makePreferences()
        defer { clearPreferences() }
        let display = DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry
        let provider = TestBatteryInformationProvider(information: BatteryInformation(percentage: 62, isCharging: false))
        let batteryService = BatteryInformationService(provider: provider)
        let controller = NotchWindowController(
            displays: { [display] },
            reduceMotion: { false },
            cursorPosition: { .zero }
        ) { cameraHeight in
            NSHostingView(rootView: NotchView(cameraHeight: cameraHeight, batteryService: batteryService, preferences: preferences))
        }
        defer { controller.hidePreview() }
        controller.showPreview()
        let panel = try #require(controller.window)
        let hostingView = try #require(panel.contentView as? NSHostingView<NotchView>)
        #expect(try await displayedTextBounds(in: hostingView) == nil)

        controller.toggleExpansion()
        let expansion = try #require(controller.frameAnimation)
        expansion.stop()
        expansion.currentProgress = 0.25
        #expect(try await displayedTextBounds(in: hostingView) == nil)
        expansion.currentProgress = 0.9
        let bounds = try #require(try await displayedTextBounds(in: hostingView))
        #expect(bounds.minY >= 40)
        let reversalFrame = panel.frame

        controller.toggleExpansion()
        #expect(panel.frame == reversalFrame)
        #expect(panel.contentView === hostingView)
        let collapse = try #require(controller.frameAnimation)
        collapse.stop()
        collapse.currentProgress = 1
        #expect(try await displayedTextBounds(in: hostingView) == nil)
        #expect(hostingView.frame.size == panel.frame.size)
    }

    @Test
    func hostingViewObservesBatteryChangesAndClearsUnavailableInformation() async throws {
        let preferences = try makePreferences()
        defer { clearPreferences() }
        let provider = TestBatteryInformationProvider()
        let service = BatteryInformationService(provider: provider)
        let controller = NotchWindowController(
            displays: { [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry] },
            reduceMotion: { true },
            cursorPosition: { .zero }
        ) { cameraHeight in
            NSHostingView(rootView: NotchView(cameraHeight: cameraHeight, batteryService: service, preferences: preferences))
        }
        defer { controller.hidePreview() }
        controller.showPreview()
        controller.toggleExpansion()
        let content = try #require(controller.window?.contentView)
        let original = try #require(try await displayedTextBounds(in: content))

        provider.information = BatteryInformation(percentage: 62, isCharging: true)
        provider.sendChange()
        let withBattery = try #require(try await displayedTextBounds(in: content))
        #expect(withBattery.minX == original.minX && withBattery.maxX > original.maxX)
        #expect(controller.window?.contentView === content)

        provider.information = nil
        provider.sendChange()
        #expect(try await displayedTextBounds(in: content) == original)
        #expect(provider.reads == 3 && provider.observationStarts == 1)
    }

    @Test(arguments: [false, true], [false, true])
    func settingsBindingImmediatelyUpdatesExistingContent(isCharging: Bool, initiallyAvailable: Bool) async throws {
        let preferences = try makePreferences()
        defer { clearPreferences() }
        let information = BatteryInformation(percentage: 62, isCharging: isCharging)
        let provider = TestBatteryInformationProvider(information: initiallyAvailable ? information : nil)
        let service = BatteryInformationService(provider: provider)
        let controller = NotchWindowController(
            displays: { [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry] },
            reduceMotion: { true },
            cursorPosition: { .zero }
        ) { cameraHeight in
            NSHostingView(rootView: NotchView(cameraHeight: cameraHeight, batteryService: service, preferences: preferences))
        }
        defer { controller.hidePreview() }
        let settings = FeaturesSettingsView(preferences: preferences, notchWindowController: controller)
        controller.showPreview()
        controller.toggleExpansion()
        let panel = try #require(controller.window)
        let content = try #require(panel.contentView)
        let expandedFrame = panel.frame
        let initial = try #require(try await displayedTextBounds(in: content))

        settings.$preferences.showBatteryStatus.wrappedValue = false
        let clockOnly = try #require(try await displayedTextBounds(in: content))
        #expect(!preferences.showBatteryStatus)
        #expect(clockOnly.minX == initial.minX && clockOnly.minY == initial.minY && clockOnly.maxY == initial.maxY)
        #expect(initiallyAvailable ? clockOnly.maxX < initial.maxX : clockOnly == initial)

        provider.information = BatteryInformation(percentage: 100, isCharging: !isCharging)
        provider.sendChange()
        #expect(try await displayedTextBounds(in: content) == clockOnly)
        #expect(service.information == provider.information)

        settings.$preferences.showBatteryStatus.wrappedValue = true
        let withBattery = try #require(try await displayedTextBounds(in: content))
        #expect(withBattery.minX == clockOnly.minX && withBattery.maxX > clockOnly.maxX)
        #expect(withBattery.minY == clockOnly.minY && withBattery.maxY == clockOnly.maxY)

        provider.information = nil
        provider.sendChange()
        #expect(try await displayedTextBounds(in: content) == clockOnly)
        for showBatteryStatus in [false, true] {
            settings.$preferences.showBatteryStatus.wrappedValue = showBatteryStatus
            #expect(try await displayedTextBounds(in: content) == clockOnly)
        }

        #expect(controller.window === panel && panel.contentView === content)
        #expect(panel.frame == expandedFrame && controller.isExpanded)
        #expect(controller.frameAnimation == nil)
        #expect(provider.reads == 3 && provider.observationStarts == 1 && provider.observationStops == 0)
    }

    private func makePreferences() throws -> PreferencesStore {
        PreferencesStore(defaults: try #require(UserDefaults(suiteName: preferencesSuiteName)))
    }

    private func clearPreferences() {
        UserDefaults(suiteName: preferencesSuiteName)?.removePersistentDomain(forName: preferencesSuiteName)
    }

    private func expandedContent(information: BatteryInformation?, size: CGSize) -> some View {
        NotchExpandedContentView(
            date: Date(timeIntervalSince1970: 1_795_651_140),
            batteryInformation: information,
            panelSize: size,
            cameraHeight: 40
        )
        .environment(\.locale, Locale(identifier: "en_GB"))
        .environment(\.timeZone, .gmt)
        .frame(width: size.width, height: size.height - 40)
        .padding(.top, 40)
        .background(.black)
    }

    private func snapshot(_ view: some View, size: CGSize) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        let image = try #require(renderer.cgImage)
        return NSBitmapImageRep(cgImage: image)
    }

    private func displayedTextBounds(in view: NSView) async throws -> CGRect? {
        try await Task.sleep(for: .milliseconds(30))
        view.layoutSubtreeIfNeeded()
        let image = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: image)
        Attachment.record(try #require(image.representation(using: .png, properties: [:])), named: "host-\(Int(view.bounds.height)).png")
        let bounds = brightBounds(in: image)
        let scale = CGFloat(image.pixelsWide) / view.bounds.width
        return bounds.map { CGRect(x: $0.minX / scale, y: $0.minY / scale, width: $0.width / scale, height: $0.height / scale) }
    }

    private func brightBounds(in image: NSBitmapImageRep, startingAtX: Int = 0) -> CGRect? {
        var bounds = CGRect.null
        for y in 0..<image.pixelsHigh {
            for x in startingAtX..<image.pixelsWide {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.05, color.redComponent > 0.05 else { continue }
                bounds = bounds.union(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        return bounds.isNull ? nil : bounds
    }
}
