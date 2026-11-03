import Foundation
import IOKit.ps
import Observation

struct BatteryInformation: Equatable, Sendable {
    let percentage: Int
    let isCharging: Bool
}

@MainActor
protocol BatteryInformationProvider: AnyObject {
    func readInformation() -> BatteryInformation?
    func startObserving(_ onChange: @escaping @MainActor () -> Void)
    func stopObserving()
}

@MainActor
final class SystemBatteryInformationProvider: BatteryInformationProvider {
    private var runLoopSource: CFRunLoopSource?
    private var onChange: (@MainActor () -> Void)?

    func readInformation() -> BatteryInformation? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        let descriptions = sources.compactMap {
            IOPSGetPowerSourceDescription(snapshot, $0)?.takeUnretainedValue() as? [String: Any]
        }
        return Self.information(in: descriptions)
    }

    nonisolated static func information(in descriptions: [[String: Any]]) -> BatteryInformation? {
        guard let battery = descriptions.first(where: { $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType }),
              battery[kIOPSIsPresentKey] as? Bool == true,
              let current = battery[kIOPSCurrentCapacityKey] as? Int,
              let maximum = battery[kIOPSMaxCapacityKey] as? Int,
              maximum > 0, current >= 0, current <= maximum,
              let isCharging = battery[kIOPSIsChargingKey] as? Bool else { return nil }
        let percentage = Int((Double(current) / Double(maximum) * 100).rounded())
        return BatteryInformation(percentage: percentage, isCharging: isCharging)
    }

    func startObserving(_ onChange: @escaping @MainActor () -> Void) {
        stopObserving()
        self.onChange = onChange
        let context = Unmanaged.passUnretained(self).toOpaque()
        runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<SystemBatteryInformationProvider>.fromOpaque(context).takeUnretainedValue().onChange?()
            }
        }, context)?.takeRetainedValue()
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }

    func stopObserving() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        runLoopSource = nil
        onChange = nil
    }

    isolated deinit {
        stopObserving()
    }
}

@MainActor
@Observable
final class BatteryInformationService {
    private let provider: any BatteryInformationProvider
    private(set) var information: BatteryInformation?

    init(provider: any BatteryInformationProvider = SystemBatteryInformationProvider()) {
        self.provider = provider
        provider.startObserving { [weak self] in
            self?.refresh()
        }
        refresh()
    }

    private func refresh() {
        let current = provider.readInformation()
        if information != current {
            information = current
        }
    }

    isolated deinit {
        provider.stopObserving()
    }
}
