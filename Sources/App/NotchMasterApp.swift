import AppKit
import SwiftUI

@main
@MainActor
struct NotchMasterApp: App {
    @NSApplicationDelegateAdaptor(NotchMasterAppDelegate.self) private var appDelegate
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        Window("NotchMaster", id: "foundation") {
            AppShellView(notchWindowController: dependencies.notchWindowController)
        }
        .defaultSize(width: 480, height: 280)

        MenuBarExtra("NotchMaster", systemImage: "macbook") {
            NotchMenuView(notchWindowController: dependencies.notchWindowController)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(preferences: dependencies.preferences, loginItemService: dependencies.loginItemService)
        }
        .defaultSize(width: 520, height: 380)
    }
}

@MainActor
final class NotchMasterAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
