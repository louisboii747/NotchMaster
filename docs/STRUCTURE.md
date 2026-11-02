# Repository file map

This is the foundation, login-item, menu bar and hover preview file layout. The native Xcode project has one macOS application target and one focused Swift Testing target. There are no package dependencies. A small adapted SwiftPieces button style is included as source with its own licence.

```text
NotchMaster/
├── .gitattributes
├── .gitignore
├── README.md
├── LICENSE
├── SwiftPieces/
│   ├── README.md
│   ├── LICENSE.txt
│   └── Controls/ElasticButton.swift
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
│   │   ├── Services/LoginItemService.swift
│   │   ├── Settings/PreferencesStore.swift
│   │   └── Windowing/
│   │       ├── DisplayGeometry.swift
│   │       ├── NotchWindowController.swift
│   │       └── NotchHoverInteraction.swift
│   └── UI/
│       ├── README.md
│       ├── AppShellView.swift
│       ├── NotchMenuView.swift
│       ├── Notch/NotchView.swift
│       └── Settings/
│           ├── SettingsView.swift
│           └── GeneralSettingsView.swift
├── Tests/
│   ├── Core/
│   │   ├── PreferencesStoreTests.swift
│   │   ├── LoginItemServiceTests.swift
│   │   ├── DisplayGeometryTests.swift
│   │   ├── NotchWindowControllerTests.swift
│   │   └── NotchHoverTests.swift
│   └── UI/
│       ├── GeneralSettingsTests.swift
│       ├── NotchViewTests.swift
│       └── NotchMenuTests.swift
└── docs/
    ├── STRUCTURE.md
    ├── ARCHITECTURE.md
    ├── PROTOTYPE_TESTING.md
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
| `SwiftPieces/` | Local macOS button-style adaptation and its licence | SwiftUI; no Core state or ServiceManagement calls |
| `docs/` | Product intent, architecture, implementation requirements | Repository-relative documentation and assets |

These are source groups in the macOS target. Separate modules or packages should be introduced only when the dependency and testing needs justify them. `Config/Shared.xcconfig` supplies the arm64-only architecture, macOS baseline, Swift 6 concurrency settings, development version, and local signing defaults. The shared scheme runs preference, login-item service, Settings lifecycle/binding, display-geometry, window-controller, hover, clock-content and menu tests. App icons are resized copies of the existing logo; documentation artwork is preserved.

## Proposed implementation file boundaries

The following names describe the wider plan. Only the Swift files shown in the tree above are implemented. Do not create the remaining files until they have a working responsibility.

| Path | Responsibility |
| :--- | :--- |
| `Sources/App/NotchMasterApp.swift` | App entry point, window/menu/Settings scenes and last-window lifecycle delegate. |
| `Sources/App/AppDependencies.swift` | Compose and retain services. |
| `Sources/UI/AppShellView.swift` | Foundation feature-settings form with a confirmed preview toggle, shared expansion speed setting and app Settings link. |
| `Sources/UI/NotchMenuView.swift` | Native menu bar Show/Hide, Expand/Collapse, preview status, feature/app Settings and Quit commands. |
| `Sources/Core/Plugins/PluginRegistry.swift` | Plugin identities, lifecycle, and enabled state. |
| `Sources/Core/Windowing/NotchWindowController.swift` | Implemented passive AppKit panel ownership, presentation, and display/sleep handling. |
| `Sources/Core/Windowing/NotchHoverInteraction.swift` | Implemented hover boundaries, entry detection, delayed collapse and manual overrides. |
| `Sources/Core/Windowing/DisplayGeometry.swift` | Implemented built-in display selection and validated compact and expanded preview geometry. |
| `Sources/Core/Settings/PreferencesStore.swift` | Validated local preferences and persistence. |
| `Sources/Core/Services/LoginItemService.swift` | Implemented observable login-item status, registration, unregistration, approval and errors through an injected system adapter. |
| `Sources/Core/Services/EntitlementService.swift` | Verified Pro access and purchase restoration. |
| `Sources/Core/Sync/SyncCoordinator.swift` | Opt-in iCloud preference synchronization. |
| `Sources/UI/Settings/SettingsView.swift` | Sidebar and detail composition. |
| `Sources/UI/Settings/SettingsCategory.swift` | Stable category identity, title, and symbol. |
| `Sources/UI/Settings/GeneralSettingsView.swift` | Native login-item controls with lifecycle status refresh and the shared `ExpansionSpeedSettings` section used by both settings forms. |
| `Sources/UI/Settings/AdvancedSettingsView.swift` | Metal effect preference and capability state. |
| `Sources/UI/Settings/InstalledPluginsView.swift` | Plugin list and lifecycle-aware toggles. |
| `Sources/UI/Settings/PluginRow.swift` | Accessible plugin label, description, and switch. |
| `Sources/UI/Settings/ProSyncSettingsView.swift` | Upgrade, account, and sync states. |
| `Sources/UI/Settings/ProUpgradeCard.swift` | Native purchase presentation. |
| `Sources/UI/Settings/AboutSettingsView.swift` | Bundle version and project information. |
| `Sources/UI/Notch/NotchView.swift` | Implemented black surface shared by compact and expanded previews. |
| `Sources/UI/Materials/NotchMaterial.swift` | Accessible surface and effect composition. |

The Xcode project, minimal test target, asset catalog, and shared build settings are included in Phase 1. Do not add empty Swift files to imply that future components already exist.
