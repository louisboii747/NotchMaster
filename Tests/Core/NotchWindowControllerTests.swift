import AppKit
import Testing
@testable import NotchMaster

@MainActor
private final class DisplayProviderFixture {
    var displays = [DisplayFixture().geometry]
}

@MainActor
private final class MotionProviderFixture {
    var reduceMotion = false
}

@Suite(.serialized)
@MainActor
struct NotchWindowControllerTests {
    @Test
    func showsAndHidesOnePassivePanelWithoutChangingFocus() throws {
        var contentCreationCount = 0
        let display = DisplayFixture().geometry
        let controller = NotchWindowController(displays: { [display] }) {
            contentCreationCount += 1
            return NSView()
        }
        defer { controller.hidePreview() }
        controller.toggleExpansion()
        #expect(controller.window == nil)
        #expect(!controller.isPreviewVisible)
        #expect(!controller.isExpanded)
        let keyWindow = NSApp.keyWindow
        let mainWindow = NSApp.mainWindow
        let wasActive = NSApp.isActive

        controller.togglePreview()

        let panel = try #require(controller.window as? NSPanel)
        #expect(controller.isPreviewVisible)
        #expect(panel.isVisible)
        #expect(panel.frame == (try DisplayGeometry.previewPlacement(in: [display]).get().frame))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(!panel.styleMask.contains(.titled))
        #expect(!panel.canBecomeKey && !panel.canBecomeMain)
        #expect(panel.ignoresMouseEvents)
        #expect(!panel.hidesOnDeactivate)
        #expect(!panel.hasShadow)
        #expect(panel.constrainFrameRect(panel.frame, to: NSScreen.main) == panel.frame)
        #expect(NSApp.keyWindow === keyWindow)
        #expect(NSApp.mainWindow === mainWindow)
        #expect(NSApp.isActive == wasActive)

        controller.togglePreview()
        #expect(!controller.isPreviewVisible)
        #expect(!panel.isVisible)
        controller.showPreview()
        #expect(controller.window === panel)
        #expect(contentCreationCount == 1)
        controller.hidePreview()
        controller.hidePreview()
        #expect(!panel.isVisible)
    }

    @Test
    func expansionReusesPanelAndContentWithoutChangingFocus() throws {
        var contentCreationCount = 0
        let display = DisplayFixture().geometry
        let controller = NotchWindowController(displays: { [display] }, reduceMotion: { true }) {
            contentCreationCount += 1
            return NSView()
        }
        defer { controller.hidePreview() }
        controller.showPreview()
        let panel = try #require(controller.window as? NSPanel)
        let content = try #require(panel.contentView)
        let compactFrame = panel.frame
        let keyWindow = NSApp.keyWindow
        let mainWindow = NSApp.mainWindow
        let wasActive = NSApp.isActive

        for isExpanded in [true, false, true, false] {
            controller.toggleExpansion()

            #expect(controller.isExpanded == isExpanded)
            #expect(controller.isPreviewVisible && panel.isVisible)
            #expect(controller.window === panel)
            #expect(panel.contentView === content)
            #expect(contentCreationCount == 1)
            #expect(panel.frame == (try DisplayGeometry.previewPlacement(in: [display], isExpanded: isExpanded).get().frame))
            #expect(isExpanded ? panel.frame.contains(compactFrame) : panel.frame == compactFrame)
            #expect(panel.styleMask.contains(.nonactivatingPanel))
            #expect(!panel.canBecomeKey && !panel.canBecomeMain)
            #expect(panel.ignoresMouseEvents)
            #expect(panel.animationBehavior == .none)
            #expect(NSApp.keyWindow === keyWindow)
            #expect(NSApp.mainWindow === mainWindow)
            #expect(NSApp.isActive == wasActive)
        }
    }

    @Test
    func hidingExpandedPreviewResetsBeforeReuse() throws {
        let controller = NotchWindowController(displays: { [DisplayFixture().geometry] }) { NSView() }
        defer { controller.hidePreview() }
        controller.showPreview()
        let panel = try #require(controller.window)
        let compactFrame = panel.frame
        controller.toggleExpansion()
        #expect(controller.isExpanded)

        controller.togglePreview()

        #expect(!controller.isExpanded)
        #expect(!controller.isPreviewVisible && !panel.isVisible)
        controller.toggleExpansion()
        #expect(!controller.isExpanded && !panel.isVisible)
        controller.showPreview()
        #expect(controller.window === panel)
        #expect(controller.isPreviewVisible && panel.isVisible)
        #expect(!controller.isExpanded)
        #expect(panel.frame == compactFrame)
    }

    @Test
    func unsupportedDisplayReportsReasonWithoutCreatingPanel() {
        var contentCreated = false
        let controller = NotchWindowController(displays: { [] }) {
            contentCreated = true
            return NSView()
        }

        controller.showPreview()

        #expect(!controller.isPreviewVisible)
        #expect(controller.window == nil)
        #expect(!contentCreated)
        #expect(controller.statusMessage == NotchPreviewUnavailableReason.noBuiltInDisplay.message)
    }

    @Test(arguments: [false, true])
    func displayChangesRepositionOrHideWithoutReopeningHiddenPreview(isExpanded: Bool) throws {
        let notifications = NotificationCenter()
        let provider = DisplayProviderFixture()
        let controller = NotchWindowController(displays: { provider.displays }, notificationCenter: notifications) {
            NSView()
        }
        defer { controller.hidePreview() }
        controller.showPreview()
        if isExpanded { controller.toggleExpansion() }
        let panel = try #require(controller.window)
        var movedDisplay = DisplayFixture(origin: CGPoint(x: -1700, y: 500))
        movedDisplay.safeAreaTop = 40
        movedDisplay.left = CGRect(x: -1700, y: 1560, width: 740, height: 40)
        movedDisplay.right = CGRect(x: -740, y: 1560, width: 740, height: 40)
        provider.displays = [movedDisplay.geometry]

        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)

        #expect(controller.isPreviewVisible)
        #expect(controller.isExpanded == isExpanded)
        #expect(controller.window === panel)
        #expect(panel.frame == (try DisplayGeometry.previewPlacement(in: provider.displays, isExpanded: isExpanded).get().frame))
        provider.displays = []
        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(!controller.isPreviewVisible)
        #expect(!controller.isExpanded)
        #expect(!panel.isVisible)
        #expect(controller.statusMessage == NotchPreviewUnavailableReason.noBuiltInDisplay.message)
        provider.displays = [DisplayFixture().geometry]
        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(!panel.isVisible)
        controller.showPreview()
        #expect(panel.isVisible)
        #expect(!controller.isExpanded)
        #expect(panel.frame == (try DisplayGeometry.previewPlacement(in: provider.displays).get().frame))
        controller.hidePreview()
        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(!panel.isVisible)
    }

    @Test
    func expansionRevalidatesDisplayBeforeResizing() throws {
        let provider = DisplayProviderFixture()
        let controller = NotchWindowController(displays: { provider.displays }) { NSView() }
        controller.showPreview()
        let panel = try #require(controller.window)
        controller.toggleExpansion()
        #expect(controller.isExpanded)
        var mirroredDisplay = DisplayFixture()
        mirroredDisplay.isMirrored = true
        provider.displays = [mirroredDisplay.geometry]

        controller.toggleExpansion()

        #expect(!controller.isExpanded)
        #expect(!controller.isPreviewVisible && !panel.isVisible)
        #expect(controller.statusMessage == NotchPreviewUnavailableReason.mirroredDisplay.message)
    }

    @Test(arguments: [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification])
    func sleepHidesPreviewUntilExplicitlyShown(_ notification: Notification.Name) throws {
        let workspaceNotifications = NotificationCenter()
        let controller = NotchWindowController(
            displays: { [DisplayFixture().geometry] },
            workspaceNotificationCenter: workspaceNotifications
        ) {
            NSView()
        }
        defer { controller.hidePreview() }
        controller.showPreview()
        let panel = try #require(controller.window)
        let compactFrame = panel.frame
        controller.toggleExpansion()
        #expect(controller.isExpanded)

        workspaceNotifications.post(name: notification, object: nil)

        #expect(!controller.isPreviewVisible)
        #expect(!controller.isExpanded)
        #expect(!panel.isVisible)
        workspaceNotifications.post(name: NSWorkspace.didWakeNotification, object: nil)
        #expect(!panel.isVisible)
        controller.showPreview()
        #expect(!controller.isExpanded)
        #expect(panel.frame == compactFrame)
    }

    @Test
    func controllerLifetimeOwnsPanelAndObservers() throws {
        let notifications = NotificationCenter()
        let workspaceNotifications = NotificationCenter()
        var controller: NotchWindowController? = NotchWindowController(
            displays: { [DisplayFixture().geometry] },
            notificationCenter: notifications,
            workspaceNotificationCenter: workspaceNotifications,
            reduceMotion: { false }
        ) {
            NSView()
        }
        controller?.showPreview()
        controller?.toggleExpansion()
        let panel = try #require(controller?.window)
        let animation = controller?.frameAnimation
        weak let owner = controller

        controller = nil

        #expect(owner == nil)
        #expect(!panel.isVisible)
        #expect(animation?.isAnimating == false)
        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        workspaceNotifications.post(name: NSWorkspace.willSleepNotification, object: nil)
        #expect(!panel.isVisible)
    }

    @Test(arguments: [CGPoint.zero, CGPoint(x: -2100, y: 700), CGPoint(x: 1800, y: -1200)])
    func animationPreservesNotchAnchorAndUsesEaseInOut(origin: CGPoint) throws {
        let display = DisplayFixture(origin: origin).geometry
        let controller = NotchWindowController(displays: { [display] }, reduceMotion: { false }) { NSView() }
        defer { controller.hidePreview() }
        controller.showPreview()
        let panel = try #require(controller.window)
        let compactFrame = panel.frame
        #expect(controller.frameAnimation == nil)

        for isExpanded in [true, false] {
            controller.toggleExpansion()
            let animation = try #require(controller.frameAnimation)
            let targetFrame = try DisplayGeometry.previewPlacement(in: [display], isExpanded: isExpanded).get().frame
            #expect(animation.animationCurve == .easeInOut)
            #expect(animation.animationBlockingMode == .nonblocking)
            #expect(animation.runLoopModesForAnimating == [.common])
            for progress: Float in [0.1, 0.25, 0.5, 0.75, 0.9] {
                animation.currentProgress = progress
                #expect(abs(panel.frame.midX - compactFrame.midX) < 0.001)
                #expect(abs(panel.frame.maxY - compactFrame.maxY) < 0.001)
                #expect(panel.frame.width > compactFrame.width)
                #expect(panel.frame.width < 380)
                #expect(display.frame.contains(panel.frame))
                if progress == 0.25 { #expect(animation.currentValue < progress) }
                if progress == 0.75 { #expect(animation.currentValue > progress) }
            }
            animation.currentProgress = 1
            #expect(panel.frame == targetFrame)
        }
    }

    @Test
    func reversalStartsAtCurrentFrameAndReadsLatestPreference() throws {
        let suiteName = "NotchMasterAnimationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesStore(defaults: defaults)
        preferences.expansionDuration = 0.60
        let controller = NotchWindowController(
            displays: { [DisplayFixture().geometry] },
            expansionDuration: { preferences.expansionDuration },
            reduceMotion: { false }
        ) { NSView() }
        defer { controller.hidePreview() }
        controller.showPreview()
        let panel = try #require(controller.window)
        let compactFrame = panel.frame
        controller.toggleExpansion()
        let expansion = try #require(controller.frameAnimation)
        #expect(expansion.duration == 0.60)
        expansion.currentProgress = 0.5
        let intermediateFrame = panel.frame
        preferences.expansionDuration = 0.15

        controller.toggleExpansion()

        let collapse = try #require(controller.frameAnimation)
        #expect(!expansion.isAnimating)
        #expect(collapse !== expansion)
        #expect(collapse.duration == 0.15)
        #expect(panel.frame == intermediateFrame)
        #expect(!controller.isExpanded)
        collapse.currentProgress = 1
        #expect(panel.frame == compactFrame)
    }

    @Test
    func rapidAlternatingRequestsKeepOnlyLatestAnimation() throws {
        let display = DisplayFixture().geometry
        let controller = NotchWindowController(displays: { [display] }, reduceMotion: { false }) { NSView() }
        defer { controller.hidePreview() }
        controller.showPreview()
        let panel = try #require(controller.window)
        let content = panel.contentView
        var previousAnimation: NSAnimation?

        for index in 0..<21 {
            let previousFrame = panel.frame
            controller.toggleExpansion()
            let animation = try #require(controller.frameAnimation)
            #expect(previousAnimation?.isAnimating != true)
            #expect(panel.frame == previousFrame)
            #expect(controller.isExpanded == index.isMultiple(of: 2))
            animation.currentProgress = 0.4
            previousAnimation = animation
        }

        previousAnimation?.currentProgress = 1
        #expect(panel.frame == (try DisplayGeometry.previewPlacement(in: [display], isExpanded: true).get().frame))
        #expect(controller.isExpanded)
        #expect(panel.contentView === content)
    }

    @Test
    func reduceMotionImmediatelyAppliesBothTargets() throws {
        let display = DisplayFixture().geometry
        let controller = NotchWindowController(displays: { [display] }, reduceMotion: { true }) { NSView() }
        defer { controller.hidePreview() }
        controller.showPreview()
        let panel = try #require(controller.window)

        for isExpanded in [true, false] {
            controller.toggleExpansion()
            #expect(controller.isExpanded == isExpanded)
            #expect(controller.frameAnimation == nil)
            #expect(panel.frame == (try DisplayGeometry.previewPlacement(in: [display], isExpanded: isExpanded).get().frame))
        }
    }

    @Test
    func enablingReduceMotionDuringAnimationFinishesImmediately() throws {
        let workspaceNotifications = NotificationCenter()
        let motion = MotionProviderFixture()
        let display = DisplayFixture().geometry
        let controller = NotchWindowController(
            displays: { [display] },
            workspaceNotificationCenter: workspaceNotifications,
            reduceMotion: { motion.reduceMotion }
        ) { NSView() }
        defer { controller.hidePreview() }
        controller.showPreview()
        controller.toggleExpansion()
        let animation = try #require(controller.frameAnimation)
        animation.currentProgress = 0.4
        motion.reduceMotion = true

        workspaceNotifications.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)

        #expect(!animation.isAnimating)
        #expect(controller.frameAnimation == nil)
        #expect(controller.isExpanded)
        #expect(controller.window?.frame == (try DisplayGeometry.previewPlacement(in: [display], isExpanded: true).get().frame))
        controller.toggleExpansion()
        #expect(controller.frameAnimation == nil)
        #expect(!controller.isExpanded)
        #expect(controller.window?.frame == (try DisplayGeometry.previewPlacement(in: [display]).get().frame))
    }

    @Test(arguments: [false, true])
    func displayChangesCancelAnimationAndApplyValidatedTarget(notificationDelivered: Bool) throws {
        let notifications = NotificationCenter()
        let provider = DisplayProviderFixture()
        let controller = NotchWindowController(
            displays: { provider.displays },
            notificationCenter: notifications,
            reduceMotion: { false }
        ) { NSView() }
        defer { controller.hidePreview() }
        controller.showPreview()
        controller.toggleExpansion()
        let animation = try #require(controller.frameAnimation)
        animation.currentProgress = 0.4
        provider.displays = [DisplayFixture(origin: CGPoint(x: -1700, y: 500)).geometry]

        if notificationDelivered {
            notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        } else {
            controller.toggleExpansion()
        }

        #expect(!animation.isAnimating)
        #expect(controller.frameAnimation == nil)
        #expect(controller.isExpanded == notificationDelivered)
        #expect(controller.window?.frame == (try DisplayGeometry.previewPlacement(
            in: provider.displays, isExpanded: notificationDelivered
        ).get().frame))
    }

    @Test(arguments: [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification])
    func sleepCancelsAnimationBeforeCompactReuse(_ notification: Notification.Name) throws {
        let notifications = NotificationCenter()
        let controller = NotchWindowController(
            displays: { [DisplayFixture().geometry] },
            workspaceNotificationCenter: notifications,
            reduceMotion: { false }
        ) { NSView() }
        defer { controller.hidePreview() }
        controller.showPreview()
        let compactFrame = controller.window?.frame
        controller.toggleExpansion()
        let animation = try #require(controller.frameAnimation)
        animation.currentProgress = 0.4

        notifications.post(name: notification, object: nil)

        #expect(!animation.isAnimating)
        #expect(controller.frameAnimation == nil)
        #expect(!controller.isPreviewVisible && !controller.isExpanded)
        controller.showPreview()
        #expect(controller.frameAnimation == nil)
        #expect(controller.window?.frame == compactFrame)
    }

    @Test
    func hidingOrLosingValidGeometryCancelsAnimation() throws {
        let provider = DisplayProviderFixture()
        let controller = NotchWindowController(displays: { provider.displays }, reduceMotion: { false }) { NSView() }
        defer { controller.hidePreview() }
        controller.showPreview()
        let compactFrame = controller.window?.frame

        for invalidGeometry in [false, true] {
            controller.toggleExpansion()
            let animation = try #require(controller.frameAnimation)
            animation.currentProgress = 0.4
            if invalidGeometry {
                var display = DisplayFixture()
                display.safeAreaTop = .nan
                provider.displays = [display.geometry]
                controller.toggleExpansion()
                #expect(controller.statusMessage == NotchPreviewUnavailableReason.invalidGeometry.message)
            } else {
                controller.hidePreview()
            }

            #expect(!animation.isAnimating)
            #expect(controller.frameAnimation == nil)
            #expect(!controller.isExpanded && !controller.isPreviewVisible)
            #expect(controller.window?.isVisible == false)
            provider.displays = [DisplayFixture().geometry]
            controller.showPreview()
            #expect(controller.frameAnimation == nil)
            #expect(controller.window?.frame == compactFrame)
        }
    }

    @Test
    func nativeAnimationCompletesWithoutChangingFocus() async throws {
        let display = DisplayFixture().geometry
        let controller = NotchWindowController(
            displays: { [display] },
            expansionDuration: { 0.15 },
            reduceMotion: { false },
            cursorPosition: { .zero }
        ) { NSView() }
        defer { controller.hidePreview() }
        controller.showPreview()
        let panel = try #require(controller.window)
        let content = panel.contentView
        let compactFrame = panel.frame
        let keyWindow = NSApp.keyWindow
        let mainWindow = NSApp.mainWindow
        let wasActive = NSApp.isActive

        for isExpanded in [true, false] {
            controller.toggleExpansion()
            let animation = try #require(controller.frameAnimation)
            var sawIntermediateFrame = false
            let deadline = ContinuousClock.now + .seconds(3)
            while animation.isAnimating, ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
                sawIntermediateFrame = sawIntermediateFrame || (panel.frame.width > compactFrame.width && panel.frame.width < 380)
                #expect(abs(panel.frame.midX - compactFrame.midX) < 0.001)
                #expect(abs(panel.frame.maxY - compactFrame.maxY) < 0.001)
                #expect(NSApp.keyWindow === keyWindow && NSApp.mainWindow === mainWindow)
                #expect(NSApp.isActive == wasActive)
            }
            #expect(!animation.isAnimating)
            #expect(sawIntermediateFrame)
            #expect(panel.frame == (try DisplayGeometry.previewPlacement(in: [display], isExpanded: isExpanded).get().frame))
            #expect(panel.contentView === content)
            #expect(panel.ignoresMouseEvents && !panel.canBecomeKey && !panel.canBecomeMain)
            #expect(panel.level == .statusBar)
        }
    }
}
