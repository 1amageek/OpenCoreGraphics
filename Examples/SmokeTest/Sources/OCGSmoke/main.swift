// OpenCoreGraphics WASM browser tests, authored as Swift Testing `@Test`
// functions that run inside headless Chromium via BrowserTestRunner.
//
// Boot flow (reactor-ABI):
//   1. `setup()` is exported to JS via `@_cdecl` + `--export=setup`.
//   2. `WasmTestingReactor.boot` installs the JavaScriptKit executor and
//      touches module-scope globals to avoid the reactor-ABI global-init
//      race (see MEMORY + ReactorBoot.swift for background).
//   3. `performSetup()` initialises WebGPU via `setupGraphicsContext()`,
//      creates a 64x64 CGContext, paints a known 3-colour pattern, and
//      performs GPU readback via `makeImageAsync()`.
//   4. `BrowserTestRunner.run()` spawns the Swift Testing ABI v0 entry
//      point. Each `@Test` function below references the captured pixel
//      buffer and asserts against it.

import Foundation
import Testing
import WasmTesting
import OpenCoreGraphics

// MARK: - Captured result (populated by performSetup)

nonisolated(unsafe) var statusText: String = "initializing"
nonisolated(unsafe) var pixelData: Data?
nonisolated(unsafe) var imageWidth: Int = 0
nonisolated(unsafe) var imageHeight: Int = 0

@_cdecl("setup")
public func setup() {
    WasmTestingReactor.boot(
        touchGlobals: {
            statusText = "initializing"
            pixelData = nil
            imageWidth = 0
            imageHeight = 0
        },
        then: {
            await performSetup()
            BrowserTestRunner.run()
        }
    )
}

@MainActor
func performSetup() async {
    do {
        try await setupGraphicsContext()
    } catch {
        statusText = "error: setupGraphicsContext failed: \(error)"
        return
    }

    guard let space = CGColorSpace(name: CGColorSpace.sRGB) else {
        statusText = "error: sRGB color space unavailable"
        return
    }
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let ctx = CGContext(
        data: nil,
        width: 64,
        height: 64,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: bitmapInfo
    ) else {
        statusText = "error: CGContext init returned nil"
        return
    }

    // Fill the whole canvas red, then punch a 16x16 green rect at (0, 0)
    // and a 16x16 blue rect at (48, 48). The three colors are well separated
    // in RGB space so a tolerance-based count is unambiguous regardless of
    // readback orientation.
    ctx.setFillColor(CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0))
    ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))

    ctx.setFillColor(CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))
    ctx.fill(CGRect(x: 0, y: 0, width: 16, height: 16))

    ctx.setFillColor(CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0))
    ctx.fill(CGRect(x: 48, y: 48, width: 16, height: 16))

    guard let image = await ctx.makeImageAsync() else {
        statusText = "error: makeImageAsync returned nil"
        return
    }
    guard let data = image.data else {
        statusText = "error: CGImage has no pixel data"
        return
    }

    pixelData = data
    imageWidth = image.width
    imageHeight = image.height
    statusText = "ready"
    print("OCGSmoke ready: \(image.width)x\(image.height), \(data.count) bytes")
}

@inline(__always)
private func absDiff(_ a: UInt8, _ b: UInt8) -> UInt8 {
    return a >= b ? a - b : b - a
}

// Counts pixels whose RGB channels are all within `tolerance` of (r, g, b).
// Alpha is ignored. Tolerance absorbs sRGB round-trip and minor compositor
// drift while still rejecting wrong-channel-order regressions.
private func countColor(r: UInt8, g: UInt8, b: UInt8, tolerance: UInt8) -> Int {
    guard let data = pixelData else { return 0 }
    var count = 0
    var i = 0
    while i + 3 < data.count {
        let dr = absDiff(data[i], r)
        let dg = absDiff(data[i + 1], g)
        let db = absDiff(data[i + 2], b)
        if dr <= tolerance, dg <= tolerance, db <= tolerance {
            count += 1
        }
        i += 4
    }
    return count
}

// MARK: - Tests
//
// These tests read `pixelData` / `imageWidth` / `imageHeight` captured by
// `performSetup()`. The pipeline is write-once (no test mutates them), but
// we still use `@Suite(.serialized)` so that a future mutation test would
// not race against the readback assertions. See memory:
// feedback_wasm_testing_serialized_suite.md

@Suite(.serialized)
struct OCGSmokeTests {

    @Test func captureSucceeded() throws {
        try #require(
            statusText == "ready",
            "performSetup did not complete cleanly: \(statusText)"
        )
        try #require(pixelData != nil, "pixelData is nil after capture")
    }

    @Test func imageHasExpectedDimensions() {
        #expect(imageWidth == 64)
        #expect(imageHeight == 64)
        // RGBA × 64 × 64 = 16384. The buffer may carry row padding; accept
        // any value ≥ that count.
        let byteLength = pixelData?.count ?? 0
        #expect(
            byteLength >= 64 * 64 * 4,
            "pixel buffer too small (got \(byteLength) bytes)"
        )
    }

    @Test func readbackContainsDrawnColors() {
        // The background fill covers the canvas except for two 16×16 rects,
        // i.e. 64*64 − 2*(16*16) = 3584 red pixels. Tolerate half of that
        // floor so anti-aliasing / minor blending at rect edges can't cause
        // flaky runs.
        let red = countColor(r: 255, g: 0, b: 0, tolerance: 12)
        let green = countColor(r: 0, g: 255, b: 0, tolerance: 12)
        let blue = countColor(r: 0, g: 0, b: 255, tolerance: 12)
        #expect(red > 1000, "red pixels (got \(red))")
        #expect(green > 100, "green pixels (got \(green))")
        #expect(blue > 100, "blue pixels (got \(blue))")
    }
}
