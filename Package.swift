// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-unidirectional-flow",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)],
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
            dependencies: []
        ),
        .testTarget(
            name: "UnidirectionalFlowTests",
            dependencies: ["UnidirectionalFlow"]
        ),
        .target(
            name: "Example",
            dependencies: ["UnidirectionalFlow"]
        )
    ]
)
