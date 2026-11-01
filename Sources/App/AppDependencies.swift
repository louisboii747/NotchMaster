import Foundation
import SwiftUI

@MainActor
final class AppDependencies {
    let preferences: PreferencesStore
    let notchWindowController: NotchWindowController

    init(defaults: UserDefaults = .standard) {
        preferences = PreferencesStore(defaults: defaults)
        notchWindowController = NotchWindowController(expansionDuration: { [preferences] in
            preferences.expansionDuration
        }) { cameraHeight in
            NSHostingView(rootView: NotchView(cameraHeight: cameraHeight))
        }
    }
}
