import SwiftUI

@MainActor
struct SettingsView: View {
    let preferences: PreferencesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("General")
                .font(.title2)
                .padding([.top, .horizontal])
            GeneralSettingsView(preferences: preferences)
        }
        .frame(minWidth: 480, minHeight: 240)
    }
}
