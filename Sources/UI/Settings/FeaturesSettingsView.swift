import SwiftUI

@MainActor
struct FeaturesSettingsView: View {
    let preferences: PreferencesStore
    let notchWindowController: NotchWindowController

    var body: some View {
        Form {
            Section {
                Text("The island is available whenever NotchMaster is running. Hover over the notch to expand it.")
            } header: {
                Text("Features")
            } footer: {
                Text(notchWindowController.statusMessage)
            }

            ExpansionSpeedSettings(preferences: preferences)
        }
        .formStyle(.grouped)
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
            Text("Animation")
        } footer: {
            Text("Faster speed means a shorter expansion duration. Changes are saved locally.")
        }
    }

    private var durationText: Text {
        Text("\(preferences.expansionDuration, format: .number.precision(.fractionLength(2))) seconds")
    }
}
