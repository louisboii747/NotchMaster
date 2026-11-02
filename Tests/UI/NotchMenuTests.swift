import AppKit
import SwiftUI
import Testing
@testable import NotchMaster

@Suite(
    .serialized,
    .enabled(
        if: ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 14, minorVersion: 4, patchVersion: 0)
        ),
        "Native menu inspection requires macOS 14.4"
    )
)
@MainActor
struct NotchMenuTests {
    @Test(arguments: [NSWorkspace.willSleepNotification, NSApplication.didChangeScreenParametersNotification])
    func menuTracksConfirmedVisibilityAndLifecycleChanges(_ notification: Notification.Name) async throws {
        guard #available(macOS 14.4, *) else { return }
        let notifications = NotificationCenter()
        let provider = MenuDisplayProviderFixture()
        let controller = NotchWindowController(
            displays: { provider.displays },
            notificationCenter: notifications,
            workspaceNotificationCenter: notifications,
            cursorPosition: { .zero }
        ) { _ in NSView() }
        defer { controller.hidePreview() }
        let menu = NSHostingMenu(rootView: NotchMenuView(notchWindowController: controller))

        try await expectPreviewTitle("Show Notch Preview", in: menu)
        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        let panel = try #require(controller.window)
        #expect(controller.isPreviewVisible && panel.isVisible)

        controller.togglePreview()
        try await expectPreviewTitle("Show Notch Preview", in: menu)
        controller.togglePreview()
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        #expect(controller.window === panel)

        provider.displays = []
        notifications.post(name: notification, object: nil)
        try await expectPreviewTitle("Show Notch Preview", in: menu)
        #expect(!controller.isPreviewVisible && !panel.isVisible)

        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Show Notch Preview", in: menu)
        #expect(!controller.isPreviewVisible && !panel.isVisible)
        #expect(controller.statusMessage == NotchPreviewUnavailableReason.noBuiltInDisplay.message)

        provider.displays = [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry]
        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        #expect(controller.window === panel)
        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Show Notch Preview", in: menu)
        #expect(!panel.isVisible)
    }

    @Test
    func closingVerificationWindowKeepsMenuAndSharedControllerOperational() async throws {
        guard #available(macOS 14.4, *) else { return }
        let controller = NotchWindowController(
            displays: { [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry] },
            cursorPosition: { .zero }
        ) { _ in NSView() }
        defer { controller.hidePreview() }
        let menu = NSHostingMenu(rootView: NotchMenuView(notchWindowController: controller))
        let verificationWindow = NSWindow(
            contentRect: CGRect(x: -3000, y: -3000, width: 480, height: 280),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        verificationWindow.isReleasedWhenClosed = false
        verificationWindow.contentView = NSHostingView(rootView: AppShellView(notchWindowController: controller))
        controller.showPreview()
        let panel = try #require(controller.window)

        verificationWindow.close()
        verificationWindow.contentView = nil

        #expect(NSApp.delegate?.applicationShouldTerminateAfterLastWindowClosed?(NSApp) == false)
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Show Notch Preview", in: menu)
        #expect(!panel.isVisible)
        menu.performActionForItem(at: 0)
        try await expectPreviewTitle("Hide Notch Preview", in: menu)
        #expect(controller.window === panel && panel.isVisible)
        #expect(menu.items.map(\.title) == ["Hide Notch Preview", "", "Open Settings…", "Quit NotchMaster"])
        #expect(menu.items[2].keyEquivalent == ",")
        #expect(menu.items[3].keyEquivalent == "q")
    }

    private func expectPreviewTitle(_ title: String, in menu: NSMenu) async throws {
        try await Task.sleep(for: .milliseconds(30))
        menu.update()
        #expect(menu.items.first?.title == title)
    }
}

@MainActor
private final class MenuDisplayProviderFixture {
    var displays = [DisplayFixture(origin: CGPoint(x: -3000, y: -3000)).geometry]
}
