import SwiftUI

@MainActor
struct AppShellView: View {
    let notchWindowController: NotchWindowController

    var body: some View {
        VStack(spacing: 16) {
            Text("NotchMaster")
                .font(.largeTitle)
            Text("Foundation build")
                .font(.headline)
            Text("A manually expandable notch preview and one local preference.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(notchWindowController.isPreviewVisible ? "Hide Notch Preview" : "Show Notch Preview") {
                notchWindowController.togglePreview()
            }
            if notchWindowController.isPreviewVisible {
                Button(notchWindowController.isExpanded ? "Collapse" : "Expand") {
                    notchWindowController.toggleExpansion()
                }
            }
            Text(notchWindowController.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SettingsLink {
                Text("Open Settings…")
            }
        }
        .padding(32)
        .frame(minWidth: 420, minHeight: 240)
    }
}
