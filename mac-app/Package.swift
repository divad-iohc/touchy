// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Touchy",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "Touchy",
            targets: ["Touchy"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "Touchy",
            path: "Sources/Touchy"
        ),
    ]
)
