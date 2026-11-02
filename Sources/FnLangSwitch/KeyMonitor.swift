import Cocoa
import Carbon

final class KeyMonitor {
    private let inputSourceManager: InputSourceManager
    private let hid = FnHIDMonitor()
    private var monitor: Any?
    private var localMonitor: Any?
    private var heldDevices = Set<UInt64>()
    private var otherKeyPressed = false
    private var cancellationReasons = Set<String>()
    private var workspaceObservers = [NSObjectProtocol]()
    private var pressTime: TimeInterval = 0
    private var switchOnRelease: Bool { UserDefaults.standard.bool(forKey: "switchOnRelease") }
    private let blockingModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]

    init(inputSourceManager: InputSourceManager) { self.inputSourceManager = inputSourceManager }

    func start() {
        Diagnostics.log("monitor.start accessibility=\(AXIsProcessTrusted()) secureInput=\(IsSecureEventInputEnabled()) releaseMode=\(switchOnRelease) backend=HID diagnosticsVersion=2 pid=\(ProcessInfo.processInfo.processIdentifier)")
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
            self.cancellationReasons.insert("hardwareChord")
            Diagnostics.log("tap.cancel reason=hardwareChord \(self.diagnosticState())")
        }
        hid.start()
        let center = NSWorkspace.shared.notificationCenter
        for (name, label) in [(NSWorkspace.willSleepNotification, "willSleep"),
                              (NSWorkspace.didWakeNotification, "didWake"),
                              (NSWorkspace.sessionDidResignActiveNotification, "sessionInactive"),
                              (NSWorkspace.sessionDidBecomeActiveNotification, "sessionActive")] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                Diagnostics.log("monitor.lifecycle event=\(label) \(self.diagnosticState())")
            })
        }
    }

    func stop() {
        Diagnostics.log("monitor.stop \(diagnosticState())")
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        workspaceObservers.removeAll()
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
        cancellationReasons.insert("eventType_\(event.type.rawValue)")
        Diagnostics.log("tap.cancel eventType=\(event.type.rawValue) \(diagnosticState())")
    }

    private func handleFn(device: UInt64, down: Bool) {
        Diagnostics.log("hid.fn down=\(down) releaseMode=\(switchOnRelease)")
        if down {
            guard heldDevices.insert(device).inserted else {
                Diagnostics.log("hid.fn.ignored reason=duplicateDown")
                return
            }
            guard heldDevices.count == 1 else {
                otherKeyPressed = true
                cancellationReasons.insert("overlappingFnDevices")
                Diagnostics.log("tap.cancel reason=overlappingFnDevices \(diagnosticState())")
                return
            }
            cancellationReasons.removeAll()
            pressTime = ProcessInfo.processInfo.systemUptime
            let keysHeld = hid.hasOtherKeysDown
            let modifiersHeld = !CGEventSource.flagsState(.combinedSessionState).intersection(blockingModifiers).isEmpty
            let secureInput = IsSecureEventInputEnabled()
            otherKeyPressed = keysHeld || modifiersHeld || secureInput
            if keysHeld { cancellationReasons.insert("keysHeldAtPress") }
            if modifiersHeld {
                cancellationReasons.insert("modifiersAtPress")
            }
            if secureInput { cancellationReasons.insert("secureInputAtPress") }
            Diagnostics.log("tap.press reasons=\(reasonSummary) \(diagnosticState())")
            if !switchOnRelease && !otherKeyPressed { inputSourceManager.toggleInputSource() }
        } else {
            guard heldDevices.remove(device) != nil, heldDevices.isEmpty else {
                Diagnostics.log("hid.fn.ignored reason=unmatchedReleaseOrOtherFnHeld \(diagnosticState())")
                return
            }
            let elapsed = ProcessInfo.processInfo.systemUptime - pressTime
            let secureInput = IsSecureEventInputEnabled()
            let modifiersHeld = !CGEventSource.flagsState(.combinedSessionState).intersection(blockingModifiers).isEmpty
            let blocked = otherKeyPressed || secureInput || modifiersHeld
            if secureInput { cancellationReasons.insert("secureInputAtRelease") }
            if modifiersHeld {
                cancellationReasons.insert("modifiersAtRelease")
            }
            // Preserve the switching rules; record the duration limit separately from cancellation.
            let outcome = !switchOnRelease ? "pressMode" : blocked ? "blocked" : elapsed >= 0.4 ? "longHold" : "switch"
            Diagnostics.log("tap.release durationMs=\(Int(elapsed * 1000)) cancelled=\(blocked) outcome=\(outcome) reasons=\(reasonSummary) \(diagnosticState())")
            if switchOnRelease && !blocked && elapsed < 0.4 { inputSourceManager.toggleInputSource() }
        }
    }
    private var reasonSummary: String {
        cancellationReasons.isEmpty ? "none" : cancellationReasons.sorted().joined(separator: ",")
    }

    private func diagnosticState() -> String {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        var modifiers = [String]()
        for (flag, name) in [(CGEventFlags.maskShift, "shift"), (.maskControl, "control"),
                             (.maskAlternate, "option"), (.maskCommand, "command")] {
            if flags.contains(flag) { modifiers.append(name) }
        }
        return "heldFnDevices=\(heldDevices.count) heldKeys=\(hid.heldKeyCount) keyStateAgeMs=\(hid.keyStateAgeMs) modifiers=\(modifiers.isEmpty ? "none" : modifiers.joined(separator: ",")) secureInput=\(IsSecureEventInputEnabled())"
    }
    deinit { stop() }
}
