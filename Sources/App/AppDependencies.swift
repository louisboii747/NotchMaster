import Foundation
import SwiftUI

@MainActor
final class AppDependencies {
    let preferences: PreferencesStore
    let notchWindowController: NotchWindowController

    init(defaults: UserDefaults = .standard) {
        preferences = PreferencesStore(defaults: defaults)
        notchWindowController = NotchWindowController {
            NSHostingView(rootView: NotchView())
        }
    }
}
