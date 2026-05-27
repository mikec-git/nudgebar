// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AlertBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AlertBar", targets: ["AlertBar"])
    ],
    targets: [
        .executableTarget(
            name: "AlertBar"
        ),
        .testTarget(
            name: "AlertBarTests",
            dependencies: ["AlertBar"]
        )
    ]
)
