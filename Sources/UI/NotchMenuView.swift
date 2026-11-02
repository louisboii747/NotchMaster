import AppKit
import SwiftUI

@MainActor
struct NotchMenuView: View {
    let notchWindowController: NotchWindowController

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(notchWindowController.isPreviewVisible ? "Hide Notch Preview" : "Show Notch Preview") {
            notchWindowController.togglePreview()
        }

        Divider()

        Button("Open Settings…") {
            NSApplication.shared.activate()
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit NotchMaster") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
