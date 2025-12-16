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
private typealias CGFloat = OpenCoreGraphics.CGFloat
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
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var components: [CGFloat] = [
                1.0, 0.0, 0.0, 1.0,  // Red
                0.0, 0.0, 1.0, 1.0   // Blue
            ]
            var locations: [CGFloat] = [0.0, 1.0]

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
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var components: [CGFloat] = [1.0, 0.0, 0.0, 1.0]

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
            #expect(color?.components?[0].native == 1.0)  // Red
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
            #expect(color?.components?[2].native == 1.0)  // Blue
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
            #expect(color?.components?[0].native == 0.5)  // Red
            #expect(color?.components?[2].native == 0.5)  // Blue
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
            #expect(color?.components?[0].native == 1.0)  // Should be clamped to first color
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
            #expect(color?.components?[2].native == 1.0)  // Should be clamped to last color
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
            #expect(color?.components?[1].native == 1.0)  // Green
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
            #expect(color?.components?[0].native == 1.0)  // Red
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
}
