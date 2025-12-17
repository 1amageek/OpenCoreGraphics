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
}
