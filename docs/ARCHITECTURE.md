# Architecture direction

Status: Phase 1 foundation, animated notch preview, automatic hover interaction with native haptic requests, an expanded live clock, date and read-only battery indicator, native menu bar controls, and Launch at Login are implemented. The startup, preference, and preview flows below exist; later feature sections record intended boundaries.

## Product boundary

NotchMaster is a macOS utility intended to place an expandable hub around a MacBook's display notch. SwiftUI renders the prototype, AppKit manages its overlay window, and Swift 6 is the language mode.

The foundation uses one native Xcode application target, Swift 6 language mode with complete concurrency checking, and an arm64-only macOS 14.0 deployment target. It was developed with Xcode 27.1 and Swift 6.4. Local builds use ad hoc signing and the initial bundle identifier `com.louisboii747.NotchMaster`. Distribution identity, purchase products, and iCloud containers remain undecided.

## Implemented startup and preference flow

`NotchMasterApp` is the `@main` SwiftUI entry point. It retains `AppDependencies` in `@State` and declares `MenuBarExtra` first, followed by one native `Settings` scene. Launch presents the menu bar utility without opening Settings. The former development window and its restoration adapter have been removed. The composition root creates the shared `PreferencesStore`, `LoginItemService`, `BatteryInformationService` and `NotchWindowController`. Settings receives the preferences, login service and preview controller explicitly. The menu receives that same controller.

The menu bar extra uses the monochrome `macbook` SF Symbol and native menu style. Expand/Collapse calls the existing controller method; availability follows app lifetime. Labels, expansion availability and status read its confirmed observable state. Open Settings activates the app and invokes SwiftUI's environment `openSettings` action. The native app Settings command and Command-comma open the same window. Quit uses native termination and Command-Q. Closing Settings leaves the app and its Dock icon running through the app delegate's last-window policy.

Settings uses a native `NavigationSplitView` with General and Features in its sidebar. General contains actual-status Launch at Login and the appearance selector. Features contains island availability guidance, confirmed controller status and `ExpansionSpeedSettings`. No enable or startup-preview switch is presented. Manual Expand/Collapse remains in the menu bar.

`AppAppearance` is a Foundation-only enum in Core. `PreferencesStore.appearance` persists `automatic`, `light` or `dark` under `appAppearance`. Missing or invalid values normalize to Automatic. UI maps that value to an optional SwiftUI `ColorScheme` and applies `preferredColorScheme` at the Settings root. Light and Dark override the entire presentation, including native window appearance. Automatic passes `nil`, releasing the override so macOS appearance changes flow through. The passive black notch content retains its existing colours.

The app initializer gives the delegate the same retained dependencies. After launch finishes, a one-time guard starts the existing controller unconditionally. `start()` requests compact presentation and hover tracking using validated geometry, without opening Settings or requesting app activation. `stop()` runs on application termination and cancels presentation and tracking. Previous `showNotchPreviewOnLaunch` values are ignored and the store no longer reads or writes that setting. Login launches use the same unconditional startup path.

The controller keeps automatic availability separate from confirmed panel visibility. Display changes revalidate a running island even after unsupported geometry hid it. System and display sleep suspend presentation, cancel animation and stop hover tracking. Each matching wake notification clears its own suspension; the island resumes only after both are awake and geometry is supported. Recovery reuses the existing panel, starts compact after a suspension, and does not request haptics or keyboard focus. Unsupported layouts remain hidden with a reason and retry on later display or wake events. There is no recovery polling or extra panel.

The store uses injected Foundation `UserDefaults` for appearance and expansion duration under `notchExpansionDuration`. Missing, malformed or non-finite durations become 0.30 seconds; finite values clamp to 0.15–0.60 seconds on load and assignment. The store does not monitor external preference edits.

`expansionSpeed` is a computed 0–1 control value. Zero means 0.60 seconds and one means 0.15 seconds. The native Features slider uses this inverse mapping and exposes duration as its accessible current value. Each transition reads the current duration through the App-injected provider. App also supplies the hosting-view factory for `NotchView`, keeping Core independent of SwiftUI view types.

`@Observable` tracks the shared preferences and `@Bindable` supplies native control bindings. `@MainActor` isolates dependencies, delegate, store and views. App, Core and UI remain source groups within one module. The macOS 14 baseline supports the Observation and Settings APIs used here; runtime compatibility still needs testing on that OS. Local signing, bundle identity and development version metadata do not establish distribution readiness.

Phase 1 validation passed on an Apple Silicon Mac running macOS 27.2 with Xcode 27.1: Debug preference tests and the Release build with Swift warnings treated as errors. Six preference tests cover eleven cases. An approved temporary XCTest UI harness using identical application sources verified the foundation window, Settings link and keyboard shortcut, inverse slider behaviour, and persistence across termination and relaunch. The temporary harness is outside the repository. macOS 14 runtime behaviour and a full VoiceOver session remain unverified.

## Layer boundaries

| Layer | Owns | Must delegate |
| :--- | :--- | :--- |
| App | App lifecycle, scenes, service composition | Business decisions to Core; rendering to UI. |
| Core | Preferences, registry, capability state, windows, integration services | SwiftUI view construction to UI. |
| UI | Native forms, notch views, interaction feedback | Persistence, registration, purchases, and sync to Core. |

Use dependency injection at the App boundary. Keep preferences, OS-reported state, and transient view state distinct. Do not turn a settings view into a global service locator.

## Windows and display geometry

`NotchWindowController` owns a lazily created borderless, non-activating `NSPanel` on the main actor. It exposes observable visibility, expansion state, and status to the Features settings page and menu bar. Its injected display provider reads `NSScreen` snapshots; an injected content factory supplies the SwiftUI hosting view. Notification centers are injectable for lifecycle tests.

`DisplayGeometry` selects a single active built-in display using the public Core Graphics display identity, independent of the main or keyboard-focused screen. Mirroring is unsupported. A positive top safe-area inset and consistent auxiliary top-left and top-right rectangles must describe a central gap in global AppKit coordinates. Missing, non-finite, or inconsistent geometry is rejected with a visible explanation, without falling back to guessed coordinates or an external display.

The compact panel spans exactly that reported gap, from the left auxiliary area's right edge to the right auxiliary area's left edge, with no side or bottom extension. Its height is the reported top safe-area inset, with its top at the display's top edge and its bottom at the safe-area boundary. Because the physical notch contains no drawable pixels, toggling the compact preview may produce little or no visible difference. The panel bypasses AppKit's normal visible-frame constraint only after geometry validation so it can occupy the menu-bar region. `NotchView` preserves the solid black surface and its 10-point rounded bottom corners. Compact rendering contains no text.

While the preview is visible, the menu bar offers Expand/Collapse alongside automatic hover interaction. Expansion targets 380 points wide and 120 points tall, never smaller than the reported notch gap. `DisplayGeometry` caps both side extensions equally to the smaller available side margin and caps the bottom extension to the available display height, preserving the gap's centre and the display's top edge. Collapse restores the exact compact frame. Expansion while hidden has no effect; no plugin content is implemented.

The controller revalidates geometry before each transition and owns at most one `NotchFrameAnimation`, an AppKit `NSAnimation` subclass using `.easeInOut`, a 60 Hz requested frame rate, and nonblocking operation in common main-run-loop modes. AppKit supplies eased progress. Each update interpolates width and height and reconstructs the origin from the target's fixed top edge and horizontal centre, resizing the existing panel and content. Intermediate widths use symmetric whole-point side offsets and heights use whole-point bottom offsets relative to the target, preventing AppKit frame rounding from shifting the centre by half a point. The final update applies the exact validated target. `NSAnimation` exposes its progress callback without actor isolation; the update captures a main-actor closure and asserts that executor with `MainActor.assumeIsolated`. The controller starts and stops animation only on the main actor and never uses threaded animation mode.

`isExpanded` records the requested target immediately, allowing the menu command to reverse an in-flight transition. Before starting another animation, the controller stops and releases the previous one, then captures the panel's current frame. There are no asynchronous completion handlers that can overwrite newer intent. A changed built-in display snapshot forces immediate placement instead of interpolating between display configurations. Initial presentation and display-change reconciliation are also immediate. `DisplayGeometry` equality supports this snapshot comparison without changing its frame calculations.

The injected Reduce Motion provider reads `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` at transition time. When enabled, the controller immediately applies the validated target. The workspace accessibility-display notification also stops an active animation and applies its requested target immediately if Reduce Motion becomes enabled. Turning it off does not animate an already settled preview.

The panel uses the status-bar level with all-Spaces and full-screen auxiliary collection behaviour. It cannot become key or main, ignores mouse events, has no shadow or presentation animation, and is ordered front without requesting app activation. Display-configuration notifications stop animation and hover tracking, revalidate a visible preview and reposition or hide it, preserving the requested expansion when geometry remains supported. System or display sleep hides it. Hiding stops animation and tracking and clears expansion. After an unsupported configuration or sleep, a running island resumes compact presentation automatically when wake and display state allow it. Visibility and expansion remain transient; the controller initializes hidden and compact, and app startup starts the same validated presentation path. Controller teardown invalidates the tracking timer, stops animation, removes observers and closes the panel.

These choices still require physical notched-display, menu-bar, Spaces, full-screen, and focus testing on hardware. External-only, clamshell, mirrored, and unnotched configurations intentionally have no preview. No fake-notch fallback is implemented.

Manual preview validation passed on arm64 macOS 27.2 with Xcode 27.2: the Debug build and all 23 test functions, covering 70 cases, with Swift warnings treated as errors. Tests cover synthetic compact and expanded geometry, display-bound clamping, passive panel and content reuse, focus preservation, repeated expansion/collapse and show/hide, display changes, expansion resets, sleep, controller cleanup, and the existing preference behaviour. They do not establish physical notch alignment or cross-application interaction.

Animation validation on 31 October 2026 passed the arm64 Debug build and all 32 test functions, covering 83 cases, on macOS 27.2 with Xcode 27.2 and Swift warnings treated as errors. There were no test failures or runtime warnings. Added coverage checks eased intermediate frames at multiple display origins, fixed anchors, current preference reads, rapid reversal, Reduce Motion changes, cancellation before display changes, hiding, sleep and teardown, and native run-loop completion without focus changes. These tests use synthetic display geometry and plain AppKit content; physical notch alignment, SwiftUI corner rendering during resizing, perceived smoothness, Spaces, full-screen behaviour and macOS 14 runtime testing remain manual validation work.

Later interactive work should:

- Derive layout from the selected display's current geometry, safe-area information, and auxiliary top areas instead of hard-coded notch sizes.
- Reconcile display changes, mirroring, scaling, full-screen transitions, sleep, and wake.
- Keep the compact hit region tight and restore it when the hub collapses.
- Avoid taking keyboard focus for passive status updates; make deliberate interaction keyboard accessible.
- Cancel obsolete transitions when display state or user intent changes.
- Define any future fake-notch behaviour for displays without a notch.

The physical notch contains no drawable pixels. The design must use the surrounding display area rather than assume content can be drawn over the camera housing.

## Expanded clock and date

`NotchView` uses `GeometryReader` to read the existing hosting view's actual dimensions during AppKit resizing. The content factory receives `safeAreaTop` from the same display snapshot that passed `DisplayGeometry.previewPlacement` validation. The controller caches only the camera height used to build the content, reusing that hosting view across transitions and hide/show. If the validated height changes, it rebuilds the content before applying the new frame. There is no UI-owned expansion state, second animation, display polling, or guessed camera size.

Below that camera height, `NotchClockView` centres a native title-sized hour and minute above a secondary subheadline-sized weekday, abbreviated month and day. SwiftUI `Text` uses Foundation date format styles with localized field ordering and the system's hour-cycle preference. A `TimelineView(.everyMinute)` supplies the current date at minute boundaries, covering time and date rollover without a custom clock timer. The compact view does not instantiate the timeline.

The text retains its natural size. A SwiftUI `visualEffect` measures it without storing layout state and computes opacity from the remaining horizontal and vertical room: 16 points on each side, 8 points above and below, then an 8-point fade range. Content is fully transparent until all text and margins fit below the camera. Insufficient space keeps it hidden. Because opacity is a pure function of current dimensions, a reversal follows the same reveal path immediately. AppKit remains responsible for panel animation and Reduce Motion; immediate target resizing also immediately resolves content visibility. The black shape and corners are unchanged.

Focused rendering and native hosting-view checks, plus remaining hardware checks, are recorded in [prototype testing](PROTOTYPE_TESTING.md).

## Read-only battery information

Core's `Services/BatteryInformationService.swift` contains a main-actor observable service, the immutable `BatteryInformation` value and an injectable `BatteryInformationProvider`. `AppDependencies` owns one service and passes it explicitly into the existing `NotchView` hosting factory. The service is independent of preferences, login items and preview visibility. UI reads its optional information through Observation; it does not import IOKit or query hardware.

`SystemBatteryInformationProvider` uses public `IOPSCopyPowerSourcesInfo`, `IOPSCopyPowerSourcesList` and `IOPSGetPowerSourceDescription` APIs. It selects the internal battery rather than an attached UPS, requires a present battery, valid current and maximum capacities and an explicit charging flag, and computes a rounded percentage from current divided by maximum. Missing or invalid data becomes unavailable, clearing any previous reading rather than presenting a guessed zero. `isCharging` is the reported charging flag, not an inference from external power; a full or paused battery can be connected without charging.

The provider installs one `IOPSNotificationCreateRunLoopSource` in the main run loop's common modes before the initial read. Power-source changes trigger a fresh snapshot; unchanged percentage and charging state do not update observable state. The C callback uses `MainActor.assumeIsolated` because the source is installed exclusively on the main run loop. Its context is unretained, and teardown removes and invalidates the source before releasing it. The service's callback captures the service weakly and stops observation on destruction. There is no battery polling timer, permission request, private API or write operation. Observation lasts for the app-owned service's lifetime, including while the preview is hidden, so reopening uses current information without a second observation lifecycle.

`NotchExpandedContentView` preserves the existing clock/date layout and minute timeline. Its trailing overlay places `NotchBatteryView` 12 points beside the clock, with a secondary monochrome battery symbol and caption-sized localized percentage. Charging uses a static bolt; otherwise the symbol rounds its fill to the nearest quarter. The accessibility label includes charging state and the value supplies the localized percentage. No battery settings or charging animation are implemented.

The battery overlay does not participate in the clock's layout. Its own geometry-based fade checks the full symmetric width needed to keep the clock centred and the maximum content height below validated camera clearance, using the existing margins and fade range. Insufficient space hides only the battery indicator; unavailable information omits it. This deliberately prioritizes an unchanged clock over showing a badge in constrained widths or long locales. Compact rendering, panel geometry and presentation, hover, haptics and animation remain owned by the existing paths.

## Hover and haptic feedback

`NotchHoverInteraction` holds transient hover state separately from the panel's requested expansion state. Its cached `NotchHoverRegions` derive from the existing validated compact and expanded frames. Activation extends the compact frame by 12 points horizontally and 10 points vertically, clipped to the display. This provides an accessible approach area below and beside the physical notch. The exit boundary adds 8 points around the expanded frame and includes the activation region for constrained displays. Both boundaries include their edges, including the display's top edge. Rendered dimensions and corners are unchanged.

The controller runs one repeating `Timer` at 30 Hz with 10 ms tolerance in the main run loop's common modes, only while a supported preview is visible. It samples `NSEvent.mouseLocation` in global AppKit coordinates, so it also works while another app is focused. The timer weakly captures the controller. It uses `MainActor.assumeIsolated` because it is installed exclusively on the main run loop. No event monitor, event tap, input interception, Accessibility permission or Input Monitoring permission is used. Samples compare the cursor with cached rectangles and a deadline; they do not enumerate displays, resize the panel or allocate a new timer. Display geometry is revalidated before a state transition and cached regions are rebuilt after display changes.

Tracking begins with a cursor baseline, producing no startup transition. A genuine entry requests expansion once and gives hover ownership of the expanded state. Staying anywhere within the wider exit boundary preserves expansion. Leaving starts a deadline 180 ms later using the monotonic system uptime. The first subsequent sample at or after the deadline collapses the panel if the cursor is still outside. Returning cancels the deadline, including a return observed on the expiry sample. Timer scheduling and sampling can add a small delay. The same sampler handles the deadline, so there is no separate delayed closure that could survive cancellation or overwrite newer intent.

Manual Expand/Collapse clears hover ownership and any pending deadline before using the existing animation path. The manual state remains until a fresh activation entry; when the cursor is already within the exit boundary, it must first leave that boundary. Entering a manually expanded preview adopts hover ownership without a redundant animation or haptic. Display notifications reset tracking against the new cursor baseline without feedback. Hiding, sleep, unsupported geometry and destruction invalidate the timer and discard the deadline. A running island automatically resumes compact presentation after wake or display recovery, with fresh hover tracking.

Only a hover request that changes the requested expansion state on the same validated display invokes the injected feedback callback, alongside starting the animation or applying the Reduce Motion target. Its production implementation retrieves `NSHapticFeedbackManager.defaultPerformer` for every request and calls `perform(.generic, performanceTime: .now)`. The performer handles current input devices, accessibility settings and user preferences; the app does not probe hardware capabilities or synthesize vibration. Reduce Motion still bypasses visual animation, while haptic policy remains with AppKit. There are no haptic requests for manual controls, repeated polling, cancelled deadlines, presentation, geometry correction, display changes, sleep/wake or teardown. Haptic requests do not establish that hardware delivered feedback, and visuals never depend on delivery.

Cursor position, monotonic time and the feedback callback are injectable at the controller boundary. Tests can fire the actual tracking timer against synthetic input and count requests without moving the user's pointer or invoking physical feedback. Hardware testing is still needed for tactile response, background interaction, perceived latency, system preference suppression and trackpad contact behaviour.

Hover validation on 31 October 2026 passed the arm64 Debug build and all 49 test functions, covering 108 cases, on macOS 27.2 with Xcode 27.2 and Swift warnings treated as errors. There were no final test failures, skipped cases or runtime warnings. Coverage includes entry, cached geometry, boundary hysteresis, delayed collapse, return cancellation, exact request counts, startup silence, manual overrides, animation reversal, live duration reads, Reduce Motion, unavailable feedback, display revalidation, sleep, timer invalidation and controller destruction. A native timer test uses real monotonic time with synthetic cursor input and verifies focus preservation. Earlier test builds required correcting a helper's access level and replacing a conditional closure expression that triggered a Swift compiler diagnostic failure. Physical haptic delivery, cross-application interaction and CPU/energy usage were not measured; macOS 14 runtime behaviour remains unverified.

## Swift 6 concurrency

AppKit windows and UI-facing mutable state belong on the main actor. Background collection, persistence, and sync should use explicit isolation and transfer `Sendable` values rather than window or view instances.

Plugin registry bookkeeping and plugin execution are separate responsibilities. Async tasks need an owner, cancellation on disable or shutdown, and bounded refresh behaviour. Do not use unchecked sendability or detached tasks to bypass isolation errors.

The foundation enables Swift 6 language mode and complete concurrency checking. Future implementation must also be compiled with the chosen macOS SDK before any build-support claim is made.

## Preferences and OS integrations

Persist small local preferences through a dedicated store. Validate values on load, clamp expansion duration to its supported range, and version any schema that later participates in sync.

`Sources/Core/Services/LoginItemService.swift` implements Launch at Login as a main-actor observable service. `MainAppLoginItemSystem` is the only adapter that calls `SMAppService.mainApp` to query status, register or unregister, and opens Apple's Login Items settings page. The injected `LoginItemSystem` protocol lets tests supply status and operations without changing real login items. `AppDependencies` creates and retains the service and passes it explicitly through `SettingsView` into `GeneralSettingsView`. `PreferencesStore` owns appearance and expansion duration; it stores no login-item state.

The native Launch at Login switch under Startup reads `LoginItemService.isEnabled`, derived strictly from `.enabled`. `.notRegistered`, `.requiresApproval`, `.notFound` and unknown future statuses are off. Pending approval disables only that switch and exposes Open Login Items Settings with an explanation; approval and removal remain under the user's control in System Settings. The service can unregister an enabled or pending registration. It does not invent a persisted desired state or claim that an accepted registration is already authorized.

Each explicit change reads system status before deciding whether an operation is needed and again after success or failure. Errors remain visible alongside the confirmed status, so failed registration leaves the switch off and failed unregistration leaves it on if macOS still reports enabled. An external status change clears the previous operation's error. Repeated requests do not re-register an enabled or approval-required service. Operations use the native synchronous API on the main actor without background workers, polling, helper executables, custom LaunchAgents or scripts.

General Settings refreshes on appearance, application activation and app-window key notifications while mounted. Returning from System Settings, reopening Settings or selecting General again reads current macOS login status. The unified window uses native grouped forms and controls. The local SwiftPieces `ElasticButton` adapter remains available as source, but the removed Open App Settings link no longer uses it. Attribution and licence information remain in [SwiftPieces](../SwiftPieces/README.md).

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

Consulted on 28 October through 3 November 2026. These links describe platform APIs and review requirements; features beyond the implemented prototype remain design proposals.

- [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [OpenSettingsAction](https://developer.apple.com/documentation/swiftui/opensettingsaction)
- [NSApplicationDelegate last-window termination](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldterminateafterlastwindowclosed(_:))
- [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [GroupedFormStyle](https://developer.apple.com/documentation/swiftui/groupedformstyle)
- [preferredColorScheme](https://developer.apple.com/documentation/swiftui/view/preferredcolorscheme(_:))
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [SMAppService registration](https://developer.apple.com/documentation/servicemanagement/smappservice/register())
- [SMAppService status](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum)
- [NSScreen safeAreaInsets](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets)
- [NSScreen auxiliaryTopLeftArea](https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea-uglc)
- [NSWindow orderFrontRegardless](https://developer.apple.com/documentation/appkit/nswindow/orderfrontregardless())
- [NSAnimation](https://developer.apple.com/documentation/appkit/nsanimation)
- [NSEvent mouseLocation](https://developer.apple.com/documentation/appkit/nsevent/mouselocation)
- [NSHapticFeedbackManager defaultPerformer](https://developer.apple.com/documentation/appkit/nshapticfeedbackmanager/defaultperformer)
- [NSHapticFeedbackPerformer](https://developer.apple.com/documentation/appkit/nshapticfeedbackperformer)
- [IOKit power-source notifications](https://developer.apple.com/documentation/iokit/1523868-iopsnotificationcreaterunloopsou)
- [IOKit current capacity](https://developer.apple.com/documentation/iokit/kiopscurrentcapacitykey)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), particularly sections 2.4.5, 2.5.2, and 4.7.
