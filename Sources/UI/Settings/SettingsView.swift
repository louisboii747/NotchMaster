import SwiftUI

private enum SettingsCategory: Hashable {
    case general
    case features
}

@MainActor
struct SettingsView: View {
    let preferences: PreferencesStore
    let loginItemService: LoginItemService
    let notchWindowController: NotchWindowController
    @State private var selection = SettingsCategory.general

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
        } detail: {
            SettingsDetail(
                selection: selection,
                preferences: preferences,
                loginItemService: loginItemService,
                notchWindowController: notchWindowController
            )
        }
        .frame(minWidth: 640, minHeight: 480)
        .preferredColorScheme(preferences.appearance.colorScheme)
    }
}

@MainActor
private struct SettingsSidebar: View {
    @Binding var selection: SettingsCategory

    var body: some View {
        List(selection: $selection) {
            Label("General", systemImage: "gearshape")
                .tag(SettingsCategory.general)
            Label("Features", systemImage: "switch.2")
                .tag(SettingsCategory.features)
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
    let notchWindowController: NotchWindowController

    var body: some View {
        switch selection {
        case .general:
            GeneralSettingsView(preferences: preferences, loginItemService: loginItemService)
                .navigationTitle("General")
        case .features:
            FeaturesSettingsView(preferences: preferences, notchWindowController: notchWindowController)
                .navigationTitle("Features")
        }
    }
}

extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
