import AppKit
import SwiftUI

@main
@MainActor
struct NotchMasterApp: App {
    @NSApplicationDelegateAdaptor(NotchMasterAppDelegate.self) private var appDelegate
    @State private var dependencies: AppDependencies

    init() {
        let dependencies = if ProcessInfo.processInfo.environment["NOTCHMASTER_TESTING"] == "1" {
            AppDependencies(nowPlayingProvider: MusicNowPlayingProvider(runningMusic: { nil }))
        } else {
            AppDependencies()
        }
        _dependencies = State(initialValue: dependencies)
        appDelegate.dependencies = dependencies
    }

    var body: some Scene {
        MenuBarExtra("NotchMaster", systemImage: "macbook") {
            NotchMenuView(notchWindowController: dependencies.notchWindowController)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(
                preferences: dependencies.preferences,
                loginItemService: dependencies.loginItemService,
                notchWindowController: dependencies.notchWindowController
            )
        }
        .defaultSize(width: 680, height: 520)
    }
}

@MainActor
final class NotchMasterAppDelegate: NSObject, NSApplicationDelegate {
    var dependencies: AppDependencies?
    private var hasFinishedLaunching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !hasFinishedLaunching else { return }
        hasFinishedLaunching = true
        dependencies?.notchWindowController.start()
        dependencies?.nowPlayingService.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        dependencies?.notchWindowController.stop()
        dependencies?.nowPlayingService.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
