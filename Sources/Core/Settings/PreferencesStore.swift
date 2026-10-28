import Foundation
import Observation

@MainActor
@Observable
final class PreferencesStore {
    static let expansionDurationKey = "notchExpansionDuration"
    static let defaultExpansionDuration: TimeInterval = 0.30
    static let expansionDurationRange: ClosedRange<TimeInterval> = 0.15...0.60

    private let defaults: UserDefaults
    private var storedExpansionDuration: TimeInterval

    var expansionDuration: TimeInterval {
        get { storedExpansionDuration }
        set {
            storedExpansionDuration = Self.validatedDuration(newValue)
            defaults.set(storedExpansionDuration, forKey: Self.expansionDurationKey)
        }
    }

    var expansionSpeed: Double {
        get {
            (Self.expansionDurationRange.upperBound - expansionDuration) / Self.durationSpan
        }
        set {
            expansionDuration = (1 - newValue) * Self.expansionDurationRange.upperBound
                + newValue * Self.expansionDurationRange.lowerBound
        }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        let persisted = defaults.object(forKey: Self.expansionDurationKey) as? Double
        storedExpansionDuration = Self.validatedDuration(persisted ?? Self.defaultExpansionDuration)
        defaults.set(storedExpansionDuration, forKey: Self.expansionDurationKey)
    }

    private static var durationSpan: TimeInterval {
        expansionDurationRange.upperBound - expansionDurationRange.lowerBound
    }

    private static func validatedDuration(_ duration: TimeInterval) -> TimeInterval {
        guard duration.isFinite else { return defaultExpansionDuration }
        return min(max(duration, expansionDurationRange.lowerBound), expansionDurationRange.upperBound)
    }
}
