import AppKit
import SwiftUI

@MainActor
struct GeneralSettingsView: View {
    @Bindable var preferences: PreferencesStore
    let loginItemService: LoginItemService

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: launchAtLogin)
                    .toggleStyle(.switch)
                    .disabled(loginItemService.requiresApproval)
                    .accessibilityIdentifier("LaunchAtLogin")

                if loginItemService.requiresApproval {
                    Button("Open Login Items Settings") {
                        loginItemService.openLoginItemsSettings()
                    }
                }

                if let errorMessage = loginItemService.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("LoginItemError")
                }
            } header: {
                Text("Startup")
            } footer: {
                Text(loginItemService.statusMessage)
            }

            Section {
                Picker("Appearance", selection: $preferences.appearance) {
                    Text("Automatic").tag(AppAppearance.automatic)
                    Text("Light").tag(AppAppearance.light)
                    Text("Dark").tag(AppAppearance.dark)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("AppAppearance")
            } header: {
                Text("Appearance")
            } footer: {
                Text("Automatic follows the macOS appearance.")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loginItemService.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItemService.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            loginItemService.refresh()
        }
    }

    var launchAtLogin: Binding<Bool> {
        Binding(
            get: { loginItemService.isEnabled },
            set: { loginItemService.setEnabled($0) }
        )
    }
}
