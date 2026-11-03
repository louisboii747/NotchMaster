# UI

Contains SwiftUI presentation. `AppShellView.swift` provides the foundation window's native feature settings form: a Notch Preview switch, confirmed preview status, the expansion speed setting and a link to the separate app Settings window. Preview visibility is temporary; the foundation switch reflects the controller after any optional startup Show request. The Settings link retains the local macOS SwiftPieces button adaptation with native Liquid Glass or bordered surfaces. `Notch/NotchView.swift` renders the black surface and a localized live clock and date below the camera when the panel has room. Content opacity follows the hosting view's actual size; AppKit owns expansion animation. `Settings/SettingsView.swift` with `GeneralSettingsView.swift` provides a native grouped form containing Startup's independent Launch at Login and Show Notch Preview on Launch switches, plus Appearance's expansion speed control. `ExpansionSpeedSettings`, declared in `GeneralSettingsView.swift`, supplies the same Appearance section to both windows. Views receive validated camera clearance, the Core preferences store, login-item service or preview controller explicitly.

General Settings uses `@Bindable` to edit the startup preview preference in the shared store without changing current visibility. General Settings binds its login switch directly to the service's confirmed enabled state, displays errors and required approval, and sends registration intents to Core. View appearance, app activation and window-focus events refresh status; the view does not call ServiceManagement or persist a login Boolean.

`NotchMenuView.swift` renders the native menu bar commands for Show/Hide, Expand/Collapse, Feature Settings, app Settings and Quit. Expansion is disabled while the preview is hidden. Titles, enabled state and the read-only status row read the shared controller directly. Feature Settings uses native `openWindow` for the existing foundation scene; Open Settings retains native `openSettings` and Command-comma. Both window actions request app activation. The menu owns no preview or preference state.

`NotchView` also receives the shared battery information service. `NotchExpandedContentView` keeps the existing clock centred and adds a secondary `NotchBatteryView` beside it without changing the clock's layout. The battery has its own geometry-based fit and fade, a static charging symbol and a localized percentage. Missing information or insufficient room omits the indicator; compact rendering remains unchanged. Hardware reads and observation stay in Core.

Planned responsibilities:

- The settings sidebar and grouped detail forms.
- General, Advanced, Installed Plugins, Pro Sync, and About pages.
- Interactive compact and expanded notch presentations.
- Plugin rows, the Pro upgrade card, and accessible system materials.

Use native controls, semantic typography, and platform spacing. Views render state and send intents to Core; views do not register login items, load code, verify purchases, or perform CloudKit operations directly.

The settings sidebar beyond General, other categories, and interactive notch views are future work. See the [settings specification](../../docs/SETTINGS.md).
