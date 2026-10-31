# Core

Owns application state and logic. `Settings/PreferencesStore.swift` is a main-actor observable store with injected `UserDefaults`, validated expansion duration, and a computed inverse speed value. `Windowing/DisplayGeometry.swift` validates built-in notch geometry from public display APIs and derives compact and expanded frames. `Windowing/NotchWindowController.swift` owns the passive preview panel, observable visibility/expansion/status, and display/sleep handling, with injected display and content providers.

`Windowing/NotchHoverInteraction.swift` derives cached activation and exit regions and handles hover entry, delayed collapse, cancellation and manual overrides. The window controller owns its cursor sampling timer and requests native haptics only for actual hover transitions. Cursor, clock and feedback providers are injectable for tests; no new preference or input permission is required.

Further planned responsibilities:

- Plugin registration, stable identities, lifecycle, and enablement state.
- Interactive notch content beyond the passive hover preview.
- Additional local preferences and validated settings updates.
- Login-item integration, purchase entitlements, and optional sync services.
- Explicit capability and error states exposed to the interface.

Keep UI view types out of state and service contracts. Isolate AppKit work to the main actor, use value snapshots across concurrency boundaries, and keep plugin execution decisions separate from registry bookkeeping.

The remaining items are ownership boundaries, not implemented services or separate Swift modules. See the [architecture](../../docs/ARCHITECTURE.md) and [plugin guide](../../docs/PLUGINS.md).
