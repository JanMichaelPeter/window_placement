// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "window_placement",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "window-placement", targets: ["window_placement"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "window_placement",
            dependencies: [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
