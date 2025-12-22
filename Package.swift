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
    ],
    dependencies: [
        // SwiftWebGPU is only used on WASM builds
        .package(url: "https://github.com/1amageek/swift-webgpu", branch: "main"),
    ],
    targets: [
        // Main target with CoreGraphics-compatible types
        // On WASM, includes WebGPU rendering via Rendering/WebGPU/
        .target(
            name: "OpenCoreGraphics",
            dependencies: [
                // SwiftWebGPU is only linked on WASM
                .product(name: "SwiftWebGPU", package: "swift-webgpu", condition: .when(platforms: [.wasi])),
            ]
        ),
        .testTarget(
            name: "OpenCoreGraphicsTests",
            dependencies: ["OpenCoreGraphics"]
        ),
    ]
)
