# Core

Owns application state and logic. `Settings/PreferencesStore.swift` is a main-actor observable store with injected `UserDefaults`, validated expansion duration, a computed inverse speed value, persisted Automatic/Light/Dark `AppAppearance`, and default-on `showBatteryStatus` and `showNowPlaying` preferences. Island availability follows app lifetime instead of a saved enable or startup preference. `Windowing/DisplayGeometry.swift` validates built-in notch geometry from public display APIs and derives compact and expanded frames. `Windowing/NotchWindowController.swift` owns the non-activating island panel, observable visibility/expansion/status, and display/sleep/wake handling, with injected display and content providers. `start()` enables automatic presentation and recovery; `stop()` cancels it. Both system and display sleep suspend the island until their matching wake notifications arrive.

`Windowing/NotchHoverInteraction.swift` derives cached activation and exit regions and handles hover entry, delayed collapse, cancellation and manual overrides. The window controller owns its cursor sampling timer and requests native haptics only for actual hover transitions. Cursor, clock and feedback providers are injectable for tests; no new preference or input permission is required.

`Services/LoginItemService.swift` owns observable login-item status, registration and unregistration, errors, refresh and the action to open Login Items settings. Its production adapter uses only `SMAppService.mainApp`; an injected `LoginItemSystem` supplies operations and status in tests. Enabled state comes from macOS, never from `PreferencesStore`. No polling or helper executable is required.

`Services/BatteryInformationService.swift` owns optional read-only battery percentage and charging information. Its injected provider reads public IOKit power-source descriptions and observes changes with one main-run-loop source, without polling. Invalid or missing internal-battery data clears the reading; teardown removes observation. Battery information is transient and stores no settings.

`Services/NowPlayingService.swift` owns playing, paused and unavailable metadata, validated sampled timing and cancellable user-initiated transport through an injected provider with explicit start/stop and independent enablement. App wires Show Now Playing changes synchronously to `setEnabled(_:)`; disabling stops observation and clears state, while enabling resumes only during the started lifecycle. `Services/MusicNowPlayingProvider.swift` uses public Apple Events and Music scripting access groups, serial background reads, five-second refreshes only while enabled, Music runs and the Mac is awake, and 256-pixel artwork thumbnails. It observes workspace lifecycle and clears resources on stop. Only Music is implemented. Its live metadata/artwork and corrected consent flow were manually confirmed on the development Mac; distribution signing, other media types and macOS 14 remain unverified. See [Now Playing architecture](../../docs/ARCHITECTURE.md#now-playing-music-provider).

Further planned responsibilities:

- Plugin registration, stable identities, lifecycle, and enablement state.
- Additional notch interactions beyond Music transport.
- Additional local preferences and validated settings updates.
- Purchase entitlements and optional sync services.
- Explicit capability and error states exposed to the interface.

Keep UI view types out of state and service contracts. Isolate AppKit work to the main actor, use value snapshots across concurrency boundaries, and keep plugin execution decisions separate from registry bookkeeping.

The remaining items are ownership boundaries, not implemented services or separate Swift modules. See the [architecture](../../docs/ARCHITECTURE.md) and [plugin guide](../../docs/PLUGINS.md).
