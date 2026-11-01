import AppKit
import Testing
@testable import NotchMaster

@MainActor
private final class HoverFixture {
    static let entry = CGPoint(x: 850, y: 1064)
    static let retained = CGPoint(x: 850, y: 1000)
    static let outside = CGPoint(x: 100, y: 100)

    var displays = [DisplayFixture().geometry]
    var position = outside
    var time: TimeInterval = 100
    var duration: TimeInterval = 0.30
    var reduceMotion = false
    var hapticRequests = 0
    var displayReads = 0
    var positionReads = 0
    let notifications = NotificationCenter()
    let workspaceNotifications = NotificationCenter()

    func makeController(
        feedback: (@MainActor () -> Void)? = nil,
        uptime: (@MainActor () -> TimeInterval)? = nil
    ) -> NotchWindowController {
        NotchWindowController(
            displays: {
                self.displayReads += 1
                return self.displays
            },
            notificationCenter: notifications,
            workspaceNotificationCenter: workspaceNotifications,
            expansionDuration: { self.duration },
            reduceMotion: { self.reduceMotion },
            cursorPosition: {
                self.positionReads += 1
                return self.position
            },
            uptime: uptime ?? { self.time },
            performHapticFeedback: feedback ?? { self.hapticRequests += 1 }
        ) { _ in NSView() }
    }

    func poll(_ controller: NotchWindowController, position: CGPoint? = nil, after interval: TimeInterval = 0) {
        if let position { self.position = position }
        time += interval
        controller.hoverTimer?.fire()
    }
}

enum HoverCleanup: CaseIterable {
    case hide
    case systemSleep
    case displaySleep
    case unsupportedDisplay
}

@Suite(.serialized)
@MainActor
struct NotchHoverTests {
    @Test(arguments: [CGPoint.zero, CGPoint(x: -2100, y: 700), CGPoint(x: 1800, y: -1200)])
    func hoverRegionsSurroundThePhysicalNotchInGlobalCoordinates(origin: CGPoint) throws {
        let display = DisplayFixture(origin: origin).geometry
        let compact = try DisplayGeometry.previewPlacement(in: [display]).get().frame
        let expanded = try DisplayGeometry.previewPlacement(in: [display], isExpanded: true).get().frame
        let regions = NotchHoverRegions(compactFrame: compact, expandedFrame: expanded, displayFrame: display.frame)

        #expect(regions.activation == CGRect(x: origin.x + 748, y: origin.y + 1058, width: 204, height: 42))
        #expect(regions.exit.contains(regions.activation))
        #expect(regions.exit.contains(expanded))
        #expect(display.frame.contains(regions.activation) && display.frame.contains(regions.exit))
        #expect(regions.containsActivation(CGPoint(x: compact.midX, y: compact.minY - 4)))
        #expect(regions.containsActivation(CGPoint(x: compact.midX, y: display.frame.maxY)))
        #expect(!regions.containsActivation(CGPoint(x: compact.midX, y: display.frame.maxY + 1)))
        #expect(compact.size == CGSize(width: 180, height: 32))
        #expect(expanded.size == CGSize(width: 380, height: 120))
    }

    @Test
    func startupInsideActivationRequiresAFreshEntry() {
        let fixture = HoverFixture()
        fixture.position = HoverFixture.entry
        let controller = fixture.makeController()
        defer { controller.hidePreview() }
        #expect(controller.hoverTimer == nil && fixture.hapticRequests == 0)
        controller.showPreview()

        for _ in 0..<10 { fixture.poll(controller, after: 0.1) }
        fixture.poll(controller, position: HoverFixture.retained)
        fixture.poll(controller, position: HoverFixture.entry)
        #expect(!controller.isExpanded)
        #expect(fixture.hapticRequests == 0)
        #expect(controller.frameAnimation == nil)

        fixture.poll(controller, position: HoverFixture.outside)
        fixture.poll(controller, position: HoverFixture.entry)
        #expect(controller.isExpanded)
        #expect(fixture.hapticRequests == 1)
    }

    @Test
    func hoverEntryUsesOneAnimationAndOneHapticWithoutChangingFocus() throws {
        let fixture = HoverFixture()
        fixture.duration = 0.45
        let controller = fixture.makeController()
        defer { controller.hidePreview() }
        controller.showPreview()
        let timer = try #require(controller.hoverTimer)
        let panel = try #require(controller.window as? NSPanel)
        let content = panel.contentView
        let keyWindow = NSApp.keyWindow
        let mainWindow = NSApp.mainWindow
        let wasActive = NSApp.isActive
        #expect(abs(timer.timeInterval - 1.0 / 30) < 0.0001)
        #expect(fixture.displayReads == 1)

        fixture.poll(controller, position: HoverFixture.entry)

        let animation = try #require(controller.frameAnimation)
        #expect(animation.duration == 0.45)
        #expect(controller.isExpanded && fixture.hapticRequests == 1)
        for index in 0..<100 {
            fixture.poll(controller, position: index.isMultiple(of: 2) ? HoverFixture.entry : HoverFixture.retained, after: 0.01)
        }
        #expect(controller.frameAnimation === animation)
        #expect(controller.hoverTimer === timer)
        #expect(controller.window === panel && panel.contentView === content)
        #expect(fixture.hapticRequests == 1 && fixture.displayReads == 2)
        #expect(NSApp.keyWindow === keyWindow && NSApp.mainWindow === mainWindow)
        #expect(NSApp.isActive == wasActive)
        #expect(panel.ignoresMouseEvents && !panel.canBecomeKey && !panel.canBecomeMain)
    }

    @Test
    func exitDelayIsCancelledByReturnAndHapticsOnlyAccompanyCompletedIntent() {
        let fixture = HoverFixture()
        let controller = fixture.makeController()
        defer { controller.hidePreview() }
        controller.showPreview()
        fixture.poll(controller, position: HoverFixture.entry)
        fixture.poll(controller, position: HoverFixture.outside)
        fixture.poll(controller, after: 0.17)
        #expect(controller.isExpanded && fixture.hapticRequests == 1)

        fixture.poll(controller, position: HoverFixture.retained, after: 0.005)
        fixture.poll(controller, after: 1)
        #expect(controller.isExpanded && fixture.hapticRequests == 1)

        fixture.poll(controller, position: HoverFixture.outside)
        fixture.poll(controller, after: 0.17)
        #expect(controller.isExpanded && fixture.hapticRequests == 1)
        fixture.poll(controller, after: 0.02)
        #expect(!controller.isExpanded && fixture.hapticRequests == 2)
        for _ in 0..<10 { fixture.poll(controller, after: 0.2) }
        #expect(!controller.isExpanded && fixture.hapticRequests == 2)
    }

    @Test
    func activationBoundaryMovementDoesNotCauseFlickerOrRepeatedFeedback() {
        let fixture = HoverFixture()
        let controller = fixture.makeController()
        defer { controller.hidePreview() }
        controller.showPreview()
        fixture.poll(controller, position: HoverFixture.entry)

        for x: CGFloat in [747, 748, 749, 951, 952, 953] {
            fixture.poll(controller, position: CGPoint(x: x, y: 1060), after: 0.2)
        }
        fixture.poll(controller, position: CGPoint(x: 651, y: 1000))
        fixture.poll(controller, position: CGPoint(x: 652, y: 1000), after: 0.1)
        fixture.poll(controller, after: 1)

        #expect(controller.isExpanded)
        #expect(fixture.hapticRequests == 1)
    }

    @Test
    func manualExpansionIsHeldUntilAFreshHoverCycle() {
        let fixture = HoverFixture()
        let controller = fixture.makeController()
        defer { controller.hidePreview() }
        controller.showPreview()
        controller.toggleExpansion()
        fixture.poll(controller, after: 1)
        fixture.poll(controller, position: HoverFixture.retained)
        fixture.poll(controller, position: HoverFixture.outside, after: 1)
        #expect(controller.isExpanded && fixture.hapticRequests == 0)

        fixture.poll(controller, position: HoverFixture.entry)
        #expect(controller.isExpanded && fixture.hapticRequests == 0)
        fixture.poll(controller, position: HoverFixture.outside)
        fixture.poll(controller, after: 0.2)
        #expect(!controller.isExpanded && fixture.hapticRequests == 1)
    }

    @Test
    func manualCollapseInsideActivationRequiresExitBeforeReactivation() {
        let fixture = HoverFixture()
        let controller = fixture.makeController()
        defer { controller.hidePreview() }
        controller.showPreview()
        fixture.poll(controller, position: HoverFixture.entry)
        controller.toggleExpansion()
        fixture.poll(controller, position: HoverFixture.retained, after: 1)
        fixture.poll(controller, position: HoverFixture.entry, after: 1)
        #expect(!controller.isExpanded && fixture.hapticRequests == 1)

        fixture.poll(controller, position: HoverFixture.outside)
        fixture.poll(controller, position: HoverFixture.entry)
        #expect(controller.isExpanded && fixture.hapticRequests == 2)
    }

    @Test
    func manualActionsCancelPendingHoverCollapse() {
        let fixture = HoverFixture()
        let controller = fixture.makeController()
        defer { controller.hidePreview() }
        controller.showPreview()
        fixture.poll(controller, position: HoverFixture.entry)
        fixture.poll(controller, position: HoverFixture.outside)
        controller.toggleExpansion()
        controller.toggleExpansion()

        fixture.poll(controller, after: 1)

        #expect(controller.isExpanded)
        #expect(fixture.hapticRequests == 1)
    }

    @Test
    func hoverReversalReadsLatestDurationAndStopsPreviousAnimation() throws {
        let fixture = HoverFixture()
        fixture.duration = 0.6
        let controller = fixture.makeController()
        defer { controller.hidePreview() }
        controller.showPreview()
        fixture.poll(controller, position: HoverFixture.entry)
        let expansion = try #require(controller.frameAnimation)
        expansion.currentProgress = 0.5
        fixture.duration = 0.15
        fixture.poll(controller, position: HoverFixture.outside)
        let intermediateFrame = controller.window?.frame

        fixture.poll(controller, after: 0.2)

        let collapse = try #require(controller.frameAnimation)
        #expect(!expansion.isAnimating && collapse !== expansion)
        #expect(collapse.duration == 0.15)
        #expect(controller.window?.frame == intermediateFrame)
        collapse.currentProgress = 0.5
        let reversingFrame = controller.window?.frame
        fixture.poll(controller, position: HoverFixture.entry)
        #expect(controller.isExpanded && fixture.hapticRequests == 3)
        #expect(!collapse.isAnimating)
        #expect(controller.window?.frame == reversingFrame)
    }

    @Test(arguments: [false, true])
    func reduceMotionAndUnavailableFeedbackPreserveVisualHoverBehaviour(feedbackSuppressed: Bool) throws {
        let fixture = HoverFixture()
        fixture.reduceMotion = true
        let feedback: (@MainActor () -> Void)?
        if feedbackSuppressed {
            feedback = {}
        } else {
            feedback = nil
        }
        let controller = fixture.makeController(feedback: feedback)
        defer { controller.hidePreview() }
        controller.showPreview()
        let compactFrame = controller.window?.frame
        fixture.poll(controller, position: HoverFixture.entry)
        #expect(controller.isExpanded && controller.frameAnimation == nil)
        #expect(controller.window?.frame == (try DisplayGeometry.previewPlacement(in: fixture.displays, isExpanded: true).get().frame))

        fixture.poll(controller, position: HoverFixture.outside)
        fixture.poll(controller, after: 0.2)

        #expect(!controller.isExpanded && controller.frameAnimation == nil)
        #expect(controller.window?.frame == compactFrame)
        #expect(fixture.hapticRequests == (feedbackSuppressed ? 0 : 2))
    }

    @Test
    func accessibilityChangesSettleAnimationWithoutExtraFeedback() throws {
        let fixture = HoverFixture()
        let controller = fixture.makeController()
        defer { controller.hidePreview() }
        controller.showPreview()
        fixture.poll(controller, position: HoverFixture.entry)
        let animation = try #require(controller.frameAnimation)
        animation.currentProgress = 0.5
        fixture.reduceMotion = true

        fixture.workspaceNotifications.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        fixture.poll(controller, after: 1)

        #expect(!animation.isAnimating && controller.frameAnimation == nil)
        #expect(controller.isExpanded && fixture.hapticRequests == 1)
    }

    @Test(arguments: HoverCleanup.allCases)
    func cleanupCancelsPendingCollapseAndInvalidatesTracking(action: HoverCleanup) throws {
        let fixture = HoverFixture()
        let controller = fixture.makeController()
        defer { controller.hidePreview() }
        controller.showPreview()
        let timer = try #require(controller.hoverTimer)
        fixture.poll(controller, position: HoverFixture.entry)
        fixture.poll(controller, position: HoverFixture.outside)

        switch action {
        case .hide:
            controller.hidePreview()
        case .systemSleep:
            fixture.workspaceNotifications.post(name: NSWorkspace.willSleepNotification, object: nil)
        case .displaySleep:
            fixture.workspaceNotifications.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        case .unsupportedDisplay:
            fixture.displays = []
            fixture.notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        }

        #expect(!timer.isValid && controller.hoverTimer == nil)
        #expect(!controller.isPreviewVisible && !controller.isExpanded)
        let reads = fixture.positionReads
        fixture.time += 1
        timer.fire()
        #expect(fixture.positionReads == reads && fixture.hapticRequests == 1)
        fixture.displays = [DisplayFixture().geometry]
        fixture.workspaceNotifications.post(name: NSWorkspace.didWakeNotification, object: nil)
        #expect(controller.hoverTimer == nil)
        controller.showPreview()
        #expect(controller.hoverTimer !== timer)
        #expect(!controller.isExpanded && fixture.hapticRequests == 1)
    }

    @Test(arguments: [false, true])
    func displayNotificationsRebaseTrackingWithoutHaptics(geometryChanged: Bool) throws {
        let fixture = HoverFixture()
        let controller = fixture.makeController()
        defer { controller.hidePreview() }
        controller.showPreview()
        fixture.poll(controller, position: HoverFixture.entry)
        fixture.poll(controller, position: HoverFixture.outside)
        let timer = try #require(controller.hoverTimer)
        if geometryChanged {
            fixture.displays = [DisplayFixture(origin: CGPoint(x: -1700, y: 500)).geometry]
        }

        fixture.notifications.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        fixture.poll(controller, after: 1)

        #expect(!timer.isValid && controller.hoverTimer !== timer)
        #expect(controller.isPreviewVisible && controller.isExpanded)
        #expect(controller.frameAnimation == nil)
        #expect(fixture.hapticRequests == 1)
    }

    @Test(arguments: [false, true])
    func transitionRevalidationSuppressesFeedbackForDisplayChanges(unsupported: Bool) {
        let fixture = HoverFixture()
        let controller = fixture.makeController()
        defer { controller.hidePreview() }
        controller.showPreview()
        fixture.displays = unsupported ? [] : [DisplayFixture(origin: CGPoint(x: -1700, y: 500)).geometry]

        fixture.poll(controller, position: HoverFixture.entry)

        #expect(fixture.hapticRequests == 0)
        #expect(controller.isPreviewVisible == !unsupported)
        #expect(controller.hoverTimer == nil || !unsupported)
        #expect(controller.frameAnimation == nil)
    }

    @Test
    func unsupportedStartupNeverStartsTrackingOrRequestsFeedback() {
        let fixture = HoverFixture()
        fixture.displays = []
        let controller = fixture.makeController()

        controller.showPreview()
        controller.toggleExpansion()
        controller.hidePreview()

        #expect(controller.window == nil && controller.hoverTimer == nil)
        #expect(fixture.hapticRequests == 0 && fixture.positionReads == 0)
    }

    @Test
    func destructionInvalidatesTimerWithoutRetainingControllerOrRequestingFeedback() throws {
        let fixture = HoverFixture()
        var controller: NotchWindowController? = fixture.makeController()
        controller?.showPreview()
        let timer = try #require(controller?.hoverTimer)
        let panel = try #require(controller?.window)
        fixture.position = HoverFixture.entry
        timer.fire()
        fixture.position = HoverFixture.outside
        timer.fire()
        weak let owner = controller

        controller = nil

        #expect(owner == nil && !timer.isValid && !panel.isVisible)
        fixture.time += 1
        timer.fire()
        #expect(fixture.hapticRequests == 1)
    }

    @Test
    func nativeTimerDrivesHoverWhilePreservingFocus() async throws {
        let fixture = HoverFixture()
        let controller = fixture.makeController(uptime: { ProcessInfo.processInfo.systemUptime })
        defer { controller.hidePreview() }
        controller.showPreview()
        let keyWindow = NSApp.keyWindow
        let mainWindow = NSApp.mainWindow
        let wasActive = NSApp.isActive
        fixture.position = HoverFixture.entry
        let expansionDeadline = ContinuousClock.now + .seconds(2)
        while !controller.isExpanded, ContinuousClock.now < expansionDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(controller.isExpanded && fixture.hapticRequests == 1)
        fixture.position = HoverFixture.outside
        try await Task.sleep(for: .milliseconds(80))
        #expect(controller.isExpanded && fixture.hapticRequests == 1)
        let collapseDeadline = ContinuousClock.now + .seconds(2)
        while controller.isExpanded, ContinuousClock.now < collapseDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!controller.isExpanded && fixture.hapticRequests == 2)
        #expect(NSApp.keyWindow === keyWindow && NSApp.mainWindow === mainWindow)
        #expect(NSApp.isActive == wasActive)
    }
}
