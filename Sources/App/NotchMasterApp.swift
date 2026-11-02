import AppKit
import SwiftUI

@main
@MainActor
struct NotchMasterApp: App {
    @NSApplicationDelegateAdaptor(NotchMasterAppDelegate.self) private var appDelegate
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        MenuBarExtra("NotchMaster", systemImage: "macbook") {
            NotchMenuView(notchWindowController: dependencies.notchWindowController)
        }
        .menuBarExtraStyle(.menu)

        Window("NotchMaster", id: "development") {
            AppShellView(
                preferences: dependencies.preferences,
                notchWindowController: dependencies.notchWindowController
            )
                .background { DevelopmentWindowRestoration().frame(width: 0, height: 0) }
        }
        .defaultSize(width: 520, height: 380)

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

private struct DevelopmentWindowRestoration: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowView { WindowView() }

    func updateNSView(_ nsView: WindowView, context: Context) {}

    final class WindowView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.isRestorable = false
        }
    }
}
