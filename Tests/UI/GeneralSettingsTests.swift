import AppKit
import ServiceManagement
import SwiftUI
import Testing
@testable import NotchMaster

@Suite(.serialized)
@MainActor
struct GeneralSettingsTests {
    @Test
    func previewOnLaunchBindingPersistsIndependentlyOfLoginApproval() async throws {
        let system = TestLoginItemSystem(status: .requiresApproval)
        try await withSettings(system: system) { view, service, _ in
            #expect(!view.preferences.showNotchPreviewOnLaunch)
            view.$preferences.showNotchPreviewOnLaunch.wrappedValue = true
            #expect(view.preferences.showNotchPreviewOnLaunch)
            #expect(service.requiresApproval && !view.launchAtLogin.wrappedValue)
            view.$preferences.showNotchPreviewOnLaunch.wrappedValue = false
            #expect(!view.preferences.showNotchPreviewOnLaunch)
            #expect(system.registrations == 0 && system.unregistrations == 0)
        }
    }

    @Test(arguments: [false, true])
    func foundationToggleUsesConfirmedPreviewState(supported: Bool) throws {
        let suiteName = "NotchMasterFoundationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let controller = NotchWindowController(
            displays: { supported ? [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry] : [] },
            reduceMotion: { true },
            cursorPosition: { .zero }
        ) { _ in NSView() }
        defer { controller.hidePreview() }
        let view = AppShellView(preferences: PreferencesStore(defaults: defaults), notchWindowController: controller)

        #expect(!view.previewVisibility.wrappedValue)
        view.previewVisibility.wrappedValue = true
        #expect(view.previewVisibility.wrappedValue == supported)
        #expect(controller.isPreviewVisible == supported)
        if !supported {
            #expect(controller.statusMessage == NotchPreviewUnavailableReason.noBuiltInDisplay.message)
        }
        view.previewVisibility.wrappedValue = false
        #expect(!controller.isPreviewVisible && !view.previewVisibility.wrappedValue)
        if !supported {
            #expect(controller.statusMessage == NotchPreviewUnavailableReason.noBuiltInDisplay.message)
        }

        controller.togglePreview()
        #expect(view.previewVisibility.wrappedValue == supported)
        controller.hidePreview()
        #expect(!view.previewVisibility.wrappedValue)
    }

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
        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: CGRect(x: -3000, y: -3000, width: 520, height: 480),
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
