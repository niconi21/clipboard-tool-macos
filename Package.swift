// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipboardTool",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClipboardTool",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/ClipboardTool",
            resources: [
                .process("Resources")
            ],
            swiftSettings: []
        ),
        .testTarget(
            name: "ClipboardToolTests",
            dependencies: ["ClipboardTool"],
            path: "Tests/ClipboardToolTests"
        )
    ]
)
