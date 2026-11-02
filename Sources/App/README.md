# App

Contains the macOS application entry point and composition root.

`NotchMasterApp.swift` declares the single verification window, native menu bar extra and Settings scene. It retains `AppDependencies.swift`, which creates the shared local preferences store and injects it into Settings. The composition root also owns the preview controller, injects the same instance into the shell and menu, and supplies its SwiftUI hosting view. The panel starts hidden and compact and is created only after supported geometry is found. The app delegate keeps the app running after the last window closes; the native Window menu can reopen the development window.

Keep feature logic in Core and presentation in UI. AppKit window management belongs to Core; App owns the coordinator's lifetime.

`AppDependencies` also owns `LoginItemService`, with an injectable `LoginItemSystem` for tests, and passes it into Settings alongside preferences. Creating dependencies queries current login status without registering anything. Launch at Login preserves the existing verification-window startup behaviour.

The root Xcode project compiles App, Core, and UI as source groups in one application module. See the [architecture](../../docs/ARCHITECTURE.md) and [file map](../../docs/STRUCTURE.md).
