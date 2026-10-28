# App

Reserved for the macOS application entry point and composition root.

During implementation, this layer will own app startup and shutdown, scene construction, the Settings scene, and the creation and lifetime of Core services. It will connect those services to UI views through explicit dependencies.

Keep feature logic in Core and presentation in UI. AppKit window management belongs to Core; App owns the coordinator's lifetime.

No application target or Swift source exists yet. See the [architecture](../../docs/ARCHITECTURE.md) and [file map](../../docs/STRUCTURE.md).
