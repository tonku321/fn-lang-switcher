import Carbon
import Foundation
import os

let log = Logger(subsystem: "com.tonku.FnLangSwitch", category: "switch")

final class InputSourceManager {
    private var inputSources: [TISInputSource] = []

    /// Input source we switched away from after typing in it.
    /// Cleared when Fn is pressed without any typing in between.
    private var previous: TISInputSource?
    /// Whether there was graphic (printable) input since the last switch.
    private var hadInputSinceSwitch = false

    init() {
        reload()
    }

    func reload() {
        guard let cfList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            inputSources = []
            return
        }
        inputSources = cfList.filter { source in
            guard let categoryPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory) else { return false }
            let category = Unmanaged<CFString>.fromOpaque(categoryPtr).takeUnretainedValue() as String
            guard category == kTISCategoryKeyboardInputSource as String else { return false }

            guard let selectablePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) else { return false }
            let selectable = Unmanaged<CFBoolean>.fromOpaque(selectablePtr).takeUnretainedValue()
            return CFBooleanGetValue(selectable)
        }
    }

    func toggleInputSource() {
        guard inputSources.count > 1 else { return }

        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let currentIndex = index(of: current)

        var nextIndex = 0
        if hadInputSinceSwitch,
           let previous, !isSame(previous, current),
           let prevIndex = index(of: previous) {
            // Typing happened in the current language — jump back to the previous one.
            nextIndex = prevIndex
        } else if let currentIndex {
            // No typing — regular cyclic switch.
            nextIndex = (currentIndex + 1) % inputSources.count
        }

        log.debug("toggle: current=\(self.inputSourceID(current), privacy: .public) idx=\(String(describing: currentIndex), privacy: .public) hadInput=\(self.hadInputSinceSwitch, privacy: .public) previous=\(self.previous.map(self.inputSourceID) ?? "nil", privacy: .public) -> next=\(self.inputSourceID(self.inputSources[nextIndex]), privacy: .public)")
        previous = hadInputSinceSwitch ? current : nil
        hadInputSinceSwitch = false

        TISSelectInputSource(inputSources[nextIndex])
    }

    /// Call when the user typed a printable character in the current input source.
    func noteGraphicInput() {
        if !hadInputSinceSwitch { log.debug("graphic input noted") }
        hadInputSinceSwitch = true
    }

    private func index(of source: TISInputSource) -> Int? {
        inputSources.firstIndex { isSame($0, source) }
    }

    /// Some third-party layouts (e.g. Ukelele bundles) report a different
    /// kTISPropertyInputSourceID for the current source than in the source list,
    /// so compare the objects themselves first and fall back to the ID.
    private func isSame(_ a: TISInputSource, _ b: TISInputSource) -> Bool {
        CFEqual(a, b) || inputSourceID(a) == inputSourceID(b)
    }

    private func inputSourceID(_ source: TISInputSource) -> String {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "" }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
}
