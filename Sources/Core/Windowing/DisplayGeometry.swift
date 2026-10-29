import AppKit
import CoreGraphics

struct DisplayGeometry {
    let name: String
    let frame: CGRect
    let safeAreaTop: CGFloat
    let auxiliaryTopLeftArea: CGRect?
    let auxiliaryTopRightArea: CGRect?
    let backingScaleFactor: CGFloat
    let isBuiltIn: Bool
    let isActive: Bool
    let isMirrored: Bool

    @MainActor
    static func current() -> [DisplayGeometry] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let displayID = CGDirectDisplayID(number.uint32Value)
            return DisplayGeometry(
                name: screen.localizedName,
                frame: screen.frame,
                safeAreaTop: screen.safeAreaInsets.top,
                auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
                auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
                backingScaleFactor: screen.backingScaleFactor,
                isBuiltIn: CGDisplayIsBuiltin(displayID) != 0,
                isActive: CGDisplayIsActive(displayID) != 0 && CGDisplayIsAsleep(displayID) == 0,
                isMirrored: CGDisplayIsInMirrorSet(displayID) != 0
            )
        }
    }

    static func previewPlacement(in displays: [DisplayGeometry]) -> Result<NotchPreviewPlacement, NotchPreviewUnavailableReason> {
        let builtInDisplays = displays.filter(\.isBuiltIn)
        guard !builtInDisplays.isEmpty else { return .failure(.noBuiltInDisplay) }
        guard builtInDisplays.count == 1, let display = builtInDisplays.first else {
            return .failure(.ambiguousBuiltInDisplay)
        }
        guard display.isActive else { return .failure(.inactiveBuiltInDisplay) }
        guard !display.isMirrored else { return .failure(.mirroredDisplay) }
        return display.previewPlacement()
    }

    private func previewPlacement() -> Result<NotchPreviewPlacement, NotchPreviewUnavailableReason> {
        guard safeAreaTop.isFinite, safeAreaTop >= 0 else { return .failure(.invalidGeometry) }
        guard safeAreaTop > 0 else { return .failure(.noNotch) }
        guard Self.isValid(frame), safeAreaTop < frame.height,
              backingScaleFactor.isFinite, backingScaleFactor > 0,
              let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea,
              Self.isValid(left), Self.isValid(right) else {
            return .failure(.invalidGeometry)
        }

        let tolerance = 1 / backingScaleFactor
        let safeTop = frame.maxY - safeAreaTop
        guard abs(left.minX - frame.minX) <= tolerance,
              abs(right.maxX - frame.maxX) <= tolerance,
              abs(left.maxY - frame.maxY) <= tolerance,
              abs(right.maxY - frame.maxY) <= tolerance,
              abs(left.minY - safeTop) <= tolerance,
              abs(right.minY - safeTop) <= tolerance,
              left.maxX <= frame.midX, right.minX >= frame.midX,
              left.maxX < right.minX else {
            return .failure(.invalidGeometry)
        }

        let previewFrame = CGRect(
            x: left.maxX,
            y: safeTop,
            width: right.minX - left.maxX,
            height: safeAreaTop
        )
        guard Self.isValid(previewFrame), frame.contains(previewFrame) else {
            return .failure(.invalidGeometry)
        }
        return .success(NotchPreviewPlacement(frame: previewFrame, displayName: name))
    }

    private static func isValid(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.width.isFinite && rect.height.isFinite
            && rect.width > 0 && rect.height > 0
            && rect.maxX.isFinite && rect.maxY.isFinite
    }
}

struct NotchPreviewPlacement: Equatable {
    let frame: CGRect
    let displayName: String
}

enum NotchPreviewUnavailableReason: Error, Equatable {
    case noBuiltInDisplay
    case ambiguousBuiltInDisplay
    case inactiveBuiltInDisplay
    case mirroredDisplay
    case noNotch
    case invalidGeometry

    var message: String {
        switch self {
        case .noBuiltInDisplay:
            "Notch preview unavailable: no built-in display is connected."
        case .ambiguousBuiltInDisplay:
            "Notch preview unavailable: a single built-in display could not be identified."
        case .inactiveBuiltInDisplay:
            "Notch preview unavailable: the built-in display is inactive or asleep."
        case .mirroredDisplay:
            "Notch preview unavailable while the built-in display is mirrored."
        case .noNotch:
            "Notch preview unavailable: the built-in display does not report a physical notch."
        case .invalidGeometry:
            "Notch preview unavailable: macOS did not report supported notch geometry."
        }
    }
}
