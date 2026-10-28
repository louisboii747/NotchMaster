import SwiftUI

private enum SettingsCategory: Hashable {
    case general
}

@MainActor
struct SettingsView: View {
    let preferences: PreferencesStore
    @State private var selection = SettingsCategory.general

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $selection)
        } detail: {
            SettingsDetail(selection: selection, preferences: preferences)
        }
        .frame(minWidth: 480, minHeight: 240)
    }
}

@MainActor
private struct SettingsSidebar: View {
    @Binding var selection: SettingsCategory

    var body: some View {
        List(selection: $selection) {
            Label("General", systemImage: "gearshape")
                .tag(SettingsCategory.general)
        }
        .listStyle(.sidebar)
        .navigationTitle("Settings")
    }
}

@MainActor
private struct SettingsDetail: View {
    let selection: SettingsCategory
    let preferences: PreferencesStore

    var body: some View {
        switch selection {
        case .general:
            GeneralSettingsView(preferences: preferences)
                .navigationTitle("General")
        }
    }
}
