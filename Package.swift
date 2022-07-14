// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-unidirectional-flow",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
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
            dependencies: ["UnidirectionalFlow"])
    ]
)
