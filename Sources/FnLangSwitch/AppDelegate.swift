import Cocoa
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var inputSourceManager: InputSourceManager!
    private var keyMonitor: KeyMonitor!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        inputSourceManager = InputSourceManager()
        keyMonitor = KeyMonitor(inputSourceManager: inputSourceManager)

        setSystemIndicator(enabled: false)
        keyMonitor.start()

        let isLoginItem = SMAppService.mainApp.status == .enabled
        let event = NSAppleEventManager.shared().currentAppleEvent
        let isLaunchedBySystem = event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem

        if !isLoginItem || !isLaunchedBySystem {
            openSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        setSystemIndicator(enabled: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    private func setSystemIndicator(enabled: Bool) {
        let value = enabled ? "1" : "0"
        let write = Process()
        write.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        write.arguments = ["write", "-g", "TSMLanguageIndicatorEnabled", "-int", value]
        try? write.run()
        write.waitUntilExit()

        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        kill.arguments = ["TextInputMenuAgent"]
        try? kill.run()
    }


    private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 160),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            w.isReleasedWhenClosed = false
            w.title = "FnLangSwitch"
            w.contentView = NSHostingView(rootView: SettingsView())
            w.center()
            settingsWindow = w
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
