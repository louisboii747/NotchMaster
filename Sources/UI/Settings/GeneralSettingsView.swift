import SwiftUI

@MainActor
struct GeneralSettingsView: View {
    @Bindable var preferences: PreferencesStore

    var body: some View {
        Form {
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
        .formStyle(.grouped)
    }

    private var durationText: Text {
        Text("\(preferences.expansionDuration, format: .number.precision(.fractionLength(2))) seconds")
    }
}
