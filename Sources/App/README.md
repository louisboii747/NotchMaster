# App

Contains the macOS application entry point and composition root.

`NotchMasterApp.swift` declares the single foundation window and native Settings scene. It retains `AppDependencies.swift`, which creates the shared local preferences store and injects it into Settings. Startup does not depend on future services.

Keep feature logic in Core and presentation in UI. AppKit window management belongs to Core; App owns the coordinator's lifetime.

The root Xcode project compiles App, Core, and UI as source groups in one application module. See the [architecture](../../docs/ARCHITECTURE.md) and [file map](../../docs/STRUCTURE.md).
