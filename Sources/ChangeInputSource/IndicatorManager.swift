import Foundation

final class IndicatorManager {
    static let shared = IndicatorManager()

    private let appDefaults = UserDefaults.standard
    private let originalKey = "OriginalTSMLanguageIndicatorEnabled"
    private let hideKey = "HideLanguageIndicator"

    private init() {}

    /// Whether the user wants the indicator hidden (our setting)
    var hideIndicator: Bool {
        get { appDefaults.bool(forKey: hideKey) }
        set {
            appDefaults.set(newValue, forKey: hideKey)
            applyIndicatorSetting(hidden: newValue)
        }
    }

    /// Save original system value and apply our setting on launch
    func onAppLaunch() {
        if !appDefaults.bool(forKey: "OriginalValueSaved") {
            let current = readSystemIndicatorValue()
            appDefaults.set(current, forKey: originalKey)
            appDefaults.set(true, forKey: "OriginalValueSaved")
        }
        if hideIndicator {
            applyIndicatorSetting(hidden: true)
        }
    }

    /// Restore original system value on quit
    func onAppQuit() {
        let original = appDefaults.object(forKey: originalKey) as? Int ?? 1
        writeSystemIndicatorValue(original)
        restartTextInputMenuAgent()
    }

    private let globalDomain = "-globalDomain"

    private func readSystemIndicatorValue() -> Int {
        let val = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["TSMLanguageIndicatorEnabled"]
        if let num = val as? NSNumber {
            return num.intValue
        }
        return 1
    }

    private func applyIndicatorSetting(hidden: Bool) {
        writeSystemIndicatorValue(hidden ? 0 : 1)
        restartTextInputMenuAgent()
    }

    private func writeSystemIndicatorValue(_ value: Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", globalDomain, "TSMLanguageIndicatorEnabled", "-int", "\(value)"]
        try? process.run()
        process.waitUntilExit()
    }

    private func restartTextInputMenuAgent() {
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        kill.arguments = ["TextInputMenuAgent"]
        try? kill.run()
    }
}
