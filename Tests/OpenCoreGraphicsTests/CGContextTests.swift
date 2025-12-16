//
//  CGContextTests.swift
//  OpenCoreGraphics
//
//  Tests for CGContext
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = OpenCoreGraphics.CGFloat
private typealias CGContext = OpenCoreGraphics.CGContext
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace
private typealias CGBitmapInfo = OpenCoreGraphics.CGBitmapInfo
private typealias CGImageAlphaInfo = OpenCoreGraphics.CGImageAlphaInfo
private typealias CGPoint = OpenCoreGraphics.CGPoint
private typealias CGSize = OpenCoreGraphics.CGSize
private typealias CGRect = OpenCoreGraphics.CGRect
private typealias CGAffineTransform = OpenCoreGraphics.CGAffineTransform
private typealias CGColor = OpenCoreGraphics.CGColor
private typealias CGLineCap = OpenCoreGraphics.CGLineCap
private typealias CGLineJoin = OpenCoreGraphics.CGLineJoin
private typealias CGBlendMode = OpenCoreGraphics.CGBlendMode
private typealias CGInterpolationQuality = OpenCoreGraphics.CGInterpolationQuality
private typealias CGTextDrawingMode = OpenCoreGraphics.CGTextDrawingMode
private typealias CGPathFillRule = OpenCoreGraphics.CGPathFillRule
private typealias CGPathDrawingMode = OpenCoreGraphics.CGPathDrawingMode

@Suite("CGContext Tests")
struct CGContextTests {

    // MARK: - Helper Methods

    fileprivate func createTestContext(width: Int = 100, height: Int = 100) -> CGContext? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
    }

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Init with valid parameters")
        func initWithValidParameters() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            let context = CGContext(
                data: nil,
                width: 100,
                height: 100,
                bitsPerComponent: 8,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )

            #expect(context != nil)
            #expect(context?.width == 100)
            #expect(context?.height == 100)
        }

        @Test("Init with zero width returns nil")
        func initWithZeroWidth() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            let context = CGContext(
                data: nil,
                width: 0,
                height: 100,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )

            #expect(context == nil)
        }

        @Test("Init with zero height returns nil")
        func initWithZeroHeight() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            let context = CGContext(
                data: nil,
                width: 100,
                height: 0,
                bitsPerComponent: 8,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )

            #expect(context == nil)
        }

        @Test("Init with zero bits per component returns nil")
        func initWithZeroBitsPerComponent() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            let context = CGContext(
                data: nil,
                width: 100,
                height: 100,
                bitsPerComponent: 0,
                bytesPerRow: 400,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )

            #expect(context == nil)
        }
    }

    // MARK: - Properties Tests

    @Suite("Properties")
    struct PropertiesTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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

        @Test("Width and height")
        func widthAndHeight() {
            let context = createTestContext()
            #expect(context?.width == 100)
            #expect(context?.height == 100)
        }

        @Test("Bits per component")
        func bitsPerComponent() {
            let context = createTestContext()
            #expect(context?.bitsPerComponent == 8)
        }

        @Test("Bytes per row")
        func bytesPerRow() {
            let context = createTestContext()
            #expect(context?.bytesPerRow == 400)
        }

        @Test("Color space")
        func colorSpace() {
            let context = createTestContext()
            #expect(context?.colorSpace?.model == .rgb)
        }

        @Test("CTM defaults to identity")
        func ctmDefaultsToIdentity() {
            let context = createTestContext()
            #expect(context?.ctm == .identity)
        }

        @Test("Line width default")
        func lineWidthDefault() {
            let context = createTestContext()
            #expect(context?.lineWidth.native == 1.0)
        }

        @Test("Interpolation quality default")
        func interpolationQualityDefault() {
            let context = createTestContext()
            #expect(context?.interpolationQuality == .default)
        }
    }

    // MARK: - Graphics State Tests

    @Suite("Graphics State")
    struct GraphicsStateTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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

        @Test("Save and restore GState")
        func saveAndRestoreGState() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(5.0)
            context.saveGState()
            context.setLineWidth(10.0)
            #expect(context.lineWidth.native == 10.0)
            context.restoreGState()
            #expect(context.lineWidth.native == 5.0)
        }

        @Test("Multiple save and restore")
        func multipleSaveAndRestore() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(1.0)
            context.saveGState()
            context.setLineWidth(2.0)
            context.saveGState()
            context.setLineWidth(3.0)

            #expect(context.lineWidth.native == 3.0)
            context.restoreGState()
            #expect(context.lineWidth.native == 2.0)
            context.restoreGState()
            #expect(context.lineWidth.native == 1.0)
        }
    }

    // MARK: - CTM Tests

    @Suite("Current Transformation Matrix")
    struct CTMTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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

        @Test("Translate")
        func translate() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.translateBy(x: 10, y: 20)
            #expect(context.ctm.tx.native == 10)
            #expect(context.ctm.ty.native == 20)
        }

        @Test("Scale")
        func scale() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.scaleBy(x: 2, y: 3)
            #expect(context.ctm.a.native == 2)
            #expect(context.ctm.d.native == 3)
        }

        @Test("Rotate")
        func rotate() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.rotate(by: CGFloat.pi / 2)
            // After 90 degree rotation, a ≈ 0, b ≈ 1, c ≈ -1, d ≈ 0
            #expect(abs(context.ctm.a.native) < 0.0001)
            #expect(abs(context.ctm.b.native - 1.0) < 0.0001)
        }

        @Test("Concatenate")
        func concatenate() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let transform = CGAffineTransform(translationX: 50, y: 50)
            context.concatenate(transform)
            #expect(context.ctm.tx.native == 50)
            #expect(context.ctm.ty.native == 50)
        }
    }

    // MARK: - Path Operations Tests

    @Suite("Path Operations")
    struct PathOperationsTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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

        @Test("Path is initially empty")
        func pathIsInitiallyEmpty() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.isPathEmpty)
        }

        @Test("Move to creates path")
        func moveToCreatesPath() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.move(to: CGPoint(x: 10, y: 10))
            #expect(!context.isPathEmpty)
        }

        @Test("Current point after move")
        func currentPointAfterMove() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.move(to: CGPoint(x: 25, y: 35))
            let point = context.currentPointOfPath
            #expect(point.x.native == 25)
            #expect(point.y.native == 35)
        }

        @Test("Add line")
        func addLine() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.move(to: CGPoint(x: 0, y: 0))
            context.addLine(to: CGPoint(x: 50, y: 50))
            let point = context.currentPointOfPath
            #expect(point.x.native == 50)
            #expect(point.y.native == 50)
        }

        @Test("Add rect")
        func addRect() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.addRect(CGRect(x: 0, y: 0, width: 50, height: 50))
            #expect(!context.isPathEmpty)
        }

        @Test("Begin path clears path")
        func beginPathClearsPath() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.move(to: CGPoint(x: 10, y: 10))
            #expect(!context.isPathEmpty)
            context.beginPath()
            #expect(context.isPathEmpty)
        }

        @Test("Path contains point")
        func pathContainsPoint() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.addRect(CGRect(x: 0, y: 0, width: 50, height: 50))
            #expect(context.pathContains(CGPoint(x: 25, y: 25)))
            #expect(!context.pathContains(CGPoint(x: 75, y: 75)))
        }

        @Test("Bounding box of path")
        func boundingBoxOfPath() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.addRect(CGRect(x: 10, y: 20, width: 30, height: 40))
            let bbox = context.boundingBoxOfPath
            #expect(bbox.origin.x.native == 10)
            #expect(bbox.origin.y.native == 20)
            #expect(bbox.width.native == 30)
            #expect(bbox.height.native == 40)
        }
    }

    // MARK: - Color Tests

    @Suite("Color Operations")
    struct ColorOperationsTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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

        @Test("Set fill color")
        func setFillColor() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let color = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            context.setFillColor(color)
            // No assertion, just verify it doesn't crash
        }

        @Test("Set stroke color")
        func setStrokeColor() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let color = CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
            context.setStrokeColor(color)
            // No assertion, just verify it doesn't crash
        }

        @Test("Set fill color RGB")
        func setFillColorRGB() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setFillColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
            // No assertion, just verify it doesn't crash
        }

        @Test("Set fill color gray")
        func setFillColorGray() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setFillColor(gray: 0.5, alpha: 1.0)
            // No assertion, just verify it doesn't crash
        }
    }

    // MARK: - Stroke Properties Tests

    @Suite("Stroke Properties")
    struct StrokePropertiesTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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

        @Test("Set line width")
        func setLineWidth() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(5.0)
            #expect(context.lineWidth.native == 5.0)
        }

        @Test("Set line cap")
        func setLineCap() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineCap(.round)
            // No direct getter, just verify it doesn't crash
        }

        @Test("Set line join")
        func setLineJoin() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineJoin(.bevel)
            // No direct getter, just verify it doesn't crash
        }

        @Test("Set miter limit")
        func setMiterLimit() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setMiterLimit(20.0)
            // No direct getter, just verify it doesn't crash
        }

        @Test("Set line dash")
        func setLineDash() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineDash(phase: 0, lengths: [5, 3])
            // No direct getter, just verify it doesn't crash
        }

        @Test("Clear line dash")
        func clearLineDash() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineDash(phase: 0, lengths: [5, 3])
            context.setLineDash(phase: 0, lengths: [])
            // No direct getter, just verify it doesn't crash
        }
    }

    // MARK: - Transparency Tests

    @Suite("Transparency and Compositing")
    struct TransparencyTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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

        @Test("Set alpha")
        func setAlpha() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setAlpha(0.5)
            // No direct getter, just verify it doesn't crash
        }

        @Test("Set blend mode")
        func setBlendMode() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setBlendMode(.multiply)
            // No direct getter, just verify it doesn't crash
        }
    }

    // MARK: - Image Quality Tests

    @Suite("Image Quality")
    struct ImageQualityTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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

        @Test("Set interpolation quality")
        func setInterpolationQuality() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setInterpolationQuality(.high)
            #expect(context.interpolationQuality == .high)
        }

        @Test("Set should antialias")
        func setShouldAntialias() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setShouldAntialias(false)
            // No direct getter, just verify it doesn't crash
        }
    }

    // MARK: - Text Tests

    @Suite("Text Operations")
    struct TextOperationsTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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

        @Test("Set text drawing mode")
        func setTextDrawingMode() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setTextDrawingMode(.stroke)
            // No direct getter, just verify it doesn't crash
        }

        @Test("Set text position")
        func setTextPosition() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setTextPosition(x: 10, y: 20)
            let pos = context.textPosition
            #expect(pos.x.native == 10)
            #expect(pos.y.native == 20)
        }

        @Test("Set text matrix")
        func setTextMatrix() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let matrix = CGAffineTransform(scaleX: 2, y: 2)
            context.setTextMatrix(matrix)
            #expect(context.textMatrix.a.native == 2)
        }

        @Test("Set character spacing")
        func setCharacterSpacing() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setCharacterSpacing(2.0)
            // No direct getter, just verify it doesn't crash
        }
    }

    // MARK: - Coordinate Conversion Tests

    @Suite("Coordinate Conversion")
    struct CoordinateConversionTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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

        @Test("User space to device space transform")
        func userSpaceToDeviceSpaceTransform() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.scaleBy(x: 2, y: 2)
            let transform = context.userSpaceToDeviceSpaceTransform
            #expect(transform.a.native == 2)
        }

        @Test("Convert point to device space")
        func convertPointToDeviceSpace() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.translateBy(x: 10, y: 20)
            let devicePoint = context.convertToDeviceSpace(CGPoint(x: 5, y: 5))
            #expect(devicePoint.x.native == 15)
            #expect(devicePoint.y.native == 25)
        }

        @Test("Convert point to user space")
        func convertPointToUserSpace() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.translateBy(x: 10, y: 20)
            let userPoint = context.convertToUserSpace(CGPoint(x: 15, y: 25))
            #expect(userPoint.x.native == 5)
            #expect(userPoint.y.native == 5)
        }
    }

    // MARK: - Make Image Tests

    @Suite("Image Creation")
    struct ImageCreationTests {

        fileprivate func createTestContext() -> CGContext? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
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

        @Test("Make image from context")
        func makeImageFromContext() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let image = context.makeImage()
            #expect(image != nil)
            #expect(image?.width == 100)
            #expect(image?.height == 100)
        }
    }

    // MARK: - Factory Functions Tests

    @Suite("Factory Functions")
    struct FactoryFunctionTests {

        @Test("CGBitmapContextCreate")
        func bitmapContextCreate() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGBitmapContextCreate(
                nil, 100, 100, 8, 400, colorSpace,
                CGImageAlphaInfo.premultipliedLast.rawValue
            )

            #expect(context != nil)
        }

        @Test("CGBitmapContextGetWidth")
        func bitmapContextGetWidth() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGBitmapContextCreate(
                nil, 100, 100, 8, 400, colorSpace,
                CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(CGBitmapContextGetWidth(context) == 100)
        }

        @Test("CGBitmapContextGetHeight")
        func bitmapContextGetHeight() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGBitmapContextCreate(
                nil, 100, 100, 8, 400, colorSpace,
                CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(CGBitmapContextGetHeight(context) == 100)
        }

        @Test("CGBitmapContextCreateImage")
        func bitmapContextCreateImage() {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGBitmapContextCreate(
                nil, 100, 100, 8, 400, colorSpace,
                CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let image = CGBitmapContextCreateImage(context)
            #expect(image != nil)
        }
    }
}
