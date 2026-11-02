# Core

Owns application state and logic. `Settings/PreferencesStore.swift` is a main-actor observable store with injected `UserDefaults`, validated expansion duration, and a computed inverse speed value. `Windowing/DisplayGeometry.swift` validates built-in notch geometry from public display APIs and derives compact and expanded frames. `Windowing/NotchWindowController.swift` owns the passive preview panel, observable visibility/expansion/status, and display/sleep handling, with injected display and content providers.

`Windowing/NotchHoverInteraction.swift` derives cached activation and exit regions and handles hover entry, delayed collapse, cancellation and manual overrides. The window controller owns its cursor sampling timer and requests native haptics only for actual hover transitions. Cursor, clock and feedback providers are injectable for tests; no new preference or input permission is required.

`Services/LoginItemService.swift` owns observable login-item status, registration and unregistration, errors, refresh and the action to open Login Items settings. Its production adapter uses only `SMAppService.mainApp`; an injected `LoginItemSystem` supplies operations and status in tests. Enabled state comes from macOS, never from `PreferencesStore`. No polling or helper executable is required.

Further planned responsibilities:

- Plugin registration, stable identities, lifecycle, and enablement state.
- Interactive notch content beyond the passive hover preview.
- Additional local preferences and validated settings updates.
- Purchase entitlements and optional sync services.
- Explicit capability and error states exposed to the interface.

Keep UI view types out of state and service contracts. Isolate AppKit work to the main actor, use value snapshots across concurrency boundaries, and keep plugin execution decisions separate from registry bookkeeping.

The remaining items are ownership boundaries, not implemented services or separate Swift modules. See the [architecture](../../docs/ARCHITECTURE.md) and [plugin guide](../../docs/PLUGINS.md).
