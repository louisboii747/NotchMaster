import Foundation
import Testing
@testable import NotchMaster

@Suite
@MainActor
struct PreferencesStoreTests {
    private func withDefaults(_ body: (UserDefaults, String) throws -> Void) throws {
        let suiteName = "NotchMasterTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults, suiteName)
    }

    @Test
    func startsWithDocumentedDefault() throws {
        try withDefaults { defaults, _ in
            let store = PreferencesStore(defaults: defaults)
            #expect(store.expansionDuration == 0.30)
        }
    }

    @Test
    func persistsAndReloadsDuration() throws {
        try withDefaults { defaults, suiteName in
            let store = PreferencesStore(defaults: defaults)
            store.expansionDuration = 0.42
            #expect(defaults.double(forKey: PreferencesStore.expansionDurationKey) == 0.42)

            let reloadedDefaults = try #require(UserDefaults(suiteName: suiteName))
            let reloaded = PreferencesStore(defaults: reloadedDefaults)
            #expect(reloaded.expansionDuration == 0.42)
        }
    }

    @Test(arguments: [(-1.0, 0.15), (0.15, 0.15), (0.60, 0.60), (2.0, 0.60)])
    func clampsOnLoadAndUpdate(duration: Double, expected: Double) throws {
        try withDefaults { defaults, _ in
            defaults.set(duration, forKey: PreferencesStore.expansionDurationKey)
            let store = PreferencesStore(defaults: defaults)
            #expect(store.expansionDuration == expected)
            #expect(defaults.double(forKey: PreferencesStore.expansionDurationKey) == expected)

            store.expansionDuration = 0.30
            store.expansionDuration = duration
            #expect(store.expansionDuration == expected)
            #expect(defaults.double(forKey: PreferencesStore.expansionDurationKey) == expected)
        }
    }

    @Test(arguments: [Double.nan, Double.infinity, -Double.infinity])
    func replacesNonFiniteDurationsWithDefault(duration: Double) throws {
        try withDefaults { defaults, _ in
            defaults.set(duration, forKey: PreferencesStore.expansionDurationKey)
            let store = PreferencesStore(defaults: defaults)
            #expect(store.expansionDuration == 0.30)
            #expect(defaults.double(forKey: PreferencesStore.expansionDurationKey) == 0.30)

            store.expansionDuration = 0.42
            store.expansionDuration = duration
            #expect(store.expansionDuration == 0.30)
            #expect(defaults.double(forKey: PreferencesStore.expansionDurationKey) == 0.30)
        }
    }

    @Test
    func replacesMalformedStoredValueWithDefault() throws {
        try withDefaults { defaults, _ in
            defaults.set("invalid", forKey: PreferencesStore.expansionDurationKey)
            let store = PreferencesStore(defaults: defaults)
            #expect(store.expansionDuration == 0.30)
            #expect(defaults.double(forKey: PreferencesStore.expansionDurationKey) == 0.30)
        }
    }

    @Test
    func increasingSpeedShortensDuration() throws {
        try withDefaults { defaults, _ in
            let store = PreferencesStore(defaults: defaults)
            #expect(abs(store.expansionSpeed - 2.0 / 3.0) < 0.000_001)
            store.expansionSpeed = 0
            #expect(store.expansionDuration == 0.60)
            store.expansionSpeed = 0.5
            #expect(abs(store.expansionDuration - 0.375) < 0.000_001)
            store.expansionSpeed = 1
            #expect(store.expansionDuration == 0.15)
            #expect(defaults.double(forKey: PreferencesStore.expansionDurationKey) == 0.15)
        }
    }
}
