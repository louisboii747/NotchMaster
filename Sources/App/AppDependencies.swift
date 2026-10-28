import Foundation

@MainActor
final class AppDependencies {
    let preferences: PreferencesStore

    init(defaults: UserDefaults = .standard) {
        preferences = PreferencesStore(defaults: defaults)
    }
}
