// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-unidirectional-flow",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .watchOS(.v10)],
    products: [
        .library(
            name: "UnidirectionalFlow",
            targets: ["UnidirectionalFlow"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "UnidirectionalFlow",
            dependencies: [],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "UnidirectionalFlowTests",
            dependencies: ["UnidirectionalFlow"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .target(
            name: "Example",
            dependencies: ["UnidirectionalFlow"]
        )
    ]
)
