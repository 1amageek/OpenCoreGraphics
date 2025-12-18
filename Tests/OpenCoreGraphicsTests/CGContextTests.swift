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
private typealias CGFloat = Foundation.CGFloat
private typealias CGContext = OpenCoreGraphics.CGContext
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace
private typealias CGBitmapInfo = OpenCoreGraphics.CGBitmapInfo
private typealias CGImageAlphaInfo = OpenCoreGraphics.CGImageAlphaInfo
private typealias CGPoint = Foundation.CGPoint
private typealias CGSize = Foundation.CGSize
private typealias CGRect = Foundation.CGRect
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
        let colorSpace = CGColorSpace.deviceRGB
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
            let colorSpace = CGColorSpace.deviceRGB
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
            let colorSpace = CGColorSpace.deviceRGB
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
            let colorSpace = CGColorSpace.deviceRGB
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
            let colorSpace = CGColorSpace.deviceRGB
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
            #expect(context?.lineWidth == 1.0)
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

        @Test("Save and restore GState")
        func saveAndRestoreGState() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(5.0)
            context.saveGState()
            context.setLineWidth(10.0)
            #expect(context.lineWidth == 10.0)
            context.restoreGState()
            #expect(context.lineWidth == 5.0)
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

            #expect(context.lineWidth == 3.0)
            context.restoreGState()
            #expect(context.lineWidth == 2.0)
            context.restoreGState()
            #expect(context.lineWidth == 1.0)
        }
    }

    // MARK: - CTM Tests

    @Suite("Current Transformation Matrix")
    struct CTMTests {

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

        @Test("Translate")
        func translate() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.translateBy(x: 10, y: 20)
            #expect(context.ctm.tx == 10)
            #expect(context.ctm.ty == 20)
        }

        @Test("Scale")
        func scale() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.scaleBy(x: 2, y: 3)
            #expect(context.ctm.a == 2)
            #expect(context.ctm.d == 3)
        }

        @Test("Rotate")
        func rotate() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.rotate(by: CGFloat.pi / 2)
            // After 90 degree rotation, a ≈ 0, b ≈ 1, c ≈ -1, d ≈ 0
            #expect(abs(context.ctm.a) < 0.0001)
            #expect(abs(context.ctm.b - 1.0) < 0.0001)
        }

        @Test("Concatenate")
        func concatenate() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let transform = CGAffineTransform(translationX: 50, y: 50)
            context.concatenate(transform)
            #expect(context.ctm.tx == 50)
            #expect(context.ctm.ty == 50)
        }
    }

    // MARK: - Path Operations Tests

    @Suite("Path Operations")
    struct PathOperationsTests {

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
            #expect(point.x == 25)
            #expect(point.y == 35)
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
            #expect(point.x == 50)
            #expect(point.y == 50)
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
            #expect(bbox.origin.x == 10)
            #expect(bbox.origin.y == 20)
            #expect(bbox.width == 30)
            #expect(bbox.height == 40)
        }
    }

    // MARK: - Color Tests

    @Suite("Color Operations")
    struct ColorOperationsTests {

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

        @Test("Set line width")
        func setLineWidth() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(5.0)
            #expect(context.lineWidth == 5.0)
        }

        @Test("Set line cap")
        func setLineCap() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.lineCap == .butt) // Default value
            context.setLineCap(.round)
            #expect(context.lineCap == .round)
            context.setLineCap(.square)
            #expect(context.lineCap == .square)
        }

        @Test("Set line join")
        func setLineJoin() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.lineJoin == .miter) // Default value
            context.setLineJoin(.bevel)
            #expect(context.lineJoin == .bevel)
            context.setLineJoin(.round)
            #expect(context.lineJoin == .round)
        }

        @Test("Set miter limit")
        func setMiterLimit() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.miterLimit == 10.0) // Default value
            context.setMiterLimit(20.0)
            #expect(context.miterLimit == 20.0)
        }

        @Test("Set flatness")
        func setFlatness() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.flatness == 0.5) // Default value
            context.setFlatness(1.0)
            #expect(context.flatness == 1.0)
        }

        @Test("Line cap is saved and restored by GState")
        func lineCapSaveRestore() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineCap(.round)
            context.saveGState()
            context.setLineCap(.square)
            #expect(context.lineCap == .square)
            context.restoreGState()
            #expect(context.lineCap == .round)
        }

        @Test("Line join is saved and restored by GState")
        func lineJoinSaveRestore() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineJoin(.bevel)
            context.saveGState()
            context.setLineJoin(.round)
            #expect(context.lineJoin == .round)
            context.restoreGState()
            #expect(context.lineJoin == .bevel)
        }

        @Test("Miter limit is saved and restored by GState")
        func miterLimitSaveRestore() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setMiterLimit(15.0)
            context.saveGState()
            context.setMiterLimit(25.0)
            #expect(context.miterLimit == 25.0)
            context.restoreGState()
            #expect(context.miterLimit == 15.0)
        }
    }

    // MARK: - Transparency Tests

    @Suite("Transparency and Compositing")
    struct TransparencyTests {

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

        @Test("Set alpha")
        func setAlpha() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.alpha == 1.0) // Default value
            context.setAlpha(0.5)
            #expect(context.alpha == 0.5)
            context.setAlpha(0.0)
            #expect(context.alpha == 0.0)
        }

        @Test("Set blend mode")
        func setBlendMode() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.blendMode == .normal) // Default value
            context.setBlendMode(.multiply)
            #expect(context.blendMode == .multiply)
            context.setBlendMode(.screen)
            #expect(context.blendMode == .screen)
        }

        @Test("Alpha is saved and restored by GState")
        func alphaSaveRestore() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setAlpha(0.8)
            context.saveGState()
            context.setAlpha(0.3)
            #expect(context.alpha == 0.3)
            context.restoreGState()
            #expect(context.alpha == 0.8)
        }

        @Test("Blend mode is saved and restored by GState")
        func blendModeSaveRestore() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setBlendMode(.overlay)
            context.saveGState()
            context.setBlendMode(.difference)
            #expect(context.blendMode == .difference)
            context.restoreGState()
            #expect(context.blendMode == .overlay)
        }
    }

    // MARK: - Image Quality Tests

    @Suite("Image Quality")
    struct ImageQualityTests {

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

        @Test("Set interpolation quality")
        func setInterpolationQuality() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.interpolationQuality == .default) // Default value
            context.setInterpolationQuality(.high)
            #expect(context.interpolationQuality == .high)
            context.setInterpolationQuality(.low)
            #expect(context.interpolationQuality == .low)
        }

        @Test("Set should antialias")
        func setShouldAntialias() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.shouldAntialias == true) // Default value
            context.setShouldAntialias(false)
            #expect(context.shouldAntialias == false)
            context.setShouldAntialias(true)
            #expect(context.shouldAntialias == true)
        }

        @Test("Set allows antialiasing")
        func setAllowsAntialiasing() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.allowsAntialiasing == true) // Default value
            context.setAllowsAntialiasing(false)
            #expect(context.allowsAntialiasing == false)
        }

        @Test("Antialiasing settings are saved and restored by GState")
        func antialiasSaveRestore() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setShouldAntialias(false)
            context.saveGState()
            context.setShouldAntialias(true)
            #expect(context.shouldAntialias == true)
            context.restoreGState()
            #expect(context.shouldAntialias == false)
        }
    }

    // MARK: - Text Tests

    @Suite("Text Operations")
    struct TextOperationsTests {

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

        @Test("Set text drawing mode")
        func setTextDrawingMode() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.textDrawingMode == .fill) // Default value
            context.setTextDrawingMode(.stroke)
            #expect(context.textDrawingMode == .stroke)
            context.setTextDrawingMode(.fillStroke)
            #expect(context.textDrawingMode == .fillStroke)
        }

        @Test("Set text position")
        func setTextPosition() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.textPosition.x == 0) // Default value
            #expect(context.textPosition.y == 0)
            context.setTextPosition(x: 10, y: 20)
            let pos = context.textPosition
            #expect(pos.x == 10)
            #expect(pos.y == 20)
        }

        @Test("Set text matrix")
        func setTextMatrix() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.textMatrix.isIdentity) // Default value
            let matrix = CGAffineTransform(scaleX: 2, y: 2)
            context.setTextMatrix(matrix)
            #expect(context.textMatrix.a == 2)
            #expect(context.textMatrix.d == 2)
        }

        @Test("Set character spacing")
        func setCharacterSpacing() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.characterSpacing == 0.0) // Default value
            context.setCharacterSpacing(2.0)
            #expect(context.characterSpacing == 2.0)
            context.setCharacterSpacing(-1.0) // Negative spacing is valid
            #expect(context.characterSpacing == -1.0)
        }

        @Test("Text drawing mode is saved and restored by GState")
        func textDrawingModeSaveRestore() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setTextDrawingMode(.clip)
            context.saveGState()
            context.setTextDrawingMode(.strokeClip)
            #expect(context.textDrawingMode == .strokeClip)
            context.restoreGState()
            #expect(context.textDrawingMode == .clip)
        }

        @Test("Character spacing is saved and restored by GState")
        func characterSpacingSaveRestore() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setCharacterSpacing(3.0)
            context.saveGState()
            context.setCharacterSpacing(5.0)
            #expect(context.characterSpacing == 5.0)
            context.restoreGState()
            #expect(context.characterSpacing == 3.0)
        }
    }

    // MARK: - Coordinate Conversion Tests

    @Suite("Coordinate Conversion")
    struct CoordinateConversionTests {

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

        @Test("User space to device space transform")
        func userSpaceToDeviceSpaceTransform() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.scaleBy(x: 2, y: 2)
            let transform = context.userSpaceToDeviceSpaceTransform
            #expect(transform.a == 2)
        }

        @Test("Convert point to device space")
        func convertPointToDeviceSpace() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.translateBy(x: 10, y: 20)
            let devicePoint = context.convertToDeviceSpace(CGPoint(x: 5, y: 5))
            #expect(devicePoint.x == 15)
            #expect(devicePoint.y == 25)
        }

        @Test("Convert point to user space")
        func convertPointToUserSpace() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.translateBy(x: 10, y: 20)
            let userPoint = context.convertToUserSpace(CGPoint(x: 15, y: 25))
            #expect(userPoint.x == 5)
            #expect(userPoint.y == 5)
        }
    }

    // MARK: - Make Image Tests

    @Suite("Image Creation")
    struct ImageCreationTests {

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
            let colorSpace = CGColorSpace.deviceRGB
            let context = CGBitmapContextCreate(
                nil, 100, 100, 8, 400, colorSpace,
                CGImageAlphaInfo.premultipliedLast.rawValue
            )

            #expect(context != nil)
        }

        @Test("CGBitmapContextGetWidth")
        func bitmapContextGetWidth() {
            let colorSpace = CGColorSpace.deviceRGB
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
            let colorSpace = CGColorSpace.deviceRGB
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
            let colorSpace = CGColorSpace.deviceRGB
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

    // MARK: - Coordinate Transformation Logic Tests

    @Suite("Coordinate Transformation Logic")
    struct CoordinateTransformationLogicTests {

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

        private func isApproximatelyEqual(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
            return abs(a - b) < tolerance
        }

        @Test("Coordinate conversion round trip")
        func coordinateConversionRoundTrip() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            // Apply complex transformation
            context.translateBy(x: 10, y: 20)
            context.scaleBy(x: 2, y: 3)
            context.rotate(by: CGFloat.pi / 6)

            let originalPoint = CGPoint(x: 15, y: 25)

            // Convert to device space and back
            let devicePoint = context.convertToDeviceSpace(originalPoint)
            let roundTrippedPoint = context.convertToUserSpace(devicePoint)

            #expect(isApproximatelyEqual(roundTrippedPoint.x, originalPoint.x))
            #expect(isApproximatelyEqual(roundTrippedPoint.y, originalPoint.y))
        }

        @Test("Translation shifts coordinates correctly")
        func translationShiftsCoordinates() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.translateBy(x: 50, y: 30)

            let userPoint = CGPoint(x: 10, y: 20)
            let devicePoint = context.convertToDeviceSpace(userPoint)

            // Device coordinates should be (10 + 50, 20 + 30) = (60, 50)
            #expect(isApproximatelyEqual(devicePoint.x, 60))
            #expect(isApproximatelyEqual(devicePoint.y, 50))
        }

        @Test("Scaling multiplies coordinates correctly")
        func scalingMultipliesCoordinates() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.scaleBy(x: 2, y: 3)

            let userPoint = CGPoint(x: 10, y: 10)
            let devicePoint = context.convertToDeviceSpace(userPoint)

            // Device coordinates should be (10 * 2, 10 * 3) = (20, 30)
            #expect(isApproximatelyEqual(devicePoint.x, 20))
            #expect(isApproximatelyEqual(devicePoint.y, 30))
        }

        @Test("Rotation by 90 degrees swaps coordinates")
        func rotation90DegreesSwapsCoordinates() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.rotate(by: CGFloat.pi / 2)

            // Point (10, 0) should rotate to (0, 10)
            let userPoint = CGPoint(x: 10, y: 0)
            let devicePoint = context.convertToDeviceSpace(userPoint)

            #expect(isApproximatelyEqual(devicePoint.x, 0))
            #expect(isApproximatelyEqual(devicePoint.y, 10))
        }

        @Test("Scale then translate order matters")
        func scaleTranslateOrder() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            // Scale by 2, then translate by 10
            context.scaleBy(x: 2, y: 2)
            context.translateBy(x: 10, y: 10)

            // Point (0, 0) goes through: scale (0,0) -> translate (10, 10) scaled = (20, 20)
            let devicePoint = context.convertToDeviceSpace(CGPoint.zero)
            #expect(isApproximatelyEqual(devicePoint.x, 20))
            #expect(isApproximatelyEqual(devicePoint.y, 20))
        }

        @Test("Convert CGSize to device space scales correctly")
        func convertSizeToDeviceSpace() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.scaleBy(x: 2, y: 3)

            let userSize = CGSize(width: 10, height: 10)
            let deviceSize = context.convertToDeviceSpace(userSize)

            #expect(isApproximatelyEqual(deviceSize.width, 20))
            #expect(isApproximatelyEqual(deviceSize.height, 30))
        }

        @Test("Convert CGRect to device space transforms correctly")
        func convertRectToDeviceSpace() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.translateBy(x: 10, y: 20)
            context.scaleBy(x: 2, y: 2)

            let userRect = CGRect(x: 5, y: 5, width: 10, height: 10)
            let deviceRect = context.convertToDeviceSpace(userRect)

            // Origin: (5*2 + 10, 5*2 + 20) = (20, 30)
            // Size: (10*2, 10*2) = (20, 20)
            #expect(isApproximatelyEqual(deviceRect.origin.x, 20))
            #expect(isApproximatelyEqual(deviceRect.origin.y, 30))
            #expect(isApproximatelyEqual(deviceRect.size.width, 20))
            #expect(isApproximatelyEqual(deviceRect.size.height, 20))
        }

        @Test("CTM is identity by default")
        func ctmIdentityByDefault() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.ctm.isIdentity)
        }

        @Test("Concatenate custom transform")
        func concatenateCustomTransform() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            // Create a shear transformation
            let shear = CGAffineTransform(a: 1, b: 0, c: 0.5, d: 1, tx: 0, ty: 0)
            context.concatenate(shear)

            let point = CGPoint(x: 0, y: 10)
            let transformed = context.convertToDeviceSpace(point)

            // x' = x + 0.5 * y = 0 + 0.5 * 10 = 5
            #expect(isApproximatelyEqual(transformed.x, 5))
            #expect(isApproximatelyEqual(transformed.y, 10))
        }
    }

    // MARK: - Graphics State Stack Logic Tests

    @Suite("Graphics State Stack Logic")
    struct GraphicsStateStackLogicTests {

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

        private func isApproximatelyEqual(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
            return abs(a - b) < tolerance
        }

        @Test("GState saves and restores CTM")
        func gstateSavesRestoresCTM() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.translateBy(x: 10, y: 20)
            context.saveGState()
            context.translateBy(x: 50, y: 50)

            // After additional translation
            #expect(context.ctm.tx == 60)
            #expect(context.ctm.ty == 70)

            context.restoreGState()

            // After restore, should be back to original translation
            #expect(context.ctm.tx == 10)
            #expect(context.ctm.ty == 20)
        }

        @Test("GState saves and restores line width")
        func gstateSavesRestoresLineWidth() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(5.0)
            context.saveGState()
            context.setLineWidth(10.0)
            context.saveGState()
            context.setLineWidth(15.0)

            #expect(context.lineWidth == 15.0)
            context.restoreGState()
            #expect(context.lineWidth == 10.0)
            context.restoreGState()
            #expect(context.lineWidth == 5.0)
        }

        @Test("GState saves and restores text position")
        func gstateSavesRestoresTextPosition() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setTextPosition(x: 10, y: 20)
            context.saveGState()
            context.setTextPosition(x: 50, y: 60)

            #expect(context.textPosition.x == 50)
            #expect(context.textPosition.y == 60)

            context.restoreGState()

            #expect(context.textPosition.x == 10)
            #expect(context.textPosition.y == 20)
        }

        @Test("GState saves and restores text matrix")
        func gstateSavesRestoresTextMatrix() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let matrix1 = CGAffineTransform(scaleX: 2, y: 2)
            context.setTextMatrix(matrix1)
            context.saveGState()

            let matrix2 = CGAffineTransform(rotationAngle: CGFloat.pi / 4)
            context.setTextMatrix(matrix2)

            #expect(isApproximatelyEqual(context.textMatrix.a, matrix2.a))

            context.restoreGState()

            #expect(isApproximatelyEqual(context.textMatrix.a, 2))
        }

        @Test("GState saves and restores interpolation quality")
        func gstateSavesRestoresInterpolationQuality() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setInterpolationQuality(.high)
            context.saveGState()
            context.setInterpolationQuality(.low)

            #expect(context.interpolationQuality == .low)

            context.restoreGState()

            #expect(context.interpolationQuality == .high)
        }

        @Test("Deep nesting of GState stack works correctly")
        func deepNestedGStateStack() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            // Create deep nesting
            for i in 1...10 {
                context.setLineWidth(CGFloat(i))
                context.saveGState()
            }

            // Verify current line width
            #expect(context.lineWidth == 10.0)

            // Unwind the stack
            for i in (1...10).reversed() {
                context.restoreGState()
                #expect(context.lineWidth == CGFloat(i))
            }
        }

        @Test("Restore on empty stack does nothing")
        func restoreOnEmptyStackDoesNothing() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(5.0)

            // Restore without any saves should not crash and keep current state
            context.restoreGState()
            context.restoreGState()
            context.restoreGState()

            #expect(context.lineWidth == 5.0)
        }
    }

    // MARK: - Pixel Data Initialization Tests

    @Suite("Pixel Data Initialization")
    struct PixelDataInitializationTests {

        @Test("Initial context pixels are all zero (transparent)")
        func initialPixelsAreZero() {
            let colorSpace = CGColorSpace.deviceRGB
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let context = CGContext(
                data: nil,
                width: 10,
                height: 10,
                bitsPerComponent: 8,
                bytesPerRow: 40,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ), let data = context.data else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let ptr = data.assumingMemoryBound(to: UInt8.self)
            let totalBytes = 10 * 40 // 10 rows * 40 bytes per row

            // All bytes should be 0 (transparent)
            for i in 0..<totalBytes {
                #expect(ptr[i] == 0, "Byte at index \(i) should be 0 but was \(ptr[i])")
            }
        }

        @Test("Make image produces correct dimensions")
        func makeImageProducesCorrectDimensions() {
            let colorSpace = CGColorSpace.deviceRGB
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let context = CGContext(
                data: nil,
                width: 50,
                height: 30,
                bitsPerComponent: 8,
                bytesPerRow: 200,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let image = context.makeImage()

            #expect(image?.width == 50)
            #expect(image?.height == 30)
            #expect(image?.bitsPerComponent == 8)
            #expect(image?.bytesPerRow == 200)
        }

        @Test("Make image preserves color space")
        func makeImagePreservesColorSpace() {
            let colorSpace = CGColorSpace.deviceRGB
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let context = CGContext(
                data: nil,
                width: 50,
                height: 30,
                bitsPerComponent: 8,
                bytesPerRow: 200,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            let image = context.makeImage()

            #expect(image?.colorSpace?.model == .rgb)
        }
    }

    // MARK: - Replace Path With Stroked Path Tests

    @Suite("Replace Path With Stroked Path")
    struct ReplacePathWithStrokedPathTests {

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

        @Test("Replace simple line path with stroked path")
        func replaceSimpleLine() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(10)
            context.move(to: CGPoint(x: 10, y: 50))
            context.addLine(to: CGPoint(x: 90, y: 50))

            let originalBbox = context.boundingBoxOfPath

            context.replacePathWithStrokedPath()

            let strokedBbox = context.boundingBoxOfPath

            // Stroked path should be taller (extend above and below)
            #expect(strokedBbox.minY < originalBbox.minY)
            #expect(strokedBbox.maxY > originalBbox.maxY)

            // Path should not be empty
            #expect(!context.isPathEmpty)
        }

        @Test("Replace empty path does nothing")
        func replaceEmptyPath() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            #expect(context.isPathEmpty)

            context.replacePathWithStrokedPath()

            #expect(context.isPathEmpty)
        }

        @Test("Stroked path uses current line width")
        func strokedPathUsesLineWidth() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.move(to: CGPoint(x: 50, y: 50))
            context.addLine(to: CGPoint(x: 50, y: 90))

            // Small line width
            context.setLineWidth(5)
            context.replacePathWithStrokedPath()
            let smallBbox = context.boundingBoxOfPath

            // Create new path with larger line width
            context.beginPath()
            context.move(to: CGPoint(x: 50, y: 50))
            context.addLine(to: CGPoint(x: 50, y: 90))
            context.setLineWidth(20)
            context.replacePathWithStrokedPath()
            let largeBbox = context.boundingBoxOfPath

            // Larger line width should produce wider path
            #expect(largeBbox.width > smallBbox.width)
        }

        @Test("Stroked path uses current line cap")
        func strokedPathUsesLineCap() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            // Test with butt cap
            context.setLineWidth(10)
            context.setLineCap(.butt)
            context.move(to: CGPoint(x: 50, y: 10))
            context.addLine(to: CGPoint(x: 50, y: 90))
            context.replacePathWithStrokedPath()
            let buttBbox = context.boundingBoxOfPath

            // Test with square cap
            context.beginPath()
            context.setLineCap(.square)
            context.move(to: CGPoint(x: 50, y: 10))
            context.addLine(to: CGPoint(x: 50, y: 90))
            context.replacePathWithStrokedPath()
            let squareBbox = context.boundingBoxOfPath

            // Square cap extends beyond endpoints, so bounding box should be taller
            #expect(squareBbox.height > buttBbox.height)
        }

        @Test("Stroked path uses current line join")
        func strokedPathUsesLineJoin() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(10)

            // Test with miter join
            context.setLineJoin(.miter)
            context.setMiterLimit(10)
            context.move(to: CGPoint(x: 10, y: 50))
            context.addLine(to: CGPoint(x: 50, y: 50))
            context.addLine(to: CGPoint(x: 50, y: 10))
            context.replacePathWithStrokedPath()

            #expect(!context.isPathEmpty)
        }

        @Test("Stroked closed path forms outline")
        func strokedClosedPath() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(10)
            context.addRect(CGRect(x: 20, y: 20, width: 60, height: 60))

            let originalBbox = context.boundingBoxOfPath

            context.replacePathWithStrokedPath()

            let strokedBbox = context.boundingBoxOfPath

            // Stroked rectangle should be larger
            #expect(strokedBbox.width > originalBbox.width)
            #expect(strokedBbox.height > originalBbox.height)
        }

        @Test("Stroked path can be filled")
        func strokedPathCanBeFilled() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(10)
            context.move(to: CGPoint(x: 10, y: 50))
            context.addLine(to: CGPoint(x: 90, y: 50))

            context.replacePathWithStrokedPath()

            // The stroked path should be fillable (this shouldn't crash)
            context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            context.fillPath()

            // After fill, path should be consumed
            #expect(context.isPathEmpty)
        }

        @Test("Stroked curve path")
        func strokedCurvePath() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(5)
            context.move(to: CGPoint(x: 10, y: 50))
            context.addQuadCurve(to: CGPoint(x: 90, y: 50), control: CGPoint(x: 50, y: 10))

            context.replacePathWithStrokedPath()

            #expect(!context.isPathEmpty)
        }

        @Test("Multiple subpaths are all stroked")
        func multipleSubpathsStroked() {
            guard let context = createTestContext() else {
                #expect(Bool(false), "Failed to create context")
                return
            }

            context.setLineWidth(5)

            // First subpath
            context.move(to: CGPoint(x: 10, y: 20))
            context.addLine(to: CGPoint(x: 40, y: 20))

            // Second subpath
            context.move(to: CGPoint(x: 60, y: 80))
            context.addLine(to: CGPoint(x: 90, y: 80))

            context.replacePathWithStrokedPath()

            let bbox = context.boundingBoxOfPath

            // Bounding box should span both subpaths
            #expect(bbox.minX <= 10)
            #expect(bbox.maxX >= 90)
            #expect(bbox.minY <= 20)
            #expect(bbox.maxY >= 80)
        }
    }
}
