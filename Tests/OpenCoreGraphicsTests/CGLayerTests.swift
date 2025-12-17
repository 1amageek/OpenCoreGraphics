//
//  CGLayerTests.swift
//  OpenCoreGraphics
//
//  Tests for CGLayer
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = Foundation.CGFloat
private typealias CGLayer = OpenCoreGraphics.CGLayer
private typealias CGContext = OpenCoreGraphics.CGContext
private typealias CGSize = Foundation.CGSize
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace
private typealias CGBitmapInfo = OpenCoreGraphics.CGBitmapInfo
private typealias CGImageAlphaInfo = OpenCoreGraphics.CGImageAlphaInfo

@Suite("CGLayer Tests")
struct CGLayerTests {

    // MARK: - Helper Methods

    fileprivate func createTestContext() -> CGContext? {
        let colorSpace = CGColorSpace.deviceRGB
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        return CGContext(
            data: nil,
            width: 100,
            height: 100,
            bitsPerComponent: 8,
            bytesPerRow: 400,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
    }

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpace.deviceRGB
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            return CGContext(
                data: nil,
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }

        @Test("Init with valid parameters")
        func initWithValidParameters() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let layer = CGLayer(context: context, size: CGSize(width: 50, height: 50))

            #expect(layer != nil)
            #expect(layer?.size.width == 50)
            #expect(layer?.size.height == 50)
        }

        @Test("Init with zero width returns nil")
        func initWithZeroWidth() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let layer = CGLayer(context: context, size: CGSize(width: 0, height: 50))

            #expect(layer == nil)
        }

        @Test("Init with zero height returns nil")
        func initWithZeroHeight() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let layer = CGLayer(context: context, size: CGSize(width: 50, height: 0))

            #expect(layer == nil)
        }

        @Test("Init with negative dimensions returns nil")
        func initWithNegativeDimensions() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let layer = CGLayer(context: context, size: CGSize(width: -10, height: 50))

            #expect(layer == nil)
        }

        @Test("Init with auxiliary info")
        func initWithAuxiliaryInfo() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let auxiliaryInfo: [String: Any] = ["key": "value"]
            let layer = CGLayer(context: context, size: CGSize(width: 50, height: 50), auxiliaryInfo: auxiliaryInfo)

            #expect(layer != nil)
        }
    }

    // MARK: - Properties Tests

    @Suite("Properties")
    struct PropertiesTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpace.deviceRGB
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            return CGContext(
                data: nil,
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }

        @Test("Size property")
        func sizeProperty() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let layer = CGLayer(context: context, size: CGSize(width: 75, height: 100))

            #expect(layer?.size.width == 75)
            #expect(layer?.size.height == 100)
        }

        @Test("Context property")
        func contextProperty() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let layer = CGLayer(context: context, size: CGSize(width: 50, height: 50))

            #expect(layer?.context != nil)
        }
    }

    // MARK: - Factory Functions Tests

    @Suite("Factory Functions")
    struct FactoryFunctionTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpace.deviceRGB
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            return CGContext(
                data: nil,
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }

        @Test("CGLayerCreateWithContext")
        func layerCreateWithContext() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let layer = CGLayerCreateWithContext(context, CGSize(width: 50, height: 50), nil)

            #expect(layer != nil)
        }

        @Test("CGLayerGetContext")
        func layerGetContext() {
            guard let context = createTestContext(),
                  let layer = CGLayer(context: context, size: CGSize(width: 50, height: 50)) else {
                #expect(Bool(false), "Failed to create context or layer")
                return
            }

            let layerContext = CGLayerGetContext(layer)

            #expect(layerContext != nil)
        }

        @Test("CGLayerGetSize")
        func layerGetSize() {
            guard let context = createTestContext(),
                  let layer = CGLayer(context: context, size: CGSize(width: 60, height: 80)) else {
                #expect(Bool(false), "Failed to create context or layer")
                return
            }

            let size = CGLayerGetSize(layer)

            #expect(size.width == 60)
            #expect(size.height == 80)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpace.deviceRGB
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            return CGContext(
                data: nil,
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }

        @Test("Very small layer")
        func verySmallLayer() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let layer = CGLayer(context: context, size: CGSize(width: 1, height: 1))

            #expect(layer != nil)
            #expect(layer?.size.width == 1)
            #expect(layer?.size.height == 1)
        }

        @Test("Large layer")
        func largeLayer() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let layer = CGLayer(context: context, size: CGSize(width: 1000, height: 1000))

            #expect(layer != nil)
        }

        @Test("Non-square layer")
        func nonSquareLayer() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let layer = CGLayer(context: context, size: CGSize(width: 200, height: 50))

            #expect(layer != nil)
            #expect(layer?.size.width == 200)
            #expect(layer?.size.height == 50)
        }
    }
}
