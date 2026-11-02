# Prototype testing and validation

NotchMaster is an early prototype, not yet a user-facing release.

The prototype supports one active, unmirrored built-in display with validated physical-notch geometry. It has native menu bar controls, a development verification window, Launch at Login, automatic hover interaction, native haptic requests, one expansion speed preference, and a passive expanded clock and date. It starts hidden. The physical camera region contains no drawable pixels.

## Automated checks

Run on an Apple Silicon Mac with Xcode:

```sh
xcodebuild -project NotchMaster.xcodeproj -scheme NotchMaster -configuration Debug -destination 'platform=macOS,arch=arm64' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build
xcodebuild -project NotchMaster.xcodeproj -scheme NotchMaster -configuration Debug -destination 'platform=macOS,arch=arm64' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES test
```

Existing tests cover preferences, validated display geometry, fixed animation anchors, reversal, hover boundaries, delayed collapse, native haptic request counts, Reduce Motion, focus, click-through panel configuration, display changes, sleep, and cleanup.

Login-item tests inject a fake system adapter and cover all reported statuses, confirmed registration and unregistration, pending approval, thrown errors, status changes during a failure, retries, duplicate requests, external changes, opening the approval page and dependency injection without persisting a login Boolean. Settings tests exercise the same binding used by the native toggle after failed operations and retries, and host the view to verify its activation and window-focus refresh callbacks. They do not register or unregister a real login item.

`NotchMenuTests` renders the actual SwiftUI menu through native `NSHostingMenu` and invokes its preview command. It checks titles against confirmed panel visibility, changes made through the shared controller, sleep and unsupported displays, failed Show requests, recovery with panel reuse, shortcuts, and continued control after closing and releasing a verification view. Native menu inspection requires macOS 14.4 or later; that suite is explicitly skipped on macOS 14.0 through 14.3 without changing the app's deployment target. Settings foreground presentation, actual status-item interaction and Quit remain manual end-to-end checks.

The clock checks compare compact SwiftUI rendering with the original black shape, verify that reveal begins only after the measured content fits, check localized expanded layouts, exercise a real `NSHostingView` during panel resizing and reversal, and verify that content receives refreshed validated camera clearance. Synthetic geometry and rendered pixels do not establish physical camera alignment or perceived animation quality.

Validation on 1 November 2026 passed the macOS arm64 Debug build and all 54 test functions, covering 120 cases, with Swift warnings treated as errors on macOS 27.2 and Xcode 27.2. There were no failures, skipped cases or reported runtime warnings. The built executable contains only arm64. `git diff --check` passed.

Menu bar validation on 2 November 2026 passed the arm64 Debug build and all 56 test functions, covering 123 cases, with Swift warnings treated as errors on macOS 27.2 and Xcode 27.2. The native menu tests ran without skips, and the full suite reported no failures or runtime warnings. SwiftLint 0.65.1 reported zero violations across 17 Swift files; SwiftFormat 0.64.5 reported no files requiring formatting. Actual status-item appearance, Settings foreground presentation, Quit, physical notch behaviour and macOS 14 runtime behaviour still require the manual checks below.

Launch at Login validation on 2 November 2026 passed the arm64 Debug build and all 67 test functions, covering 147 cases, with Swift warnings treated as errors on macOS 27.2 and Xcode 27.2. The full suite reported no failures, skips or runtime warnings. SwiftLint 0.65.1 found no violations across 21 Swift files, SwiftFormat 0.64.5 required no formatting changes, and `git diff --check` passed. The executable contains only arm64, and the SwiftPieces licence notice is included in its resources. Automated checks cover injected service operations and Settings binding/lifecycle behaviour; real login launching and the foundation button appearance and interaction remain manual checks.

Compact rendering matched the original surface at 32, 40 and 80-point camera heights. Expanded fitting and pixel-bound checks passed for US English, UK English, German, French, Japanese and Saudi Arabic, including 40-point camera clearance. Inspected test-result snapshots showed the native 12-hour and 24-hour formats and localized date order. Native hosting-view captures confirmed hidden compact and early-expansion content, visible content near full expansion, and hidden content after reversal to compact. The pixel test freezes native animation at each sample frame; existing tests separately exercise uninterrupted native animation. PNG attachments are retained in the Xcode test results.

Physical camera alignment, perceived animation smoothness, preference changes in macOS Settings, automatic minute and midnight rollover, hardware haptics, energy use, Spaces/full-screen interaction and macOS 14 runtime behaviour remain manual checks.

## Current preview behaviour

The project uses local ad hoc signing without a development team. Distribution signing remains undecided. Run the app from Xcode and click the monochrome MacBook menu bar symbol to show or hide the preview, open Settings or quit. The Show/Hide title reflects the shared controller's confirmed visibility. Closing the verification or Settings window leaves the utility running. The app retains its Dock icon, and Window > NotchMaster reopens the verification window for manual Expand and Collapse controls. Expansion animates the same black panel around and below the reported physical notch, keeping its top edge and horizontal centre fixed. Collapse restores the exact compact frame. Each transition reads the latest expansion duration from Settings. Rapid reversals stop the previous animation and continue from the current size. Reduce Motion applies the target immediately, including when enabled during an animation.

The preview starts hidden, does not take keyboard focus, and passes mouse events through. Initial presentation and display changes apply validated geometry immediately. Unsupported, inactive, or mirrored built-in displays produce an explanatory message without showing a panel. Display changes cancel any animation and revalidate placement; hiding, unsupported geometry, or sleep resets expansion. After hiding, the preview must be explicitly shown again and starts compact. Use Open Settings or Command-comma to edit expansion speed, then alternate Expand and Collapse to check the new duration without restarting. Physical notch alignment, animation appearance, Spaces, and full-screen interaction still need manual hardware testing.

The expanded preview shows the current hour and minute in white native type, with a subtle localized weekday and date below it. SwiftUI refreshes at minute boundaries and uses native date formatting, including the user's locale and 12/24-hour preference. Content sits entirely below the validated camera height and fades with the hosting view's actual size once the text fits. Compact rendering is unchanged; constrained layouts keep content hidden rather than clipping it.

While the preview is shown, move the pointer toward the physical notch from below or either side. The activation region extends 12 points on each side of the compact notch and 10 points below it. The exit region surrounds the expanded frame with an 8-point margin. Both regions stay within the built-in display. Leaving the exit region starts a 180 ms collapse delay; returning cancels it. Cursor sampling runs at 30 Hz, including while another app is focused, without intercepting input or requesting Accessibility or Input Monitoring permissions. Sampling and the delay stop when the preview is hidden or unsupported, on sleep, and when its controller is destroyed.

Manual Expand/Collapse cancels pending hover actions and holds the chosen state. A fresh entry into the activation region resumes automatic interaction; if the pointer was already nearby when a manual action occurred, first leave the wider exit region. A stationary pointer at initial presentation or after a display change produces no transition or haptic request.

Each actual hover expansion or delayed collapse requests one immediate `.generic` haptic through `NSHapticFeedbackManager.defaultPerformer`. Repeated polling, cancelled collapses, manual controls and lifecycle changes do not request feedback. AppKit selects the performer using the current input device, accessibility settings and system preferences. Feedback is optional: macOS may suppress it, including when there is no compatible trackpad or no finger touching it. Visual interaction always works independently.

## Launch at Login checks

The project currently uses local ad hoc signing. Apple's Service Management API requires a code-signed app and can reject a registration when its signature is unsuitable. An Xcode build in DerivedData is useful for UI and error-path checks, but its build location and executable can change between builds. A passing unit suite or successful Debug launch does not establish login launching for an installed app. Do not assume that moving an app to Applications alone fixes a signing error.

For an end-to-end check, build with a suitable Apple-issued signing identity, install the app at a stable path such as `/Applications/NotchMaster.app`, and run that copy. Use one copy with the bundle identifier under test, and remove any old registration before replacing or moving that copy. No signing identity or login-item registration is changed by the automated tests. The app keeps its existing verification window on startup, including a login launch.

1. Open Settings > General. With no existing registration, Launch at Login must be off. Enable it and compare the switch and status text with System Settings > General > Login Items. It must turn on only when macOS reports enabled.
2. If approval is required, the switch must remain off and disabled, with an explanation and Open Login Items Settings. Use that action, approve NotchMaster, then return to General Settings. The switch must refresh to the actual enabled state. Remove or deny the item there to verify the corresponding pending or disabled state on return.
3. Change the item externally while NotchMaster stays running. Return from System Settings, switch from the foundation window to Settings, and close/reopen Settings. Each path must show current macOS status without restarting the app.
4. Disable Launch at Login and confirm macOS removes the registration while NotchMaster continues running. If enabling or disabling fails, check the inline error and confirm the switch matches macOS rather than the requested value. Rebuild, move or re-sign test copies only after disabling their old registration.
5. With a properly signed installed copy enabled, save your work, log out and back in, and confirm the app launches with its usual verification window and hidden notch preview. Disable the item and repeat to confirm it no longer launches. Saved expansion speed must remain independent of login-item registration.
6. Exercise every foundation-window button with the pointer and keyboard in light and dark appearances, then with Reduce Motion and Reduce Transparency. Check the native Liquid Glass treatment on macOS 26 or later, the bordered fallback on earlier systems, and that each button performs its action once. Recheck Settings access and native focus indication.

Real registration, approval prompts, installed-app signing and login/logout behaviour require these manual checks. The macOS 14 runtime and appearance fallback remain separate hardware/OS validation work.

## MacBook checks before review

Use a MacBook with a physical notch and a Force Touch trackpad for the haptic checks. Assess physical feedback and perceived latency on hardware.

Before the notch checks:

1. Launch and confirm a monochrome MacBook menu bar symbol with a meaningful NotchMaster VoiceOver label. The menu must initially say Show Notch Preview. Show and hide from the menu, then from the verification window, reopening the menu each time to check that both agree. Compact preview visibility may be visually subtle because the camera area has no drawable pixels.
2. Close the verification window with the preview hidden, then show the preview through the menu. Repeat with the preview already shown. Hover expansion and delayed collapse must still work. Reopen the verification window through Window > NotchMaster and check that its controls reflect the current state.
3. Focus another app, then choose Open Settings from the menu. Settings must appear in front with the existing expansion speed preference. Close Settings and reopen it from the menu; test Command-comma while NotchMaster is active. Change the speed and confirm subsequent notch transitions use it.
4. Sleep/wake or switch to an unsupported display configuration while the preview is shown. Reopen the menu and confirm it says Show Notch Preview; recovery requires an explicit Show after supported geometry returns. With unsupported geometry, Show must stay Show and no panel should appear; the verification window provides the reason.
5. Quit through the menu and confirm the status item and preview disappear. Relaunch and confirm the preview starts hidden and the saved expansion speed remains. Test Command-Q separately, plus keyboard navigation and VoiceOver for the menu, in light and dark appearances.

Then check the existing notch behaviour:

1. Run the Debug app, show the preview, and check that compact appearance is unchanged with no text. Expand using the temporary control and by hovering. The white time and subtle date must sit below the physical camera, centred in the black area, with intact bottom corners.
2. Test the fastest and slowest expansion speeds. Repeatedly reverse expansion and collapse at early, middle and late points. Text should fade only when it fits, disappear before the panel becomes too small, and avoid clipped glyphs or flashes.
3. Leave the expanded clock visible across a minute boundary without moving the pointer. Check the time against macOS. Check date rollover across midnight when practical, plus reopening after sleep or a system clock/time-zone change.
4. Test macOS Language & Region settings with both 12-hour and 24-hour time, differing date orders, a longer localized weekday, and a non-English region. Check formatting and fit, including changes while the app is running. Test a different calendar or time zone if configured.
5. Focus another app and approach the notch from below and both sides. Check expansion, the 180 ms collapse delay, return cancellation, manual overrides, and subtle optional trackpad feedback. Confirm typing stays with the focused app, clicks pass through the panel, and movement near the activation boundary does not chatter.
6. Enable Reduce Motion before expanding, then during an animation. Panel and content should immediately resolve to the requested size. Repeat with system haptics disabled and with a mouse.
7. Test built-in display scaling and arrangement changes, external displays, mirroring, clamshell, sleep/wake, menu-bar interaction, Spaces and full-screen apps. Unsupported geometry must hide the panel; recovery requires explicitly showing the compact preview again.
8. Check VoiceOver presentation of the expanded time and date. Check macOS 14 separately before claiming runtime compatibility. Inspect idle CPU/energy if leaving the expanded clock visible for an extended period.

## Before reporting a problem

Include the Mac model, macOS version, whether a physical notch is present, display or mirroring configuration, and the exact steps to reproduce. Describe whether the issue involves visual animation, pointer detection, optional trackpad feedback, clock formatting or updates, or accessibility settings. Use the [issue tracker](https://github.com/louisboii747/NotchMaster/issues); a requested haptic is not guaranteed to be delivered by the hardware.

## Further technical detail

See [Architecture](ARCHITECTURE.md) for display geometry, window ownership and test coverage. The [file map](STRUCTURE.md) identifies implemented and planned code.

## Platform references

- [SwiftUI GeometryReader](https://developer.apple.com/documentation/swiftui/geometryreader)
- [SwiftUI visualEffect](https://developer.apple.com/documentation/swiftui/view/visualeffect(_:))
- [Minute-aligned timeline schedule](https://developer.apple.com/documentation/swiftui/timelineschedule/everyminute)
- [Foundation Date.FormatStyle](https://developer.apple.com/documentation/foundation/date/formatstyle)
