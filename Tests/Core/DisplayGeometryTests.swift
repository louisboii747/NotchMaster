import AppKit
import Testing
@testable import NotchMaster

struct DisplayFixture {
    var name = "Built-in Test Display"
    var frame: CGRect
    var safeAreaTop: CGFloat = 32
    var left: CGRect?
    var right: CGRect?
    var scale: CGFloat = 2
    var isBuiltIn = true
    var isActive = true
    var isMirrored = false

    init(origin: CGPoint = .zero) {
        frame = CGRect(origin: origin, size: CGSize(width: 1700, height: 1100))
        left = CGRect(x: origin.x, y: origin.y + 1068, width: 760, height: 32)
        right = CGRect(x: origin.x + 940, y: origin.y + 1068, width: 760, height: 32)
    }

    var geometry: DisplayGeometry {
        DisplayGeometry(
            name: name,
            frame: frame,
            safeAreaTop: safeAreaTop,
            auxiliaryTopLeftArea: left,
            auxiliaryTopRightArea: right,
            backingScaleFactor: scale,
            isBuiltIn: isBuiltIn,
            isActive: isActive,
            isMirrored: isMirrored
        )
    }
}

@Suite
struct DisplayGeometryTests {
    @Test(arguments: [CGPoint.zero, CGPoint(x: -2100, y: 700), CGPoint(x: 1800, y: -1200)])
    func usesBuiltInGlobalGeometryWhenExternalDisplayComesFirst(origin: CGPoint) throws {
        let builtIn = DisplayFixture(origin: origin)
        var external = DisplayFixture()
        external.isBuiltIn = false

        let placement = try DisplayGeometry.previewPlacement(in: [external.geometry, builtIn.geometry]).get()

        #expect(placement.displayName == builtIn.name)
        #expect(placement.frame == CGRect(x: origin.x + 760, y: origin.y + 1068, width: 180, height: 32))
        #expect(placement.frame.maxY == builtIn.frame.maxY)
        #expect(builtIn.frame.contains(placement.frame))
    }

    @Test
    func derivesNotchSizeFromReportedAreas() throws {
        var display = DisplayFixture()
        display.safeAreaTop = 40
        display.left = CGRect(x: 0, y: 1060, width: 740, height: 40)
        display.right = CGRect(x: 960, y: 1060, width: 740, height: 40)

        let placement = try DisplayGeometry.previewPlacement(in: [display.geometry]).get()

        #expect(placement.frame == CGRect(x: 740, y: 1060, width: 220, height: 40))
    }

    @Test(
        arguments: [CGPoint.zero, CGPoint(x: -2100, y: 700), CGPoint(x: 1800, y: -1200)],
        [CGFloat(1), CGFloat(2)]
    )
    func expandedPreviewSurroundsReportedNotch(origin: CGPoint, scale: CGFloat) throws {
        var display = DisplayFixture(origin: origin)
        display.scale = scale
        display.safeAreaTop = 40
        display.left = CGRect(x: origin.x, y: origin.y + 1060, width: 740, height: 40)
        display.right = CGRect(x: origin.x + 960, y: origin.y + 1060, width: 740, height: 40)
        var external = DisplayFixture()
        external.isBuiltIn = false
        let displays = [external.geometry, display.geometry]
        let compact = try DisplayGeometry.previewPlacement(in: displays).get()

        let expanded = try DisplayGeometry.previewPlacement(in: displays, isExpanded: true).get()

        #expect(expanded.displayName == display.name)
        #expect(expanded.frame == CGRect(x: origin.x + 660, y: origin.y + 980, width: 380, height: 120))
        #expect(expanded.frame.midX == compact.frame.midX)
        #expect(expanded.frame.maxY == display.frame.maxY)
        #expect(expanded.frame.minX < compact.frame.minX)
        #expect(expanded.frame.maxX > compact.frame.maxX)
        #expect(expanded.frame.minY < compact.frame.minY)
        #expect(expanded.frame.contains(compact.frame))
        #expect(display.frame.contains(expanded.frame))
    }

    @Test(arguments: [CGFloat(380), CGFloat(420)])
    func expandedPreviewNeverNarrowsPhysicalNotch(notchWidth: CGFloat) throws {
        var display = DisplayFixture()
        let sideWidth = (display.frame.width - notchWidth) / 2
        display.left = CGRect(x: 0, y: 1068, width: sideWidth, height: 32)
        display.right = CGRect(x: sideWidth + notchWidth, y: 1068, width: sideWidth, height: 32)
        let compact = try DisplayGeometry.previewPlacement(in: [display.geometry]).get()

        let expanded = try DisplayGeometry.previewPlacement(in: [display.geometry], isExpanded: true).get()

        #expect(expanded.frame.width == notchWidth)
        #expect(expanded.frame.height == 120)
        #expect(expanded.frame.midX == compact.frame.midX)
        #expect(expanded.frame.maxY == display.frame.maxY)
        #expect(expanded.frame.contains(compact.frame))
        #expect(display.frame.contains(expanded.frame))
    }

    @Test(arguments: [CGPoint.zero, CGPoint(x: -2100, y: 700)])
    func expandedPreviewClampsExtensionsWhileStayingCenteredOnNotch(origin: CGPoint) throws {
        var display = DisplayFixture(origin: origin)
        display.frame.size = CGSize(width: 400, height: 100)
        display.left = CGRect(x: origin.x, y: origin.y + 68, width: 170, height: 32)
        display.right = CGRect(x: origin.x + 350, y: origin.y + 68, width: 50, height: 32)
        let compact = try DisplayGeometry.previewPlacement(in: [display.geometry]).get()

        let expanded = try DisplayGeometry.previewPlacement(in: [display.geometry], isExpanded: true).get()

        #expect(expanded.frame == CGRect(x: origin.x + 120, y: origin.y, width: 280, height: 100))
        #expect(expanded.frame.midX == compact.frame.midX)
        #expect(expanded.frame.midX != display.frame.midX)
        #expect(expanded.frame.maxY == display.frame.maxY)
        #expect(expanded.frame.contains(compact.frame))
        #expect(display.frame.contains(expanded.frame))
    }

    @Test
    func acceptsDisplayWithoutRoomForVisualExtensions() throws {
        var display = DisplayFixture()
        display.frame.size.height = 36
        display.left?.origin.y = 4
        display.right?.origin.y = 4

        let placement = try DisplayGeometry.previewPlacement(in: [display.geometry]).get()

        #expect(placement.frame == CGRect(x: 760, y: 4, width: 180, height: 32))
        #expect(display.frame.contains(placement.frame))
    }

    @Test(arguments: [false, true])
    func rejectsExternalOnlyAndAmbiguousDisplays(isExpanded: Bool) {
        var external = DisplayFixture()
        external.isBuiltIn = false
        #expect(DisplayGeometry.previewPlacement(in: [], isExpanded: isExpanded) == .failure(.noBuiltInDisplay))
        #expect(DisplayGeometry.previewPlacement(in: [external.geometry], isExpanded: isExpanded)
            == .failure(.noBuiltInDisplay))
        #expect(DisplayGeometry.previewPlacement(
            in: [DisplayFixture().geometry, DisplayFixture().geometry], isExpanded: isExpanded
        )
            == .failure(.ambiguousBuiltInDisplay))
    }

    @Test(arguments: [false, true])
    func rejectsInactiveMirroredAndUnnotchedDisplays(isExpanded: Bool) {
        var display = DisplayFixture()
        display.isActive = false
        #expect(DisplayGeometry.previewPlacement(in: [display.geometry], isExpanded: isExpanded)
            == .failure(.inactiveBuiltInDisplay))
        display.isActive = true
        display.isMirrored = true
        #expect(DisplayGeometry.previewPlacement(in: [display.geometry], isExpanded: isExpanded) == .failure(.mirroredDisplay))
        display.isMirrored = false
        display.safeAreaTop = 0
        display.left = nil
        display.right = nil
        #expect(DisplayGeometry.previewPlacement(in: [display.geometry], isExpanded: isExpanded) == .failure(.noNotch))
    }

    enum InvalidGeometry: CaseIterable {
        case missingLeft, missingRight, emptyArea, overlappingAreas, offCenterGap
        case outsideScreen, wrongTop, wrongSafeBoundary, nonFiniteTop, negativeTop
        case nonFiniteFrame, negativeFrame, excessiveTop, invalidScale, nonFiniteScale
    }

    @Test(arguments: InvalidGeometry.allCases, [false, true])
    func rejectsIncompleteOrInconsistentGeometry(_ invalid: InvalidGeometry, isExpanded: Bool) {
        var display = DisplayFixture()
        switch invalid {
        case .missingLeft:
            display.left = nil
        case .missingRight:
            display.right = nil
        case .emptyArea:
            display.left = .zero
        case .overlappingAreas:
            display.left?.size.width = 1000
        case .offCenterGap:
            display.left?.size.width = 900
        case .outsideScreen:
            display.left?.origin.x = -50
        case .wrongTop:
            display.right?.size.height = 20
        case .wrongSafeBoundary:
            display.right?.origin.y -= 10
        case .nonFiniteTop:
            display.safeAreaTop = .nan
        case .negativeTop:
            display.safeAreaTop = -32
        case .nonFiniteFrame:
            display.frame.origin.x = .infinity
        case .negativeFrame:
            display.frame.size.width = -1700
        case .excessiveTop:
            display.safeAreaTop = display.frame.height
        case .invalidScale:
            display.scale = 0
        case .nonFiniteScale:
            display.scale = .infinity
        }

        #expect(DisplayGeometry.previewPlacement(in: [display.geometry], isExpanded: isExpanded) == .failure(.invalidGeometry))
    }
}
