// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MagicTapClient",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "MagicTapClient", targets: ["MagicTapClient"]),
    ],
    targets: [
        .executableTarget(
            name: "MagicTapClient",
            path: "Sources/MagicTapClient"
        ),
        .testTarget(
            name: "MagicTapClientTests",
            dependencies: ["MagicTapClient"],
            path: "Tests/MagicTapClientTests"
        ),
    ]
)
