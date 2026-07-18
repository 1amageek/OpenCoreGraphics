// swift-tools-version: 6.0
//
// OpenCoreGraphics WASM smoke-test executable. Built with the same toolchain
// and runtime layout as megaman (`swift-wasmport`) so Playwright can exercise
// the CGContext → WebGPU pipeline in headless Chromium.
//
// Builds with:
//   swift build --product OCGSmoke --swift-sdk swift-6.3.1-RELEASE_wasm -c release
// then copy .build/wasm32-unknown-wasip1/release/OCGSmoke.wasm into
// tests/e2e/.build/wasm/ where server.mjs serves it.

import PackageDescription

let package = Package(
    name: "OCGSmoke",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/1amageek/swift-wasm-testing", branch: "main"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.53.0"),
    ],
    targets: [
        .executableTarget(
            name: "OCGSmoke",
            dependencies: [
                .product(name: "OpenCoreGraphics", package: "OpenCoreGraphics"),
                .product(name: "WasmTesting", package: "swift-wasm-testing"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    // JavaScriptKit only binds against WASI-reactor modules.
                    // Encode the flag here so plain `swift build` produces a
                    // JavaScriptKit-compatible artifact (the CLI wrapper is
                    // not in the loop for this target).
                    "-Xclang-linker", "-mexec-model=reactor",
                    "-Xlinker", "--export=setup",
                ])
            ]
        ),
    ]
)
