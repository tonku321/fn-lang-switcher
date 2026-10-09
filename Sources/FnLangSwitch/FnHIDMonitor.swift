import Cocoa
import IOKit.hid

/// Fn state plus transient keyboard state for chord cancellation. No text is decoded or logged.
final class FnHIDMonitor {
    private var manager: IOHIDManager?
    private var heldKeys = Set<String>()
    var hasOtherKeysDown: Bool { !heldKeys.isEmpty }
    var onOtherKey: (() -> Void)?
    var onState: ((UInt64, Bool) -> Void)?

    func start() {
        let hid = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = hid
        IOHIDManagerSetDeviceMatching(hid, nil)
        let matches: [[String: Int]] = [
            [kIOHIDElementUsagePageKey: 0x07],
            [kIOHIDElementUsagePageKey: 0xFF, kIOHIDElementUsageKey: 3],
            [kIOHIDElementUsagePageKey: 0xFF01, kIOHIDElementUsageKey: 3],
            [kIOHIDElementUsagePageKey: 0x0C, kIOHIDElementUsageKey: 0x029D],
        ]
        IOHIDManagerSetInputValueMatchingMultiple(hid, matches as CFArray)
        IOHIDManagerRegisterInputValueCallback(hid, { context, result, _, value in
            guard result == kIOReturnSuccess, let context else { return }
            let owner = Unmanaged<FnHIDMonitor>.fromOpaque(context).takeUnretainedValue()
            let element = IOHIDValueGetElement(value)
            let page = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            let device = IOHIDElementGetDevice(element)
            // Registry identity prevents two keyboards from corrupting each other's press state.
            var id: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id)
            let down = IOHIDValueGetIntegerValue(value) != 0
            if page == 0x07 {
                // Ignore HID error/rollover values; retain only temporary pressed-state identity.
                guard usage > 3 else { return }
                let identity = "\(id):\(IOHIDElementGetCookie(element))"
                if down {
                    owner.heldKeys.insert(identity)
                    owner.onOtherKey?()
                } else {
                    owner.heldKeys.remove(identity)
                }
                return
            }
            guard (page == 0xFF && usage == 3) || (page == 0xFF01 && usage == 3)
                || (page == 0x0C && usage == 0x029D) else { return }
            owner.onState?(id, down)
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(hid, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(hid, IOOptionBits(kIOHIDOptionsTypeNone))
        Diagnostics.log("hid.open result=\(result) inputMonitoring=\(CGPreflightListenEventAccess())")
    }

    func stop() {
        if let hid = manager {
            IOHIDManagerUnscheduleFromRunLoop(hid, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(hid, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        heldKeys.removeAll()
    }
    deinit { stop() }
}
