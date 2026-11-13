import Foundation
import Observation

enum AppAppearance: String, CaseIterable {
    case automatic
    case light
    case dark
}

@MainActor
@Observable
final class PreferencesStore {
    static let expansionDurationKey = "notchExpansionDuration"
    static let appearanceKey = "appAppearance"
    static let showBatteryStatusKey = "showBatteryStatus"
    static let showNowPlayingKey = "showNowPlaying"
    static let defaultExpansionDuration: TimeInterval = 0.30
    static let expansionDurationRange: ClosedRange<TimeInterval> = 0.15...0.60

    private let defaults: UserDefaults
    private let onShowNowPlayingChange: @MainActor (Bool) -> Void
    private var storedExpansionDuration: TimeInterval

    var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
        }
    }

    var showBatteryStatus: Bool {
        didSet {
            defaults.set(showBatteryStatus, forKey: Self.showBatteryStatusKey)
        }
    }

    var showNowPlaying: Bool {
        didSet {
            defaults.set(showNowPlaying, forKey: Self.showNowPlayingKey)
            if showNowPlaying != oldValue { onShowNowPlayingChange(showNowPlaying) }
        }
    }

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

    init(defaults: UserDefaults, onShowNowPlayingChange: @escaping @MainActor (Bool) -> Void = { _ in }) {
        self.defaults = defaults
        self.onShowNowPlayingChange = onShowNowPlayingChange
        appearance = defaults.string(forKey: Self.appearanceKey).flatMap(AppAppearance.init(rawValue:)) ?? .automatic
        showBatteryStatus = defaults.object(forKey: Self.showBatteryStatusKey) as? Bool ?? true
        showNowPlaying = defaults.object(forKey: Self.showNowPlayingKey) as? Bool ?? true
        let persisted = defaults.object(forKey: Self.expansionDurationKey) as? Double
        storedExpansionDuration = Self.validatedDuration(persisted ?? Self.defaultExpansionDuration)
        defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
        defaults.set(showBatteryStatus, forKey: Self.showBatteryStatusKey)
        defaults.set(showNowPlaying, forKey: Self.showNowPlayingKey)
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
