// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-unidirectional-flow",
    platforms: [.iOS("17"), .macOS("14"), .tvOS("17"), .watchOS("10")],
    products: [
        .library(
            name: "UnidirectionalFlow",
            targets: ["UnidirectionalFlow"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "UnidirectionalFlow",
            dependencies: []),
        .testTarget(
            name: "UnidirectionalFlowTests",
            dependencies: ["UnidirectionalFlow"]),
        .target(name: "Example", dependencies: ["UnidirectionalFlow"])
    ]
)
