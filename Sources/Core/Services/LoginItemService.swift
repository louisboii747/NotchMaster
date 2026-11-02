import Foundation
import Observation
import ServiceManagement

@MainActor
protocol LoginItemSystem {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openLoginItemsSettings()
}

@MainActor
struct MainAppLoginItemSystem: LoginItemSystem {
    private let service = SMAppService.mainApp

    var status: SMAppService.Status { service.status }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
@Observable
final class LoginItemService {
    private let system: any LoginItemSystem
    private(set) var status: SMAppService.Status
    private(set) var errorMessage: String?

    var isEnabled: Bool { status == .enabled }
    var requiresApproval: Bool { status == .requiresApproval }

    var statusMessage: String {
        switch status {
        case .enabled:
            "NotchMaster will open when you log in."
        case .notRegistered:
            "NotchMaster won't open automatically when you log in."
        case .requiresApproval:
            "Approval required. Allow NotchMaster in Login Items before it can open at login."
        case .notFound:
            "macOS couldn't find the login item. Try again from an installed copy of NotchMaster."
        @unknown default:
            "macOS reported an unrecognized login-item status."
        }
    }

    init(system: any LoginItemSystem = MainAppLoginItemSystem()) {
        self.system = system
        status = system.status
    }

    func refresh() {
        let currentStatus = system.status
        if currentStatus != status {
            errorMessage = nil
        }
        status = currentStatus
    }

    func setEnabled(_ enabled: Bool) {
        refresh()
        errorMessage = nil
        defer { status = system.status }

        do {
            if enabled {
                guard status != .enabled, status != .requiresApproval else { return }
                try system.register()
            } else {
                guard status != .notRegistered, status != .notFound else { return }
                try system.unregister()
            }
        } catch {
            let action = enabled ? "enable" : "disable"
            errorMessage = "Couldn't \(action) Launch at Login. \(error.localizedDescription)"
        }
    }

    func openLoginItemsSettings() {
        system.openLoginItemsSettings()
    }
}
