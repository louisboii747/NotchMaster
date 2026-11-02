# UI

Contains SwiftUI presentation. `AppShellView.swift` provides the verification window, temporary Show/Hide Notch Preview and Expand/Collapse controls, and geometry status. `Notch/NotchView.swift` renders the black surface and a localized live clock and date below the camera when the panel has room. Content opacity follows the hosting view's actual size; AppKit owns expansion animation. `Settings/SettingsView.swift` with `GeneralSettingsView.swift` provides a native grouped form containing only the functional expansion speed control. Views receive validated camera clearance, the Core preferences store or preview controller explicitly.

`NotchMenuView.swift` renders the native menu bar commands. It reads preview visibility directly from the shared controller, sends the existing toggle intent, opens the existing Settings scene after requesting app activation, and invokes native Quit. It owns no preview or preference state.

Planned responsibilities:

- The settings sidebar and grouped detail forms.
- General, Advanced, Installed Plugins, Pro Sync, and About pages.
- Interactive compact and expanded notch presentations.
- Plugin rows, the Pro upgrade card, and accessible system materials.

Use native controls, semantic typography, and platform spacing. Views render state and send intents to Core; views do not register login items, load code, verify purchases, or perform CloudKit operations directly.

The settings sidebar beyond General, other categories, and interactive notch views are future work. See the [settings specification](../../docs/SETTINGS.md).
