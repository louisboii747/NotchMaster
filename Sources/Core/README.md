# Core

Owns application state and logic. Phase 1 implements only `Settings/PreferencesStore.swift`, a main-actor observable store with injected `UserDefaults`, validated expansion duration, and a computed inverse speed value.

Further planned responsibilities:

- Plugin registration, stable identities, lifecycle, and enablement state.
- AppKit notch window coordination and display geometry.
- Additional local preferences and validated settings updates.
- Login-item integration, purchase entitlements, and optional sync services.
- Explicit capability and error states exposed to the interface.

Keep UI view types out of state and service contracts. Isolate AppKit work to the main actor, use value snapshots across concurrency boundaries, and keep plugin execution decisions separate from registry bookkeeping.

The remaining items are ownership boundaries, not implemented services or separate Swift modules. See the [architecture](../../docs/ARCHITECTURE.md) and [plugin guide](../../docs/PLUGINS.md).
