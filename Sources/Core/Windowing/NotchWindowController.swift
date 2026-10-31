import AppKit
import Observation

@MainActor
@Observable
final class NotchWindowController: NSWindowController {
    private(set) var isPreviewVisible = false
    private(set) var isExpanded = false
    private(set) var statusMessage = "Preview hidden. Requires a built-in display with a physical notch."

    private let displays: @MainActor () -> [DisplayGeometry]
    private let makeContentView: @MainActor () -> NSView
    private let expansionDuration: @MainActor () -> TimeInterval
    private let reduceMotion: @MainActor () -> Bool
    private let notificationCenter: NotificationCenter
    private let workspaceNotificationCenter: NotificationCenter
    private var presentedDisplay: DisplayGeometry?
    @ObservationIgnored private(set) var frameAnimation: NotchFrameAnimation?

    init(
        displays: @escaping @MainActor () -> [DisplayGeometry] = DisplayGeometry.current,
        notificationCenter: NotificationCenter = .default,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        expansionDuration: @escaping @MainActor () -> TimeInterval = { PreferencesStore.defaultExpansionDuration },
        reduceMotion: @escaping @MainActor () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
        makeContentView: @escaping @MainActor () -> NSView
    ) {
        self.displays = displays
        self.makeContentView = makeContentView
        self.expansionDuration = expansionDuration
        self.reduceMotion = reduceMotion
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
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(accessibilityDisplayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    isolated deinit {
        notificationCenter.removeObserver(self)
        workspaceNotificationCenter.removeObserver(self)
        frameAnimation?.stop()
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
        presentPreview(isExpanded: isExpanded)
    }

    func toggleExpansion() {
        guard isPreviewVisible else { return }
        presentPreview(isExpanded: !isExpanded, animated: true)
    }

    func hidePreview() {
        cancelFrameAnimation()
        window?.orderOut(nil)
        presentedDisplay = nil
        isPreviewVisible = false
        isExpanded = false
        statusMessage = "Notch preview hidden."
    }

    private func presentPreview(isExpanded: Bool, animated: Bool = false) {
        cancelFrameAnimation()
        let currentDisplays = displays()
        switch DisplayGeometry.previewPlacement(in: currentDisplays, isExpanded: isExpanded) {
        case .success(let placement):
            let panel = window ?? makePanel(frame: placement.frame)
            let display = currentDisplays.first(where: \.isBuiltIn)
            if animated, isPreviewVisible, display == presentedDisplay,
               !reduceMotion(), panel.frame != placement.frame {
                let animation = NotchFrameAnimation(
                    panel: panel,
                    targetFrame: placement.frame,
                    duration: expansionDuration()
                )
                frameAnimation = animation
                animation.start()
            } else {
                panel.setFrame(placement.frame, display: true, animate: false)
            }
            presentedDisplay = display
            panel.orderFrontRegardless()
            isPreviewVisible = true
            self.isExpanded = isExpanded
            let previewName = isExpanded ? "Expanded notch preview" : "Notch preview"
            statusMessage = "\(previewName) shown on \(placement.displayName)."
        case .failure(let reason):
            hidePreview()
            statusMessage = reason.message
        }
    }

    private func cancelFrameAnimation() {
        frameAnimation?.stop()
        frameAnimation = nil
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

    @objc private func accessibilityDisplayOptionsChanged(_ notification: Notification) {
        guard isPreviewVisible, reduceMotion() else { return }
        presentPreview(isExpanded: isExpanded)
    }
}

final class NotchFrameAnimation: NSAnimation {
    private let updateFrame: @MainActor @Sendable (CGFloat) -> Void

    @MainActor
    init(panel: NSWindow, targetFrame: CGRect, duration: TimeInterval) {
        let startFrame = panel.frame
        updateFrame = { [weak panel] progress in
            let width = startFrame.width + (targetFrame.width - startFrame.width) * progress
            let height = startFrame.height + (targetFrame.height - startFrame.height) * progress
            let size = CGSize(
                width: targetFrame.width + 2 * ((width - targetFrame.width) / 2).rounded(),
                height: targetFrame.height + (height - targetFrame.height).rounded()
            )
            let frame = progress >= 1 ? targetFrame : CGRect(
                x: targetFrame.midX - size.width / 2,
                y: targetFrame.maxY - size.height,
                width: size.width,
                height: size.height
            )
            panel?.setFrame(frame, display: true, animate: false)
        }
        super.init(duration: duration, animationCurve: .easeInOut)
        animationBlockingMode = .nonblocking
        frameRate = 60
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var currentProgress: NSAnimation.Progress {
        didSet {
            let progress = CGFloat(currentValue)
            let updateFrame = updateFrame
            MainActor.assumeIsolated {
                updateFrame(progress)
            }
        }
    }

    override var runLoopModesForAnimating: [RunLoop.Mode]? {
        [.common]
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
