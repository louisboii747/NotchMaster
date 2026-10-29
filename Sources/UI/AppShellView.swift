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
            Text("A static notch preview and one local preference.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(notchWindowController.isPreviewVisible ? "Hide Notch Preview" : "Show Notch Preview") {
                notchWindowController.togglePreview()
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
