import Foundation
import IOKit.ps
import Combine

/// Reads Mac battery level (0..1) and charging state via IOPowerSources.
/// Updates every 15s on the main run loop. Also responds to power source
/// change notifications for near-immediate refresh on plug/unplug.
final class BatteryMonitor: ObservableObject {
    @Published var level: Double = 1.0
    @Published var isCharging: Bool = false
    @Published var hasBattery: Bool = true

    private var timer: Timer?
    private var notifySource: CFRunLoopSource?

    init() {
        refresh()
        let t = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        // Live plug/unplug
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        let src = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let me = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { me.refresh() }
        }, ctx)?.takeRetainedValue()
        if let src {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
            notifySource = src
        }
    }

    deinit {
        timer?.invalidate()
        if let src = notifySource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .defaultMode)
        }
    }

    func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            hasBattery = false
            return
        }
        var foundBattery = false
        for src in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, src)?.takeUnretainedValue() as? [String: Any] else { continue }
            if let type = desc[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType {
                foundBattery = true
                if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
                   let maxCap = desc[kIOPSMaxCapacityKey] as? Int, maxCap > 0 {
                    level = Swift.min(1.0, Double(cur) / Double(maxCap))
                }
                if let charging = desc[kIOPSIsChargingKey] as? Bool {
                    isCharging = charging
                } else if let state = desc[kIOPSPowerSourceStateKey] as? String {
                    isCharging = (state == kIOPSACPowerValue)
                }
            }
        }
        hasBattery = foundBattery
    }
}

