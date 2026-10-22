// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TeslaMDA",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MDACore"),
        .executableTarget(
            name: "TeslaMDA",
            dependencies: ["MDACore"]
        ),
        .testTarget(
            name: "MDACoreTests",
            dependencies: ["MDACore"]
        ),
    ]
)
