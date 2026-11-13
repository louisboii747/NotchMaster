import AppKit
import SwiftUI
import Testing
@testable import NotchMaster

@Suite(.serialized)
@MainActor
struct AppLifecycleTests {
    private static var testHostWindow: NSWindow?

    @Test
    func defaultStartupMakesIslandAvailable() throws {
        try withStartup { dependencies, delegate in
            let controller = dependencies.notchWindowController
            let panel = try #require(controller.window)
            let timer = try #require(controller.hoverTimer)
            #expect(controller.isPreviewVisible && panel.isVisible && !controller.isExpanded)
            #expect(dependencies.nowPlayingService.isObserving)
            #expect(timer.isValid)
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            #expect(controller.window === panel && controller.hoverTimer === timer)
        }
    }

    @Test(arguments: [false, true], [false, true])
    func startupIgnoresLegacyToggleAndLoginStatus(legacyPreviewOnLaunch: Bool, loginEnabled: Bool) throws {
        try withStartup(legacyPreviewOnLaunch: legacyPreviewOnLaunch, loginEnabled: loginEnabled) { dependencies, _ in
            let controller = dependencies.notchWindowController
            #expect(controller.isPreviewVisible && !controller.isExpanded)
            #expect(controller.hoverTimer?.isValid == true)
        }
    }

    @Test
    func unsupportedStartupReportsReasonWithoutRepeatedLaunchRequests() throws {
        try withStartup(supported: false) { dependencies, delegate in
            let controller = dependencies.notchWindowController
            #expect(!controller.isPreviewVisible && !controller.isExpanded)
            #expect(controller.window == nil && controller.hoverTimer == nil)
            #expect(controller.statusMessage == NotchPreviewUnavailableReason.noBuiltInDisplay.message)
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            #expect(controller.statusMessage == NotchPreviewUnavailableReason.noBuiltInDisplay.message)
        }
    }

    @Test
    func terminationStopsIslandAndHoverTracking() throws {
        try withStartup { dependencies, delegate in
            let controller = dependencies.notchWindowController
            let timer = try #require(controller.hoverTimer)
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            #expect(!controller.isPreviewVisible && !controller.isExpanded)
            #expect(controller.hoverTimer == nil && !timer.isValid)
            #expect(!dependencies.nowPlayingService.isObserving && dependencies.nowPlayingService.state == .unavailable)
        }
    }

    @Test(arguments: [false, true])
    func nowPlayingPreferenceControlsObservationDuringAppLifetime(showNowPlaying: Bool) throws {
        let provider = TestNowPlayingProvider()
        try withStartup(showNowPlaying: showNowPlaying, nowPlayingProvider: provider) { dependencies, delegate in
            let service = dependencies.nowPlayingService
            let preferences = dependencies.preferences
            let panel = try #require(dependencies.notchWindowController.window)
            let content = panel.contentView
            let frame = panel.frame
            #expect(service.isObserving == showNowPlaying)
            #expect(provider.starts == (showNowPlaying ? 1 : 0) && provider.stops == 0)
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            #expect(provider.starts == (showNowPlaying ? 1 : 0))

            let settings = FeaturesSettingsView(preferences: preferences, notchWindowController: dependencies.notchWindowController)
            settings.$preferences.showNowPlaying.wrappedValue = true
            let staleCallback = try #require(provider.onChange)
            staleCallback(.playing(NowPlayingTrack(title: "Song", artist: "Artist", artwork: nil)))
            #expect(service.state.track != nil)
            for _ in 0..<3 {
                let starts = provider.starts
                let stops = provider.stops
                settings.$preferences.showNowPlaying.wrappedValue = false
                #expect(!service.isObserving && service.state == .unavailable && provider.stops == stops + 1)
                settings.$preferences.showNowPlaying.wrappedValue = false
                #expect(provider.stops == stops + 1)
                settings.$preferences.showNowPlaying.wrappedValue = true
                settings.$preferences.showNowPlaying.wrappedValue = true
                #expect(service.isObserving && provider.starts == starts + 1)
                staleCallback(.playing(NowPlayingTrack(title: "Stale", artist: "Artist", artwork: nil)))
                #expect(service.state == .unavailable)
            }
            #expect(dependencies.notchWindowController.window === panel && panel.contentView === content && panel.frame == frame)
            #expect(!dependencies.notchWindowController.isExpanded && dependencies.notchWindowController.frameAnimation == nil)

            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            let starts = provider.starts
            let stops = provider.stops
            preferences.showNowPlaying = false
            preferences.showNowPlaying = true
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            #expect(!service.isObserving && service.state == .unavailable)
            #expect(provider.starts == starts && provider.stops == stops)
        }
    }

    private func withStartup(
        legacyPreviewOnLaunch: Bool? = nil,
        loginEnabled: Bool = false,
        supported: Bool = true,
        showNowPlaying: Bool? = nil,
        nowPlayingProvider: TestNowPlayingProvider = TestNowPlayingProvider(),
        body: (AppDependencies, NotchMasterAppDelegate) throws -> Void
    ) throws {
        let suiteName = "NotchMasterStartupTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        if let legacyPreviewOnLaunch {
            defaults.set(legacyPreviewOnLaunch, forKey: "showNotchPreviewOnLaunch")
        }
        if let showNowPlaying {
            defaults.set(showNowPlaying, forKey: PreferencesStore.showNowPlayingKey)
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
        defer { controller.stop() }
        let dependencies = AppDependencies(defaults: defaults, loginItemSystem: system, nowPlayingProvider: nowPlayingProvider, notchWindowController: controller)
        defer { dependencies.nowPlayingService.stop() }
        let delegate = NotchMasterAppDelegate()
        delegate.dependencies = dependencies
        let visibleWindows = NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) }
        let keyWindow = NSApp.keyWindow
        #expect(controller.window == nil)

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        try body(dependencies, delegate)

        #expect(displayRequests == 1)
        #expect(NSApp.windows.filter { $0.isVisible && $0.styleMask.contains(.titled) } == visibleWindows)
        #expect(NSApp.keyWindow === keyWindow)
        #expect(system.registrations == 0 && system.unregistrations == 0 && system.settingsOpened == 0)
    }

    @Test
    func launchKeepsSettingsHiddenWithoutADevelopmentWindow() throws {
        #expect(NSApp.activationPolicy() == .regular)
        #expect(!NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) })
        #expect(NSApp.windowsMenu?.items.contains { $0.title == "NotchMaster" } != true)
        let hostWindow = NSWindow(
            contentRect: CGRect(x: -3000, y: -3000, width: 100, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        hostWindow.title = "NotchMaster Test Host"
        hostWindow.isRestorable = false
        Self.testHostWindow = hostWindow
        hostWindow.orderFront(nil)
        #expect(NSApp.delegate?.applicationShouldTerminateAfterLastWindowClosed?(NSApp) == false)
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
    func allSettingsCommandsReuseOneWindow() async throws {
        guard #available(macOS 14.4, *) else { return }
        let controller = NotchWindowController(displays: { [] }) { _ in NSView() }
        let menu = NSHostingMenu(rootView: NotchMenuView(notchWindowController: controller))
        try await expectExpansionTitle("Expand Notch Preview", in: menu)
        #expect(!menu.items.contains { $0.title == "Feature Settings…" })

        let settingsCommand = try #require(menu.items.firstIndex { $0.title == "Open Settings…" })
        menu.performActionForItem(at: settingsCommand)
        try await Task.sleep(for: .milliseconds(50))
        let settingsWindow = try #require(NSApp.windows.first {
            $0.isVisible && $0.title != "NotchMaster Test Host" && $0.styleMask.contains(.titled)
        })
        defer { settingsWindow.close() }

        menu.performActionForItem(at: settingsCommand)
        try await Task.sleep(for: .milliseconds(50))
        #expect(NSApp.windows.filter {
            $0.isVisible && $0.title != "NotchMaster Test Host" && $0.styleMask.contains(.titled)
        } == [settingsWindow])

        settingsWindow.close()
        #expect(!settingsWindow.isVisible)
        let appMenu = try #require(NSApp.mainMenu?.items.first?.submenu)
        let appSettingsCommand = try #require(appMenu.items.firstIndex { $0.keyEquivalent == "," })
        appMenu.performActionForItem(at: appSettingsCommand)
        try await Task.sleep(for: .milliseconds(50))
        #expect(settingsWindow.isVisible)
        #expect(controller.window == nil && !controller.isPreviewVisible)
    }

    @Test
    func menuControlsExpansionOfAutomaticallyAvailableIsland() async throws {
        guard #available(macOS 14.4, *) else { return }
        let controller = NotchWindowController(
            displays: { [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry] },
            reduceMotion: { true },
            cursorPosition: { .zero }
        ) { _ in NSView() }
        defer { controller.stop() }
        controller.start()
        let menu = NSHostingMenu(rootView: NotchMenuView(notchWindowController: controller))

        try await expectExpansionTitle("Expand Notch Preview", in: menu)
        #expect(menu.items[0].isEnabled)
        menu.performActionForItem(at: 0)
        try await expectExpansionTitle("Collapse Notch Preview", in: menu)
        #expect(controller.isExpanded)
        controller.toggleExpansion()
        try await expectExpansionTitle("Expand Notch Preview", in: menu)
        menu.performActionForItem(at: 0)
        try await expectExpansionTitle("Collapse Notch Preview", in: menu)
        menu.performActionForItem(at: 0)
        try await expectExpansionTitle("Expand Notch Preview", in: menu)
        #expect(!controller.isExpanded && controller.isPreviewVisible)
        #expect(!menu.items.contains { $0.title == "Show Notch Preview" || $0.title == "Hide Notch Preview" })
    }

    @Test(arguments: [NSWorkspace.willSleepNotification, NSApplication.didChangeScreenParametersNotification])
    func menuTracksAutomaticLifecycleRecovery(_ notification: Notification.Name) async throws {
        guard #available(macOS 14.4, *) else { return }
        let notifications = NotificationCenter()
        let provider = MenuDisplayProviderFixture()
        let controller = NotchWindowController(
            displays: { provider.displays },
            notificationCenter: notifications,
            workspaceNotificationCenter: notifications,
            cursorPosition: { .zero }
        ) { _ in NSView() }
        defer { controller.stop() }
        controller.start()
        let panel = try #require(controller.window)
        let menu = NSHostingMenu(rootView: NotchMenuView(notchWindowController: controller))
        try await expectExpansionTitle("Expand Notch Preview", in: menu)
        #expect(menu.items[0].isEnabled)

        provider.displays = []
        notifications.post(name: notification, object: nil)
        try await expectExpansionTitle("Expand Notch Preview", in: menu)
        #expect(!controller.isPreviewVisible && !panel.isVisible && !menu.items[0].isEnabled)
        #expect(menu.items[1].title == controller.statusMessage)
        menu.performActionForItem(at: 0)
        #expect(!controller.isExpanded)

        provider.displays = [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry]
        notifications.post(name: NSWorkspace.didWakeNotification, object: nil)
        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        try await expectExpansionTitle("Expand Notch Preview", in: menu)
        #expect(controller.window === panel && controller.isPreviewVisible && panel.isVisible)
        #expect(menu.items[0].isEnabled)
    }

    @Test
    func closingSettingsWindowKeepsMenuAndSharedControllerOperational() async throws {
        guard #available(macOS 14.4, *) else { return }
        let controller = NotchWindowController(
            displays: { [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry] },
            cursorPosition: { .zero }
        ) { _ in NSView() }
        defer { controller.stop() }
        let menu = NSHostingMenu(rootView: NotchMenuView(notchWindowController: controller))
        let verificationWindow = NSWindow(
            contentRect: CGRect(x: -3000, y: -3000, width: 480, height: 280),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        verificationWindow.isReleasedWhenClosed = false
        let suiteName = "NotchMasterMenuTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        verificationWindow.contentView = NSHostingView(rootView: SettingsView(
            preferences: PreferencesStore(defaults: defaults),
            loginItemService: LoginItemService(system: TestLoginItemSystem()),
            notchWindowController: controller
        ))
        controller.start()
        let panel = try #require(controller.window)

        verificationWindow.close()
        verificationWindow.contentView = nil

        #expect(NSApp.delegate?.applicationShouldTerminateAfterLastWindowClosed?(NSApp) == false)
        try await expectExpansionTitle("Expand Notch Preview", in: menu)
        #expect(controller.window === panel && panel.isVisible && controller.hoverTimer?.isValid == true)
        menu.performActionForItem(at: 0)
        try await expectExpansionTitle("Collapse Notch Preview", in: menu)
        #expect(controller.isExpanded)
        #expect(menu.items.map(\.title) == [
            "Collapse Notch Preview", controller.statusMessage, "", "Open Settings…", "Quit NotchMaster"
        ])
        #expect(menu.items[3].keyEquivalent == ",")
        #expect(menu.items[4].keyEquivalent == "q")
    }

    private func expectExpansionTitle(_ title: String, in menu: NSMenu) async throws {
        try await Task.sleep(for: .milliseconds(30))
        menu.update()
        #expect(menu.items.first?.title == title)
    }
}

@MainActor
private final class MenuDisplayProviderFixture {
    var displays = [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry]
}
