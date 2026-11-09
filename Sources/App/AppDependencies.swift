import Foundation
import SwiftUI

@MainActor
final class AppDependencies {
    let preferences: PreferencesStore
    let loginItemService: LoginItemService
    let batteryInformationService: BatteryInformationService
    let notchWindowController: NotchWindowController

    init(
        defaults: UserDefaults = .standard,
        loginItemSystem: any LoginItemSystem = MainAppLoginItemSystem(),
        batteryInformationProvider: any BatteryInformationProvider = SystemBatteryInformationProvider(),
        notchWindowController: NotchWindowController? = nil
    ) {
        preferences = PreferencesStore(defaults: defaults)
        loginItemService = LoginItemService(system: loginItemSystem)
        batteryInformationService = BatteryInformationService(provider: batteryInformationProvider)
        self.notchWindowController = notchWindowController ?? NotchWindowController(expansionDuration: { [preferences] in
            preferences.expansionDuration
        }) { [batteryInformationService, preferences] cameraHeight in
            NSHostingView(rootView: NotchView(
                cameraHeight: cameraHeight,
                batteryService: batteryInformationService,
                preferences: preferences
            ))
        }
    }
}
