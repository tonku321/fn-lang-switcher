// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FnLangSwitch",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "FnLangSwitch",
            path: "Sources/FnLangSwitch",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
            ]
        ),
    ]
)
