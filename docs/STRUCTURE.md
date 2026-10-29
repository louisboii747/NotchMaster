# Repository file map

This is the foundation and static preview file layout. The native Xcode project has one macOS application target and one focused Swift Testing target. There are no third-party dependencies or packages.

```text
NotchMaster/
├── .gitattributes
├── .gitignore
├── README.md
├── LICENSE
├── Config/
│   └── Shared.xcconfig
├── NotchMaster.xcodeproj/
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/NotchMaster.xcscheme
├── Resources/
│   └── Assets.xcassets/
│       ├── Contents.json
│       └── AppIcon.appiconset/
│           ├── Contents.json
│           └── icon-*.png
├── Sources/
│   ├── App/
│   │   ├── README.md
│   │   ├── NotchMasterApp.swift
│   │   └── AppDependencies.swift
│   ├── Core/
│   │   ├── README.md
│   │   ├── Settings/PreferencesStore.swift
│   │   └── Windowing/
│   │       ├── DisplayGeometry.swift
│   │       └── NotchWindowController.swift
│   └── UI/
│       ├── README.md
│       ├── AppShellView.swift
│       ├── Notch/NotchView.swift
│       └── Settings/
│           ├── SettingsView.swift
│           └── GeneralSettingsView.swift
├── Tests/
│   └── Core/
│       ├── PreferencesStoreTests.swift
│       ├── DisplayGeometryTests.swift
│       └── NotchWindowControllerTests.swift
└── docs/
    ├── STRUCTURE.md
    ├── ARCHITECTURE.md
    ├── SETTINGS.md
    ├── PLUGINS.md
    ├── BRAND.md
    └── assets/
        ├── logo.png
        ├── hero.png
        ├── app-store-soon.svg
        └── support.svg
```

## Ownership

| Location | Responsibility | Allowed dependencies during implementation |
| :--- | :--- | :--- |
| `Sources/App/` | Entry point, scenes, lifecycle, dependency composition | Core and UI |
| `Sources/Core/` | State, plugin registry, platform services, window coordinator | Foundation and required Apple frameworks; no UI-layer dependency |
| `Sources/UI/` | Settings, notch presentation, reusable materials | Core contracts and SwiftUI; AppKit bridging only when presentation requires it |
| `docs/` | Product intent, architecture, implementation requirements | Repository-relative documentation and assets |

These are source groups in the macOS target. Separate modules or packages should be introduced only when the dependency and testing needs justify them. `Config/Shared.xcconfig` supplies the arm64-only architecture, macOS baseline, Swift 6 concurrency settings, development version, and local signing defaults. The shared scheme runs preference, display-geometry, and window-controller tests. App icons are resized copies of the existing logo; documentation artwork is preserved.

## Proposed implementation file boundaries

The following names describe the wider plan. Only the Swift files shown in the tree above are implemented. Do not create the remaining files until they have a working responsibility.

| Path | Responsibility |
| :--- | :--- |
| `Sources/App/NotchMasterApp.swift` | App entry point and Settings scene. |
| `Sources/App/AppDependencies.swift` | Compose and retain services. |
| `Sources/UI/AppShellView.swift` | Verification window and temporary Show/Hide Notch Preview control. |
| `Sources/Core/Plugins/PluginRegistry.swift` | Plugin identities, lifecycle, and enabled state. |
| `Sources/Core/Windowing/NotchWindowController.swift` | Implemented passive AppKit panel ownership, presentation, and display/sleep handling. |
| `Sources/Core/Windowing/DisplayGeometry.swift` | Implemented built-in display selection and validated static preview geometry. |
| `Sources/Core/Settings/PreferencesStore.swift` | Validated local preferences and persistence. |
| `Sources/Core/Services/LoginItemService.swift` | Launch-at-login status and registration. |
| `Sources/Core/Services/EntitlementService.swift` | Verified Pro access and purchase restoration. |
| `Sources/Core/Sync/SyncCoordinator.swift` | Opt-in iCloud preference synchronization. |
| `Sources/UI/Settings/SettingsView.swift` | Sidebar and detail composition. |
| `Sources/UI/Settings/SettingsCategory.swift` | Stable category identity, title, and symbol. |
| `Sources/UI/Settings/GeneralSettingsView.swift` | Login item and expansion speed controls. |
| `Sources/UI/Settings/AdvancedSettingsView.swift` | Metal effect preference and capability state. |
| `Sources/UI/Settings/InstalledPluginsView.swift` | Plugin list and lifecycle-aware toggles. |
| `Sources/UI/Settings/PluginRow.swift` | Accessible plugin label, description, and switch. |
| `Sources/UI/Settings/ProSyncSettingsView.swift` | Upgrade, account, and sync states. |
| `Sources/UI/Settings/ProUpgradeCard.swift` | Native purchase presentation. |
| `Sources/UI/Settings/AboutSettingsView.swift` | Bundle version and project information. |
| `Sources/UI/Notch/NotchView.swift` | Implemented black compact surface; expansion remains future work. |
| `Sources/UI/Materials/NotchMaterial.swift` | Accessible surface and effect composition. |

The Xcode project, minimal test target, asset catalog, and shared build settings are included in Phase 1. Do not add empty Swift files to imply that future components already exist.
