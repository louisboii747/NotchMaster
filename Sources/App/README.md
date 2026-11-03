# App

Contains the macOS application entry point and composition root.

`NotchMasterApp.swift` declares the native menu bar extra first, followed by one Settings scene. The menu bar is the default launch scene. Open Settings and the native app Settings command share that window; there is no separate development window. Closing Settings keeps the utility and its Dock icon running through the app delegate's last-window policy.

`AppDependencies.swift` owns the shared preferences store, login-item service, battery information service and preview controller. Settings receives preferences, login service and preview controller explicitly; the menu receives the same controller. App injects the current expansion-duration provider and the SwiftUI notch hosting factory, keeping UI types out of Core.

After application launch finishes, the delegate starts the existing island controller unconditionally. Supported geometry presents the compact island and starts hover tracking without opening Settings or requesting focus. Unsupported geometry exposes its reason; display and wake notifications restore availability automatically when supported. Application termination stops the controller and hover tracking.

Creating dependencies reads current login status without registering anything. Login operations and battery reads have injectable providers. Tests can also inject the preview controller. Launch at Login controls only whether macOS launches the app. Every launch makes the island available.

The root Xcode project compiles App, Core and UI as source groups in one application module. See the [architecture](../../docs/ARCHITECTURE.md) and [file map](../../docs/STRUCTURE.md).
