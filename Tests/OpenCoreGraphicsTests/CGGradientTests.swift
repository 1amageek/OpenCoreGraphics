//
//  CGGradientTests.swift
//  OpenCoreGraphics
//
//  Tests for CGGradient and CGGradientDrawingOptions
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = Foundation.CGFloat
private typealias CGGradient = OpenCoreGraphics.CGGradient
private typealias CGGradientDrawingOptions = OpenCoreGraphics.CGGradientDrawingOptions
private typealias CGColor = OpenCoreGraphics.CGColor
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace

// MARK: - CGGradientDrawingOptions Tests

@Suite("CGGradientDrawingOptions Tests")
struct CGGradientDrawingOptionsTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGGradientDrawingOptions.drawsBeforeStartLocation.rawValue == 1)
        #expect(CGGradientDrawingOptions.drawsAfterEndLocation.rawValue == 2)
    }

    @Test("Empty options")
    func emptyOptions() {
        let options: CGGradientDrawingOptions = []
        #expect(options.rawValue == 0)
    }

    @Test("Combined options")
    func combinedOptions() {
        let options: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        #expect(options.contains(.drawsBeforeStartLocation))
        #expect(options.contains(.drawsAfterEndLocation))
        #expect(options.rawValue == 3)
    }

    @Test("Contains check")
    func containsCheck() {
        let options = CGGradientDrawingOptions.drawsBeforeStartLocation
        #expect(options.contains(.drawsBeforeStartLocation))
        #expect(!options.contains(.drawsAfterEndLocation))
    }
}

// MARK: - CGGradient Tests

@Suite("CGGradient Tests")
struct CGGradientTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Init with colors and locations")
        func initWithColorsAndLocations() {
            let colors = [
                CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            ]
            let locations: [CGFloat] = [0.0, 1.0]

            let gradient = CGGradient(colors: colors, locations: locations)

            #expect(gradient != nil)
            #expect(gradient?.colors.count == 2)
            #expect(gradient?.locations?.count == 2)
            #expect(gradient?.numberOfLocations == 2)
        }

        @Test("Init with colors without locations")
        func initWithColorsWithoutLocations() {
            let colors = [
                CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            ]

            let gradient = CGGradient(colors: colors, locations: nil)

            #expect(gradient != nil)
            #expect(gradient?.colors.count == 3)
            #expect(gradient?.locations == nil)
        }

        @Test("Init with color space and colors")
        func initWithColorSpaceAndColors() {
            let colorSpace = CGColorSpace.deviceRGB
            let colors = [
                CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            ]
            let locations: [CGFloat] = [0.0, 1.0]

            let gradient = CGGradient(colorSpace: colorSpace, colors: colors, locations: locations)

            #expect(gradient != nil)
            #expect(gradient?.colorSpace == colorSpace)
        }

        @Test("Init with empty colors returns nil")
        func initWithEmptyColors() {
            let colors: [CGColor] = []
            let gradient = CGGradient(colors: colors, locations: nil)

            #expect(gradient == nil)
        }

        @Test("Init with mismatched locations returns nil")
        func initWithMismatchedLocations() {
            let colorSpace = CGColorSpace.deviceRGB
            let colors = [
                CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            ]
            let locations: [CGFloat] = [0.0, 0.5, 1.0]  // 3 locations for 2 colors

            let gradient = CGGradient(colorSpace: colorSpace, colors: colors, locations: locations)

            #expect(gradient == nil)
        }

        @Test("Init with color components")
        func initWithColorComponents() {
            let colorSpace = CGColorSpace.deviceRGB
            let components: [CGFloat] = [
                1.0, 0.0, 0.0, 1.0,  // Red
                0.0, 0.0, 1.0, 1.0   // Blue
            ]
            let locations: [CGFloat] = [0.0, 1.0]

            let gradient = components.withUnsafeBufferPointer { compPtr in
                locations.withUnsafeBufferPointer { locPtr in
                    CGGradient(
                        colorSpace: colorSpace,
                        colorComponents: compPtr.baseAddress!,
                        locations: locPtr.baseAddress,
                        count: 2
                    )
                }
            }

            #expect(gradient != nil)
            #expect(gradient?.colors.count == 2)
        }

        @Test("Init with zero count returns nil")
        func initWithZeroCount() {
            let colorSpace = CGColorSpace.deviceRGB
            let components: [CGFloat] = [1.0, 0.0, 0.0, 1.0]

            let gradient = components.withUnsafeBufferPointer { compPtr in
                CGGradient(
                    colorSpace: colorSpace,
                    colorComponents: compPtr.baseAddress!,
                    locations: nil,
                    count: 0
                )
            }

            #expect(gradient == nil)
        }
    }

    // MARK: - Properties Tests

    @Suite("Properties")
    struct PropertiesTests {

        @Test("Number of locations")
        func numberOfLocations() {
            let colors = [
                CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            ]

            let gradient = CGGradient(colors: colors, locations: nil)

            #expect(gradient?.numberOfLocations == 3)
        }

        @Test("Color space from first color")
        func colorSpaceFromFirstColor() {
            let colors = [
                CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            ]

            let gradient = CGGradient(colors: colors, locations: nil)

            #expect(gradient?.colorSpace.model == .rgb)
        }
    }

    // MARK: - Color Interpolation Tests

    @Suite("Color Interpolation")
    struct ColorInterpolationTests {

        @Test("Color at position 0")
        func colorAtPositionZero() {
            let colors = [
                CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            ]
            let locations: [CGFloat] = [0.0, 1.0]

            let gradient = CGGradient(colors: colors, locations: locations)
            let color = gradient?.color(at: 0.0)

            #expect(color != nil)
            #expect(color?.components?[0] == 1.0)  // Red
        }

        @Test("Color at position 1")
        func colorAtPositionOne() {
            let colors = [
                CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            ]
            let locations: [CGFloat] = [0.0, 1.0]

            let gradient = CGGradient(colors: colors, locations: locations)
            let color = gradient?.color(at: 1.0)

            #expect(color != nil)
            #expect(color?.components?[2] == 1.0)  // Blue
        }

        @Test("Color at midpoint")
        func colorAtMidpoint() {
            let colors = [
                CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            ]
            let locations: [CGFloat] = [0.0, 1.0]

            let gradient = CGGradient(colors: colors, locations: locations)
            let color = gradient?.color(at: 0.5)

            #expect(color != nil)
            // At midpoint, red and blue should both be 0.5
            #expect(color?.components?[0] == 0.5)  // Red
            #expect(color?.components?[2] == 0.5)  // Blue
        }

        @Test("Color at position clamped below 0")
        func colorAtPositionBelowZero() {
            let colors = [
                CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            ]
            let locations: [CGFloat] = [0.0, 1.0]

            let gradient = CGGradient(colors: colors, locations: locations)
            let color = gradient?.color(at: -0.5)

            #expect(color != nil)
            #expect(color?.components?[0] == 1.0)  // Should be clamped to first color
        }

        @Test("Color at position clamped above 1")
        func colorAtPositionAboveOne() {
            let colors = [
                CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            ]
            let locations: [CGFloat] = [0.0, 1.0]

            let gradient = CGGradient(colors: colors, locations: locations)
            let color = gradient?.color(at: 1.5)

            #expect(color != nil)
            #expect(color?.components?[2] == 1.0)  // Should be clamped to last color
        }

        @Test("Color with evenly spaced implicit locations")
        func colorWithImplicitLocations() {
            let colors = [
                CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0),
                CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            ]

            let gradient = CGGradient(colors: colors, locations: nil)

            // At 0.5, should be at the middle color (green)
            let color = gradient?.color(at: 0.5)
            #expect(color != nil)
            #expect(color?.components?[1] == 1.0)  // Green
        }
    }

    // MARK: - Edge Case Tests

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        @Test("Single color gradient")
        func singleColorGradient() {
            let colors = [CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)]

            let gradient = CGGradient(colors: colors, locations: nil)

            #expect(gradient != nil)
            #expect(gradient?.numberOfLocations == 1)
        }

        @Test("Color at any position for single color")
        func colorAtAnyPositionSingleColor() {
            let colors = [CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)]

            let gradient = CGGradient(colors: colors, locations: nil)
            let color = gradient?.color(at: 0.5)

            #expect(color != nil)
            #expect(color?.components?[0] == 1.0)  // Red
        }

        @Test("Many colors gradient")
        func manyColorsGradient() {
            let colors = (0..<10).map { i in
                CGColor(red: CGFloat(Double(i) / 9.0), green: 0.0, blue: 0.0, alpha: 1.0)
            }

            let gradient = CGGradient(colors: colors, locations: nil)

            #expect(gradient != nil)
            #expect(gradient?.numberOfLocations == 10)
        }
    }

    // MARK: - Mathematical Interpolation Logic Tests

    @Suite("Interpolation Logic")
    struct InterpolationLogicTests {

        // Helper to check if two values are approximately equal
        private func isApproximatelyEqual(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
            return abs(a - b) < tolerance
        }

        @Test("Gray interpolation at exact midpoint produces 50% gray")
        func grayInterpolationMidpoint() {
            let black = CGColor(gray: 0.0, alpha: 1.0)
            let white = CGColor(gray: 1.0, alpha: 1.0)
            let gradient = CGGradient(colors: [black, white], locations: [0.0, 1.0])!

            let midColor = gradient.color(at: 0.5)!
            let grayValue = midColor.components![0]

            // At midpoint, gray should be exactly 0.5
            #expect(isApproximatelyEqual(grayValue, 0.5))
        }

        @Test("Gray interpolation at 25% produces 0.25 gray")
        func grayInterpolationQuarter() {
            let black = CGColor(gray: 0.0, alpha: 1.0)
            let white = CGColor(gray: 1.0, alpha: 1.0)
            let gradient = CGGradient(colors: [black, white], locations: [0.0, 1.0])!

            let color = gradient.color(at: 0.25)!
            let grayValue = color.components![0]

            #expect(isApproximatelyEqual(grayValue, 0.25))
        }

        @Test("Gray interpolation at 75% produces 0.75 gray")
        func grayInterpolationThreeQuarter() {
            let black = CGColor(gray: 0.0, alpha: 1.0)
            let white = CGColor(gray: 1.0, alpha: 1.0)
            let gradient = CGGradient(colors: [black, white], locations: [0.0, 1.0])!

            let color = gradient.color(at: 0.75)!
            let grayValue = color.components![0]

            #expect(isApproximatelyEqual(grayValue, 0.75))
        }

        @Test("Alpha channel is interpolated correctly")
        func alphaInterpolation() {
            let transparent = CGColor(gray: 0.5, alpha: 0.0)
            let opaque = CGColor(gray: 0.5, alpha: 1.0)
            let gradient = CGGradient(colors: [transparent, opaque], locations: [0.0, 1.0])!

            // At 0.0, alpha should be 0.0
            let atZero = gradient.color(at: 0.0)!
            #expect(isApproximatelyEqual(atZero.alpha, 0.0))

            // At 0.5, alpha should be 0.5
            let atHalf = gradient.color(at: 0.5)!
            #expect(isApproximatelyEqual(atHalf.alpha, 0.5))

            // At 1.0, alpha should be 1.0
            let atOne = gradient.color(at: 1.0)!
            #expect(isApproximatelyEqual(atOne.alpha, 1.0))
        }

        @Test("Three color gradient interpolation between first and second color")
        func threeColorFirstSegment() {
            let red = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            let green = CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
            let blue = CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            let gradient = CGGradient(colors: [red, green, blue], locations: [0.0, 0.5, 1.0])!

            // At 0.25, we're halfway between red and green
            let color = gradient.color(at: 0.25)!
            let r = color.components![0]
            let g = color.components![1]
            let b = color.components![2]

            #expect(isApproximatelyEqual(r, 0.5))
            #expect(isApproximatelyEqual(g, 0.5))
            #expect(isApproximatelyEqual(b, 0.0))
        }

        @Test("Three color gradient interpolation between second and third color")
        func threeColorSecondSegment() {
            let red = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            let green = CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
            let blue = CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
            let gradient = CGGradient(colors: [red, green, blue], locations: [0.0, 0.5, 1.0])!

            // At 0.75, we're halfway between green and blue
            let color = gradient.color(at: 0.75)!
            let r = color.components![0]
            let g = color.components![1]
            let b = color.components![2]

            #expect(isApproximatelyEqual(r, 0.0))
            #expect(isApproximatelyEqual(g, 0.5))
            #expect(isApproximatelyEqual(b, 0.5))
        }

        @Test("Nil locations produces evenly distributed colors")
        func nilLocationsEvenDistribution() {
            let c1 = CGColor(gray: 0.0, alpha: 1.0)
            let c2 = CGColor(gray: 0.5, alpha: 1.0)
            let c3 = CGColor(gray: 1.0, alpha: 1.0)
            let gradient = CGGradient(colors: [c1, c2, c3], locations: nil)!

            // With nil locations, colors should be at 0.0, 0.5, 1.0
            // At 0.5, should get the middle color (gray = 0.5)
            let atMiddle = gradient.color(at: 0.5)!
            #expect(isApproximatelyEqual(atMiddle.components![0], 0.5))

            // At 0.25, should be halfway between c1 (0.0) and c2 (0.5) = 0.25
            let atQuarter = gradient.color(at: 0.25)!
            #expect(isApproximatelyEqual(atQuarter.components![0], 0.25))
        }

        @Test("Custom locations affect interpolation correctly")
        func customLocations() {
            let black = CGColor(gray: 0.0, alpha: 1.0)
            let white = CGColor(gray: 1.0, alpha: 1.0)
            // Black at 0.2, white at 0.8
            let gradient = CGGradient(colors: [black, white], locations: [0.2, 0.8])!

            // At 0.2, should be black
            let atStart = gradient.color(at: 0.2)!
            #expect(isApproximatelyEqual(atStart.components![0], 0.0))

            // At 0.8, should be white
            let atEnd = gradient.color(at: 0.8)!
            #expect(isApproximatelyEqual(atEnd.components![0], 1.0))

            // At 0.5 (midpoint between 0.2 and 0.8), should be 0.5 gray
            let atMid = gradient.color(at: 0.5)!
            #expect(isApproximatelyEqual(atMid.components![0], 0.5))
        }

        @Test("Position before first location returns first color")
        func positionBeforeFirstLocation() {
            let black = CGColor(gray: 0.0, alpha: 1.0)
            let white = CGColor(gray: 1.0, alpha: 1.0)
            let gradient = CGGradient(colors: [black, white], locations: [0.3, 0.7])!

            // At 0.1 (before first location 0.3), should clamp to black
            let color = gradient.color(at: 0.1)!
            #expect(isApproximatelyEqual(color.components![0], 0.0))
        }

        @Test("Position after last location returns last color")
        func positionAfterLastLocation() {
            let black = CGColor(gray: 0.0, alpha: 1.0)
            let white = CGColor(gray: 1.0, alpha: 1.0)
            let gradient = CGGradient(colors: [black, white], locations: [0.3, 0.7])!

            // At 0.9 (after last location 0.7), should clamp to white
            let color = gradient.color(at: 0.9)!
            #expect(isApproximatelyEqual(color.components![0], 1.0))
        }

        @Test("Linear interpolation formula is correct: c1 + (c2-c1)*t")
        func linearInterpolationFormula() {
            // Test with specific values: gray 0.2 to gray 0.8
            let c1 = CGColor(gray: 0.2, alpha: 1.0)
            let c2 = CGColor(gray: 0.8, alpha: 1.0)
            let gradient = CGGradient(colors: [c1, c2], locations: [0.0, 1.0])!

            // At t=0.5: 0.2 + (0.8 - 0.2) * 0.5 = 0.2 + 0.3 = 0.5
            let atHalf = gradient.color(at: 0.5)!
            #expect(isApproximatelyEqual(atHalf.components![0], 0.5))

            // At t=0.25: 0.2 + (0.8 - 0.2) * 0.25 = 0.2 + 0.15 = 0.35
            let atQuarter = gradient.color(at: 0.25)!
            #expect(isApproximatelyEqual(atQuarter.components![0], 0.35))

            // At t=0.75: 0.2 + (0.8 - 0.2) * 0.75 = 0.2 + 0.45 = 0.65
            let atThreeQuarter = gradient.color(at: 0.75)!
            #expect(isApproximatelyEqual(atThreeQuarter.components![0], 0.65))
        }
    }
}
