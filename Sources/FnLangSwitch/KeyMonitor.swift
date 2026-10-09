import Cocoa
import Carbon

final class KeyMonitor {
    private let inputSourceManager: InputSourceManager
    private let hid = FnHIDMonitor()
    private var monitor: Any?
    private var localMonitor: Any?
    private var heldDevices = Set<UInt64>()
    private var otherKeyPressed = false
    private var pressTime: TimeInterval = 0
    private var switchOnRelease: Bool { UserDefaults.standard.bool(forKey: "switchOnRelease") }
    private let blockingModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]

    init(inputSourceManager: InputSourceManager) { self.inputSourceManager = inputSourceManager }

    func start() {
        Diagnostics.log("monitor.start accessibility=\(AXIsProcessTrusted()) secureInput=\(IsSecureEventInputEnabled()) releaseMode=\(switchOnRelease) backend=HID")
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp, .systemDefined]
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] in self?.handleEvent($0) }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
        hid.onState = { [weak self] device, down in self?.handleFn(device: device, down: down) }
        hid.onOtherKey = { [weak self] in
            guard let self, !self.heldDevices.isEmpty else { return }
            self.otherKeyPressed = true
            Diagnostics.log("tap.cancel reason=hardwareChord")
        }
        hid.start()
    }

    func stop() {
        hid.stop()
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        monitor = nil
        localMonitor = nil
        heldDevices.removeAll()
    }

    private func handleEvent(_ event: NSEvent) {
        guard !heldDevices.isEmpty else { return }
        // Fn's own flagsChanged event is not a chord. All other input cancels a tap.
        if event.type == .flagsChanged && event.keyCode == 63 { return }
        otherKeyPressed = true
        Diagnostics.log("tap.cancel eventType=\(event.type.rawValue)")
    }

    private func handleFn(device: UInt64, down: Bool) {
        Diagnostics.log("hid.fn down=\(down) releaseMode=\(switchOnRelease)")
        if down {
            guard heldDevices.insert(device).inserted else { return }
            guard heldDevices.count == 1 else { otherKeyPressed = true; return }
            pressTime = ProcessInfo.processInfo.systemUptime
            otherKeyPressed = hid.hasOtherKeysDown || !CGEventSource.flagsState(.combinedSessionState).intersection(blockingModifiers).isEmpty
                || IsSecureEventInputEnabled()
            if !switchOnRelease && !otherKeyPressed { inputSourceManager.toggleInputSource() }
        } else {
            guard heldDevices.remove(device) != nil, heldDevices.isEmpty else { return }
            let elapsed = ProcessInfo.processInfo.systemUptime - pressTime
            let blocked = otherKeyPressed || IsSecureEventInputEnabled()
                || !CGEventSource.flagsState(.combinedSessionState).intersection(blockingModifiers).isEmpty
            Diagnostics.log("tap.release durationMs=\(Int(elapsed * 1000)) cancelled=\(blocked)")
            if switchOnRelease && !blocked && elapsed < 0.4 { inputSourceManager.toggleInputSource() }
        }
    }
    deinit { stop() }
}
