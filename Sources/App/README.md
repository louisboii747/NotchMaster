# App

Contains the macOS application entry point and composition root.

`NotchMasterApp.swift` declares the native menu bar extra first, then the foundation feature-settings window and the separate app Settings scene. The menu bar extra is the default launch scene. Feature Settings in the menu bar and Window > NotchMaster open the foundation form, which contains the preview feature toggle and expansion speed preference. Operational Show/Hide and Expand/Collapse commands are in the menu bar. The app retains `AppDependencies.swift`, which creates the shared local preferences store and injects it into both windows. The composition root also owns the preview controller, injects the same instance into the foundation form and menu, and supplies its SwiftUI hosting view. The panel starts hidden and compact and is created only after supported geometry is found. The app delegate keeps the app running after the last window closes, with the Dock icon retained.

The development window uses a zero-size native view attachment to set `NSWindow.isRestorable` to false on macOS 14 and later. Its new `development` scene identifier replaces `foundation` to avoid selecting previous startup-window restoration records. Only this temporary window gives up restoration; Settings keeps its scene policy.

Keep feature logic in Core and presentation in UI. Preview window management belongs to Core; App owns its lifetime and the development-window lifecycle policy.

`AppDependencies` also owns `LoginItemService`, with an injectable `LoginItemSystem` for tests, and passes it into Settings alongside preferences. Creating dependencies queries current login status without registering anything. Launch at Login uses the same quiet startup.

The root Xcode project compiles App, Core, and UI as source groups in one application module. See the [architecture](../../docs/ARCHITECTURE.md) and [file map](../../docs/STRUCTURE.md).
