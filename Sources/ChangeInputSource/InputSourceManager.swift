import Carbon
import Foundation

final class InputSourceManager {
    private var inputSources: [TISInputSource] = []

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
        let currentID = inputSourceID(current)

        var nextIndex = 0
        if let idx = inputSources.firstIndex(where: { inputSourceID($0) == currentID }) {
            nextIndex = (idx + 1) % inputSources.count
        }

        TISSelectInputSource(inputSources[nextIndex])
    }

    private func inputSourceID(_ source: TISInputSource) -> String {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "" }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
}
