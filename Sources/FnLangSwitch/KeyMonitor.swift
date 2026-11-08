import Cocoa

final class KeyMonitor {
    private let inputSourceManager: InputSourceManager
    private var monitor: Any?
    private var fnWasDown = false
    private var otherKeyPressed = false
    private var fnPressTime: UInt64 = 0

    /// Maximum interval (ns) for a plain Fn tap — a quick tap switches, a held Fn does not.
    private static let tapThresholdNs: UInt64 = 400_000_000 // 400 ms

    private var switchOnRelease: Bool {
        UserDefaults.standard.bool(forKey: "switchOnRelease")
    }

    init(inputSourceManager: InputSourceManager) {
        self.inputSourceManager = inputSourceManager
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .keyDown, .keyUp, .systemDefined]
        ) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handleEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            handleFlags(event)
            return
        }
        if fnWasDown && switchOnRelease {
            otherKeyPressed = true
        }
        if event.type == .keyDown && Self.isGraphicInput(event) {
            inputSourceManager.noteGraphicInput()
        }
    }

    /// True if the key event produces printable text (not a shortcut, arrow, F-key, etc.).
    private static func isGraphicInput(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if !flags.isDisjoint(with: [.command, .control, .function]) { return false }
        guard let chars = event.characters, !chars.isEmpty else { return false }
        return chars.unicodeScalars.contains { scalar in
            // 0xF700–0xF8FF: AppKit function-key codes (arrows, F1…, Home, etc.)
            !CharacterSet.controlCharacters.contains(scalar)
                && !(0xF700...0xF8FF).contains(scalar.value)
        }
    }

    private func handleFlags(_ event: NSEvent) {
        let fnDown = event.modifierFlags.contains(.function)

        if fnDown && !fnWasDown {
            // Fn just pressed
            if switchOnRelease {
                otherKeyPressed = false
                fnPressTime = mach_absolute_time()
            } else {
                inputSourceManager.toggleInputSource()
            }
        } else if !fnDown && fnWasDown {
            // Fn just released
            if switchOnRelease {
                let elapsed = mach_absolute_time() - fnPressTime
                var info = mach_timebase_info_data_t()
                mach_timebase_info(&info)
                let elapsedNs = elapsed * UInt64(info.numer) / UInt64(info.denom)
                if !otherKeyPressed && elapsedNs < Self.tapThresholdNs {
                    inputSourceManager.toggleInputSource()
                }
            }
        } else if fnDown && fnWasDown && switchOnRelease {
            // Other modifier changed while Fn is held (e.g. Fn+Shift)
            otherKeyPressed = true
        }

        fnWasDown = fnDown
    }

    deinit { stop() }
}
