//
//  CGColorTests.swift
//  OpenCoreGraphics
//
//  Tests for CGColor type
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = Foundation.CGFloat
private typealias CGColor = OpenCoreGraphics.CGColor
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace
private typealias CGColorRenderingIntent = OpenCoreGraphics.CGColorRenderingIntent

@Suite("CGColor Tests")
struct CGColorTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Init with gray and alpha")
        func initWithGray() {
            let color = CGColor(gray: 0.5, alpha: 1.0)
            #expect(color.numberOfComponents == 2)
            #expect(color.components?[0] == 0.5)
            #expect(color.components?[1] == 1.0)
            #expect(color.colorSpace?.model == .monochrome)
        }

        @Test("Init with RGB")
        func initWithRGB() {
            let color = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            #expect(color.numberOfComponents == 4)
            #expect(color.components?[0] == 1.0)
            #expect(color.components?[1] == 0.5)
            #expect(color.components?[2] == 0.25)
            #expect(color.components?[3] == 1.0)
            #expect(color.colorSpace?.model == .rgb)
        }

        @Test("Init with sRGB")
        func initWithSRGB() {
            let color = CGColor(srgbRed: 1.0, green: 0.5, blue: 0.25, alpha: 0.8)
            #expect(color.numberOfComponents == 4)
            #expect(color.components?[0] == 1.0)
            #expect(color.components?[1] == 0.5)
            #expect(color.components?[2] == 0.25)
            #expect(color.components?[3] == 0.8)
        }

        @Test("Init with CMYK")
        func initWithCMYK() {
            let color = CGColor(genericCMYKCyan: 0.2, magenta: 0.4, yellow: 0.6, black: 0.1, alpha: 1.0)
            #expect(color.numberOfComponents == 5)
            #expect(color.components?[0] == 0.2)
            #expect(color.components?[1] == 0.4)
            #expect(color.components?[2] == 0.6)
            #expect(color.components?[3] == 0.1)
            #expect(color.components?[4] == 1.0)
            #expect(color.colorSpace?.model == .cmyk)
        }

        @Test("Init with generic gray gamma 2.2")
        func initWithGenericGray() {
            let color = CGColor(genericGrayGamma2_2Gray: 0.7, alpha: 0.9)
            #expect(color.numberOfComponents == 2)
            #expect(color.components?[0] == 0.7)
            #expect(color.components?[1] == 0.9)
        }

        @Test("Init with color space and components")
        func initWithColorSpaceAndComponents() {
            let colorSpace = CGColorSpace.deviceRGB
            let components: [CGFloat] = [1.0, 0.5, 0.25, 0.8]
            let color = components.withUnsafeBufferPointer { buffer in
                CGColor(colorSpace: colorSpace, components: buffer.baseAddress!)
            }
            #expect(color != nil)
            #expect(color?.numberOfComponents == 4)
            #expect(color?.components?[0] == 1.0)
            #expect(color?.alpha == 0.8)
        }
    }

    // MARK: - Static Properties Tests

    @Suite("Static Colors")
    struct StaticColorsTests {

        @Test("Black color")
        func blackColor() {
            let black = CGColor.black
            #expect(black.colorSpace?.model == .monochrome)
            #expect(black.components?[0] == 0.0)
            #expect(black.alpha == 1.0)
        }

        @Test("White color")
        func whiteColor() {
            let white = CGColor.white
            #expect(white.colorSpace?.model == .monochrome)
            #expect(white.components?[0] == 1.0)
            #expect(white.alpha == 1.0)
        }

        @Test("Clear color")
        func clearColor() {
            let clear = CGColor.clear
            #expect(clear.colorSpace?.model == .monochrome)
            #expect(clear.components?[0] == 0.0)
            #expect(clear.alpha == 0.0)
        }
    }

    // MARK: - Properties Tests

    @Suite("Properties")
    struct PropertiesTests {

        @Test("Alpha property for RGB")
        func alphaRGB() {
            let color = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 0.8)
            #expect(color.alpha == 0.8)
        }

        @Test("Alpha property for gray")
        func alphaGray() {
            let color = CGColor(gray: 0.5, alpha: 0.7)
            #expect(color.alpha == 0.7)
        }

        @Test("Number of components for RGB")
        func numberOfComponentsRGB() {
            let color = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            #expect(color.numberOfComponents == 4)
        }

        @Test("Number of components for gray")
        func numberOfComponentsGray() {
            let color = CGColor(gray: 0.5, alpha: 1.0)
            #expect(color.numberOfComponents == 2)
        }

        @Test("Number of components for CMYK")
        func numberOfComponentsCMYK() {
            let color = CGColor(genericCMYKCyan: 0.2, magenta: 0.4, yellow: 0.6, black: 0.1, alpha: 1.0)
            #expect(color.numberOfComponents == 5)
        }

        @Test("Color space property")
        func colorSpaceProperty() {
            let rgbColor = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            let grayColor = CGColor(gray: 0.5, alpha: 1.0)

            #expect(rgbColor.colorSpace?.model == .rgb)
            #expect(grayColor.colorSpace?.model == .monochrome)
        }
    }

    // MARK: - Copy Tests

    @Suite("Copy Operations")
    struct CopyTests {

        @Test("Copy color")
        func copyColor() {
            let original = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 0.8)
            let copy = original.copy()
            #expect(copy != nil)
            #expect(copy == original)
        }

        @Test("Copy with new alpha")
        func copyWithAlpha() {
            let original = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            let copy = original.copy(alpha: 0.5)
            #expect(copy != nil)
            #expect(copy?.alpha == 0.5)
            #expect(copy?.components?[0] == 1.0) // Red unchanged
            #expect(copy?.components?[1] == 0.5) // Green unchanged
            #expect(copy?.components?[2] == 0.25) // Blue unchanged
        }

        @Test("Copy preserves color space")
        func copyPreservesColorSpace() {
            let original = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            let copy = original.copy()
            #expect(copy?.colorSpace == original.colorSpace)
        }
    }

    // MARK: - Conversion Tests

    @Suite("Color Conversion")
    struct ConversionTests {

        @Test("Convert to same color space")
        func convertToSameColorSpace() {
            let color = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            let colorSpace = CGColorSpace.deviceRGB
            let converted = color.converted(to: colorSpace, intent: .defaultIntent, options: nil)
            #expect(converted != nil)
            #expect(converted?.components?[0] == 1.0)
            #expect(converted?.components?[1] == 0.5)
            #expect(converted?.components?[2] == 0.25)
        }

        @Test("Convert gray to RGB")
        func convertGrayToRGB() {
            let grayColor = CGColor(gray: 0.5, alpha: 1.0)
            let rgbColorSpace = CGColorSpace.deviceRGB
            let converted = grayColor.converted(to: rgbColorSpace, intent: .defaultIntent, options: nil)
            #expect(converted != nil)
            #expect(converted?.numberOfComponents == 4)
            #expect(converted?.components?[0] == 0.5) // R
            #expect(converted?.components?[1] == 0.5) // G
            #expect(converted?.components?[2] == 0.5) // B
            #expect(converted?.components?[3] == 1.0) // A
        }

        @Test("Convert RGB to gray")
        func convertRGBToGray() {
            let rgbColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            let grayColorSpace = CGColorSpace.deviceGray
            let converted = rgbColor.converted(to: grayColorSpace, intent: .defaultIntent, options: nil)
            #expect(converted != nil)
            #expect(converted?.numberOfComponents == 2)
            // White RGB should convert to white gray
            #expect(converted?.components?[0] ?? 0 > 0.9)
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Equal colors")
        func equalColors() {
            let c1 = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            let c2 = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            #expect(c1 == c2)
        }

        @Test("Unequal colors different components")
        func unequalColorsDifferentComponents() {
            let c1 = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            let c2 = CGColor(red: 0.5, green: 0.5, blue: 0.25, alpha: 1.0)
            #expect(c1 != c2)
        }

        @Test("Unequal colors different alpha")
        func unequalColorsDifferentAlpha() {
            let c1 = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            let c2 = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 0.5)
            #expect(c1 != c2)
        }

        @Test("Unequal colors different color space")
        func unequalColorsDifferentColorSpace() {
            let rgbColor = CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
            let grayColor = CGColor(gray: 0.5, alpha: 1.0)
            #expect(rgbColor != grayColor)
        }

        @Test("Static colors equality")
        func staticColorsEquality() {
            let black1 = CGColor.black
            let black2 = CGColor(gray: 0.0, alpha: 1.0)
            #expect(black1 == black2)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Equal colors have equal hashes")
        func equalColorsEqualHashes() {
            let c1 = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            let c2 = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            #expect(c1.hashValue == c2.hashValue)
        }

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGColor>()
            set.insert(CGColor.black)
            set.insert(CGColor.white)
            set.insert(CGColor(gray: 0.0, alpha: 1.0)) // Same as black
            #expect(set.count == 2)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        @Test("Zero alpha")
        func zeroAlpha() {
            let color = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 0.0)
            #expect(color.alpha == 0.0)
        }

        @Test("Full alpha")
        func fullAlpha() {
            let color = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            #expect(color.alpha == 1.0)
        }

        @Test("Component values at boundaries")
        func componentBoundaries() {
            let minColor = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            let maxColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            #expect(minColor.components?[0] == 0.0)
            #expect(maxColor.components?[0] == 1.0)
        }

        @Test("Very small component values")
        func verySmallComponents() {
            let color = CGColor(red: 0.001, green: 0.001, blue: 0.001, alpha: 1.0)
            #expect(color.components?[0] == 0.001)
        }
    }

    // MARK: - Color Conversion Logic Tests

    @Suite("Color Conversion Logic")
    struct ColorConversionLogicTests {

        private func isApproximatelyEqual(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
            return abs(a - b) < tolerance
        }

        @Test("Gray to RGB conversion produces equal R, G, B components")
        func grayToRGBEqualComponents() {
            let grayValues: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]

            for gray in grayValues {
                let grayColor = CGColor(gray: gray, alpha: 1.0)
                let converted = grayColor.converted(to: .deviceRGB, intent: .defaultIntent, options: nil)

                guard let c = converted else {
                    #expect(Bool(false), "Conversion failed for gray=\(gray)")
                    continue
                }

                let r = c.components?[0] ?? -1
                let g = c.components?[1] ?? -1
                let b = c.components?[2] ?? -1

                // For gray, R = G = B = gray value
                #expect(isApproximatelyEqual(r, g), "R(\(r)) should equal G(\(g)) for gray=\(gray)")
                #expect(isApproximatelyEqual(g, b), "G(\(g)) should equal B(\(b)) for gray=\(gray)")
                #expect(isApproximatelyEqual(r, gray), "R(\(r)) should equal gray(\(gray))")
            }
        }

        @Test("White RGB to gray conversion produces white gray")
        func whiteRGBToGray() {
            let white = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            let converted = white.converted(to: .deviceGray, intent: .defaultIntent, options: nil)

            #expect(converted != nil)
            #expect(isApproximatelyEqual(converted?.components?[0] ?? 0, 1.0),
                   "White RGB should convert to white gray")
        }

        @Test("Black RGB to gray conversion produces black gray")
        func blackRGBToGray() {
            let black = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
            let converted = black.converted(to: .deviceGray, intent: .defaultIntent, options: nil)

            #expect(converted != nil)
            #expect(isApproximatelyEqual(converted?.components?[0] ?? 1, 0.0),
                   "Black RGB should convert to black gray")
        }

        @Test("Alpha value preserved during conversion")
        func alphaPreservedDuringConversion() {
            let alphaValues: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]

            for alpha in alphaValues {
                let color = CGColor(red: 0.5, green: 0.3, blue: 0.7, alpha: alpha)
                let converted = color.converted(to: .deviceGray, intent: .defaultIntent, options: nil)

                #expect(converted?.alpha == alpha,
                       "Alpha \(alpha) should be preserved after conversion, got \(converted?.alpha ?? -1)")
            }
        }

        @Test("Copy with alpha creates independent color")
        func copyWithAlphaIndependent() {
            let original = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            let copy = original.copy(alpha: 0.3)

            // Original should be unchanged
            #expect(original.alpha == 1.0)

            // Copy should have new alpha
            #expect(copy?.alpha == 0.3)

            // Color components should be the same
            #expect(copy?.components?[0] == 1.0)
            #expect(copy?.components?[1] == 0.5)
            #expect(copy?.components?[2] == 0.25)
        }

        @Test("Copy with same alpha produces equal color")
        func copyWithSameAlphaEqual() {
            let original = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 0.8)
            let copy = original.copy(alpha: 0.8)

            #expect(copy == original)
        }

        @Test("Conversion round trip gray -> RGB -> gray")
        func conversionRoundTripGray() {
            let grayValues: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]

            for gray in grayValues {
                let original = CGColor(gray: gray, alpha: 1.0)
                let rgb = original.converted(to: .deviceRGB, intent: .defaultIntent, options: nil)
                let backToGray = rgb?.converted(to: .deviceGray, intent: .defaultIntent, options: nil)

                #expect(backToGray != nil)
                #expect(isApproximatelyEqual(backToGray?.components?[0] ?? -1, gray),
                       "Round trip for gray=\(gray) failed: got \(backToGray?.components?[0] ?? -1)")
            }
        }

        @Test("Mid-gray RGB converts to approximately 0.5 gray")
        func midGrayRGBToGray() {
            // Mid gray RGB (0.5, 0.5, 0.5) should convert to approximately 0.5 gray
            let midGray = CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
            let converted = midGray.converted(to: .deviceGray, intent: .defaultIntent, options: nil)

            #expect(converted != nil)
            #expect(isApproximatelyEqual(converted?.components?[0] ?? 0, 0.5))
        }

        @Test("Color conversion preserves number of components for same model")
        func conversionPreservesComponentsCount() {
            let rgb1 = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            let converted = rgb1.converted(to: .deviceRGB, intent: .defaultIntent, options: nil)

            #expect(converted?.numberOfComponents == rgb1.numberOfComponents)
        }

        @Test("CMYK color can be created")
        func cmykColorCreation() {
            // Verify CMYK color can be created and has correct properties
            let cyan = CGColor(genericCMYKCyan: 1.0, magenta: 0.0, yellow: 0.0, black: 0.0, alpha: 1.0)

            #expect(cyan.numberOfComponents == 5)  // C, M, Y, K, Alpha
            #expect(cyan.colorSpace?.model == .cmyk)
            #expect(cyan.components?[0] == 1.0)  // Cyan
            #expect(cyan.components?[1] == 0.0)  // Magenta
            #expect(cyan.components?[2] == 0.0)  // Yellow
            #expect(cyan.components?[3] == 0.0)  // Black
            #expect(cyan.alpha == 1.0)
        }

        @Test("All rendering intents work without crash")
        func allRenderingIntentsWork() {
            let color = CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
            let intents: [CGColorRenderingIntent] = [
                .defaultIntent,
                .absoluteColorimetric,
                .relativeColorimetric,
                .perceptual,
                .saturation
            ]

            for intent in intents {
                let converted = color.converted(to: .deviceGray, intent: intent, options: nil)
                #expect(converted != nil, "Conversion with intent \(intent) should succeed")
            }
        }

        @Test("Component values are clamped to 0-1 range after conversion")
        func componentsClamped() {
            let color = CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
            let converted = color.converted(to: .deviceGray, intent: .defaultIntent, options: nil)

            if let gray = converted?.components?[0] {
                #expect(gray >= 0.0 && gray <= 1.0,
                       "Gray component should be in 0-1 range, got \(gray)")
            }
        }
    }

    // MARK: - Sendable Conformance Tests

    @Suite("Sendable Conformance")
    struct SendableTests {

        @Test("CGColor can be sent across actor boundaries")
        func sendableConformance() async {
            let color = CGColor(red: 1.0, green: 0.5, blue: 0.25, alpha: 1.0)
            let result = await Task {
                return color.alpha
            }.value
            #expect(result == 1.0)
        }
    }

    // MARK: - Extended Color Conversion Tests

    @Suite("Extended Color Conversion")
    struct ExtendedColorConversionTests {

        private func isApproximatelyEqual(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 0.05) -> Bool {
            return abs(a - b) < tolerance
        }

        // MARK: - CMYK Conversion Tests

        @Test("RGB to CMYK conversion - pure red")
        func rgbToCmykPureRed() {
            let red = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            guard let cmykSpace = CGColorSpace(name: CGColorSpace.genericCMYK) else {
                #expect(Bool(false), "Failed to create CMYK color space")
                return
            }
            let converted = red.converted(to: cmykSpace, intent: .defaultIntent, options: nil)

            #expect(converted != nil)
            #expect(converted?.numberOfComponents == 5) // C, M, Y, K, Alpha

            // Pure red in CMYK should be 0% cyan, 100% magenta, 100% yellow, 0% black
            if let c = converted?.components {
                #expect(isApproximatelyEqual(c[0], 0.0), "Cyan should be ~0")
                #expect(isApproximatelyEqual(c[1], 1.0), "Magenta should be ~1")
                #expect(isApproximatelyEqual(c[2], 1.0), "Yellow should be ~1")
                #expect(isApproximatelyEqual(c[3], 0.0), "Black should be ~0")
            }
        }

        @Test("RGB to CMYK conversion - pure black")
        func rgbToCmykPureBlack() {
            let black = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
            guard let cmykSpace = CGColorSpace(name: CGColorSpace.genericCMYK) else {
                #expect(Bool(false), "Failed to create CMYK color space")
                return
            }
            let converted = black.converted(to: cmykSpace, intent: .defaultIntent, options: nil)

            #expect(converted != nil)
            // Pure black should be 0, 0, 0, 1 in CMYK (all in K channel)
            if let c = converted?.components {
                #expect(isApproximatelyEqual(c[0], 0.0), "Cyan should be 0")
                #expect(isApproximatelyEqual(c[1], 0.0), "Magenta should be 0")
                #expect(isApproximatelyEqual(c[2], 0.0), "Yellow should be 0")
                #expect(isApproximatelyEqual(c[3], 1.0), "Black should be 1")
            }
        }

        @Test("CMYK to RGB conversion - pure cyan")
        func cmykToRgbPureCyan() {
            let cyan = CGColor(genericCMYKCyan: 1.0, magenta: 0.0, yellow: 0.0, black: 0.0, alpha: 1.0)
            let converted = cyan.converted(to: .deviceRGB, intent: .defaultIntent, options: nil)

            #expect(converted != nil)
            // Pure cyan should be R=0, G=1, B=1
            if let c = converted?.components {
                #expect(isApproximatelyEqual(c[0], 0.0), "Red should be ~0")
                #expect(isApproximatelyEqual(c[1], 1.0), "Green should be ~1")
                #expect(isApproximatelyEqual(c[2], 1.0), "Blue should be ~1")
            }
        }

        @Test("CMYK to RGB round trip preserves color")
        func cmykToRgbRoundTrip() {
            guard let cmykSpace = CGColorSpace(name: CGColorSpace.genericCMYK) else {
                #expect(Bool(false), "Failed to create CMYK color space")
                return
            }

            let original = CGColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 0.9)
            let cmyk = original.converted(to: cmykSpace, intent: .defaultIntent, options: nil)
            let backToRgb = cmyk?.converted(to: .deviceRGB, intent: .defaultIntent, options: nil)

            #expect(backToRgb != nil)
            if let orig = original.components, let back = backToRgb?.components {
                #expect(isApproximatelyEqual(orig[0], back[0]), "Red should be preserved")
                #expect(isApproximatelyEqual(orig[1], back[1]), "Green should be preserved")
                #expect(isApproximatelyEqual(orig[2], back[2]), "Blue should be preserved")
            }
            #expect(backToRgb?.alpha == 0.9, "Alpha should be preserved")
        }

        @Test("Gray to CMYK conversion")
        func grayToCmyk() {
            let gray = CGColor(gray: 0.5, alpha: 1.0)
            guard let cmykSpace = CGColorSpace(name: CGColorSpace.genericCMYK) else {
                #expect(Bool(false), "Failed to create CMYK color space")
                return
            }
            let converted = gray.converted(to: cmykSpace, intent: .defaultIntent, options: nil)

            #expect(converted != nil)
            // 50% gray should have 50% K channel, no CMY
            if let c = converted?.components {
                #expect(isApproximatelyEqual(c[0], 0.0), "Cyan should be 0")
                #expect(isApproximatelyEqual(c[1], 0.0), "Magenta should be 0")
                #expect(isApproximatelyEqual(c[2], 0.0), "Yellow should be 0")
                #expect(isApproximatelyEqual(c[3], 0.5), "Black should be ~0.5")
            }
        }

        @Test("CMYK to Gray conversion")
        func cmykToGray() {
            let cmyk = CGColor(genericCMYKCyan: 0.0, magenta: 0.0, yellow: 0.0, black: 0.5, alpha: 1.0)
            let converted = cmyk.converted(to: .deviceGray, intent: .defaultIntent, options: nil)

            #expect(converted != nil)
            if let g = converted?.components?[0] {
                #expect(isApproximatelyEqual(g, 0.5), "Gray should be ~0.5 for 50% black")
            }
        }

        // MARK: - Lab Conversion Tests

        @Test("RGB to Lab conversion - white")
        func rgbToLabWhite() {
            let white = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            guard let labSpace = CGColorSpace(name: CGColorSpace.genericLab) else {
                #expect(Bool(false), "Failed to create Lab color space")
                return
            }
            let converted = white.converted(to: labSpace, intent: .defaultIntent, options: nil)

            #expect(converted != nil)
            // White in Lab should be L=100, a≈0, b≈0
            if let c = converted?.components {
                #expect(isApproximatelyEqual(c[0], 100.0, tolerance: 1.0), "L should be ~100 for white")
                #expect(isApproximatelyEqual(c[1], 0.0, tolerance: 1.0), "a should be ~0 for white")
                #expect(isApproximatelyEqual(c[2], 0.0, tolerance: 1.0), "b should be ~0 for white")
            }
        }

        @Test("RGB to Lab conversion - black")
        func rgbToLabBlack() {
            let black = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
            guard let labSpace = CGColorSpace(name: CGColorSpace.genericLab) else {
                #expect(Bool(false), "Failed to create Lab color space")
                return
            }
            let converted = black.converted(to: labSpace, intent: .defaultIntent, options: nil)

            #expect(converted != nil)
            // Black in Lab should be L≈0, a≈0, b≈0
            if let c = converted?.components {
                #expect(isApproximatelyEqual(c[0], 0.0, tolerance: 1.0), "L should be ~0 for black")
            }
        }

        @Test("Lab to RGB round trip preserves color")
        func labToRgbRoundTrip() {
            guard let labSpace = CGColorSpace(name: CGColorSpace.genericLab) else {
                #expect(Bool(false), "Failed to create Lab color space")
                return
            }

            let original = CGColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 0.8)
            let lab = original.converted(to: labSpace, intent: .defaultIntent, options: nil)
            let backToRgb = lab?.converted(to: .deviceRGB, intent: .defaultIntent, options: nil)

            #expect(backToRgb != nil)
            if let orig = original.components, let back = backToRgb?.components {
                #expect(isApproximatelyEqual(orig[0], back[0], tolerance: 0.1), "Red should be preserved")
                #expect(isApproximatelyEqual(orig[1], back[1], tolerance: 0.1), "Green should be preserved")
                #expect(isApproximatelyEqual(orig[2], back[2], tolerance: 0.1), "Blue should be preserved")
            }
        }

        // MARK: - XYZ Conversion Tests

        @Test("RGB to XYZ conversion - white D65")
        func rgbToXyzWhite() {
            let white = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            guard let xyzSpace = CGColorSpace(name: CGColorSpace.genericXYZ) else {
                #expect(Bool(false), "Failed to create XYZ color space")
                return
            }
            let converted = white.converted(to: xyzSpace, intent: .defaultIntent, options: nil)

            #expect(converted != nil)
            // sRGB white (1,1,1) in XYZ D65 should be approximately (0.95047, 1.0, 1.08883)
            if let c = converted?.components {
                #expect(isApproximatelyEqual(c[0], 0.95047, tolerance: 0.01), "X should be ~0.95047")
                #expect(isApproximatelyEqual(c[1], 1.0, tolerance: 0.01), "Y should be ~1.0")
                #expect(isApproximatelyEqual(c[2], 1.08883, tolerance: 0.01), "Z should be ~1.08883")
            }
        }

        @Test("XYZ to RGB round trip preserves color")
        func xyzToRgbRoundTrip() {
            guard let xyzSpace = CGColorSpace(name: CGColorSpace.genericXYZ) else {
                #expect(Bool(false), "Failed to create XYZ color space")
                return
            }

            let original = CGColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 0.9)
            let xyz = original.converted(to: xyzSpace, intent: .defaultIntent, options: nil)
            let backToRgb = xyz?.converted(to: .deviceRGB, intent: .defaultIntent, options: nil)

            #expect(backToRgb != nil)
            if let orig = original.components, let back = backToRgb?.components {
                #expect(isApproximatelyEqual(orig[0], back[0]), "Red should be preserved")
                #expect(isApproximatelyEqual(orig[1], back[1]), "Green should be preserved")
                #expect(isApproximatelyEqual(orig[2], back[2]), "Blue should be preserved")
            }
        }

        // MARK: - Lab <-> XYZ Direct Conversion Tests

        @Test("Lab to XYZ direct conversion")
        func labToXyzDirect() {
            guard let labSpace = CGColorSpace(name: CGColorSpace.genericLab),
                  let xyzSpace = CGColorSpace(name: CGColorSpace.genericXYZ) else {
                #expect(Bool(false), "Failed to create color spaces")
                return
            }

            // White in Lab (L=100, a=0, b=0)
            let white = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            let labWhite = white.converted(to: labSpace, intent: .defaultIntent, options: nil)
            let xyzFromLab = labWhite?.converted(to: xyzSpace, intent: .defaultIntent, options: nil)

            #expect(xyzFromLab != nil)
            if let c = xyzFromLab?.components {
                // D65 white point
                #expect(isApproximatelyEqual(c[0], 0.95047, tolerance: 0.02), "X should be ~0.95047")
                #expect(isApproximatelyEqual(c[1], 1.0, tolerance: 0.02), "Y should be ~1.0")
            }
        }

        // MARK: - Chained Conversion Tests

        @Test("CMYK to Lab via RGB")
        func cmykToLabViaRgb() {
            guard let labSpace = CGColorSpace(name: CGColorSpace.genericLab) else {
                #expect(Bool(false), "Failed to create Lab color space")
                return
            }

            let cmyk = CGColor(genericCMYKCyan: 0.0, magenta: 0.0, yellow: 0.0, black: 0.0, alpha: 1.0)
            let lab = cmyk.converted(to: labSpace, intent: .defaultIntent, options: nil)

            #expect(lab != nil)
            // White CMYK should convert to white Lab (L≈100)
            if let l = lab?.components?[0] {
                #expect(isApproximatelyEqual(l, 100.0, tolerance: 2.0), "L should be ~100 for white")
            }
        }

        @Test("XYZ to CMYK via RGB")
        func xyzToCmykViaRgb() {
            guard let xyzSpace = CGColorSpace(name: CGColorSpace.genericXYZ),
                  let cmykSpace = CGColorSpace(name: CGColorSpace.genericCMYK) else {
                #expect(Bool(false), "Failed to create color spaces")
                return
            }

            // Create XYZ white and convert to CMYK
            let rgbWhite = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            let xyzWhite = rgbWhite.converted(to: xyzSpace, intent: .defaultIntent, options: nil)
            let cmykFromXyz = xyzWhite?.converted(to: cmykSpace, intent: .defaultIntent, options: nil)

            #expect(cmykFromXyz != nil)
            // White should have all CMYK channels near 0
            if let c = cmykFromXyz?.components {
                #expect(isApproximatelyEqual(c[0], 0.0, tolerance: 0.1), "C should be ~0")
                #expect(isApproximatelyEqual(c[1], 0.0, tolerance: 0.1), "M should be ~0")
                #expect(isApproximatelyEqual(c[2], 0.0, tolerance: 0.1), "Y should be ~0")
                #expect(isApproximatelyEqual(c[3], 0.0, tolerance: 0.1), "K should be ~0")
            }
        }

        // MARK: - Alpha Preservation Tests

        @Test("Alpha preserved through CMYK conversion")
        func alphaPreservedCmyk() {
            guard let cmykSpace = CGColorSpace(name: CGColorSpace.genericCMYK) else {
                #expect(Bool(false), "Failed to create CMYK color space")
                return
            }

            let alphaValues: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]
            for alpha in alphaValues {
                let color = CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: alpha)
                let converted = color.converted(to: cmykSpace, intent: .defaultIntent, options: nil)
                #expect(converted?.alpha == alpha, "Alpha \(alpha) should be preserved through CMYK")
            }
        }

        @Test("Alpha preserved through Lab conversion")
        func alphaPreservedLab() {
            guard let labSpace = CGColorSpace(name: CGColorSpace.genericLab) else {
                #expect(Bool(false), "Failed to create Lab color space")
                return
            }

            let color = CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.7)
            let converted = color.converted(to: labSpace, intent: .defaultIntent, options: nil)
            #expect(converted?.alpha == 0.7, "Alpha should be preserved through Lab")
        }

        @Test("Alpha preserved through XYZ conversion")
        func alphaPreservedXyz() {
            guard let xyzSpace = CGColorSpace(name: CGColorSpace.genericXYZ) else {
                #expect(Bool(false), "Failed to create XYZ color space")
                return
            }

            let color = CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.3)
            let converted = color.converted(to: xyzSpace, intent: .defaultIntent, options: nil)
            #expect(converted?.alpha == 0.3, "Alpha should be preserved through XYZ")
        }
    }
}
