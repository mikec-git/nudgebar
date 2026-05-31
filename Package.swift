// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Nudgebar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Nudgebar", targets: ["Nudgebar"])
    ],
    targets: [
        .executableTarget(
            name: "Nudgebar"
        ),
        .testTarget(
            name: "NudgebarTests",
            dependencies: ["Nudgebar"]
        )
    ]
)
