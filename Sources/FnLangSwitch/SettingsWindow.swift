import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var launchAtLogin: Bool = {
        SMAppService.mainApp.status == .enabled
    }()

    @AppStorage("switchOnRelease") private var switchOnRelease = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Press the FN key to switch keyboard input source.")
                .fixedSize()
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }

                Toggle("Switch on Fn release (ignores Fn+key combos)", isOn: $switchOnRelease)
            }

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(24)
        .frame(width: 400, height: 200)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
