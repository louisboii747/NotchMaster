# Core

Reserved for application state, plugin management, and platform services.

Planned responsibilities:

- Plugin registration, stable identities, lifecycle, and enablement state.
- AppKit notch window coordination and display geometry.
- Local preferences and validated settings updates.
- Login-item integration, purchase entitlements, and optional sync services.
- Explicit capability and error states exposed to the interface.

Keep UI view types out of state and service contracts. Isolate AppKit work to the main actor, use value snapshots across concurrency boundaries, and keep plugin execution decisions separate from registry bookkeeping.

These are ownership boundaries, not implemented services or separate Swift modules. See the [architecture](../../docs/ARCHITECTURE.md) and [plugin guide](../../docs/PLUGINS.md).
