import Cocoa

final class KeyMonitor {
    private let inputSourceManager: InputSourceManager
    private var monitor: Any?
    private var fnWasDown = false

    init(inputSourceManager: InputSourceManager) {
        self.inputSourceManager = inputSourceManager
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event)
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handleFlags(_ event: NSEvent) {
        let fnDown = event.modifierFlags.contains(.function)
        if fnDown && !fnWasDown {
            inputSourceManager.toggleInputSource()
        }
        fnWasDown = fnDown
    }

    deinit { stop() }
}
