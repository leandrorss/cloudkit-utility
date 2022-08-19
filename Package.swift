// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CloudKitUtility",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "CloudKitUtility", targets: ["CloudKitUtility"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CloudKitUtility",
            dependencies: []),
        .testTarget(
            name: "CloudKitUtilityTests",
            dependencies: ["CloudKitUtility"]),
    ]
)
