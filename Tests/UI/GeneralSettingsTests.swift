import AppKit
import ServiceManagement
import SwiftUI
import Testing
@testable import NotchMaster

@Suite(.serialized)
@MainActor
struct GeneralSettingsTests {
    @Test(arguments: [false, true])
    func failedOperationsKeepTheSettingsBindingConsistent(enabling: Bool) async throws {
        let system = TestLoginItemSystem(status: enabling ? .notRegistered : .enabled)
        system.operationError = LoginItemTestError.rejected
        try await withSettings(system: system) { view, service, _ in
            view.launchAtLogin.wrappedValue = enabling

            #expect(view.launchAtLogin.wrappedValue == !enabling)
            #expect(service.errorMessage != nil)

            system.operationError = nil
            view.launchAtLogin.wrappedValue = enabling
            #expect(view.launchAtLogin.wrappedValue == enabling)
            #expect(service.errorMessage == nil)
        }
    }

    @Test(arguments: [NSApplication.didBecomeActiveNotification, NSWindow.didBecomeKeyNotification])
    func activationRefreshesExternallyChangedStatus(_ notification: Notification.Name) async throws {
        let system = TestLoginItemSystem()
        try await withSettings(system: system) { view, service, host in
            system.status = .enabled
            NotificationCenter.default.post(name: notification, object: host.window)
            try await Task.sleep(for: .milliseconds(30))

            #expect(view.launchAtLogin.wrappedValue)
            #expect(service.isEnabled)
            #expect(system.registrations == 0 && system.unregistrations == 0)
        }
    }

    @Test
    func appearanceChangesUpdateWindowAndAutomaticFollowsInheritedAppearance() async throws {
        let previousAppearance = NSApp.appearance
        defer { NSApp.appearance = previousAppearance }
        NSApp.appearance = NSAppearance(named: .aqua)
        try await withSettings(system: TestLoginItemSystem()) { view, _, host in
            let window = try #require(host.window)
            #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua)

            view.$preferences.appearance.wrappedValue = .dark
            try await Task.sleep(for: .milliseconds(50))
            #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
            try recordSnapshot(host, named: "settings-dark.png")

            view.$preferences.appearance.wrappedValue = .light
            try await Task.sleep(for: .milliseconds(50))
            #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua)
            try recordSnapshot(host, named: "settings-light.png")

            NSApp.appearance = NSAppearance(named: .darkAqua)
            try await Task.sleep(for: .milliseconds(50))
            #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua)

            view.$preferences.appearance.wrappedValue = .automatic
            try await Task.sleep(for: .milliseconds(50))
            #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)

            NSApp.appearance = NSAppearance(named: .aqua)
            try await Task.sleep(for: .milliseconds(50))
            #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua)
        }
    }

    private func recordSnapshot(_ view: NSView, named name: String) throws {
        view.layoutSubtreeIfNeeded()
        let image = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: image)
        Attachment.record(try #require(image.representation(using: .png, properties: [:])), named: name)
    }

    private func withSettings(
        system: TestLoginItemSystem,
        body: (GeneralSettingsView, LoginItemService, NSView) async throws -> Void
    ) async throws {
        let suiteName = "NotchMasterSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = LoginItemService(system: system)
        let view = GeneralSettingsView(
            preferences: PreferencesStore(defaults: defaults),
            loginItemService: service
        )
        let controller = NotchWindowController(displays: { [] }) { _ in NSView() }
        let host = NSHostingView(rootView: SettingsView(
            preferences: view.preferences,
            loginItemService: service,
            notchWindowController: controller
        ))
        let window = NSWindow(
            contentRect: CGRect(x: -3000, y: -3000, width: 680, height: 520),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(30))
        try await body(view, service, host)
    }
}
