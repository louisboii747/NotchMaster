# Native settings specification

Status: one native Settings window combines General and Features. General implements Launch at Login and Automatic/Light/Dark appearance. Features implements island status and expansion speed. Other categories below remain future requirements.

## Opening Settings

Open Settings in the menu bar, the standard app Settings command and Command-comma all open or focus the same SwiftUI Settings scene. The former Feature Settings command and separate development window have been removed. Closing Settings leaves the menu bar utility running. All controls use the existing `AppDependencies` preferences, login service and preview controller.

Manual Expand/Collapse and confirmed island status remain available in the menu bar. The island becomes available automatically after launch, expands on hover and recovers after wake or supported-display changes. Neither Settings nor the menu has an availability switch.

## Window structure

Use the app's native SwiftUI Settings scene with a two-column `NavigationSplitView` built from `sidebar` and `detail`. The sidebar contains a single-selection `List` with sidebar styling. Select General on first open, use stable category identifiers, and keep the selected detail title consistent with the sidebar.

The detail canvas uses `Form` with `.formStyle(.grouped)` and native `Section` grouping. Let SwiftUI manage row insets, form spacing, separators, selection treatment, control sizes, and window appearance. Do not introduce custom spacing frameworks, hand-drawn switch controls, simulated traffic lights, or a replacement navigation system.

Use native semantic colours in both appearances. Automatic follows macOS; Light and Dark override the Settings window appearance. The result should feel at home beside System Settings while remaining a normal independent app.

## Sidebar

| Category | SF Symbol | Detail title |
| :--- | :--- | :--- |
| General | `gearshape` | General |
| Features | `switch.2` | Features |
| Advanced | `slider.horizontal.3` | Advanced |
| Installed Plugins | `puzzlepiece.extension` | Installed Plugins |
| Pro Sync | `icloud` | Pro Sync |
| About | `info.circle` | About |

Use native `Label` rows and the user's accent colour. Verify symbol availability against the chosen deployment target.

## General

| Group | Control | Behaviour |
| :--- | :--- | :--- |
| Startup | **Launch at Login** · native toggle | Implemented through Core's Service Management adapter. On only for confirmed enabled status; off when unregistered. Show errors and required approval. |
| Appearance | **Appearance** · native segmented picker | Automatic, Light or Dark. Saved locally under `appAppearance`, default Automatic. Applies immediately to the entire Settings window, including its sidebar and title bar. |

Automatic releases the explicit appearance preference and follows subsequent macOS light/dark changes while Settings is open. Light and Dark remain selected independently of macOS. Reopening Settings or relaunching the app retains the selection. Unknown or malformed saved values fall back to Automatic. The black notch preview keeps its existing colours.

Launch-at-login state comes from `SMAppService.mainApp` through `LoginItemService`, with no UserDefaults Boolean. Each operation re-reads macOS status, including after a thrown error. Failed registration stays off and failed unregistration stays on when that is still the confirmed state. Status text describes disabled, enabled, approval-required, missing-service and unknown states. Errors are shown inline and remain until another attempt or an external status change.

When approval is required, the switch remains off and disabled, accompanied by Open Login Items Settings. This opens Apple's Login Items page through the Core adapter; the user grants approval or removes the pending item there. Returning to General Settings refreshes the status. Appearance, app activation and app-window focus notifications also refresh it without polling.

Launch at Login only controls whether macOS launches the app. Every app launch starts island availability without opening Settings. Existing saved `showNotchPreviewOnLaunch` values are ignored. The current project uses ad hoc signing; validate actual login launching with a properly signed installed copy, as described in [prototype testing](PROTOTYPE_TESTING.md#launch-at-login-checks).

## Features

Features explains automatic hover behaviour and displays the existing controller's confirmed status. There is no preview enable switch. Unsupported geometry displays the reason; availability resumes automatically when supported geometry returns. Wake recovery starts compact, with hover ready again.

The Animation section contains Dynamic Notch Expansion Speed and its current duration. Slow maps to 0.60 seconds and Fast to 0.15 seconds, with a default duration of 0.30 seconds. Give the slider labelled endpoints and an accessible value. Changes persist locally and affect subsequent transitions. Reduce Motion applies the controller's reduced transition behaviour independently of this preference.

## Advanced

Use a grouped Rendering section with a native **Enable Metal Border Shaders** toggle and secondary explanatory text: “Add animated border effects to the notch.”

Keep the stored preference distinct from effective rendering capability. When unsupported or overridden by accessibility settings, explain why the effect is inactive. A system-material or static-border fallback must remain usable. Rendering policy and the initial default will be decided after power and accessibility testing.

## Installed Plugins

Use a grouped form section with custom plugin rows built from native text and toggle controls. Each row contains an SF Symbol, plugin name, secondary description, and trailing switch. Keep the entire control accessible with a meaningful label and state.

The following are **fictional design fixtures**, not existing plugins or claimed community integrations:

| Name | Symbol | Descriptive subtitle | Initial fixture state |
| :--- | :--- | :--- | :--- |
| Now Playing | `music.note` | Playback details and controls at a glance. | Enabled |
| Focus Timer | `timer` | Keep your current focus session in view. | Disabled |
| System Pulse | `waveform.path.ecg` | A compact view of supported system metrics. | Disabled |

Fixtures belong only in future previews or explicit demo data. Shipping UI must read the real registry and show a native empty state when no plugins are installed.

Enabling or disabling a plugin is a lifecycle operation. Show pending work, prevent duplicate requests, expose errors, and restore the confirmed state after a failure. Disabling must stop ongoing work and release resources. The list needs distinct empty, loading, and unavailable states.

## Pro Sync

Present a native grouped upgrade card with the `icloud` symbol, the heading **Keep your setup in sync**, and supporting text: “Bring eligible preferences and layouts to your other Macs with NotchMaster Pro.” Use semantic title and body styles; retain the system's form spacing and materials.

The eventual primary action is **Upgrade to Pro**, accompanied by **Restore Purchases**. Resolve actual pricing and purchase wording from StoreKit. Do not invent a price, imply a subscription type, or show success before a verified entitlement exists.

| State | Presentation and action |
| :--- | :--- |
| Product loading | Native progress indication; upgrade action unavailable. |
| Free | Upgrade card and restoration action. |
| Purchasing or restoring | Progress and duplicate-action prevention. |
| User cancelled | Return to the previous stable state without an error alert. |
| Purchase unavailable or failed | Clear error and a retry path. |
| Pro, sync off | Explain sync scope and offer explicit opt-in. |
| Pro, iCloud unavailable | Explain account or service status and how to retry. |
| Pro, syncing or current | Show meaningful sync status and last successful sync when known. |
| Pro, sync failed | Preserve local preferences, show the error, and offer retry. |

Never treat a purchase as iCloud sign-in or as consent to upload data. Synchronize only the approved settings schema. Exclude plugin binaries, credentials, and private plugin content.

## About

Use the brand asset, app name, actual bundle version and build number, MIT licence information, and repository links. Read version values from the built bundle when it exists. An app without release metadata must not display an invented release version.

A donation action may remain unavailable until a real destination is configured. Do not substitute a fabricated payment link.

## Typography and accessibility

- Use semantic fonts such as `.body`, `.headline`, and `.title2` where hierarchy requires them.
- Use `.foregroundStyle(.secondary)` for descriptions and metadata.
- Honour light and dark appearance, accent colour, increased contrast, Reduce Motion, and Reduce Transparency.
- Use native keyboard navigation, focus, and VoiceOver labels for sidebar rows, toggles, plugin controls, and the slider.
- Keep text readable when the window is resized and when text size or localisation changes.
- Keep asynchronous service work out of view bodies and make transient state visible.

## Acceptance criteria for implementation

The settings feature is ready for review when the sidebar and detail selection stay synchronized, grouped forms use platform spacing, settings persist correctly, OS integration failures remain visible, plugin toggles track confirmed registry state, and Pro states work without fabricated data.

Verify on the eventual deployment baseline and current macOS, using keyboard navigation and VoiceOver, both appearances, reduced visual effects, a resized window, and purchase/sync failure conditions. An image of the intended design is not evidence that these behaviours work.

## Apple references

- [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [GroupedFormStyle](https://developer.apple.com/documentation/swiftui/groupedformstyle)
- [preferredColorScheme](https://developer.apple.com/documentation/swiftui/view/preferredcolorscheme(_:))
- [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
