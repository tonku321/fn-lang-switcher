import Cocoa
import CoreGraphics

final class KeyMonitor {
    private let inputSourceManager: InputSourceManager
    private var monitor: Any?

    private var switchOnRelease: Bool {
        UserDefaults.standard.bool(forKey: "switchOnRelease")
    }

    private var fnWasDown = false
    private var fnPressTime: UInt64 = 0

    // Number of physical keyDown events when Fn was pressed.
    private var keyDownCountAtFnPress: UInt32 = 0

    // Other modifiers used together with Fn.
    private var otherModifierUsed = false
    private var modifiersAtFnPress: NSEvent.ModifierFlags = []

    private static let longPressThresholdNs: UInt64 =
        400_000_000

    private static let otherModifierMask:
        NSEvent.ModifierFlags = [
            .capsLock,
            .shift,
            .control,
            .option,
            .command
        ]

    init(inputSourceManager: InputSourceManager) {
        self.inputSourceManager = inputSourceManager
    }

    func start() {
        // We only need flagsChanged, exactly like the original project.
        // Ordinary key presses are detected using the Quartz
        // hardware-event counter instead.
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: .flagsChanged
        ) { [weak self] event in
            self?.handleFlags(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }

        monitor = nil
    }

    private func handleFlags(_ event: NSEvent) {
        let fnDown =
            event.modifierFlags.contains(.function)

        if fnDown && !fnWasDown {
            // Fn has just been pressed.
            fnWasDown = true

            if !switchOnRelease {
                inputSourceManager.toggleInputSource()
                return
            }

            fnPressTime = mach_absolute_time()

            keyDownCountAtFnPress =
                CGEventSource.counterForEventType(
                    .hidSystemState,
                    eventType: .keyDown
                )

            modifiersAtFnPress =
                event.modifierFlags.intersection(
                    Self.otherModifierMask
                )

            // If Shift/Control/etc. was already held before Fn,
            // this is a combination rather than a plain Fn press.
            otherModifierUsed =
                !modifiersAtFnPress.isEmpty

            return
        }

        if fnDown && fnWasDown {
            // Fn is still held. Check whether another modifier
            // changed while it was held.
            let currentModifiers =
                event.modifierFlags.intersection(
                    Self.otherModifierMask
                )

            if currentModifiers != modifiersAtFnPress {
                otherModifierUsed = true
            }

            return
        }

        if !fnDown && fnWasDown {
            // Fn has just been released.
            fnWasDown = false

            if !switchOnRelease {
                return
            }

            let keyDownCountNow =
                CGEventSource.counterForEventType(
                    .hidSystemState,
                    eventType: .keyDown
                )

            // If the counter changed, at least one ordinary key
            // was pressed while Fn was held.
            //
            // This catches Fn+Delete even if Delete was pressed
            // and released long before Fn itself was released.
            let otherKeyUsed =
                keyDownCountNow != keyDownCountAtFnPress

            if otherKeyUsed || otherModifierUsed {
                return
            }

            let elapsed =
                mach_absolute_time() - fnPressTime

            var info =
                mach_timebase_info_data_t()

            mach_timebase_info(&info)

            let elapsedNs =
                elapsed
                * UInt64(info.numer)
                / UInt64(info.denom)

            if elapsedNs < Self.longPressThresholdNs {
                inputSourceManager.toggleInputSource()
            } else {
                inputSourceManager.showAllInputSourcesMenu()
            }
        }
    }

    deinit {
        stop()
    }
}
