import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var launchAtLogin: Bool = {
        SMAppService.mainApp.status == .enabled
    }()

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

            }

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(24)
        .frame(width: 400, height: 160)
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
