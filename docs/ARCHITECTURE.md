# Architecture direction

Status: Phase 1 foundation and the first manually expandable notch preview are implemented. The startup, preference, and preview flows below exist; later feature sections record intended boundaries.

## Product boundary

NotchMaster is a macOS utility intended to place an expandable hub around a MacBook's display notch. SwiftUI renders the prototype, AppKit manages its overlay window, and Swift 6 is the language mode.

The foundation uses one native Xcode application target, Swift 6 language mode with complete concurrency checking, and an arm64-only macOS 14.0 deployment target. It was developed with Xcode 27.1 and Swift 6.4. Local builds use ad hoc signing and the initial bundle identifier `com.louisboii747.NotchMaster`. Distribution identity, purchase products, and iCloud containers remain undecided.

## Implemented startup and preference flow

`NotchMasterApp` is the `@main` SwiftUI entry point. It retains `AppDependencies` in `@State`, opens a single verification window, and declares a native `Settings` scene. The composition root creates `PreferencesStore` and `NotchWindowController`. It passes preferences explicitly through `SettingsView` to `GeneralSettingsView` and the controller to `AppShellView`. App composes the controller with a content factory that hosts UI's `NotchView`, keeping Core independent of UI view types. No panel is created until Show Notch Preview succeeds.

The store uses Foundation `UserDefaults` for one local duration under `notchExpansionDuration`. It accepts an injected defaults instance so tests can use isolated suites. Missing, malformed, or non-finite values become 0.30 seconds. Finite values are clamped to 0.15–0.60 seconds on load and assignment, and the validated value is persisted. The store does not monitor changes made outside the running app.

`expansionSpeed` is a computed 0–1 control value, not another stored preference. Zero means 0.60 seconds and one means 0.15 seconds. The native slider uses this inverse mapping and displays the duration as its accessible current value. The manual preview does not read or change this preference; no expansion animation is implemented.

`@Observable` lets SwiftUI track the store's duration. `@Bindable` creates the slider's two-way binding, so changes pass through the store's validation and persistence. `@State` retains the app's composition root across SwiftUI updates. `@MainActor` isolates the composition root, store, and views to the UI executor; the tiny defaults updates run there synchronously. No detached work or unchecked sendability is needed. App, Core, and UI remain source groups within one module rather than separate packages.

The macOS 14 baseline permits native Observation and `SettingsLink`. Review that baseline on older hardware before promising runtime compatibility. The bundle identifier, 0.1.0 build metadata, and local signing setup are development choices, not a distribution commitment. App Sandbox is enabled without additional capabilities; hardened runtime is requested but Xcode disables it for ad hoc signing. Distribution signing needs separate validation.

Phase 1 validation passed on an Apple Silicon Mac running macOS 27.2 with Xcode 27.1: Debug preference tests and the Release build with Swift warnings treated as errors. Six preference tests cover eleven cases. An approved temporary XCTest UI harness using identical application sources verified the foundation window, Settings link and keyboard shortcut, inverse slider behaviour, and persistence across termination and relaunch. The temporary harness is outside the repository. macOS 14 runtime behaviour and a full VoiceOver session remain unverified.

## Layer boundaries

| Layer | Owns | Must delegate |
| :--- | :--- | :--- |
| App | App lifecycle, scenes, service composition | Business decisions to Core; rendering to UI. |
| Core | Preferences, registry, capability state, windows, integration services | SwiftUI view construction to UI. |
| UI | Native forms, notch views, interaction feedback | Persistence, registration, purchases, and sync to Core. |

Use dependency injection at the App boundary. Keep preferences, OS-reported state, and transient view state distinct. Do not turn a settings view into a global service locator.

## Windows and display geometry

`NotchWindowController` owns a lazily created borderless, non-activating `NSPanel` on the main actor. It exposes observable visibility, expansion state, and status to the temporary shell controls. Its injected display provider reads `NSScreen` snapshots; an injected content factory supplies the SwiftUI hosting view. Notification centers are injectable for lifecycle tests.

`DisplayGeometry` selects a single active built-in display using the public Core Graphics display identity, independent of the main or keyboard-focused screen. Mirroring is unsupported. A positive top safe-area inset and consistent auxiliary top-left and top-right rectangles must describe a central gap in global AppKit coordinates. Missing, non-finite, or inconsistent geometry is rejected with a visible explanation, without falling back to guessed coordinates or an external display.

The compact panel spans exactly that reported gap, from the left auxiliary area's right edge to the right auxiliary area's left edge, with no side or bottom extension. Its height is the reported top safe-area inset, with its top at the display's top edge and its bottom at the safe-area boundary. Because the physical notch contains no drawable pixels, toggling the compact preview may produce little or no visible difference. The panel bypasses AppKit's normal visible-frame constraint only after geometry validation so it can occupy the menu-bar region. `NotchView` draws a solid black surface with rounded bottom corners; there are no controls or animations inside it.

While the preview is visible, `AppShellView` offers a temporary Expand/Collapse button. Expansion targets 380 points wide and 120 points tall, never smaller than the reported notch gap. `DisplayGeometry` caps both side extensions equally to the smaller available side margin and caps the bottom extension to the available display height, preserving the gap's centre and the display's top edge. The controller revalidates geometry and immediately resizes the same panel and content view without animation. Collapse restores the exact compact frame. Expansion while hidden has no effect; no hover handling or plugin content is implemented.

The panel uses the status-bar level with all-Spaces and full-screen auxiliary collection behaviour. It cannot become key or main, ignores mouse events, has no shadow or presentation animation, and is ordered front without requesting app activation. Display-configuration notifications revalidate a visible preview and reposition or hide it, preserving expansion when geometry remains supported. System or display sleep hides it. Hiding always clears expansion. After an unsupported configuration or sleep, the user must explicitly show it again in compact form. Visibility and expansion are transient and start hidden and compact on launch. Controller teardown removes observers and closes the panel.

These choices still require physical notched-display, menu-bar, Spaces, full-screen, and focus testing on hardware. External-only, clamshell, mirrored, and unnotched configurations intentionally have no preview. No fake-notch fallback is implemented.

Manual preview validation passed on arm64 macOS 27.2 with Xcode 27.2: the Debug build and all 23 test functions, covering 70 cases, with Swift warnings treated as errors. Tests cover synthetic compact and expanded geometry, display-bound clamping, passive panel and content reuse, focus preservation, repeated expansion/collapse and show/hide, display changes, expansion resets, sleep, controller cleanup, and the existing preference behaviour. They do not establish physical notch alignment or cross-application interaction.

Later interactive work should:

- Derive layout from the selected display's current geometry, safe-area information, and auxiliary top areas instead of hard-coded notch sizes.
- Reconcile display changes, mirroring, scaling, full-screen transitions, sleep, and wake.
- Keep the compact hit region tight and restore it when the hub collapses.
- Avoid taking keyboard focus for passive status updates; make deliberate interaction keyboard accessible.
- Cancel obsolete transitions when display state or user intent changes.
- Define any future fake-notch behaviour for displays without a notch.

The physical notch contains no drawable pixels. The design must use the surrounding display area rather than assume content can be drawn over the camera housing.

## Swift 6 concurrency

AppKit windows and UI-facing mutable state belong on the main actor. Background collection, persistence, and sync should use explicit isolation and transfer `Sendable` values rather than window or view instances.

Plugin registry bookkeeping and plugin execution are separate responsibilities. Async tasks need an owner, cancellation on disable or shutdown, and bounded refresh behaviour. Do not use unchecked sendability or detached tasks to bypass isolation errors.

The foundation enables Swift 6 language mode and complete concurrency checking. Future implementation must also be compiled with the chosen macOS SDK before any build-support claim is made.

## Preferences and OS integrations

Persist small local preferences through a dedicated store. Validate values on load, clamp expansion duration to its supported range, and version any schema that later participates in sync.

Launch at Login must reflect Service Management status. A stored Boolean alone cannot establish that macOS will launch the app. Registration failure, pending approval, and changes made outside the app need visible states.

Metal border effects are optional presentation. Respect Reduce Motion and Reduce Transparency, provide a non-Metal fallback, and avoid continuous rendering when the hub is inactive.

## Plugin boundary

Start by defining and validating the registry and bundled plugin lifecycle. Third-party packaging, loading, signing, isolation, and installation are open decisions. A registry alone is not a sandbox, and an in-process plugin inherits the host's process privileges.

The [plugin guide](PLUGINS.md) records author-facing design requirements without inventing a public SDK or package format.

## Pro and sync

The proposed Pro scope is opt-in iCloud synchronization of eligible settings and layouts. StoreKit-verified entitlement state should control access; local settings must remain usable while offline or when sync is unavailable.

Sync requires explicit account, entitlement, container, schema, conflict, retry, and sign-out handling. Never sync plugin executable code, signing material, authentication secrets, or plugin data without a separately reviewed data contract. iCloud sync does not imply remote control of another Mac.

The purchase type, price, App Store product identifiers, and CloudKit implementation have not been selected. UI copy must use verified store-provided product information once available.

## Distribution decision

App Store distribution and community extensions need a deliberate compatibility review before choosing a loader. Apple's review rules address sandboxing, downloaded code, and plug-ins; the intended mechanism must be evaluated against the applicable rules. Do not assume arbitrary downloaded Swift bundles can ship in the App Store edition.

Bundled modules, constrained declarative content, supported extension mechanisms, and a separately distributed community build are options to evaluate. No option is selected by this scaffold, and no App Store approval is implied.

## Implementation milestones

1. Choose the macOS baseline, toolchain, bundle identity, and project format.
2. Implement and verify the native settings flow with real persistence and service states.
3. Prototype panel geometry and interaction on a notched MacBook and an external display.
4. Establish the plugin contract with bundled reference implementations.
5. Select and validate community and App Store distribution boundaries.
6. Implement and verify purchases and sync using their sandbox environments.

## Apple references

Consulted on 28–29 October 2026. These links describe platform APIs and review requirements; features beyond the foundation and manual preview remain design proposals.

- [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [GroupedFormStyle](https://developer.apple.com/documentation/swiftui/groupedformstyle)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [NSScreen safeAreaInsets](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets)
- [NSScreen auxiliaryTopLeftArea](https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea-uglc)
- [NSWindow orderFrontRegardless](https://developer.apple.com/documentation/appkit/nswindow/orderfrontregardless())
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), particularly sections 2.4.5, 2.5.2, and 4.7.
