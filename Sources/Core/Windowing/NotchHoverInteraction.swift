import Foundation

struct NotchHoverRegions {
    let activation: CGRect
    let exit: CGRect

    init(compactFrame: CGRect, expandedFrame: CGRect, displayFrame: CGRect) {
        activation = compactFrame.insetBy(dx: -12, dy: -10).intersection(displayFrame)
        exit = expandedFrame.insetBy(dx: -8, dy: -8).union(activation).intersection(displayFrame)
    }

    func containsActivation(_ point: CGPoint) -> Bool {
        Self.contains(point, in: activation)
    }

    func containsExit(_ point: CGPoint) -> Bool {
        Self.contains(point, in: exit)
    }

    private static func contains(_ point: CGPoint, in rect: CGRect) -> Bool {
        point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }
}

struct NotchHoverInteraction {
    static let samplingInterval: TimeInterval = 1.0 / 30
    static let collapseDelay: TimeInterval = 0.18

    private let regions: NotchHoverRegions
    private var lastPosition: CGPoint
    private var isArmed: Bool
    private var ownsExpansion = false
    private var collapseDeadline: TimeInterval?

    init(regions: NotchHoverRegions, position: CGPoint) {
        self.regions = regions
        lastPosition = position
        isArmed = !regions.containsActivation(position)
    }

    mutating func manualOverride(at position: CGPoint) {
        lastPosition = position
        isArmed = !regions.containsExit(position)
        ownsExpansion = false
        collapseDeadline = nil
    }

    mutating func update(position: CGPoint, time: TimeInterval) -> Bool? {
        guard position.x.isFinite, position.y.isFinite, time.isFinite else { return nil }
        let moved = position != lastPosition
        lastPosition = position

        if ownsExpansion {
            if regions.containsExit(position) {
                collapseDeadline = nil
            } else if let deadline = collapseDeadline {
                if time >= deadline {
                    ownsExpansion = false
                    isArmed = true
                    collapseDeadline = nil
                    return false
                }
            } else {
                collapseDeadline = time + Self.collapseDelay
            }
            return nil
        }

        guard isArmed else {
            if !regions.containsExit(position) { isArmed = true }
            return nil
        }
        guard moved, regions.containsActivation(position) else { return nil }
        isArmed = false
        ownsExpansion = true
        return true
    }
}
