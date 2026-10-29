# UI

Contains SwiftUI presentation. `AppShellView.swift` provides the verification window, temporary Show/Hide Notch Preview control, and geometry status. `Notch/NotchView.swift` renders the static black compact surface. `Settings/SettingsView.swift` with `GeneralSettingsView.swift` provides a native grouped form containing only the functional expansion speed control. Views receive the Core preferences store or preview controller explicitly.

Planned responsibilities:

- The settings sidebar and grouped detail forms.
- General, Advanced, Installed Plugins, Pro Sync, and About pages.
- Compact and expanded notch presentations.
- Plugin rows, the Pro upgrade card, and accessible system materials.

Use native controls, semantic typography, and platform spacing. Views render state and send intents to Core; views do not register login items, load code, verify purchases, or perform CloudKit operations directly.

The settings sidebar beyond General, other categories, and interactive notch views are future work. See the [settings specification](../../docs/SETTINGS.md).
