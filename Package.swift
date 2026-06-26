// swift-tools-version:6.0
import PackageDescription

// Personal project: Swift 5 language mode keeps strict-concurrency friction low
// for a SwiftUI + SwiftData + async app while still using the Swift 6.3 toolchain.
//
// Test wiring note: the Command Line Tools (no Xcode) ship Swift Testing as a
// framework outside the default search paths and have no XCTest runner, so plain
// `swift test` cannot run the suites. Use `scripts/test.sh` (or `make test`),
// which adds the framework/rpath flags and `--disable-xctest`. Keeping those
// machine paths in the script (not here) leaves Package.swift portable.
let swift5: SwiftSetting = .swiftLanguageMode(.v5)

let package = Package(
    name: "TrayOps",
    platforms: [.macOS(.v14)],
    products: [
        // GUI binary is "TrayOpsApp", not "TrayOps": a "TrayOps"/"trayops" pair
        // collides on macOS's case-insensitive filesystem (same module and binary
        // name). The CLI keeps the "trayops" command name users type.
        .executable(name: "TrayOpsApp", targets: ["TrayOpsGUI"]),
        .executable(name: "trayops", targets: ["TrayOpsCLI"]),
        .library(name: "TrayOpsCore", targets: ["TrayOpsCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.3"),
    ],
    targets: [
        // Agnostic domain core: no SwiftUI, no terminal.
        .target(
            name: "TrayOpsCore",
            swiftSettings: [swift5]
        ),
        // SwiftUI views live in a library so the UI E2E suite (ViewInspector)
        // can import them — SwiftPM cannot import an executable target.
        .target(
            name: "TrayOpsUI",
            dependencies: ["TrayOpsCore"],
            swiftSettings: [swift5]
        ),
        // GUI executable: thin @main shell that launches the menu bar scene.
        .executableTarget(
            name: "TrayOpsGUI",
            dependencies: ["TrayOpsCore", "TrayOpsUI"],
            swiftSettings: [swift5]
        ),
        // CLI executable.
        .executableTarget(
            name: "TrayOpsCLI",
            dependencies: [
                "TrayOpsCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [swift5]
        ),
        // Shared test helpers (regular target so multiple test targets can reuse it).
        .target(
            name: "TrayOpsTestSupport",
            dependencies: ["TrayOpsCore"],
            path: "Tests/Support",
            swiftSettings: [swift5]
        ),
        .testTarget(
            name: "TrayOpsCoreTests",
            dependencies: ["TrayOpsCore", "TrayOpsTestSupport"],
            swiftSettings: [swift5]
        ),
        .testTarget(
            name: "TrayOpsCLITests",
            dependencies: ["TrayOpsTestSupport", "TrayOpsCLI"],
            swiftSettings: [swift5]
        ),
        .testTarget(
            name: "TrayOpsUITests",
            dependencies: [
                "TrayOpsUI",
                "TrayOpsCore",
                "TrayOpsTestSupport",
                .product(name: "ViewInspector", package: "ViewInspector"),
            ],
            swiftSettings: [swift5]
        ),
    ]
)
