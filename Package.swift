// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "DayPeek",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DayPeek",
            path: "Sources/DayPeek",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "DayPeekTests",
            dependencies: ["DayPeek"],
            path: "Tests/DayPeekTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
