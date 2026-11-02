import Foundation
import ServiceManagement
import Testing
@testable import NotchMaster

@MainActor
final class TestLoginItemSystem: LoginItemSystem {
    var status: SMAppService.Status
    var registrationStatus: SMAppService.Status = .enabled
    var unregistrationStatus: SMAppService.Status = .notRegistered
    var operationError: (any Error)?
    var statusAfterFailure: SMAppService.Status?
    private(set) var registrations = 0
    private(set) var unregistrations = 0
    private(set) var settingsOpened = 0

    init(status: SMAppService.Status = .notRegistered) {
        self.status = status
    }

    func register() throws {
        registrations += 1
        try failIfRequested()
        status = registrationStatus
    }

    func unregister() throws {
        unregistrations += 1
        try failIfRequested()
        status = unregistrationStatus
    }

    func openLoginItemsSettings() {
        settingsOpened += 1
    }

    private func failIfRequested() throws {
        if let operationError {
            if let statusAfterFailure { status = statusAfterFailure }
            throw operationError
        }
    }
}

enum LoginItemTestError: LocalizedError {
    case rejected

    var errorDescription: String? { "The test operation was rejected." }
}

@Suite
@MainActor
struct LoginItemServiceTests {
    @Test(arguments: [SMAppService.Status.notRegistered, .enabled, .requiresApproval, .notFound])
    func initialStateComesFromTheSystem(_ status: SMAppService.Status) {
        let system = TestLoginItemSystem(status: status)
        let service = LoginItemService(system: system)

        #expect(service.status == status)
        #expect(service.isEnabled == (status == .enabled))
        #expect(service.requiresApproval == (status == .requiresApproval))
        #expect(service.errorMessage == nil)
        #expect(!service.statusMessage.isEmpty)
        #expect(system.registrations == 0 && system.unregistrations == 0)
    }

    @Test(arguments: [SMAppService.Status.enabled, .requiresApproval, .notRegistered, .notFound])
    func registrationUsesConfirmedStatus(_ resultingStatus: SMAppService.Status) {
        let system = TestLoginItemSystem()
        system.registrationStatus = resultingStatus
        let service = LoginItemService(system: system)

        service.setEnabled(true)

        #expect(system.registrations == 1)
        #expect(service.status == resultingStatus)
        #expect(service.isEnabled == (resultingStatus == .enabled))
        #expect(service.requiresApproval == (resultingStatus == .requiresApproval))
    }

    @Test(arguments: [SMAppService.Status.enabled, .requiresApproval])
    func unregistersEnabledAndPendingServices(_ initialStatus: SMAppService.Status) {
        let system = TestLoginItemSystem(status: initialStatus)
        let service = LoginItemService(system: system)

        service.setEnabled(false)

        #expect(system.unregistrations == 1)
        #expect(service.status == .notRegistered)
        #expect(!service.isEnabled && !service.requiresApproval)
        #expect(service.errorMessage == nil)
    }

    @Test(arguments: [false, true])
    func failuresKeepTheConfirmedToggleState(enabling: Bool) {
        let initialStatus: SMAppService.Status = enabling ? .notRegistered : .enabled
        let system = TestLoginItemSystem(status: initialStatus)
        system.operationError = LoginItemTestError.rejected
        let service = LoginItemService(system: system)

        service.setEnabled(enabling)

        #expect(service.status == initialStatus)
        #expect(service.isEnabled == !enabling)
        #expect(service.errorMessage?.contains("The test operation was rejected.") == true)
        #expect(system.registrations == (enabling ? 1 : 0))
        #expect(system.unregistrations == (enabling ? 0 : 1))
        service.refresh()
        #expect(service.errorMessage != nil)

        system.operationError = nil
        service.setEnabled(enabling)
        #expect(service.isEnabled == enabling)
        #expect(service.errorMessage == nil)
    }

    @Test(arguments: [SMAppService.Status.enabled, .requiresApproval, .notRegistered, .notFound])
    func rechecksStatusEvenWhenAnOperationThrows(_ resultingStatus: SMAppService.Status) {
        let system = TestLoginItemSystem()
        system.operationError = LoginItemTestError.rejected
        system.statusAfterFailure = resultingStatus
        let service = LoginItemService(system: system)

        service.setEnabled(true)

        #expect(service.status == resultingStatus)
        #expect(service.isEnabled == (resultingStatus == .enabled))
        #expect(service.requiresApproval == (resultingStatus == .requiresApproval))
        #expect(service.errorMessage != nil)
    }

    @Test
    func refreshReconcilesExternalChangesWithoutRegistration() {
        let system = TestLoginItemSystem()
        system.operationError = LoginItemTestError.rejected
        let service = LoginItemService(system: system)
        service.setEnabled(true)

        for status in [SMAppService.Status.requiresApproval, .enabled, .notRegistered, .notFound] {
            system.status = status
            service.refresh()
            #expect(service.status == status)
            #expect(service.isEnabled == (status == .enabled))
            #expect(service.requiresApproval == (status == .requiresApproval))
            #expect(service.errorMessage == nil)
        }
        #expect(system.registrations == 1 && system.unregistrations == 0)
    }

    @Test
    func duplicateRequestsAndExternalChangesDoNotRepeatOperations() {
        let system = TestLoginItemSystem()
        let service = LoginItemService(system: system)
        service.setEnabled(false)
        system.status = .enabled
        service.setEnabled(true)
        system.status = .requiresApproval
        service.setEnabled(true)
        system.status = .notFound
        service.setEnabled(false)

        #expect(system.registrations == 0 && system.unregistrations == 0)
        #expect(service.status == .notFound)
    }

    @Test
    func openingSystemSettingsDoesNotChangeRegistration() {
        let system = TestLoginItemSystem(status: .requiresApproval)
        let service = LoginItemService(system: system)

        service.openLoginItemsSettings()

        #expect(system.settingsOpened == 1)
        #expect(system.registrations == 0 && system.unregistrations == 0)
        #expect(service.requiresApproval && !service.isEnabled)
    }

    @Test
    func compositionInjectsSystemWithoutPersistingALoginBoolean() throws {
        let suiteName = "NotchMasterLoginTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let system = TestLoginItemSystem()
        let dependencies = AppDependencies(defaults: defaults, loginItemSystem: system)

        dependencies.loginItemService.setEnabled(true)
        dependencies.preferences.expansionSpeed = 1

        #expect(system.registrations == 1)
        #expect(dependencies.loginItemService.isEnabled)
        #expect(dependencies.preferences.expansionDuration == 0.15)
        #expect(defaults.persistentDomain(forName: suiteName)?.keys.sorted() == [PreferencesStore.expansionDurationKey])
    }
}
