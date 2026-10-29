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
        #expect(controller.window == nil)
        #expect(!controller.isPreviewVisible)
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

    @Test
    func displayChangesRepositionOrHideWithoutReopeningHiddenPreview() throws {
        let notifications = NotificationCenter()
        let provider = DisplayProviderFixture()
        let controller = NotchWindowController(displays: { provider.displays }, notificationCenter: notifications) {
            NSView()
        }
        defer { controller.hidePreview() }
        controller.showPreview()
        let panel = try #require(controller.window)
        provider.displays = [DisplayFixture(origin: CGPoint(x: -1700, y: 500)).geometry]

        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)

        #expect(controller.isPreviewVisible)
        #expect(panel.frame == (try DisplayGeometry.previewPlacement(in: provider.displays).get().frame))
        provider.displays = []
        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(!controller.isPreviewVisible)
        #expect(!panel.isVisible)
        #expect(controller.statusMessage == NotchPreviewUnavailableReason.noBuiltInDisplay.message)
        provider.displays = [DisplayFixture().geometry]
        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(!panel.isVisible)
        controller.showPreview()
        #expect(panel.isVisible)
        controller.hidePreview()
        notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        #expect(!panel.isVisible)
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

        workspaceNotifications.post(name: notification, object: nil)

        #expect(!controller.isPreviewVisible)
        #expect(!panel.isVisible)
        workspaceNotifications.post(name: NSWorkspace.didWakeNotification, object: nil)
        #expect(!panel.isVisible)
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
