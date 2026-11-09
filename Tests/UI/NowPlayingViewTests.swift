import AppKit
import SwiftUI
import Testing
@testable import NotchMaster

@Suite(.serialized)
@MainActor
struct NowPlayingViewTests {
    private let track = NowPlayingTrack(title: "A Long Song Title That Must Truncate Gracefully", artist: "An Artist With A Long Name", artwork: nil)
    private let size = CGSize(width: 480, height: 152)

    @Test(arguments: [false, true])
    func metadataAndMissingArtworkFitBelowCamera(paused: Bool) throws {
        let state: NowPlayingState = paused ? .paused(track) : .playing(track)
        let image = try snapshot(expanded(state), size: size)
        let baseline = try snapshot(expanded(.unavailable), size: size)
        #expect(image.tiffRepresentation != baseline.tiffRepresentation)
        let bounds = try #require(brightBounds(image))
        #expect(bounds.minY >= 54 && bounds.maxY <= 138)
        #expect(bounds.minX >= 24 && bounds.maxX <= 456)
        Attachment.record(try #require(image.representation(using: .png, properties: [:])), named: "now-playing-\(paused).png")
    }

    @Test
    func unavailableComponentHasNoSizeAndNarrowLayoutRetainsClock() throws {
        let unavailable = NSHostingView(rootView: NotchNowPlayingView(state: .unavailable)).fittingSize
        #expect(unavailable == .zero)
        let narrow = CGSize(width: 280, height: 152)
        #expect(try snapshot(expanded(.playing(track), size: narrow), size: narrow).tiffRepresentation == snapshot(expanded(.unavailable, size: narrow), size: narrow).tiffRepresentation)
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
        #expect(try await capture(content).tiffRepresentation == compact.tiffRepresentation)
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

    private func expanded(_ state: NowPlayingState, size: CGSize? = nil) -> some View {
        let size = size ?? self.size
        return NotchExpandedContentView(
            date: Date(timeIntervalSince1970: 1_795_651_140), batteryInformation: BatteryInformation(percentage: 62, isCharging: false),
            panelSize: size, cameraHeight: 40, nowPlayingState: state
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

    private func brightBounds(_ image: NSBitmapImageRep) -> CGRect? {
        var bounds = CGRect.null
        for y in 0..<image.pixelsHigh {
            for x in 0..<image.pixelsWide {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), color.redComponent > 0.05 else { continue }
                bounds = bounds.union(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        return bounds.isNull ? nil : bounds
    }
}
