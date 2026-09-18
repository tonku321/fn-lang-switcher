import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var inputSourceManager: InputSourceManager!
    private var keyMonitor: KeyMonitor!
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        inputSourceManager = InputSourceManager()
        keyMonitor = KeyMonitor(
            inputSourceManager: inputSourceManager
        )

        keyMonitor.start()
        setupStatusItem()

        let isLoginItem =
            SMAppService.mainApp.status == .enabled

        let event =
            NSAppleEventManager.shared()
                .currentAppleEvent

        let isLaunchedBySystem =
            event?.eventID == kAEOpenApplication
            && event?
                .paramDescriptor(
                    forKeyword: keyAEPropData
                )?
                .enumCodeValue
                == keyAELaunchedAsLogInItem

        if !isLoginItem || !isLaunchedBySystem {
            openSettings()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        openSettings()
        return false
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "globe",
                accessibilityDescription: "FnLangSwitch"
            )

            image?.isTemplate = true
            button.image = image
            button.toolTip = "FnLangSwitch"
        }

        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )

        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit FnLangSwitch",
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        )

        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: 400,
                    height: 200
                ),
                styleMask: [
                    .titled,
                    .closable
                ],
                backing: .buffered,
                defer: false
            )

            w.isReleasedWhenClosed = false
            w.title = "FnLangSwitch"
            w.contentViewController = SettingsViewController()
            w.center()

            settingsWindow = w
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
