import AppKit
import Observation

@MainActor
@Observable
final class NotchWindowController: NSWindowController {
    private(set) var isPreviewVisible = false
    private(set) var statusMessage = "Preview hidden. Requires a built-in display with a physical notch."

    private let displays: @MainActor () -> [DisplayGeometry]
    private let makeContentView: @MainActor () -> NSView
    private let notificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter

    init(
        displays: @escaping @MainActor () -> [DisplayGeometry] = DisplayGeometry.current,
        notificationCenter: NotificationCenter = .default,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        makeContentView: @escaping @MainActor () -> NSView
    ) {
        self.displays = displays
        self.makeContentView = makeContentView
        self.notificationCenter = notificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        super.init(window: nil)
        notificationCenter.addObserver(
            self,
            selector: #selector(displayConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            workspaceNotificationCenter.addObserver(self, selector: #selector(sleepStarted), name: name, object: nil)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    isolated deinit {
        notificationCenter.removeObserver(self)
        workspaceNotificationCenter.removeObserver(self)
        window?.close()
    }

    func togglePreview() {
        if isPreviewVisible {
            hidePreview()
        } else {
            showPreview()
        }
    }

    func showPreview() {
        switch DisplayGeometry.previewPlacement(in: displays()) {
        case .success(let placement):
            let panel = window ?? makePanel(frame: placement.frame)
            panel.setFrame(placement.frame, display: true)
            panel.orderFrontRegardless()
            isPreviewVisible = true
            statusMessage = "Notch preview shown on \(placement.displayName)."
        case .failure(let reason):
            hidePreview()
            statusMessage = reason.message
        }
    }

    func hidePreview() {
        window?.orderOut(nil)
        isPreviewVisible = false
        statusMessage = "Notch preview hidden."
    }

    private func makePanel(frame: CGRect) -> NSPanel {
        let panel = NotchPreviewPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Notch Preview"
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.animationBehavior = .none
        panel.contentView = makeContentView()
        window = panel
        return panel
    }

    @objc private func displayConfigurationChanged(_ notification: Notification) {
        guard isPreviewVisible else { return }
        showPreview()
    }

    @objc private func sleepStarted(_ notification: Notification) {
        guard isPreviewVisible else { return }
        hidePreview()
    }
}

@MainActor
private final class NotchPreviewPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
