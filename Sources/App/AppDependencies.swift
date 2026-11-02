import Foundation
import SwiftUI

@MainActor
final class AppDependencies {
    let preferences: PreferencesStore
    let loginItemService: LoginItemService
    let notchWindowController: NotchWindowController

    init(defaults: UserDefaults = .standard, loginItemSystem: any LoginItemSystem = MainAppLoginItemSystem()) {
        preferences = PreferencesStore(defaults: defaults)
        loginItemService = LoginItemService(system: loginItemSystem)
        notchWindowController = NotchWindowController(expansionDuration: { [preferences] in
            preferences.expansionDuration
        }) { cameraHeight in
            NSHostingView(rootView: NotchView(cameraHeight: cameraHeight))
        }
    }
}
