# UI

Contains SwiftUI presentation. Phase 1 implements `AppShellView.swift`, a clearly labelled foundation window, and `Settings/SettingsView.swift` with `GeneralSettingsView.swift`, a native grouped form containing only the functional expansion speed control. Views receive the Core preferences store explicitly.

Planned responsibilities:

- The settings sidebar and grouped detail forms.
- General, Advanced, Installed Plugins, Pro Sync, and About pages.
- Compact and expanded notch presentations.
- Plugin rows, the Pro upgrade card, and accessible system materials.

Use native controls, semantic typography, and platform spacing. Views render state and send intents to Core; views do not register login items, load code, verify purchases, or perform CloudKit operations directly.

The sidebar, other categories, and notch views are future work. See the [settings specification](../../docs/SETTINGS.md).
