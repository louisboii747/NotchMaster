# Prototype testing and validation

NotchMaster is not yet a user-facing release. These notes preserve the existing prototype behaviour and hardware validation steps from the main [README](../README.md).

## Current preview and manual validation

The project uses local ad hoc signing without a development team. Distribution signing remains undecided. Run the app from Xcode and use Show Notch Preview, then Expand and Collapse in the verification window. Expansion animates the same black panel around and below the reported physical notch, keeping its top edge and horizontal centre fixed. Collapse restores the exact compact frame. Each transition reads the latest expansion duration from Settings. Rapid reversals stop the previous animation and continue from the current size. Reduce Motion applies the target immediately, including when enabled during an animation.

The preview starts hidden, does not take keyboard focus, and passes mouse events through. Initial presentation and display changes apply validated geometry immediately. Unsupported, inactive, or mirrored built-in displays produce an explanatory message without showing a panel. Display changes cancel any animation and revalidate placement; hiding, unsupported geometry, or sleep resets expansion. After hiding, the preview must be explicitly shown again and starts compact. Use Open Settings or Command-comma to edit expansion speed, then alternate Expand and Collapse to check the new duration without restarting. Physical notch alignment, animation appearance, Spaces, and full-screen interaction still need manual hardware testing.

While the preview is shown, move the pointer toward the physical notch from below or either side. The activation region extends 12 points on each side of the compact notch and 10 points below it. The exit region surrounds the expanded frame with an 8-point margin. Both regions stay within the built-in display. Leaving the exit region starts a 180 ms collapse delay; returning cancels it. Cursor sampling runs at 30 Hz, including while another app is focused, without intercepting input or requesting Accessibility or Input Monitoring permissions. Sampling and the delay stop when the preview is hidden or unsupported, on sleep, and when its controller is destroyed.

Manual Expand/Collapse cancels pending hover actions and holds the chosen state. A fresh entry into the activation region resumes automatic interaction; if the pointer was already nearby when a manual action occurred, first leave the wider exit region. A stationary pointer at initial presentation or after a display change produces no transition or haptic request.

Each actual hover expansion or delayed collapse requests one immediate `.generic` haptic through `NSHapticFeedbackManager.defaultPerformer`. Repeated polling, cancelled collapses, manual controls and lifecycle changes do not request feedback. AppKit selects the performer using the current input device, accessibility settings and system preferences. Feedback is optional: macOS may suppress it, including when there is no compatible trackpad or no finger touching it. Visual interaction always works independently.

For manual validation on a MacBook with a Force Touch trackpad, show the preview, focus another app, then approach and leave the notch. Check that each transition feels subtle, returning during the collapse delay keeps the panel expanded, and movement near the activation boundary does not chatter. Also test manual overrides, Settings duration changes, Reduce Motion, system haptic preferences, a mouse without haptics, display changes and sleep. Physical feedback, perceived latency, menu-bar interaction, Spaces and full-screen behaviour require hardware testing.

## Before reporting a problem

Include the Mac model, macOS version, whether a physical notch is present, display or mirroring configuration, and the exact steps to reproduce. Describe whether the issue involves visual animation, pointer detection, optional trackpad feedback, or accessibility settings. Use the [issue tracker](https://github.com/louisboii747/NotchMaster/issues); a requested haptic is not guaranteed to be delivered by the hardware.

## Further technical detail

See [Architecture](ARCHITECTURE.md) for display geometry, window ownership and test coverage. The [file map](STRUCTURE.md) identifies implemented and planned code.
