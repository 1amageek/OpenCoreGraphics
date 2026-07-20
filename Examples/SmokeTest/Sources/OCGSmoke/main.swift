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
nonisolated(unsafe) var maskPixelData: Data?
nonisolated(unsafe) var patternPixelData: Data?
nonisolated(unsafe) var maskedImagePixelData: Data?
nonisolated(unsafe) var mixedDrawingPixelData: Data?
nonisolated(unsafe) var imageShadowPixelData: Data?

@_cdecl("setup")
public func setup() {
    WasmTestingReactor.boot(
        touchGlobals: {
            statusText = "initializing"
            pixelData = nil
            imageWidth = 0
            imageHeight = 0
            maskPixelData = nil
            patternPixelData = nil
            maskedImagePixelData = nil
            mixedDrawingPixelData = nil
            imageShadowPixelData = nil
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

    guard let capturedMask = await captureImageMask(space: space, bitmapInfo: bitmapInfo) else {
        statusText = "error: image-mask capture failed"
        return
    }
    maskPixelData = capturedMask

    guard let capturedPattern = await captureCallbackPattern(space: space, bitmapInfo: bitmapInfo) else {
        statusText = "error: callback-pattern capture failed"
        return
    }
    patternPixelData = capturedPattern

    guard let capturedImage = await captureMaskedImage(space: space, bitmapInfo: bitmapInfo) else {
        statusText = "error: masked-image capture failed"
        return
    }
    maskedImagePixelData = capturedImage

    guard let mixedDrawing = await captureMixedDrawing(space: space, bitmapInfo: bitmapInfo) else {
        statusText = "error: mixed-drawing capture failed"
        return
    }
    mixedDrawingPixelData = mixedDrawing

    guard let imageShadow = await captureImageShadow(space: space, bitmapInfo: bitmapInfo) else {
        statusText = "error: image-shadow capture failed"
        return
    }
    imageShadowPixelData = imageShadow

    statusText = "ready"
    print("OCGSmoke ready: \(image.width)x\(image.height), \(data.count) bytes")
}

@MainActor
private func captureImageMask(space: CGColorSpace, bitmapInfo: CGBitmapInfo) async -> Data? {
    guard let context = CGContext(
        data: nil,
        width: 4,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: bitmapInfo
    ) else {
        return nil
    }

    let maskData = Data([0, 85, 170, 255])
    guard let mask = CGImage(
        maskWidth: 4,
        height: 1,
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        bytesPerRow: 4,
        provider: CGDataProvider(data: maskData),
        decode: nil,
        shouldInterpolate: false
    ) else {
        return nil
    }

    context.clip(to: CGRect(x: 0, y: 0, width: 4, height: 1), mask: mask)
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 4, height: 1))
    return await context.makeImageAsync()?.data
}

@MainActor
private func captureCallbackPattern(space: CGColorSpace, bitmapInfo: CGBitmapInfo) async -> Data? {
    guard let context = CGContext(
        data: nil,
        width: 8,
        height: 2,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: bitmapInfo
    ), let patternSpace = CGColorSpace(patternBaseSpace: nil) else {
        return nil
    }

    var callbacks = CGPatternCallbacks(
        drawPattern: { _, cellContext in
            guard let cellContext = cellContext else { return }
            cellContext.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            cellContext.fill(CGRect(x: 0, y: 0, width: 1, height: 2))
            cellContext.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            cellContext.fill(CGRect(x: 1, y: 0, width: 1, height: 2))
        },
        releaseInfo: nil
    )
    let pattern = withUnsafePointer(to: &callbacks) { pointer in
        CGPattern(
            info: nil,
            bounds: CGRect(x: 0, y: 0, width: 2, height: 2),
            matrix: .identity,
            xStep: 2,
            yStep: 2,
            tiling: .constantSpacing,
            isColored: true,
            callbacks: pointer
        )
    }
    guard let pattern = pattern else { return nil }

    guard let mask = CGImage(
        maskWidth: 8,
        height: 1,
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        bytesPerRow: 8,
        provider: CGDataProvider(data: Data([0, 0, 0, 0, 255, 255, 255, 255])),
        decode: nil,
        shouldInterpolate: false
    ) else {
        return nil
    }

    context.setShouldAntialias(false)
    context.clip(to: CGRect(x: 0, y: 0, width: 8, height: 2), mask: mask)
    context.setFillColorSpace(patternSpace)
    let components: [CGFloat] = [1]
    components.withUnsafeBufferPointer { buffer in
        guard let baseAddress = buffer.baseAddress else { return }
        context.setFillPattern(pattern, colorComponents: baseAddress)
    }
    context.fill(CGRect(x: 0, y: 0, width: 8, height: 2))
    return await context.makeImageAsync()?.data
}

@MainActor
private func captureMaskedImage(space: CGColorSpace, bitmapInfo: CGBitmapInfo) async -> Data? {
    guard let context = CGContext(
        data: nil,
        width: 4,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: bitmapInfo
    ), let source = CGImage(
        width: 2,
        height: 1,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: 8,
        space: space,
        bitmapInfo: bitmapInfo,
        provider: CGDataProvider(data: Data([255, 0, 0, 255, 0, 0, 255, 255])),
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ), let mask = CGImage(
        maskWidth: 4,
        height: 1,
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        bytesPerRow: 4,
        provider: CGDataProvider(data: Data([0, 85, 170, 255])),
        decode: nil,
        shouldInterpolate: false
    ) else {
        return nil
    }

    context.setInterpolationQuality(.none)
    context.clip(to: CGRect(x: 0, y: 0, width: 4, height: 1), mask: mask)
    context.draw(source, in: CGRect(x: 0, y: 0, width: 4, height: 1))
    return await context.makeImageAsync()?.data
}

@MainActor
private func captureMixedDrawing(space: CGColorSpace, bitmapInfo: CGBitmapInfo) async -> Data? {
    guard let context = CGContext(
        data: nil,
        width: 8,
        height: 2,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: bitmapInfo
    ), let source = CGImage(
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: 4,
        space: space,
        bitmapInfo: bitmapInfo,
        provider: CGDataProvider(data: Data([0, 0, 255, 255])),
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ), let patternSpace = CGColorSpace(patternBaseSpace: nil) else {
        return nil
    }

    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 8, height: 2))
    context.setInterpolationQuality(.none)
    context.draw(source, in: CGRect(x: 2, y: 0, width: 2, height: 2))

    var callbacks = CGPatternCallbacks(
        drawPattern: { _, cellContext in
            guard let cellContext = cellContext else { return }
            cellContext.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
            cellContext.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        },
        releaseInfo: nil
    )
    let pattern = withUnsafePointer(to: &callbacks) { pointer in
        CGPattern(
            info: nil,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            matrix: .identity,
            xStep: 1,
            yStep: 1,
            tiling: .constantSpacing,
            isColored: true,
            callbacks: pointer
        )
    }
    guard let pattern = pattern else { return nil }

    context.setFillColorSpace(patternSpace)
    let components: [CGFloat] = [1]
    components.withUnsafeBufferPointer { buffer in
        guard let baseAddress = buffer.baseAddress else { return }
        context.setFillPattern(pattern, colorComponents: baseAddress)
    }
    context.fill(CGRect(x: 4, y: 0, width: 4, height: 2))
    return await context.makeImageAsync()?.data
}

@MainActor
private func captureImageShadow(space: CGColorSpace, bitmapInfo: CGBitmapInfo) async -> Data? {
    guard let context = CGContext(
        data: nil,
        width: 8,
        height: 2,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: bitmapInfo
    ), let source = CGImage(
        width: 2,
        height: 1,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: 8,
        space: space,
        bitmapInfo: bitmapInfo,
        provider: CGDataProvider(data: Data([255, 255, 255, 255, 0, 0, 0, 0])),
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ) else {
        return nil
    }

    context.setShouldAntialias(false)
    context.setInterpolationQuality(.none)
    context.setShadow(offset: CGSize(width: 4, height: 0), blur: 0, color: .black)
    context.draw(source, in: CGRect(x: 0, y: 0, width: 4, height: 2))
    return await context.makeImageAsync()?.data
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
        try #require(maskPixelData != nil, "maskPixelData is nil after capture")
        try #require(patternPixelData != nil, "patternPixelData is nil after capture")
        try #require(maskedImagePixelData != nil, "maskedImagePixelData is nil after capture")
        try #require(mixedDrawingPixelData != nil, "mixedDrawingPixelData is nil after capture")
        try #require(imageShadowPixelData != nil, "imageShadowPixelData is nil after capture")
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

    @Test func imageMaskUsesContinuousInverseAlpha() throws {
        let data = try #require(maskPixelData)
        let alpha = stride(from: 3, to: data.count, by: 4).map { data[$0] }
        #expect(alpha.count == 4)
        #expect(absDiff(alpha[0], 255) <= 3)
        #expect(absDiff(alpha[1], 170) <= 3)
        #expect(absDiff(alpha[2], 85) <= 3)
        #expect(absDiff(alpha[3], 0) <= 3)
    }

    @Test func callbackPatternUsesRenderedCellColors() throws {
        let data = try #require(patternPixelData)
        var red = 0
        var blue = 0
        var offset = 0
        while offset + 3 < data.count {
            if data[offset] > 240, data[offset + 1] < 12, data[offset + 2] < 12 {
                red += 1
            }
            if data[offset] < 12, data[offset + 1] < 12, data[offset + 2] > 240 {
                blue += 1
            }
            offset += 4
        }
        #expect(red >= 4, "callback red pixels (got \(red))")
        #expect(blue >= 2, "callback blue pixels (got \(blue))")
        let transparent = stride(from: 3, to: data.count, by: 4).filter { data[$0] < 3 }.count
        #expect(transparent >= 8, "pattern mask transparent pixels (got \(transparent))")
    }

    @Test func imageDrawingUsesImageMaskCoverage() throws {
        let data = try #require(maskedImagePixelData)
        let alpha = stride(from: 3, to: data.count, by: 4).map { data[$0] }
        #expect(alpha.count == 4)
        #expect(absDiff(alpha[0], 255) <= 3)
        #expect(absDiff(alpha[1], 170) <= 3)
        #expect(absDiff(alpha[2], 85) <= 3)
        #expect(absDiff(alpha[3], 0) <= 3)
    }

    @Test func antialiasedPathsImagesAndPatternsPreserveDrawingOrder() throws {
        let data = try #require(mixedDrawingPixelData)
        var red = 0
        var green = 0
        var blue = 0
        var offset = 0
        while offset + 3 < data.count {
            let r = data[offset]
            let g = data[offset + 1]
            let b = data[offset + 2]
            if r > 240, g < 12, b < 12 { red += 1 }
            if r < 12, g > 240, b < 12 { green += 1 }
            if r < 12, g < 12, b > 240 { blue += 1 }
            offset += 4
        }
        #expect(red >= 4, "mixed red pixels (got \(red))")
        #expect(green >= 6, "mixed green pixels (got \(green))")
        #expect(blue >= 2, "mixed blue pixels (got \(blue))")
    }

    @Test func imageShadowUsesSourceAlphaInsteadOfImageBounds() throws {
        let data = try #require(imageShadowPixelData)
        let bytesPerRow = data.count / 2
        let opaqueShadowOffset = 4 * 4
        let transparentShadowOffset = 6 * 4
        for row in 0..<2 {
            let opaque = row * bytesPerRow + opaqueShadowOffset
            let transparent = row * bytesPerRow + transparentShadowOffset
            #expect(data[opaque] < 8)
            #expect(data[opaque + 1] < 8)
            #expect(data[opaque + 2] < 8)
            #expect(data[opaque + 3] > 247)
            #expect(data[transparent + 3] < 8)
        }
    }
}
