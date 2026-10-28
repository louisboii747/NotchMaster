# Native settings specification

Status: the Phase 1 native Settings scene implements only General's expansion speed slider and local persistence. The sidebar and other controls below remain future requirements.

## Window structure

Use the app's native SwiftUI Settings scene with a two-column `NavigationSplitView` built from `sidebar` and `detail`. The sidebar contains a single-selection `List` with sidebar styling. Select General on first open, use stable category identifiers, and keep the selected detail title consistent with the sidebar.

The detail canvas uses `Form` with `.formStyle(.grouped)` and native `Section` grouping. Let SwiftUI manage row insets, form spacing, separators, selection treatment, control sizes, and window appearance. Do not introduce custom spacing frameworks, hand-drawn switch controls, simulated traffic lights, or a replacement navigation system.

Follow the system's current appearance rather than freeze a pixel copy of one macOS release. The result should feel at home beside System Settings while remaining a normal independent app.

## Sidebar

| Category | SF Symbol | Detail title |
| :--- | :--- | :--- |
| General | `gearshape` | General |
| Advanced | `slider.horizontal.3` | Advanced |
| Installed Plugins | `puzzlepiece.extension` | Installed Plugins |
| Pro Sync | `icloud` | Pro Sync |
| About | `info.circle` | About |

Use native `Label` rows and the user's accent colour. Verify symbol availability against the chosen deployment target.

## General

| Group | Control | Behaviour |
| :--- | :--- | :--- |
| Startup | **Launch at Login** · native toggle | Bind through a Service Management adapter. Show actual registration status; handle failure and approval requirements. Default to off. |
| Appearance | **Dynamic Notch Expansion Speed** · native slider | Slow-to-fast presentation mapped inversely to expansion duration. Proposed duration range: 0.15–0.60 seconds, default 0.30 seconds. Clamp persisted values. |

Give the slider labelled endpoints and an accessible current value. Increasing speed must shorten the duration. Reduce Motion should provide an appropriate reduced transition regardless of the stored animation preference.

Launch-at-login changes must report failure and reconcile the visible toggle with actual OS state. Do not present successful enablement before registration succeeds. Re-read status when the Settings window becomes active so external changes are reflected.

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
- [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
