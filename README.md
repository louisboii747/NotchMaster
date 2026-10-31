<p align="center">
  <img src="docs/assets/logo.png" width="112" height="112" alt="NotchMaster logo: a white N with a notch on an orange square">
</p>

<h1 align="center">NotchMaster</h1>

<h3 align="center">
  An expandable, feature rich notch app with plugin support for your Apple Silicon Mac.
</h3>

<p align="center">
  <img src="https://img.shields.io/badge/status-foundation-EE5836?style=flat-square" alt="Foundation build">
  <img src="https://img.shields.io/badge/platform-macOS-20201D?style=flat-square&amp;logo=apple&amp;logoColor=white" alt="For macOS">
  <img src="https://img.shields.io/badge/Swift-6-20201D?style=flat-square&amp;logo=swift&amp;logoColor=white" alt="Language: Swift 6">
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-20201D?style=flat-square" alt="Planned interface: SwiftUI and AppKit">
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-MIT-20201D?style=flat-square" alt="MIT licence"></a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#free--pro">Free &amp; Pro</a> ·
  <a href="#development">Development</a> ·
  <a href="#how-to-build-plugins">Plugins</a> ·
  <a href="#support">Support</a>
</p>

<p align="center">
  <img src="docs/assets/hero.png" width="100%" alt="NotchMaster. Your Mac's notch, now useful. A macOS utility in development. Concept artwork of a notch panel with playback, timer, and activity icons.">
</p>

<p align="center">
  <a href="#availability"><img src="docs/assets/app-store-soon.svg" width="220" height="64" alt="Planned for the Mac App Store; no listing yet"></a>
</p>

> **Prototype build.** The app opens a verification window with temporary Show/Hide Notch Preview and Expand/Collapse controls and native Settings with one persisted expansion speed preference. The preview is a passive black surface around a supported built-in physical notch. Expansion is manual and immediate; hover interaction, animations, and the plugin SDK are not implemented. Features below describe the product plan. NotchMaster is a working title.

## Features

NotchMaster is designed to bring Dynamic Island-style interactions to the Mac. The hub will sit behind the physical MacBook notch and expand to show controls and information from the plugins you enable.

- Compact and expanded views for each plugin.
- Native settings for launch at login, expansion speed, and plugin controls.
- Optional Metal border effects with accessibility fallbacks.
- Local preferences, with optional iCloud sync through Pro.
- Fake notch implementation for Apple Silicon Macs without a physical notch.

## Free & Pro

NotchMaster keeps the core free, but offers iCloud sync and additional features as a Pro upgrade through the Mac App Store. Pricing and plugin delivery, and some Pro features are still undecided.

| Feature | Free | Pro |
| :--- | :--- | :--- |
| Expandable notch with extensive controls | Included | Included |
| Now playing screensaver | Not Included | Included |
| Native settings and local preferences | Included | Included |
| Plugin registry and enable/disable controls | Included | Included |
| Expansion speed and Metal border effects | Included | Included |
| Community plugins | Planned; packaging undecided | App Store delivery under review |
| iCloud preference and layout sync | Not included | Included |
| Purchase restoration and sync controls | Not applicable | Included |

Free features won't require a NotchMaster account. Pro sync would use iCloud and require opt-in. Sync will cover approved preferences and layouts; plugin code, credentials, and private plugin content will stay out of it.

All features are subject to change.

## Compatibility

| Mac | Compatible | Notes
| :--- | :--- |  :--- |
| M1 | ✅ Fully Compatible. | Fully compatible to build, test and use NotchMaster.
| M2 | ✅ Fully Compatible. | Fully compatible to build, test and use NotchMaster.
| M3 | ✅ Fully Compatible. | Fully compatible to build, test and use NotchMaster.
| M4 | ✅ Fully Compatible. | Fully compatible to build, test and use NotchMaster.
| M5 | ✅ Fully Compatible. | Fully compatible to build, test and use NotchMaster.
| M6 | ✅ Fully Compatible. | Fully compatible to build, test and use NotchMaster.
| Apple Silicon Mac Mini, Mac, Mac Pro, etc. | ✅ Fully Compatible. | Any Mac without a built in display will have the Virtual Notch implemented. All features are still compatible.
| Intel x86_64 | ❌ NOT Compatible. | Why? Apple dropped support for Intel Macs with macOS 27, and development of NotchMaster is designed for Apple Silicon Macs only.

## Development

The prototype uses Swift 6 language mode with complete concurrency checking, SwiftUI presentation, and an AppKit-managed preview panel. The initial deployment target is macOS 14.0. Open `NotchMaster.xcodeproj` in Xcode and select the shared NotchMaster scheme and My Mac destination.

As mentioned in [Compatibility](#compatibility), Intel Macs are **not** supported due to losing support in recent macOS updates, and app development is designed only for Apple's M series SoC processors. The NotchMaster app will **not** build *or* run on **any** x86_64 Mac. **This will not change.**

Ensure Xcode and Git are installed on your Mac, then use these terminal commands to clone and open the NotchMaster repository.

```sh
git clone https://github.com/louisboii747/NotchMaster.git
cd NotchMaster
open NotchMaster.xcodeproj
```


Build and run the focused preference, geometry, and window-controller tests for Apple Silicon:

```sh
xcodebuild -project NotchMaster.xcodeproj -scheme NotchMaster -configuration Debug -destination 'platform=macOS,arch=arm64' build
xcodebuild -project NotchMaster.xcodeproj -scheme NotchMaster -configuration Debug -destination 'platform=macOS,arch=arm64' test
```

The project uses local ad hoc signing without a development team. Distribution signing remains undecided. Run the app from Xcode and use Show Notch Preview, then Expand and Collapse in the verification window. Expansion resizes the same black panel around and below the reported physical notch, keeping its top aligned with the display. Collapse restores the exact compact frame. The preview starts hidden, does not take keyboard focus, and passes mouse events through. Unsupported, inactive, or mirrored built-in displays produce an explanatory message without showing a panel. Display changes revalidate placement; hiding, unsupported geometry, or sleep resets expansion. After hiding, the preview must be explicitly shown again and starts compact. Use Open Settings or Command-comma to edit the preference; immediate resizing does not use expansion speed.

| Path | Purpose |
| :--- | :--- |
| [`Sources/App/`](Sources/App/README.md) | App entry point, scenes, and lifecycle. |
| [`Sources/Core/`](Sources/Core/README.md) | Plugin registry, window management, and state. |
| [`Sources/UI/`](Sources/UI/README.md) | Settings, notch views, and materials. |
| [`docs/`](docs/STRUCTURE.md) | File map, architecture, settings, and plugin notes. |

The source folders contain the foundation, manual notch preview, and ownership notes. The [file map](docs/STRUCTURE.md) separates implemented files from future work; the [architecture](docs/ARCHITECTURE.md) explains startup and data flow.

## How to build plugins

The plugin SDK will enter development shortly after NotchMaster has a working, downloadable version. The [plugin guide](docs/PLUGINS.md) records the proposed lifecycle, permissions, and cleanup requirements. Third-party code loading and App Store packaging still need to be decided.

For now, [open an issue](https://github.com/louisboii747/NotchMaster/issues) describing what your plugin would do, what it should show in each view, and which data or permissions it would need.


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
