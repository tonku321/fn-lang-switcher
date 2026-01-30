import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var launchAtLogin: Bool = {
        SMAppService.mainApp.status == .enabled
    }()

    @State private var hideIndicator: Bool = IndicatorManager.shared.hideIndicator

    var body: some View {
        VStack(spacing: 16) {
            Text("Change Input Source")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Press the FN key to switch keyboard input source.")
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }

                Toggle("Hide language indicator near cursor", isOn: $hideIndicator)
                    .onChange(of: hideIndicator) { newValue in
                        IndicatorManager.shared.hideIndicator = newValue
                    }
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 400, height: 300)
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
