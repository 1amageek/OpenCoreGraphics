// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenCoreGraphics",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "OpenCoreGraphics",
            targets: ["OpenCoreGraphics"]
        ),
        .library(
            name: "CGWebGPU",
            targets: ["CGWebGPU"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/1amageek/swift-webgpu.git", branch: "main"),
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
        // WebGPU rendering bridge (WASM only)
        .target(
            name: "CGWebGPU",
            dependencies: [
                "OpenCoreGraphics",
                .product(name: "SwiftWebGPU", package: "swift-webgpu"),
            ]
        ),
        .testTarget(
            name: "OpenCoreGraphicsTests",
            dependencies: ["OpenCoreGraphics"]
        ),
    ]
)
