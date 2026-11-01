import AppKit
import SwiftUI
import Testing
@testable import NotchMaster

@Suite(.serialized)
@MainActor
struct NotchViewTests {
    @Test(arguments: [CGFloat(32), CGFloat(40), CGFloat(80)])
    func compactRenderingMatchesTheOriginalSurface(cameraHeight: CGFloat) throws {
        let size = CGSize(width: 180, height: cameraHeight)
        let compact = try snapshot(NotchView(cameraHeight: cameraHeight), size: size)
        let original = try snapshot(
            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous)
                .fill(.black)
                .ignoresSafeArea(),
            size: size
        )

        #expect(compact.tiffRepresentation == original.tiffRepresentation)
        #expect(brightBounds(in: compact) == nil)
    }

    @Test
    func contentFadesOnlyAfterItFitsAndReversesAtTheSameSize() {
        let contentSize = CGSize(width: 240, height: 52)
        var increasing: [Double] = []
        for height in 32...120 {
            let opacity = NotchView.contentOpacity(
                panelSize: CGSize(width: 380, height: height),
                contentSize: contentSize,
                cameraHeight: 32
            )
            increasing.append(opacity)
            if height <= 100 { #expect(opacity == 0) }
            if height >= 108 { #expect(opacity == 1) }
        }

        #expect(increasing == increasing.sorted())
        #expect(increasing.contains { $0 > 0 && $0 < 1 })
        let decreasing = (32...120).reversed().map { height in
            NotchView.contentOpacity(
                panelSize: CGSize(width: 380, height: height),
                contentSize: contentSize,
                cameraHeight: 32
            )
        }
        #expect(decreasing == increasing.reversed())
        #expect(NotchView.contentOpacity(
            panelSize: CGSize(width: 260, height: 120),
            contentSize: contentSize,
            cameraHeight: 32
        ) == 0)
    }

    @Test(arguments: ["en_US", "en_GB", "de_DE", "fr_FR", "ja_JP", "ar_SA"])
    func localizedContentFitsBelowTheCamera(localeIdentifier: String) throws {
        let locale = Locale(identifier: localeIdentifier)
        let clock = NotchClockView(date: Date(timeIntervalSince1970: 1_795_651_140))
            .environment(\.locale, locale)
            .environment(\.timeZone, try #require(TimeZone(secondsFromGMT: 0)))
        let size = NSHostingView(rootView: clock).fittingSize

        #expect(NotchView.contentOpacity(
            panelSize: CGSize(width: 380, height: 120),
            contentSize: size,
            cameraHeight: 40
        ) == 1)

        let image = try snapshot(
            NotchView(cameraHeight: 40).environment(\.locale, locale),
            size: CGSize(width: 380, height: 120)
        )
        Attachment.record(try #require(image.representation(using: .png, properties: [:])), named: "clock-\(localeIdentifier).png")
        let bounds = try #require(brightBounds(in: image))
        #expect(bounds.minY >= 48)
        #expect(bounds.maxY <= 112)
        #expect(bounds.minX >= 16)
        #expect(bounds.maxX <= 364)
    }

    @Test
    func hostingViewTracksAnimatedPanelResizingAndReversal() async throws {
        let display = DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry
        let controller = NotchWindowController(
            displays: { [display] },
            reduceMotion: { false },
            cursorPosition: { .zero }
        ) { cameraHeight in
            NSHostingView(rootView: NotchView(cameraHeight: cameraHeight))
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

    private func brightBounds(in image: NSBitmapImageRep) -> CGRect? {
        var bounds = CGRect.null
        for y in 0..<image.pixelsHigh {
            for x in 0..<image.pixelsWide {
                guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.05, color.redComponent > 0.05 else { continue }
                bounds = bounds.union(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        return bounds.isNull ? nil : bounds
    }
}
