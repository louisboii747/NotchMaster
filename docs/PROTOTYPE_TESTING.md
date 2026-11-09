# Prototype testing and validation

NotchMaster is an early prototype, not yet a user-facing release.

The prototype supports one active, unmirrored built-in display with validated physical-notch geometry. It has native menu bar controls, one Settings window with General and Features pages and saved Automatic/Light/Dark appearance, Launch at Login, automatic hover interaction, native haptic requests, an expansion speed preference, and a passive expanded clock and date. Launch keeps Settings closed and makes the compact island available automatically on supported geometry. Hover expands it; wake and display recovery restore availability. The physical camera region contains no drawable pixels.

## Automated checks

Run on an Apple Silicon Mac with Xcode:

```sh
xcodebuild -project NotchMaster.xcodeproj -scheme NotchMaster -configuration Debug -destination 'platform=macOS,arch=arm64' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build
xcodebuild -project NotchMaster.xcodeproj -scheme NotchMaster -configuration Debug -destination 'platform=macOS,arch=arm64' -parallel-testing-enabled NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES test
swiftlint lint --strict
swiftformat --lint . --config .swiftformat
```

Existing tests cover preferences, validated display geometry, fixed animation anchors, reversal, hover boundaries, delayed collapse, native haptic request counts, Reduce Motion, focus, click-through panel configuration, display changes, sleep, and cleanup.

Battery tests inject a provider with explicit change events. They cover the initial snapshot, event-driven percentage and charging updates, unavailable-data recovery and clearing, observer cleanup, internal-battery selection, capacity normalization and missing or malformed fields. No test changes power management or charging. Rendering checks compare compact pixels with the original surface in both charging states, preserve the clock's pixels when adding the battery, enforce camera clearance and margins, and omit the battery when only the clock fits. Native hosting-view tests verify that provider events update the existing content without replacing it and that unavailable information removes the indicator. The panel resizing and reversal test also runs with battery data present.

Battery visibility tests cover the default-on value, both persisted values, loading and reloading with isolated UserDefaults, and fallback from malformed data. Native hosting tests change the actual Features binding while expanded, covering charging and non-charging data and initially unavailable information. They verify immediate hide/show without a minute-timeline tick, continued battery updates while disabled, unavailable-data clearing, unchanged clock bounds and panel frame, identical panel/content instances, and a single uninterrupted battery observation. Compact pixel comparisons run with both visibility values. These new tests require a macOS run; they have not been executed in the Linux editing workspace.

Startup tests invoke the real delegate callback with injected dependencies and synthetic display geometry. They verify unconditional compact availability and active hover tracking, independence from legacy saved startup-toggle values and login status, and no duplicate startup request. Unsupported launch keeps the panel absent and exposes its reason. Termination stops visibility and tracking. These checks assert no new titled window, no focus change and no login-item operations.

Login-item tests inject a fake system adapter and cover all reported statuses, confirmed registration and unregistration, pending approval, thrown errors, status changes during a failure, retries, duplicate requests, external changes, opening the approval page and dependency injection without persisting a login Boolean. Settings tests exercise the same binding used by the native toggle after failed operations and retries, and host the view to verify its activation and window-focus refresh callbacks. They do not register or unregister a real login item.

`NotchMenuTests` renders the actual SwiftUI menu through native `NSHostingMenu` and invokes Expand/Collapse. It checks expansion availability while hidden, titles after external controller changes, the status row while geometry is unsupported, sleep, display recovery, panel reuse, shortcuts, and continued control after closing Settings. Native menu actions verify that repeated Open Settings requests and the standard app Settings command reuse one window after closing and reopening it. Native menu inspection requires macOS 14.4 or later; that suite is explicitly skipped on macOS 14.0 through 14.3 without changing the app's deployment target. Settings foreground presentation from another app, actual status-item interaction and Quit remain manual end-to-end checks.

Automatic-availability checks start the controller and drive its actual hover timer with synthetic cursor input. They verify hover expansion and delayed collapse without an enable action, recovery after unsupported geometry, overlapping system/display sleep in both wake orders, panel reuse, timer cleanup, silent compact recovery and no resurrection after stopping. Low-level panel tests also exercise explicit show/hide calls to validate cleanup and reuse independently of app lifetime.

`AppLifecycleTests` checks that the real test-host app starts without a visible Settings or development window and retains regular activation policy. It also verifies the removed development-window command is absent. Finder relaunch, previously saved scene state and installed-app login launching still need the checks below.

Appearance tests persist and reload every mode, normalize invalid values, and host the actual Settings root in a native window. They check immediate Light/Dark overrides, independence from inherited appearance while explicitly selected, and inherited light/dark changes after returning to Automatic. These tests temporarily change only the test application's inherited appearance and restore it afterward; they do not change the global macOS preference.

After asserting startup state, the lifecycle test retains an off-screen, non-restorable test window for the test process lifetime. On macOS 27.2, a combined run with no persistent host window received a Quit event before completing; the same run with this fixture passed. This window exists only in the test bundle. Closing all real app windows and remaining available through the menu bar remains a manual end-to-end check.

The clock checks compare compact SwiftUI rendering with the original black shape, verify that reveal begins only after the measured content fits, check localized expanded layouts, exercise a real `NSHostingView` during panel resizing and reversal, and verify that content receives refreshed validated camera clearance. The surface rendering check samples the top edge, inward shoulder cutaways and rounded bottom corners at full, intermediate and constrained sizes; compact pixel comparisons still use the original surface. The updated shoulder rendering test has not been run in the Linux editing workspace and needs macOS validation. Synthetic geometry and rendered pixels do not establish physical camera alignment or perceived animation quality.

Validation on 1 November 2026 passed the macOS arm64 Debug build and all 54 test functions, covering 120 cases, with Swift warnings treated as errors on macOS 27.2 and Xcode 27.2. There were no failures, skipped cases or reported runtime warnings. The built executable contains only arm64. `git diff --check` passed.

Menu bar validation on 2 November 2026 passed the arm64 Debug build and all 56 test functions, covering 123 cases, with Swift warnings treated as errors on macOS 27.2 and Xcode 27.2. The native menu tests ran without skips, and the full suite reported no failures or runtime warnings. SwiftLint 0.65.1 reported zero violations across 17 Swift files; SwiftFormat 0.64.5 reported no files requiring formatting. Actual status-item appearance, Settings foreground presentation, Quit, physical notch behaviour and macOS 14 runtime behaviour still require the manual checks below.

Launch at Login validation on 2 November 2026 passed the arm64 Debug build and all 67 test functions, covering 147 cases, with Swift warnings treated as errors on macOS 27.2 and Xcode 27.2. The full suite reported no failures, skips or runtime warnings. SwiftLint 0.65.1 found no violations across 21 Swift files, SwiftFormat 0.64.5 required no formatting changes, and `git diff --check` passed. The executable contains only arm64, and the SwiftPieces licence notice is included in its resources. Automated checks cover injected service operations and Settings binding/lifecycle behaviour; real login launching and the foundation button appearance and interaction remain manual checks.

Quiet startup validation on 2 November 2026 passed the arm64 Debug build and all 68 test functions, covering 148 cases, with Swift warnings treated as errors on macOS 27.2 and Xcode 27.2. There were no failures, skipped cases or reported runtime warnings. SwiftLint 0.65.1 found no violations across 21 Swift files, SwiftFormat 0.64.5 required no formatting changes, and `git diff --check` passed. Startup, regular activation policy, native Window-menu access, close/reopen and the development window's disabled restoration are covered automatically. Saved-state migration, Finder relaunch, closing all app windows without the test fixture, installed-app login launching and macOS 14 runtime behaviour remain manual checks.

Menu controls and separate settings validation on 2 November 2026 passed the arm64 Debug build and all 71 test functions, covering 152 cases, with Swift warnings treated as errors on macOS 27.2 and Xcode 27.2. There were no failures, skipped cases or reported runtime warnings. SwiftLint 0.65.1 found no violations across 21 Swift files, SwiftFormat 0.64.5 required no formatting changes, and `git diff --check` passed. New checks cover menu expansion, disabled state, status feedback, native actions opening separate feature/app Settings windows, repeated foundation-window requests and the feature toggle's confirmed state. Actual status-item interaction, visual form layout, keyboard/VoiceOver behaviour, hardware notch behaviour and macOS 14 runtime checks remain manual.

Startup preview validation on 3 November 2026 passed the arm64 Debug build and all 76 test functions, covering 161 cases, with Swift warnings treated as errors on macOS 27.2 and Xcode 27.2. There were no failures, skipped cases or reported runtime warnings. SwiftLint 0.65.1 found no violations across 21 Swift files and SwiftFormat 0.64.5 required no formatting changes. The executable contains only arm64. Launch preference persistence, the Settings binding and one-time delegate behaviour use isolated defaults, synthetic displays and fake login-item operations; Finder relaunch, physical notch behaviour, visual/accessible toggle presentation, installed-app login launching and macOS 14 runtime behaviour remain manual checks.

Battery indicator validation on 3 November 2026 passed the arm64 Debug build and all 86 test functions, covering 198 cases, with Swift warnings treated as errors on macOS 27.2 and Xcode 27.2. There were no failures, skipped cases or reported runtime warnings. SwiftLint 0.65.1 found no violations across 23 Swift files, SwiftFormat 0.64.5 required no formatting changes, and `git diff --check` passed. The executable contains only arm64. Inspected charging and non-charging render attachments show the secondary badge beside the unchanged clock. These synthetic checks do not establish physical camera alignment, live charger transitions, optimized-charging behaviour or macOS 14 runtime compatibility; use the MacBook Air checks below.

Unified Settings validation on 3 November 2026 passed the arm64 Debug build and all 90 test functions, covering 206 cases, with Swift warnings treated as errors on macOS 27.2. There were no failures, skips or reported runtime warnings. SwiftLint reported zero violations across 23 Swift files, SwiftFormat required no formatting changes, and `git diff --check` passed. Native tests verify window reuse, close/reopen, appearance changes and preference persistence. General form render attachments were inspected in Light and Dark; off-screen AppKit captures do not fully reproduce sidebar vibrancy. Full visual interaction, a real global macOS appearance change, VoiceOver and macOS 14 remain manual checks. Computer-use inspection was unavailable because the server timed out.

Automatic island validation on 3 November 2026 passed the arm64 Debug build and all 91 test functions, covering 207 cases, with Swift warnings treated as errors on macOS 27.2. There were no failures, skips or reported runtime warnings. SwiftLint reported zero violations across 23 Swift files, SwiftFormat required no formatting changes, and `git diff --check` passed. Synthetic native tests cover startup, hover readiness, legacy preference independence, display recovery, overlapping sleep/wake, termination and menu/settings behaviour. Physical hover feel, real sleep/wake, installed-app login launching and macOS 14 remain manual checks.

Compact rendering matched the original surface at 32, 40 and 80-point camera heights. Expanded fitting and pixel-bound checks passed for US English, UK English, German, French, Japanese and Saudi Arabic, including 40-point camera clearance. Inspected test-result snapshots showed the native 12-hour and 24-hour formats and localized date order. Native hosting-view captures confirmed hidden compact and early-expansion content, visible content near full expansion, and hidden content after reversal to compact. The pixel test freezes native animation at each sample frame; existing tests separately exercise uninterrupted native animation. PNG attachments are retained in the Xcode test results.

Physical camera alignment, perceived animation smoothness, preference changes in macOS Settings, automatic minute and midnight rollover, hardware haptics, energy use, Spaces/full-screen interaction and macOS 14 runtime behaviour remain manual checks.

## Current preview behaviour

The project uses local ad hoc signing without a development team. Distribution signing remains undecided. The MacBook menu bar menu contains Expand/Collapse, status, Open Settings and Quit. Open Settings and Command-comma reuse one native window. General contains startup and appearance controls; Features contains automatic-hover guidance, status, Show Battery Status and expansion speed. Closing Settings leaves the utility and its Dock icon running. Expansion animates the same black panel around and below the physical notch, keeping its top edge and horizontal centre fixed. Collapse restores the compact frame. Each transition reads the saved duration; rapid reversals continue from the current size. Reduce Motion applies the target immediately.

The island starts compact automatically after app launch and becomes hover-ready on supported geometry. It does not take keyboard focus and passes mouse events through. Initial presentation and display changes apply validated geometry immediately. Unsupported, inactive or mirrored built-in displays expose a reason while keeping the panel hidden. Sleep cancels animation and tracking; matching wake notifications and supported-display changes restore compact availability automatically. Use Open Settings or Command-comma and select Features to edit expansion speed, then alternate Expand and Collapse to check the next transition. Physical alignment, Spaces and full-screen interaction still need hardware testing.

The expanded preview shows the current hour and minute in white native type, with a subtle localized weekday and date below it. SwiftUI refreshes at minute boundaries and uses native date formatting, including the user's locale and 12/24-hour preference. Content sits entirely below the validated camera height and fades with the hosting view's actual size once the text fits. Compact rendering is unchanged; constrained layouts keep content hidden rather than clipping it.

A secondary battery icon and localized percentage sit beside the clock when there is room. The clock stays centred and keeps its existing layout. The static bolt means macOS reports active charging; plugged-in batteries that are full or paused may have no bolt. Missing or invalid battery information omits the indicator, and insufficient width hides it independently of the clock. Battery information refreshes once at service initialization and on public IOKit power-source notifications, including while the preview is hidden. It has no polling timer or charging animation. Show Battery Status in Features > Notch Content defaults to on and persists across launches. Turning it off immediately removes only the indicator, without stopping battery observation or changing the clock, date, compact rendering, panel size or animation.

While the preview is shown, move the pointer toward the physical notch from below or either side. The activation region extends 12 points on each side of the compact notch and 10 points below it. The exit region surrounds the expanded frame with an 8-point margin. Both regions stay within the built-in display. Leaving the exit region starts a 180 ms collapse delay; returning cancels it. Cursor sampling runs at 30 Hz, including while another app is focused, without intercepting input or requesting Accessibility or Input Monitoring permissions. Sampling and the delay stop when the preview is hidden or unsupported, on sleep, and when its controller is destroyed.

Manual Expand/Collapse cancels pending hover actions and holds the chosen state. A fresh entry into the activation region resumes automatic interaction; if the pointer was already nearby when a manual action occurred, first leave the wider exit region. A stationary pointer at initial presentation or after a display change produces no transition or haptic request.

Each actual hover expansion or delayed collapse requests one immediate `.generic` haptic through `NSHapticFeedbackManager.defaultPerformer`. Repeated polling, cancelled collapses, manual controls and lifecycle changes do not request feedback. AppKit selects the performer using the current input device, accessibility settings and system preferences. Feedback is optional: macOS may suppress it, including when there is no compatible trackpad or no finger touching it. Visual interaction always works independently.

## Unified Settings and appearance checks

1. With Settings closed, quit fully and launch from Xcode and Finder. Confirm the menu bar and Dock icons remain, Settings stays closed and hover expands the automatically available island. No separate development window should be available or restored.
2. Open Settings through the menu bar, then use the standard app Settings command and Command-comma. Each must focus the same window. Close it and reopen it. Hover and Expand/Collapse must remain usable while Settings is closed.
3. Select General and Features in the sidebar. Check the correct detail title and controls. Under Features, verify automatic-hover guidance and confirmed status, including an unsupported-display reason when appropriate. Neither page should have a preview enable or startup-preview switch. Change expansion speed and confirm later transitions use it.
4. Under General > Appearance, choose Dark and Light. Check the sidebar, form, text, controls and native title bar in each appearance. The choice must apply immediately without changing preview visibility or notch colours. Close/reopen Settings and relaunch to verify persistence.
5. Choose Automatic, change macOS between light and dark, and confirm the open Settings window follows each change. Repeat after selecting an explicit appearance, returning to Automatic, and relaunching. Explicit Light and Dark must remain independent of macOS changes.
6. Check both pages with keyboard navigation, VoiceOver, resizing, increased contrast, Reduce Motion and Reduce Transparency. Repeat on macOS 14 before claiming baseline runtime validation. The native menu test suite requires macOS 14.4 or later.
7. Quit through the menu and test Command-Q separately. Confirm menu and preview teardown and saved preferences on relaunch.

## Automatic island availability checks

1. Launch on a supported notched display without opening Settings. Move the pointer into the notch activation area and confirm expansion. Leave the expanded area and confirm delayed collapse. Repeat after closing Settings. No enable action should be needed.
2. Launch a copy with the former startup-preview setting saved as either false or true. Both must behave identically. Check manual app launches and signed installed-app login launches independently.
3. Launch with external-only, mirrored, clamshell or otherwise unsupported geometry. No panel should appear, expansion should be disabled, and the menu and Features page should show the reason. Restore supported built-in geometry without relaunching or opening Settings. The compact island and hover tracking must become available automatically.
4. Sleep/wake the Mac and separately sleep/wake the display. Confirm compact recovery and hover expansion without an enable action. No stale animation, pending collapse or extra haptic should survive the suspension. Test display changes around wake as well.
5. Quit while expanded and confirm the panel and menu disappear. Relaunch and check compact availability with saved appearance and expansion speed preserved. Repeat on macOS 14 before claiming baseline validation.

## Launch at Login checks

The project currently uses local ad hoc signing. Apple's Service Management API requires a code-signed app and can reject a registration when its signature is unsuitable. An Xcode build in DerivedData is useful for UI and error-path checks, but its build location and executable can change between builds. A passing unit suite or successful Debug launch does not establish login launching for an installed app. Do not assume that moving an app to Applications alone fixes a signing error.

For an end-to-end check, build with a suitable Apple-issued signing identity, install the app at a stable path such as `/Applications/NotchMaster.app`, and run that copy. Use one copy with the bundle identifier under test, and remove any old registration before replacing or moving that copy. No signing identity or login-item registration is changed by the automated tests. Login launches use the same automatic availability path as manual launches, with Settings closed and the compact island ready for hover on supported geometry.

1. Open Settings > General. With no existing registration, Launch at Login must be off. Enable it and compare the switch and status text with System Settings > General > Login Items. It must turn on only when macOS reports enabled.
2. If approval is required, the switch must remain off and disabled, with an explanation and Open Login Items Settings. Use that action, approve NotchMaster, then return to General Settings. The switch must refresh to the actual enabled state. Remove or deny the item there to verify the corresponding pending or disabled state on return.
3. Change the item externally while NotchMaster stays running. Return from System Settings, switch from Features to General, and close/reopen Settings. Each path must show current macOS status without restarting the app.
4. Disable Launch at Login and confirm macOS removes the registration while NotchMaster continues running. If enabling or disabling fails, check the inline error and confirm the switch matches macOS rather than the requested value. Rebuild, move or re-sign test copies only after disabling their old registration.
5. With a properly signed installed copy enabled, save your work, log out and back in, and confirm the menu bar icon appears with Settings closed and the island available on hover. Disable the login item and repeat to confirm it no longer launches. Saved appearance and expansion speed must remain independent of login-item registration.
6. Exercise the Features speed slider, plus General login-item and appearance controls, with the pointer and keyboard in both appearances and with reduced visual effects. Confirm every Settings entry point reuses the same window.

Real registration, approval prompts, installed-app signing and login/logout behaviour require these manual checks. The macOS 14 runtime and appearance fallback remain separate hardware/OS validation work.

## Battery visibility preference checks

1. With no saved battery preference, open Settings > Features > Notch Content and confirm Show Battery Status is on. Check its native switch, keyboard operation and VoiceOver label in Light and Dark appearances.
2. Expand the notch using the menu, then change the switch while it stays expanded. Only the battery indicator should disappear or return immediately, without waiting for a clock tick, moving the clock/date, resizing the panel or restarting its animation.
3. With the switch off, collapse and re-expand, change charging state, and sleep/wake. The battery must remain hidden while the clock and hover behaviour work normally. Re-enable and compare the current reading with macOS.
4. Close/reopen Settings and fully quit/relaunch with the switch off, then repeat with it on. Confirm the selection persists and compact appearance stays unchanged. Unavailable data must never create a placeholder or guessed reading, regardless of the switch.

## Battery checks on MacBook Air

1. Launch and hover to expand the island on a supported built-in display. Check that the expanded surface joins the display's top edge through inward-curving shoulders, without the outward-rounded wallpaper gaps. Check that the bottom corners remain rounded, including during slow expansion and reversal. Compare the percentage with macOS, allowing for rounding and notification timing. Check the gap between the battery badge and the centred clock, with both fully below the physical camera. Collapse and confirm the compact surface returns to its original size and shape.
2. Connect and disconnect power while expanded. Check the static bolt against macOS's actual charging state, including optimized charging or a full battery when practical. A power cable alone must not imply charging. The clock, focus, hover and panel must not jump or restart.
3. Collapse the island, change power state, then hover to expand it again. It should use the latest battery information. Sleep/wake and hover again to verify automatic recovery. Leave it expanded through a percentage change and a clock minute boundary.
4. Exercise rapid expansion/collapse reversals at slow and fast speeds and with Reduce Motion. Check that the indicator never crosses camera clearance or clips. Try longer locale formats; when there is insufficient horizontal room, only the battery should disappear and the clock should retain its existing behaviour.
5. Check the battery's VoiceOver label, charging state and percentage. Unavailable information is covered by the injected tests; when encountered on hardware, the badge should disappear without a fabricated reading or disruption to the clock. Physical appearance, charger transitions, optimized charging, idle energy use and macOS 14 remain manual validation work.

## MacBook checks before review

Use a MacBook with a physical notch and a Force Touch trackpad for the haptic checks. Assess physical feedback and perceived latency on hardware.

Run these checks with the app open and Settings closed:

1. Launch and confirm the monochrome MacBook menu bar symbol and meaningful VoiceOver label. On supported geometry, Expand Notch Preview should be enabled immediately. Hover to expand and leave to collapse. Compact visibility may be subtle because the physical camera area has no drawable pixels.
2. With Settings closed, alternate menu Expand/Collapse and automatic hover. Titles must follow both paths. Open Settings > Features and check the same confirmed status without an enable toggle.
3. Focus another app and choose Open Settings from the menu. It must appear in front. Close and reopen it, then test Command-comma while NotchMaster is active. Change expansion speed and confirm subsequent transitions use it.
4. Sleep/wake or switch to unsupported geometry. Tracking and expansion must stop while unavailable, with a reason visible. Restore supported geometry and confirm compact hover availability returns automatically.
5. Quit through the menu and confirm teardown. Relaunch and confirm compact availability and saved expansion speed. Test Command-Q, keyboard navigation and VoiceOver in both appearances.

Then check the existing notch behaviour:

1. Run the Debug app and check that compact appearance is unchanged with no text. Expand using the menu command and by hovering. The white time and subtle date must sit below the physical camera, centred in the black area, with intact bottom corners.
2. Test the fastest and slowest expansion speeds. Repeatedly reverse expansion and collapse at early, middle and late points. Text should fade only when it fits, disappear before the panel becomes too small, and avoid clipped glyphs or flashes.
3. Leave the expanded clock visible across a minute boundary without moving the pointer. Check the time against macOS. Check date rollover across midnight when practical, plus reopening after sleep or a system clock/time-zone change.
4. Test macOS Language & Region settings with both 12-hour and 24-hour time, differing date orders, a longer localized weekday, and a non-English region. Check formatting and fit, including changes while the app is running. Test a different calendar or time zone if configured.
5. Focus another app and approach the notch from below and both sides. Check expansion, the 180 ms collapse delay, return cancellation, manual overrides, and subtle optional trackpad feedback. Confirm typing stays with the focused app, clicks pass through the panel, and movement near the activation boundary does not chatter.
6. Enable Reduce Motion before expanding, then during an animation. Panel and content should immediately resolve to the requested size. Repeat with system haptics disabled and with a mouse.
7. Test built-in display scaling and arrangement changes, external displays, mirroring, clamshell, sleep/wake, menu-bar interaction, Spaces and full-screen apps. Unsupported geometry must hide the panel; recovery must restore compact hover availability automatically.
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
