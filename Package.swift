// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AIStupidLevelMenuBarWatcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AIStupidLevelWatcher",
            targets: ["AIStupidLevelWatcher"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AIStupidLevelWatcher",
            path: "Sources/AIStupidLevelWatcher"
        )
    ]
)
