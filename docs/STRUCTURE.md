# Repository file map

This is the complete tracked file layout for the initialization phase. There are no Swift source files, dependency manifests, generated projects, or build targets.

```text
NotchMaster/
├── .gitattributes
├── .gitignore
├── README.md
├── LICENSE
├── Sources/
│   ├── App/
│   │   └── README.md
│   ├── Core/
│   │   └── README.md
│   └── UI/
│       └── README.md
└── docs/
    ├── STRUCTURE.md
    ├── ARCHITECTURE.md
    ├── SETTINGS.md
    ├── PLUGINS.md
    ├── BRAND.md
    └── assets/
        ├── logo.png
        ├── hero.svg
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

These are source groups for a future macOS target. Separate modules or packages should be introduced only when the dependency and testing needs justify them.

## Proposed implementation file boundaries

The following names are a plan. **None of these files is created by this initialization.**

| Future path | Responsibility |
| :--- | :--- |
| `Sources/App/NotchMasterApp.swift` | App entry point and Settings scene. |
| `Sources/App/AppDependencies.swift` | Compose and retain services. |
| `Sources/Core/Plugins/PluginRegistry.swift` | Plugin identities, lifecycle, and enabled state. |
| `Sources/Core/Windowing/NotchWindowController.swift` | AppKit panel ownership and presentation. |
| `Sources/Core/Windowing/DisplayGeometry.swift` | Display selection and notch-safe geometry. |
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
| `Sources/UI/Notch/NotchView.swift` | Compact and expanded surface rendering. |
| `Sources/UI/Materials/NotchMaterial.swift` | Accessible surface and effect composition. |

When app work starts, add the actual Xcode project or package definition, test targets, asset catalog, and shared build settings in the same reviewed change. Do not add empty Swift files to imply that these components already exist.
