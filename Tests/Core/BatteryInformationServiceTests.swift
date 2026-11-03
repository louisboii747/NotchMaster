import Foundation
import IOKit.ps
import Testing
@testable import NotchMaster

@MainActor
final class TestBatteryInformationProvider: BatteryInformationProvider {
    var information: BatteryInformation?
    private(set) var reads = 0
    private(set) var observationStarts = 0
    private(set) var observationStops = 0
    private var onChange: (@MainActor () -> Void)?

    init(information: BatteryInformation? = nil) {
        self.information = information
    }

    func readInformation() -> BatteryInformation? {
        reads += 1
        return information
    }

    func startObserving(_ onChange: @escaping @MainActor () -> Void) {
        observationStarts += 1
        self.onChange = onChange
    }

    func stopObserving() {
        observationStops += 1
        onChange = nil
    }

    func sendChange() {
        onChange?()
    }
}

@Suite
@MainActor
struct BatteryInformationServiceTests {
    @Test
    func readsInitiallyAndOnlyRefreshesAfterProviderEvents() {
        let initial = BatteryInformation(percentage: 37, isCharging: false)
        let provider = TestBatteryInformationProvider(information: initial)
        let service = BatteryInformationService(provider: provider)
        #expect(service.information == initial)
        #expect(provider.reads == 1 && provider.observationStarts == 1)

        provider.information = BatteryInformation(percentage: 72, isCharging: true)
        #expect(service.information == initial && provider.reads == 1)
        provider.sendChange()
        #expect(service.information == provider.information && provider.reads == 2)

        provider.information = nil
        provider.sendChange()
        #expect(service.information == nil && provider.reads == 3)
        provider.information = BatteryInformation(percentage: 100, isCharging: false)
        provider.sendChange()
        #expect(service.information == provider.information && provider.reads == 4)
    }

    @Test
    func unavailableInitiallyCanRecoverAndObservationIsReleased() {
        let provider = TestBatteryInformationProvider()
        var service: BatteryInformationService? = BatteryInformationService(provider: provider)
        weak let weakService = service
        #expect(service?.information == nil)
        provider.information = BatteryInformation(percentage: 0, isCharging: false)
        provider.sendChange()
        #expect(service?.information == provider.information)

        service = nil
        #expect(weakService == nil && provider.observationStops == 1)
        provider.sendChange()
        #expect(provider.reads == 2)
    }

    @Test(arguments: [(0, 100, 0), (51, 200, 26), (2500, 5000, 50), (100, 100, 100)], [false, true])
    func decodesCapacityAndActualChargingState(capacity: (Int, Int, Int), isCharging: Bool) {
        var description = batteryDescription
        description[kIOPSCurrentCapacityKey] = capacity.0
        description[kIOPSMaxCapacityKey] = capacity.1
        description[kIOPSIsChargingKey] = isCharging

        #expect(SystemBatteryInformationProvider.information(in: [description]) == BatteryInformation(
            percentage: capacity.2, isCharging: isCharging
        ))
    }

    @Test(arguments: [(-1, 100), (1, 0), (1, -1), (101, 100)])
    func rejectsInvalidCapacities(capacity: (Int, Int)) {
        var description = batteryDescription
        description[kIOPSCurrentCapacityKey] = capacity.0
        description[kIOPSMaxCapacityKey] = capacity.1
        #expect(SystemBatteryInformationProvider.information(in: [description]) == nil)
    }

    @Test(arguments: [kIOPSTypeKey, kIOPSIsPresentKey, kIOPSCurrentCapacityKey, kIOPSMaxCapacityKey, kIOPSIsChargingKey])
    func missingOrMalformedFieldsAreUnavailable(key: String) {
        var description = batteryDescription
        description.removeValue(forKey: key)
        #expect(SystemBatteryInformationProvider.information(in: [description]) == nil)
        description[key] = "invalid"
        #expect(SystemBatteryInformationProvider.information(in: [description]) == nil)
    }

    @Test
    func ignoresExternalPowerSourcesAndAbsentBatteries() {
        var external = batteryDescription
        external[kIOPSTypeKey] = kIOPSUPSType
        var absent = batteryDescription
        absent[kIOPSIsPresentKey] = false
        #expect(SystemBatteryInformationProvider.information(in: []) == nil)
        #expect(SystemBatteryInformationProvider.information(in: [external]) == nil)
        #expect(SystemBatteryInformationProvider.information(in: [absent]) == nil)
        #expect(SystemBatteryInformationProvider.information(in: [external, batteryDescription]) == BatteryInformation(
            percentage: 62, isCharging: false
        ))
    }

    private var batteryDescription: [String: Any] {
        [
            kIOPSTypeKey: kIOPSInternalBatteryType,
            kIOPSIsPresentKey: true,
            kIOPSCurrentCapacityKey: 62,
            kIOPSMaxCapacityKey: 100,
            kIOPSIsChargingKey: false
        ]
    }
}
