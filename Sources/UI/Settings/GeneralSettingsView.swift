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

                Toggle("Show Notch Preview on Launch", isOn: $preferences.showNotchPreviewOnLaunch)
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("ShowNotchPreviewOnLaunch")
            } header: {
                Text("Startup")
            } footer: {
                Text(loginItemService.statusMessage)
            }

            ExpansionSpeedSettings(preferences: preferences)
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

@MainActor
struct ExpansionSpeedSettings: View {
    @Bindable var preferences: PreferencesStore

    var body: some View {
        Section {
            Slider(value: $preferences.expansionSpeed, in: 0...1) {
                Text("Dynamic Notch Expansion Speed")
            } minimumValueLabel: {
                Text("Slow")
            } maximumValueLabel: {
                Text("Fast")
            }
            .accessibilityLabel("Dynamic Notch Expansion Speed")
            .accessibilityValue(durationText)

            LabeledContent("Expansion duration") {
                durationText
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Faster speed means a shorter expansion duration. Changes are saved locally.")
        }
    }

    private var durationText: Text {
        Text("\(preferences.expansionDuration, format: .number.precision(.fractionLength(2))) seconds")
    }
}
