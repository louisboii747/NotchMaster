# UI

Contains SwiftUI presentation. `Settings/SettingsView.swift` presents one native Settings window with General and Features in its sidebar. General contains the Launch at Login switch, plus a native Automatic/Light/Dark appearance picker. Features contains island availability guidance, confirmed status, the native Show Battery Status switch and the expansion speed control. Views receive the shared preferences store, login service and preview controller explicitly.

`SettingsView` maps Core's persisted `AppAppearance` to an optional SwiftUI `ColorScheme` and applies `preferredColorScheme` at the root. Light and Dark override the entire presentation. Automatic releases the override and follows macOS changes. Native semantic colours and grouped forms supply both appearances.

General uses `@Bindable` for persisted appearance. Launch at Login binds directly to the service's confirmed status, displays approval guidance and errors, and sends intents to Core. View appearance, app activation and window focus refresh status. Features reads confirmed status from the controller and uses `@Bindable` for saved battery visibility. Island availability follows app lifetime; Settings has no enable or startup-preview switch.

`NotchMenuView.swift` provides Expand/Collapse, status, Open Settings and Quit. Open Settings activates the app and uses native `openSettings` with Command-comma. The menu owns no preview or preference state.

`Notch/NotchView.swift` renders the black notch surface with a localized clock and date below the camera when the hosting view has room. AppKit owns expansion animation. The notch receives the shared preferences and read-only battery service. The battery indicator keeps the clock centred and hides when disabled or when information or space is unavailable. Preference changes update the existing hosting view immediately and leave battery observation running. Settings appearance does not change the black notch surface.

Use native controls, semantic typography and platform spacing. Views render state and send intents to Core. Other settings categories, plugin rows, Pro controls and interactive notch content remain future work. See the [settings specification](../../docs/SETTINGS.md).
