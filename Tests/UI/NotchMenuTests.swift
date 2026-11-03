import AppKit
import SwiftUI
import Testing
@testable import NotchMaster

@Suite(.serialized)
@MainActor
struct AppLifecycleTests {
    private static var testHostWindow: NSWindow?

    @Test
    func defaultStartupDoesNotRequestPreview() throws {
        try withStartup(previewOnLaunch: nil) { dependencies, delegate in
            #expect(!dependencies.preferences.showNotchPreviewOnLaunch)
            #expect(dependencies.notchWindowController.window == nil)
            dependencies.preferences.showNotchPreviewOnLaunch = true
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            #expect(dependencies.notchWindowController.window == nil)
        }
    }

    @Test(arguments: [false, true], [false, true])
    func startupUsesPreviewPreferenceIndependentlyOfLoginStatus(previewOnLaunch: Bool, loginEnabled: Bool) throws {
        try withStartup(previewOnLaunch: previewOnLaunch, loginEnabled: loginEnabled) { dependencies, delegate in
            let controller = dependencies.notchWindowController
            #expect(controller.isPreviewVisible == previewOnLaunch)
            #expect(!controller.isExpanded)
            if previewOnLaunch {
                let panel = try #require(controller.window)
                #expect(panel.isVisible)
                #expect(controller.statusMessage == "Notch preview shown on Built-in Test Display.")
                controller.hidePreview()
            } else {
                #expect(controller.window == nil && controller.hoverTimer == nil)
                #expect(controller.statusMessage == "Preview hidden. Requires a built-in display with a physical notch.")
            }

            dependencies.preferences.showNotchPreviewOnLaunch = true
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            #expect(!controller.isPreviewVisible)
        }
    }

    @Test
    func unsupportedStartupKeepsFailureStatusAndDoesNotRetry() throws {
        try withStartup(previewOnLaunch: true, supported: false) { dependencies, delegate in
            let controller = dependencies.notchWindowController
            #expect(!controller.isPreviewVisible && !controller.isExpanded)
            #expect(controller.window == nil && controller.hoverTimer == nil)
            #expect(controller.statusMessage == NotchPreviewUnavailableReason.noBuiltInDisplay.message)
            #expect(dependencies.preferences.showNotchPreviewOnLaunch)

            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            #expect(controller.statusMessage == NotchPreviewUnavailableReason.noBuiltInDisplay.message)
        }
    }

    private func withStartup(
        previewOnLaunch: Bool?,
        loginEnabled: Bool = false,
        supported: Bool = true,
        body: (AppDependencies, NotchMasterAppDelegate) throws -> Void
    ) throws {
        let suiteName = "NotchMasterStartupTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        if let previewOnLaunch {
            defaults.set(previewOnLaunch, forKey: PreferencesStore.showNotchPreviewOnLaunchKey)
        }
        let system = TestLoginItemSystem(status: loginEnabled ? .enabled : .notRegistered)
        var displayRequests = 0
        let controller = NotchWindowController(
            displays: {
                displayRequests += 1
                return supported ? [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry] : []
            },
            reduceMotion: { true },
            cursorPosition: { .zero }
        ) { _ in NSView() }
        defer { controller.hidePreview() }
        let dependencies = AppDependencies(defaults: defaults, loginItemSystem: system, notchWindowController: controller)
        let delegate = NotchMasterAppDelegate()
        delegate.dependencies = dependencies
        let visibleWindows = NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) }
        let keyWindow = NSApp.keyWindow
        #expect(controller.window == nil)

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        try body(dependencies, delegate)

        #expect(displayRequests == (previewOnLaunch == true ? 1 : 0))
        #expect(NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) } == visibleWindows)
        #expect(NSApp.keyWindow === keyWindow)
        #expect(system.registrations == 0 && system.unregistrations == 0 && system.settingsOpened == 0)
    }

    @Test
    func launchKeepsDevelopmentWindowHiddenAndWindowMenuReopensIt() async throws {
        #expect(NSApp.activationPolicy() == .regular)
        #expect(!NSApp.windows.contains { $0.title == "NotchMaster" && $0.isVisible })
        let hostWindow = NSWindow(
            contentRect: CGRect(x: -3000, y: -3000, width: 100, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        hostWindow.title = "NotchMaster Test Host"
        hostWindow.isRestorable = false
        Self.testHostWindow = hostWindow
        hostWindow.orderFront(nil)

        let menu = try #require(NSApp.windowsMenu)
        let commandIndex = try #require(menu.items.firstIndex { $0.title == "NotchMaster" })
        menu.performActionForItem(at: commandIndex)
        try await Task.sleep(for: .milliseconds(30))
        let window = try #require(NSApp.windows.first { $0.title == "NotchMaster" && $0.isVisible })
        defer { window.close() }

        #expect(!window.isRestorable)
        #expect(window.contentView != nil)
        window.close()
        #expect(!window.isVisible)
        #expect(NSApp.delegate?.applicationShouldTerminateAfterLastWindowClosed?(NSApp) == false)
        menu.performActionForItem(at: commandIndex)
        try await Task.sleep(for: .milliseconds(30))
        #expect(NSApp.windows.first { $0.title == "NotchMaster" && $0.isVisible } === window)
        #expect(!window.isRestorable)
    }
}

@Suite(
    .serialized,
    .enabled(
        if: ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 14, minorVersion: 4, patchVersion: 0)
        ),
        "Native menu inspection requires macOS 14.4"
    )
)
@MainActor
struct NotchMenuTests {
    @Test
    func featureSettingsAndAppSettingsRemainSeparateWindows() async throws {
        guard #available(macOS 14.4, *) else { return }
        let controller = NotchWindowController(displays: { [] }) { _ in NSView() }
        let menu = NSHostingMenu(rootView: NotchMenuView(notchWindowController: controller))
        try await expectPreviewTitle("Show Notch Preview", in: menu)

        let featureCommand = try #require(menu.items.firstIndex { $0.title == "Feature Settings…" })
        menu.performActionForItem(at: featureCommand)
        try await Task.sleep(for: .milliseconds(30))
        let foundationWindow = try #require(NSApp.windows.first { $0.title == "NotchMaster" && $0.isVisible })
        defer { foundationWindow.close() }

        let settingsCommand = try #require(menu.items.firstIndex { $0.title == "Open Settings…" })
        menu.performActionForItem(at: settingsCommand)
        try await Task.sleep(for: .milliseconds(30))
        let settingsWindow = try #require(NSApp.windows.first {
            $0.isVisible && $0 !== foundationWindow && $0.title != "NotchMaster Test Host" && $0.styleMask.contains(.titled)
        })
        defer { settingsWindow.close() }
        #expect(foundationWindow.isVisible)

        menu.performActionForItem(at: featureCommand)
        try await Task.sleep(for: .milliseconds(30))
        #expect(NSApp.windows.filter { $0.title == "NotchMaster" && $0.isVisible }.count == 1)
        #expect(settingsWindow.isVisible)
        #expect(controller.window == nil && !controller.isPreviewVisible)
    }

    @Test
    func menuControlsExpansionAndTracksExternalStateChanges() async throws {
        guard #available(macOS 14.4, *) else { return }
        let controller = NotchWindowController(
            displays: { [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry] },
            reduceMotion: { true },
            cursorPosition: { .zero }
        ) { _ in NSView() }
        defer { controller.hidePreview() }
        let menu = NSHostingMenu(rootView: NotchMenuView(notchWindowController: controller))

        try await expectPreviewTitle("Show Notch Preview", in: menu)
        #expect(menu.items[1].title == "Expand Notch Preview")
        #expect(!menu.items[1].isEnabled)
        menu.performActionForItem(at: 1)
        #expect(controller.window == nil && !controller.isExpanded)

        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        #expect(menu.items[1].isEnabled)
        menu.performActionForItem(at: 1)
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        #expect(controller.isExpanded)
        #expect(menu.items[1].title == "Collapse Notch Preview")

        controller.toggleExpansion()
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        #expect(menu.items[1].title == "Expand Notch Preview")
        controller.toggleExpansion()
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        #expect(menu.items[1].title == "Collapse Notch Preview")
        menu.performActionForItem(at: 1)
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        #expect(!controller.isExpanded)
        #expect(menu.items[1].title == "Expand Notch Preview")
        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Show Notch Preview", in: menu)
        #expect(!menu.items[1].isEnabled)
        #expect(menu.items[2].title == controller.statusMessage)
    }

    @Test(arguments: [NSWorkspace.willSleepNotification, NSApplication.didChangeScreenParametersNotification])
    func menuTracksConfirmedVisibilityAndLifecycleChanges(_ notification: Notification.Name) async throws {
        guard #available(macOS 14.4, *) else { return }
        let notifications = NotificationCenter()
        let provider = MenuDisplayProviderFixture()
        let controller = NotchWindowController(
            displays: { provider.displays },
            notificationCenter: notifications,
            workspaceNotificationCenter: notifications,
            cursorPosition: { .zero }
        ) { _ in NSView() }
        defer { controller.hidePreview() }
        let menu = NSHostingMenu(rootView: NotchMenuView(notchWindowController: controller))

        try await expectPreviewTitle("Show Notch Preview", in: menu)
        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        let panel = try #require(controller.window)
        #expect(controller.isPreviewVisible && panel.isVisible)

        controller.togglePreview()
        try await expectPreviewTitle("Show Notch Preview", in: menu)
        controller.togglePreview()
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        #expect(controller.window === panel)

        provider.displays = []
        notifications.post(name: notification, object: nil)
        try await expectPreviewTitle("Show Notch Preview", in: menu)
        #expect(!controller.isPreviewVisible && !panel.isVisible)

        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Show Notch Preview", in: menu)
        #expect(!controller.isPreviewVisible && !panel.isVisible)
        #expect(controller.statusMessage == NotchPreviewUnavailableReason.noBuiltInDisplay.message)
        #expect(menu.items[2].title == controller.statusMessage)
        #expect(!menu.items[1].isEnabled)

        provider.displays = [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry]
        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        #expect(controller.window === panel)
        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Show Notch Preview", in: menu)
        #expect(!panel.isVisible)
    }

    @Test
    func closingFoundationWindowKeepsMenuAndSharedControllerOperational() async throws {
        guard #available(macOS 14.4, *) else { return }
        let controller = NotchWindowController(
            displays: { [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry] },
            cursorPosition: { .zero }
        ) { _ in NSView() }
        defer { controller.hidePreview() }
        let menu = NSHostingMenu(rootView: NotchMenuView(notchWindowController: controller))
        let verificationWindow = NSWindow(
            contentRect: CGRect(x: -3000, y: -3000, width: 480, height: 280),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        verificationWindow.isReleasedWhenClosed = false
        let suiteName = "NotchMasterMenuTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        verificationWindow.contentView = NSHostingView(rootView: AppShellView(
            preferences: PreferencesStore(defaults: defaults), notchWindowController: controller
        ))
        controller.showPreview()
        let panel = try #require(controller.window)

        verificationWindow.close()
        verificationWindow.contentView = nil

        #expect(NSApp.delegate?.applicationShouldTerminateAfterLastWindowClosed?(NSApp) == false)
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Show Notch Preview", in: menu)
        #expect(!panel.isVisible)
        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        #expect(controller.window === panel && panel.isVisible)
        #expect(menu.items.map(\.title) == [
            "Hide Notch Preview", "Expand Notch Preview", controller.statusMessage, "",
            "Feature Settings…", "Open Settings…", "Quit NotchMaster"
        ])
        #expect(menu.items[5].keyEquivalent == ",")
        #expect(menu.items[6].keyEquivalent == "q")
    }

    private func expectPreviewTitle(_ title: String, in menu: NSMenu) async throws {
        try await Task.sleep(for: .milliseconds(30))
        menu.update()
        #expect(menu.items.first?.title == title)
    }
}

@MainActor
private final class MenuDisplayProviderFixture {
    var displays = [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry]
}
