import AppKit
import ServiceManagement

final class SettingsViewController: NSViewController {
    private let launchAtLoginButton = NSButton(
        checkboxWithTitle: "Launch at login",
        target: nil,
        action: nil
    )

    private let switchOnReleaseButton = NSButton(
        checkboxWithTitle: "Switch on Fn release (enables long press)",
        target: nil,
        action: nil
    )

    override func loadView() {
        let rootView = NSView()
        rootView.translatesAutoresizingMaskIntoConstraints = false

        let description = NSTextField(
            labelWithString: "Press the FN key to switch keyboard input source."
        )
        description.textColor = .secondaryLabelColor
        description.alignment = .center
        description.maximumNumberOfLines = 0
        description.lineBreakMode = .byWordWrapping

        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(launchAtLoginChanged)
        launchAtLoginButton.state =
            SMAppService.mainApp.status == .enabled ? .on : .off

        switchOnReleaseButton.target = self
        switchOnReleaseButton.action = #selector(switchOnReleaseChanged)
        switchOnReleaseButton.state =
            UserDefaults.standard.bool(forKey: "switchOnRelease") ? .on : .off

        let settings = NSStackView(views: [
            launchAtLoginButton,
            switchOnReleaseButton
        ])
        settings.orientation = .vertical
        settings.alignment = .leading
        settings.spacing = 12

        let quitButton = NSButton(
            title: "Quit",
            target: self,
            action: #selector(quit)
        )
        quitButton.bezelStyle = .rounded

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.setContentCompressionResistancePriority(
            .defaultLow,
            for: .vertical
        )

        let content = NSStackView(views: [
            description,
            settings,
            spacer,
            quitButton
        ])
        content.orientation = .vertical
        content.alignment = .centerX
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(
                equalTo: rootView.leadingAnchor,
                constant: 24
            ),
            content.trailingAnchor.constraint(
                equalTo: rootView.trailingAnchor,
                constant: -24
            ),
            content.topAnchor.constraint(
                equalTo: rootView.topAnchor,
                constant: 24
            ),
            content.bottomAnchor.constraint(
                equalTo: rootView.bottomAnchor,
                constant: -24
            ),
            description.widthAnchor.constraint(
                lessThanOrEqualTo: rootView.widthAnchor,
                constant: -48
            ),
            spacer.widthAnchor.constraint(
                equalTo: content.widthAnchor
            )
        ])

        view = rootView
    }

    @objc private func launchAtLoginChanged() {
        let enabled = launchAtLoginButton.state == .on

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginButton.state =
                SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }

    @objc private func switchOnReleaseChanged() {
        UserDefaults.standard.set(
            switchOnReleaseButton.state == .on,
            forKey: "switchOnRelease"
        )
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
