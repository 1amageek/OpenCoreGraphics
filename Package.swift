// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenCoreGraphics",
    products: [
        .library(
            name: "OpenCoreGraphics",
            targets: ["OpenCoreGraphics"]
        ),
    ],
    targets: [
        // Protocol conformances and extensions for geometry types
        .target(
            name: "CGExtensions"
        ),
        // Main target with CoreGraphics-compatible types
        .target(
            name: "OpenCoreGraphics",
            dependencies: ["CGExtensions"]
        ),
        .testTarget(
            name: "OpenCoreGraphicsTests",
            dependencies: ["OpenCoreGraphics"]
        ),
    ]
)
