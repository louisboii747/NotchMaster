# UI

Reserved for SwiftUI presentation and reusable visual components.

Planned responsibilities:

- The settings sidebar and grouped detail forms.
- General, Advanced, Installed Plugins, Pro Sync, and About pages.
- Compact and expanded notch presentations.
- Plugin rows, the Pro upgrade card, and accessible system materials.

Use native controls, semantic typography, and platform spacing. Views render state and send intents to Core; views do not register login items, load code, verify purchases, or perform CloudKit operations directly.

No views or mock app implementation exist yet. See the [settings specification](../../docs/SETTINGS.md).
