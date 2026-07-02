// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "NextMeet",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NextMeet", targets: ["NextMeet"])
    ],
    targets: [
        .executableTarget(
            name: "NextMeet",
            linkerSettings: [
                .linkedFramework("EventKit"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
