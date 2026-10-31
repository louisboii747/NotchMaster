import AppKit
import Testing
@testable import NotchMaster

@MainActor
private final class DisplayProviderFixture {
    var displays = [DisplayFixture().geometry]
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
        let controller = NotchWindowController(displays: { [display] }) {
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
            workspaceNotificationCenter: workspaceNotifications
        ) {
            NSView()
        }
        controller?.showPreview()
        let panel = try #require(controller?.window)
        weak let owner = controller

        controller = nil

        #expect(owner == nil)
        #expect(!panel.isVisible)
        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        workspaceNotifications.post(name: NSWorkspace.willSleepNotification, object: nil)
        #expect(!panel.isVisible)
    }
}
