import SwiftUI

@MainActor
struct AppShellView: View {
    let preferences: PreferencesStore
    let notchWindowController: NotchWindowController

    var body: some View {
        Form {
            Section {
                Toggle("Notch Preview", isOn: previewVisibility)
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("NotchPreview")
            } header: {
                Text("Features")
            } footer: {
                Text("The preview starts hidden each time NotchMaster launches.\n\(notchWindowController.statusMessage)")
            }

            ExpansionSpeedSettings(preferences: preferences)

            Section {
                SettingsLink {
                    Text("Open App Settings…")
                }
            }
        }
        .formStyle(.grouped)
        .buttonStyle(ElasticButton())
        .frame(minWidth: 480, minHeight: 380)
    }

    var previewVisibility: Binding<Bool> {
        Binding(
            get: { notchWindowController.isPreviewVisible },
            set: { isVisible in
                guard isVisible != notchWindowController.isPreviewVisible else { return }
                if isVisible {
                    notchWindowController.showPreview()
                } else {
                    notchWindowController.hidePreview()
                }
            }
        )
    }
}
