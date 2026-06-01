// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Nudgebar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Nudgebar", targets: ["Nudgebar"]),
        .library(name: "NudgebarCore", targets: ["NudgebarCore"]),
        .library(name: "NudgebarProviders", targets: ["NudgebarProviders"]),
        .library(name: "NudgebarAuth", targets: ["NudgebarAuth"]),
        .library(name: "NudgebarPersistence", targets: ["NudgebarPersistence"]),
        .library(name: "NudgebarMacOSSupport", targets: ["NudgebarMacOSSupport"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NudgebarCore"
        ),
        .target(
            name: "NudgebarAuth",
            dependencies: ["NudgebarCore"],
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .target(
            name: "NudgebarPersistence",
            dependencies: ["NudgebarCore"]
        ),
        .target(
            name: "NudgebarProviders",
            dependencies: ["NudgebarAuth", "NudgebarCore"]
        ),
        .target(
            name: "NudgebarMacOSSupport",
            dependencies: [
                "NudgebarCore",
                "NudgebarPersistence",
                "NudgebarProviders"
            ],
            linkerSettings: [
                .linkedFramework("EventKit"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .executableTarget(
            name: "Nudgebar",
            dependencies: [
                "NudgebarAuth",
                "NudgebarCore",
                "NudgebarMacOSSupport",
                "NudgebarPersistence",
                "NudgebarProviders"
            ]
        ),
        .testTarget(
            name: "NudgebarCoreTests",
            dependencies: ["NudgebarCore"]
        ),
        .testTarget(
            name: "NudgebarProvidersTests",
            dependencies: ["NudgebarProviders"]
        ),
        .testTarget(
            name: "NudgebarAuthTests",
            dependencies: ["NudgebarAuth"]
        ),
        .testTarget(
            name: "NudgebarPersistenceTests",
            dependencies: ["NudgebarPersistence"]
        ),
        .testTarget(
            name: "NudgebarWorkflowTests",
            dependencies: [
                "NudgebarCore",
                "NudgebarPersistence",
                "NudgebarProviders"
            ]
        ),
        .testTarget(
            name: "NudgebarTests",
            dependencies: ["Nudgebar", "NudgebarCore", "NudgebarProviders", "NudgebarAuth"]
        )
    ],
    swiftLanguageModes: [.v5]
)
