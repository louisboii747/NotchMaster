import SwiftUI

private enum SettingsCategory: Hashable {
    case general
}

@MainActor
struct SettingsView: View {
    let preferences: PreferencesStore
    let loginItemService: LoginItemService
    @State private var selection = SettingsCategory.general

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $selection)
        } detail: {
            SettingsDetail(selection: selection, preferences: preferences, loginItemService: loginItemService)
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
    let loginItemService: LoginItemService

    var body: some View {
        switch selection {
        case .general:
            GeneralSettingsView(preferences: preferences, loginItemService: loginItemService)
                .navigationTitle("General")
        }
    }
}
