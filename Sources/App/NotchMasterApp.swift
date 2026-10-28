import SwiftUI

@main
@MainActor
struct NotchMasterApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        Window("NotchMaster", id: "foundation") {
            AppShellView()
        }
        .defaultSize(width: 480, height: 280)

        Settings {
            SettingsView(preferences: dependencies.preferences)
        }
        .defaultSize(width: 520, height: 260)
    }
}
