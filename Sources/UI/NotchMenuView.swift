import AppKit
import SwiftUI

@MainActor
struct NotchMenuView: View {
    let notchWindowController: NotchWindowController

    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(notchWindowController.isPreviewVisible ? "Hide Notch Preview" : "Show Notch Preview") {
            notchWindowController.togglePreview()
        }

        Button(notchWindowController.isExpanded ? "Collapse Notch Preview" : "Expand Notch Preview") {
            notchWindowController.toggleExpansion()
        }
        .disabled(!notchWindowController.isPreviewVisible)

        Text(notchWindowController.statusMessage)

        Divider()

        Button("Feature Settings…") {
            NSApplication.shared.activate()
            openWindow(id: "development")
        }

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
