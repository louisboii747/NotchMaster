<p align="center">
  <img src="docs/assets/logo.png" width="112" height="112" alt="NotchMaster logo: a white N with a notch on an orange square">
</p>

<h1 align="center">NotchMaster</h1>

<h3 align="center">
  An expandable notch utility for Apple Silicon Macs, built with SwiftUI and AppKit. Plugin support is planned.
</h3>

<p align="center">
  <img src="https://img.shields.io/badge/status-prototype-EE5836?style=flat-square" alt="Early prototype">
  <img src="https://img.shields.io/badge/platform-macOS-20201D?style=flat-square&amp;logo=apple&amp;logoColor=white" alt="For macOS">
  <img src="https://img.shields.io/badge/Swift-6-20201D?style=flat-square&amp;logo=swift&amp;logoColor=white" alt="Language: Swift 6">
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-20201D?style=flat-square" alt="SwiftUI and AppKit">
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-MIT-20201D?style=flat-square" alt="MIT licence"></a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#free--pro">Free &amp; Pro</a> ·
  <a href="#compatibility">Compatibility</a> ·
  <a href="#availability">Availability</a> ·
  <a href="#development">Development</a> ·
  <a href="#plugin-development">Plugins</a> ·
  <a href="#follow-development">Follow development</a> ·
  <a href="#support">Support</a>
</p>

<p align="center">
  <img src="docs/assets/hero.png" width="100%" alt="NotchMaster. Your Mac's notch, now useful. A macOS utility in development. Concept artwork of a notch panel with playback, timer, and activity icons.">
</p>

<p align="center"><sub>Concept artwork showing planned controls; not a screenshot of the current prototype.</sub></p>

<p align="center">
  <a href="#availability"><img src="docs/assets/app-store-soon.svg" width="220" height="64" alt="Planned for the Mac App Store; no listing yet"></a>
</p>

> **Early prototype, not yet released.** On a supported built-in MacBook notch, NotchMaster currently offers a passive black notch preview with a live local clock and date when expanded, hover expansion and delayed collapse, adjustable animation speed, Reduce Motion support, and optional trackpad haptic requests. A native menu bar menu provides Expand/Collapse, status, Settings and Quit controls. One Settings window combines General and Features, with Automatic, Light and Dark appearance. Settings stays closed at startup. There is no downloadable release or plugin SDK yet. The hero artwork and remaining feature plans below show the intended direction, not functionality already shipped.

## Features

NotchMaster aims to turn the MacBook notch into a useful, expandable hub. Development is incremental: each interaction is implemented and tested before larger features are added.

**Working in the current prototype**

- Compact black notch preview on supported built-in displays, with hover expansion and delayed collapse.
- Live local clock and date below the camera when expanded, with localized time and date formatting.
- Read-only battery percentage and charging indicator beside the expanded clock, updated on power-source changes.
- Native AppKit animation, plus an expansion-speed preference saved in Settings.
- Reduce Motion support and optional native trackpad haptic requests on hover transitions.
- Native menu bar controls for Expand/Collapse, preview status, Settings and Quit, available with Settings closed.
- Launch at Login in General Settings, backed by macOS registration status with approval guidance and visible errors.
- The island is available automatically while the app runs, with hover expansion and automatic wake/display recovery.
- One Settings window for General and Features, with Automatic, Light and Dark appearance saved locally.

**Planned, not implemented yet**

- Compact and expanded plugin views with useful controls and information.
- A plugin registry and settings to enable or disable plugins.
- Optional Metal border effects and additional accessibility options.
- A virtual notch for Apple Silicon Macs without a physical display notch.
- Optional iCloud preference and layout sync as part of a potential Pro edition.

## Free & Pro

The intended model is a useful free core, with optional Pro features distributed through the Mac App Store. **No Pro edition, pricing, or purchase flow is available yet.** This is a proposed feature split, not a list of shipped entitlements.

| Planned capability | Free (proposed) | Pro (proposed) |
| :--- | :--- | :--- |
| Expandable notch and core controls | Planned | Included |
| Native settings and local preferences | Planned | Included |
| Plugin registry and enable/disable controls | Planned | Included |
| Expansion speed and optional Metal border effects | Planned | Included |
| Community plugins | Delivery undecided | App Store compatibility under review |
| Now Playing screensaver | - | Planned |
| iCloud preference and layout sync | - | Planned |
| Purchase restoration and sync controls | - | Planned |

The free edition is intended to work without a NotchMaster account. Proposed Pro sync would be opt-in and limited to approved preferences and layouts, never plugin code, credentials, or private plugin content. The feature split may change.

## Compatibility

NotchMaster currently targets **Apple Silicon (arm64) and macOS 14.0 or later**. The prototype requires a built-in physical notch with geometry that macOS reports as supported. A deployment target does not mean that every OS version or Mac has been tested.

| Hardware | Current prototype | Future direction |
| :--- | :--- | :--- |
| MacBook Air with M5 and a physical notch | Tested during development on macOS 27.2 | Continue hardware and OS validation |
| Other Apple Silicon MacBooks with a physical notch | Designed to work with supported display geometry; not verified on every model | Broader compatibility testing |
| Apple Silicon Macs without a physical notch (including desktops) | Not supported by the current notch preview | Virtual notch planned |
| Intel Macs | Not supported; the Xcode target is arm64-only | No Intel version planned |

The preview validates system-reported display geometry instead of guessing. Mirrored, inactive, or unsupported built-in displays do not show the preview. See [Architecture](docs/ARCHITECTURE.md) for implementation details and test coverage.

## Availability

**There is no public download or Mac App Store listing yet.** NotchMaster is still under development. Developers can [build the prototype from source](#development); a public release and Mac App Store distribution are goals, not announced dates.

## Development

The repository includes an Xcode project using Swift 6 language mode, SwiftUI, AppKit and complete concurrency checking. Open `NotchMaster.xcodeproj` in Xcode on an Apple Silicon Mac.

```sh
git clone https://github.com/louisboii747/NotchMaster.git
cd NotchMaster
open NotchMaster.xcodeproj
```

Build and run the focused preference, login-item, Settings, geometry, window-controller, hover, SwiftUI content and menu tests for Apple Silicon:

```sh
xcodebuild -project NotchMaster.xcodeproj -scheme NotchMaster -configuration Debug -destination 'platform=macOS,arch=arm64' build
xcodebuild -project NotchMaster.xcodeproj -scheme NotchMaster -configuration Debug -destination 'platform=macOS,arch=arm64' test
```

### Continuous integration

[macOS CI](.github/workflows/macos-ci.yml) runs on pull requests to `main`, pushes to `main`, and manual dispatch. Its separate jobs build and test the arm64 macOS app using Xcode 27 (treating Swift warnings as errors), and check SwiftLint plus SwiftFormat styling. CI does not replace manual physical-notch, haptic, or full-screen testing.

To run the same style checks locally, install the tools with `brew install swiftlint swiftformat` and run:

```sh
swiftlint lint --strict
swiftformat --lint .
```

To apply the configured formatting locally, run `swiftformat .` and review the diff before committing. SwiftLint and SwiftFormat use the deliberately small rule sets in `.swiftlint.yml` and `.swiftformat`; extend these rules incrementally as the codebase develops.

The prototype uses local ad hoc signing; distribution signing isn't configured. Launch leaves Settings closed and makes the compact island available immediately on a supported display. Hover over the notch to expand it. Use the monochrome MacBook menu bar icon to expand/collapse, read status, open Settings or quit. Open Settings and Command-comma reuse one window. General contains startup and appearance preferences; Features contains island status and expansion speed. Closing Settings leaves the utility and its Dock icon running. Quit uses Command-Q.

Settings > General > Appearance offers Automatic, Light and Dark. Automatic defaults to the macOS appearance and follows changes while the window is open. Light and Dark override the entire Settings window. The selection persists across launches. The passive black notch preview retains its existing colours.

The island needs no enable switch or startup preview preference. It becomes available after launch, expands when the pointer enters the notch area, and collapses after the pointer leaves. Sleep temporarily suspends it; wake or a supported-display change restores compact presentation automatically. Unsupported, mirrored or external-only display configurations remain unavailable, with the reason visible in the menu and Features page. Existing saved startup-preview values are ignored. See [automatic island testing](docs/PROTOTYPE_TESTING.md#automatic-island-availability-checks).

General Settings includes a native Launch at Login switch. It is off when macOS reports no registration, and on only when macOS confirms the app is enabled. Approval-required status offers Open Login Items Settings. Status refreshes when Settings appears and when the app or a window becomes active. No login Boolean is stored in preferences. Test actual login launching with a properly signed installed copy at a stable path; an ad hoc Xcode build does not establish that behaviour. See [login-item testing](docs/PROTOTYPE_TESTING.md#launch-at-login-checks).

The local macOS adaptation of [SwiftPieces ElasticButton](https://swiftpieces.com/docs/components/controls/elastic-button) remains available as source under its separate [SwiftPieces licence](SwiftPieces/LICENSE.txt). Settings uses native form controls.

The expanded notch includes a subtle battery icon and localized percentage beside the centred clock and date. It shows a static bolt only while macOS reports charging. Missing battery information or insufficient space omits the indicator while preserving the clock. Battery updates use public IOKit power-source notifications without a polling timer; compact appearance is unchanged.

For battery and live clock behaviour, hover boundaries, animation, accessibility, haptics and manual testing, see **[Prototype testing](docs/PROTOTYPE_TESTING.md)**. For implementation details, see [Architecture](docs/ARCHITECTURE.md) and the [file map](docs/STRUCTURE.md).

| Path | Purpose |
| :--- | :--- |
| [`Sources/App/`](Sources/App/README.md) | App entry point, scenes and lifecycle. |
| [`Sources/Core/`](Sources/Core/README.md) | Preferences and window management; plugin infrastructure is planned. |
| [`Sources/UI/`](Sources/UI/README.md) | Settings and notch presentation. |
| [`docs/`](docs/STRUCTURE.md) | Architecture, testing notes and future plugin design. |

## Plugin development

A public plugin SDK, installable plugin format and stable third-party API **do not exist yet**. The [plugin guide](docs/PLUGINS.md) explains the design goals, lifecycle requirements and unresolved distribution decisions; it is not a tutorial for an existing SDK.

For now, [open an issue](https://github.com/louisboii747/NotchMaster/issues) explaining the plugin you'd like to build, its compact and expanded views, and any data or permissions it would need.

## Follow development

NotchMaster is being developed publicly in small, testable steps. You can **Watch** the [GitHub repository](https://github.com/louisboii747/NotchMaster) for updates, check [Releases](https://github.com/louisboii747/NotchMaster/releases) when builds become available, or browse [Issues](https://github.com/louisboii747/NotchMaster/issues) to suggest improvements and discuss ideas.

There is no beta sign-up or public download yet. When testing opens, details will be posted in the repository.

## Support

<p align="center">
  <img src="docs/assets/support.svg" width="100%" alt="Support NotchMaster. Suggest a plugin or send a pull request. Donations aren't set up yet.">
</p>

<p align="center">
  <a href="https://github.com/louisboii747/NotchMaster"><img src="https://img.shields.io/badge/Star%20on-GitHub-20201D?style=for-the-badge&amp;logo=github&amp;logoColor=white" alt="Star NotchMaster on GitHub"></a>
  <img src="https://img.shields.io/badge/Donations-not%20set%20up-737269?style=for-the-badge" alt="Donations aren't set up yet">
</p>

If you have a plugin idea or spot a problem in the docs, feel free to share it by [opening an issue](https://github.com/louisboii747/NotchMaster/issues). Pull requests for docs, structure, and artwork are welcome at this stage.

The donation button is inactive for now. Any future donations will support development and won't unlock Pro.

## Licence

[MIT](LICENSE) · © 2026 Louis Hinchliffe.

NotchMaster is an independent project and isn't affiliated with Apple. Apple, MacBook, macOS, iCloud, App Store, and Dynamic Island are trademarks of Apple Inc.
