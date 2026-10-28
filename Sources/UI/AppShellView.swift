import SwiftUI

@MainActor
struct AppShellView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("NotchMaster")
                .font(.largeTitle)
            Text("Foundation build")
                .font(.headline)
            Text("A minimal macOS app with one local preference.")
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
