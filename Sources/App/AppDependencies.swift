import Foundation
import SwiftUI

@MainActor
final class AppDependencies {
    let preferences: PreferencesStore
    let loginItemService: LoginItemService
    let batteryInformationService: BatteryInformationService
    let nowPlayingService: NowPlayingService
    let notchWindowController: NotchWindowController

    init(
        defaults: UserDefaults = .standard,
        loginItemSystem: any LoginItemSystem = MainAppLoginItemSystem(),
        batteryInformationProvider: any BatteryInformationProvider = SystemBatteryInformationProvider(),
        nowPlayingProvider: any NowPlayingProvider = MusicNowPlayingProvider(),
        notchWindowController: NotchWindowController? = nil
    ) {
        nowPlayingService = NowPlayingService(provider: nowPlayingProvider)
        preferences = PreferencesStore(defaults: defaults) { [nowPlayingService] enabled in
            nowPlayingService.setEnabled(enabled)
        }
        nowPlayingService.setEnabled(preferences.showNowPlaying)
        loginItemService = LoginItemService(system: loginItemSystem)
        batteryInformationService = BatteryInformationService(provider: batteryInformationProvider)
        self.notchWindowController = notchWindowController ?? NotchWindowController(expansionDuration: { [preferences] in
            preferences.expansionDuration
        }) { [batteryInformationService, nowPlayingService, preferences] cameraHeight in
            NSHostingView(rootView: NotchView(
                cameraHeight: cameraHeight,
                batteryService: batteryInformationService,
                preferences: preferences,
                nowPlayingService: nowPlayingService
            ))
        }
    }
}
