import AppKit
import Carbon
import Foundation

final class InputSourceManager: NSObject {
    private var inputSources: [TISInputSource] = []
    private var allInputSources: [TISInputSource] = []

    override init() {
        super.init()
        reload()
    }

    func reload() {
        guard let cfList =
            TISCreateInputSourceList(nil, false)?.takeRetainedValue()
                as? [TISInputSource]
        else {
            inputSources = []
            allInputSources = []
            return
        }

        let candidates = cfList.filter { source in
            guard
                stringProperty(source, kTISPropertyInputSourceCategory)
                    == kTISCategoryKeyboardInputSource as String
            else {
                return false
            }

            guard boolProperty(
                source,
                kTISPropertyInputSourceIsSelectCapable
            ) else {
                return false
            }

            guard boolProperty(
                source,
                kTISPropertyInputSourceIsEnabled
            ) else {
                return false
            }

            return true
        }

        allInputSources = candidates.sorted {
            localizedName($0).localizedCaseInsensitiveCompare(
                localizedName($1)
            ) == .orderedAscending
        }
        inputSources = allInputSources
    }

    func toggleInputSource() {
        reload()

        guard inputSources.count > 1 else {
            return
        }

        let current =
            TISCopyCurrentKeyboardInputSource()
                .takeRetainedValue()

        let currentID = inputSourceID(current)

        let currentIndex = inputSources.firstIndex {
            inputSourceID($0) == currentID
        } ?? -1

        let nextIndex =
            currentIndex >= 0
            ? (currentIndex + 1) % inputSources.count
            : 0

        TISSelectInputSource(inputSources[nextIndex])
    }

    func showAllInputSourcesMenu() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.reload()

            guard !self.allInputSources.isEmpty else {
                return
            }

            let current =
                TISCopyCurrentKeyboardInputSource()
                    .takeRetainedValue()

            let currentID =
                self.inputSourceID(current)

            let menu = NSMenu()
            menu.autoenablesItems = false

            for (index, source) in self.allInputSources.enumerated() {
                let item = NSMenuItem(
                    title: self.localizedName(source),
                    action: #selector(
                        self.selectInputSourceFromMenu(_:)
                    ),
                    keyEquivalent: ""
                )

                item.target = self
                item.tag = index

                if self.inputSourceID(source) == currentID {
                    item.state = .on
                }

                menu.addItem(item)
            }

            menu.popUp(
                positioning: nil,
                at: NSEvent.mouseLocation,
                in: nil
            )
        }
    }

    @objc private func selectInputSourceFromMenu(
        _ sender: NSMenuItem
    ) {
        guard allInputSources.indices.contains(sender.tag) else {
            return
        }

        TISSelectInputSource(
            allInputSources[sender.tag]
        )
    }

    private func inputSourceID(
        _ source: TISInputSource
    ) -> String {
        stringProperty(
            source,
            kTISPropertyInputSourceID
        ) ?? ""
    }

    private func localizedName(
        _ source: TISInputSource
    ) -> String {
        stringProperty(
            source,
            kTISPropertyLocalizedName
        ) ?? ""
    }

    private func stringProperty(
        _ source: TISInputSource,
        _ key: CFString
    ) -> String? {
        guard let ptr =
            TISGetInputSourceProperty(
                source,
                key
            )
        else {
            return nil
        }

        return Unmanaged<CFString>
            .fromOpaque(ptr)
            .takeUnretainedValue() as String
    }

    private func boolProperty(
        _ source: TISInputSource,
        _ key: CFString
    ) -> Bool {
        guard let ptr =
            TISGetInputSourceProperty(
                source,
                key
            )
        else {
            return false
        }

        let value =
            Unmanaged<CFBoolean>
                .fromOpaque(ptr)
                .takeUnretainedValue()

        return CFBooleanGetValue(value)
    }
}
