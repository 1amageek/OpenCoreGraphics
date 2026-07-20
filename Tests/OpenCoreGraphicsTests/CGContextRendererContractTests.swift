//
//  CGContextRendererContractTests.swift
//  OpenCoreGraphics
//
//  Renderer-delegate contract tests that aggregate multiple drawing scenarios
//  without relying on image snapshots.
//

import Foundation
import Synchronization
import Testing
@testable import OpenCoreGraphics

private typealias CGFloat = Foundation.CGFloat
private typealias CGContext = OpenCoreGraphics.CGContext
private typealias CGColor = OpenCoreGraphics.CGColor
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace
private typealias CGBitmapInfo = OpenCoreGraphics.CGBitmapInfo
private typealias CGImage = OpenCoreGraphics.CGImage
private typealias CGImageAlphaInfo = OpenCoreGraphics.CGImageAlphaInfo
private typealias CGBlendMode = OpenCoreGraphics.CGBlendMode
private typealias CGLineCap = OpenCoreGraphics.CGLineCap
private typealias CGLineJoin = OpenCoreGraphics.CGLineJoin
private typealias CGInterpolationQuality = OpenCoreGraphics.CGInterpolationQuality
private typealias CGPathFillRule = OpenCoreGraphics.CGPathFillRule
private typealias CGGradient = OpenCoreGraphics.CGGradient
private typealias CGGradientDrawingOptions = OpenCoreGraphics.CGGradientDrawingOptions
private typealias CGRect = Foundation.CGRect
private typealias CGPoint = Foundation.CGPoint
private typealias CGSize = Foundation.CGSize

@Suite("CGContext Renderer Contract Tests")
struct CGContextRendererContractTests {
    private enum Operation: Sendable {
        case fill(bounds: CGRect, alpha: CGFloat, blendMode: CGBlendMode, rule: CGPathFillRule, clipRules: [CGPathFillRule], shadowBlur: CGFloat, shouldAntialias: Bool)
        case stroke(bounds: CGRect, lineWidth: CGFloat, lineCap: CGLineCap, lineJoin: CGLineJoin, dashPhase: CGFloat, dashLengths: [CGFloat], alpha: CGFloat, blendMode: CGBlendMode, clipRules: [CGPathFillRule])
        case drawImage(rect: CGRect, alpha: CGFloat, blendMode: CGBlendMode, interpolationQuality: CGInterpolationQuality, clipRules: [CGPathFillRule])
        case clear(rect: CGRect, clipRules: [CGPathFillRule], shouldAntialias: Bool)
        case linearGradient(start: CGPoint, end: CGPoint, options: CGGradientDrawingOptions)
        case radialGradient(startCenter: CGPoint, startRadius: CGFloat, endCenter: CGPoint, endRadius: CGFloat, options: CGGradientDrawingOptions)
        case layer(rect: CGRect, alpha: CGFloat, blendMode: CGBlendMode, interpolationQuality: CGInterpolationQuality, clipRules: [CGPathFillRule])
    }

    private final class RecordingRenderer: CGContextStatefulRendererDelegate, CGLayerRendererDelegate {
        private let operations = Mutex<[Operation]>([])
        private let drawingStates = Mutex<[CGDrawingState]>([])

        func snapshot() -> [Operation] {
            operations.withLock { $0 }
        }

        func stateSnapshot() -> [CGDrawingState] {
            drawingStates.withLock { $0 }
        }

        func fill(path: CGPath, color: CGColor, alpha: CGFloat, blendMode: CGBlendMode, rule: CGPathFillRule) {}

        func stroke(
            path: CGPath,
            color: CGColor,
            lineWidth: CGFloat,
            lineCap: CGLineCap,
            lineJoin: CGLineJoin,
            miterLimit: CGFloat,
            dashPhase: CGFloat,
            dashLengths: [CGFloat],
            alpha: CGFloat,
            blendMode: CGBlendMode
        ) {}

        func clear(rect: CGRect) {}

        func draw(
            image: CGImage,
            in rect: CGRect,
            alpha: CGFloat,
            blendMode: CGBlendMode,
            interpolationQuality: CGInterpolationQuality
        ) {}

        func drawLinearGradient(
            _ gradient: CGGradient,
            start: CGPoint,
            end: CGPoint,
            options: CGGradientDrawingOptions
        ) {}

        func drawRadialGradient(
            _ gradient: CGGradient,
            startCenter: CGPoint,
            startRadius: CGFloat,
            endCenter: CGPoint,
            endRadius: CGFloat,
            options: CGGradientDrawingOptions
        ) {}

        func draw(
            layer: CGLayer,
            in rect: CGRect,
            alpha: CGFloat,
            blendMode: CGBlendMode,
            interpolationQuality: CGInterpolationQuality,
            state: CGDrawingState
        ) {
            operations.withLock {
                $0.append(
                    .layer(
                        rect: rect,
                        alpha: alpha,
                        blendMode: blendMode,
                        interpolationQuality: interpolationQuality,
                        clipRules: state.clipPaths.map(\.rule)
                    )
                )
            }
        }

        func drawShading(_ shading: CGShading, alpha: CGFloat, blendMode: CGBlendMode) {}

        func fillWithPattern(
            path: CGPath,
            pattern: CGPattern,
            patternSpace: CGColorSpace,
            colorComponents: [CGFloat]?,
            patternPhase: CGSize,
            alpha: CGFloat,
            blendMode: CGBlendMode,
            rule: CGPathFillRule
        ) {}

        func strokeWithPattern(
            path: CGPath,
            pattern: CGPattern,
            patternSpace: CGColorSpace,
            colorComponents: [CGFloat]?,
            patternPhase: CGSize,
            lineWidth: CGFloat,
            lineCap: CGLineCap,
            lineJoin: CGLineJoin,
            miterLimit: CGFloat,
            dashPhase: CGFloat,
            dashLengths: [CGFloat],
            alpha: CGFloat,
            blendMode: CGBlendMode
        ) {}

        func fill(path: CGPath, color: CGColor, alpha: CGFloat, blendMode: CGBlendMode, rule: CGPathFillRule, state: CGDrawingState) {
            drawingStates.withLock { $0.append(state) }
            operations.withLock {
                $0.append(
                    .fill(
                        bounds: path.boundingBox,
                        alpha: alpha,
                        blendMode: blendMode,
                        rule: rule,
                        clipRules: state.clipPaths.map(\.rule),
                        shadowBlur: state.shadowBlur,
                        shouldAntialias: state.shouldAntialias
                    )
                )
            }
        }

        func stroke(
            path: CGPath,
            color: CGColor,
            lineWidth: CGFloat,
            lineCap: CGLineCap,
            lineJoin: CGLineJoin,
            miterLimit: CGFloat,
            dashPhase: CGFloat,
            dashLengths: [CGFloat],
            alpha: CGFloat,
            blendMode: CGBlendMode,
            state: CGDrawingState
        ) {
            operations.withLock {
                $0.append(
                    .stroke(
                        bounds: path.boundingBox,
                        lineWidth: lineWidth,
                        lineCap: lineCap,
                        lineJoin: lineJoin,
                        dashPhase: dashPhase,
                        dashLengths: dashLengths,
                        alpha: alpha,
                        blendMode: blendMode,
                        clipRules: state.clipPaths.map(\.rule)
                    )
                )
            }
        }

        func clear(rect: CGRect, state: CGDrawingState) {
            operations.withLock {
                $0.append(
                    .clear(
                        rect: rect,
                        clipRules: state.clipPaths.map(\.rule),
                        shouldAntialias: state.shouldAntialias
                    )
                )
            }
        }

        func draw(
            image: CGImage,
            in rect: CGRect,
            alpha: CGFloat,
            blendMode: CGBlendMode,
            interpolationQuality: CGInterpolationQuality,
            state: CGDrawingState
        ) {
            operations.withLock {
                $0.append(
                    .drawImage(
                        rect: rect,
                        alpha: alpha,
                        blendMode: blendMode,
                        interpolationQuality: interpolationQuality,
                        clipRules: state.clipPaths.map(\.rule)
                    )
                )
            }
        }

        func drawLinearGradient(
            _ gradient: CGGradient,
            start: CGPoint,
            end: CGPoint,
            options: CGGradientDrawingOptions,
            state: CGDrawingState
        ) {
            operations.withLock {
                $0.append(.linearGradient(start: start, end: end, options: options))
            }
        }

        func drawRadialGradient(
            _ gradient: CGGradient,
            startCenter: CGPoint,
            startRadius: CGFloat,
            endCenter: CGPoint,
            endRadius: CGFloat,
            options: CGGradientDrawingOptions,
            state: CGDrawingState
        ) {
            operations.withLock {
                $0.append(
                    .radialGradient(
                        startCenter: startCenter,
                        startRadius: startRadius,
                        endCenter: endCenter,
                        endRadius: endRadius,
                        options: options
                    )
                )
            }
        }
    }

    private func createContext(width: Int = 64, height: Int = 64) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )
    }

    private func createImage(width: Int = 2, height: Int = 2) -> CGImage? {
        let provider = CGDataProvider(data: Data(repeating: 0x80, count: width * height * 4))
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private func expectApproximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 0.001) {
        #expect(abs(lhs - rhs) < tolerance)
    }

    @Test("CGLayer drawing stays on the renderer path and preserves graphics state")
    func layerDrawingPreservesState() throws {
        let context = try #require(createContext())
        let layer = try #require(CGLayer(context: context, size: CGSize(width: 8, height: 6)))
        let renderer = RecordingRenderer()
        context.rendererDelegate = renderer
        context.translateBy(x: 10, y: 20)
        context.setAlpha(0.4)
        context.setBlendMode(.multiply)
        context.setInterpolationQuality(.none)
        context.addRect(CGRect(x: 0, y: 0, width: 50, height: 50))
        context.clip()

        context.draw(layer, in: CGRect(x: 2, y: 3, width: 8, height: 6))

        let operations = renderer.snapshot()
        #expect(operations.count == 1)
        guard case let .layer(rect, alpha, blendMode, interpolationQuality, clipRules) = operations[0] else {
            Issue.record("Expected a layer operation")
            return
        }
        #expect(rect == CGRect(x: 12, y: 23, width: 8, height: 6))
        #expect(alpha == 0.4)
        #expect(blendMode == .multiply)
        #expect(interpolationQuality == .none)
        #expect(clipRules == [.winding])
    }

    @Test("Renderer readback failure is not replaced by stale context storage")
    func rendererReadbackFailureIsExplicit() async throws {
        let context = try #require(createContext(width: 2, height: 2))
        let renderer = RecordingRenderer()
        context.rendererDelegate = renderer

        #expect(context.makeImage() != nil)
        #expect(await context.makeImageAsync() == nil)
    }

    @Test("Rendering intent is part of the saved graphics state")
    func renderingIntentIsSavedAndRestored() throws {
        let context = try #require(createContext())
        let renderer = RecordingRenderer()
        context.rendererDelegate = renderer

        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        context.saveGState()
        context.setRenderingIntent(.saturation)
        context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
        context.restoreGState()
        context.fill(CGRect(x: 2, y: 0, width: 1, height: 1))

        let states = renderer.stateSnapshot()
        #expect(states.count == 3)
        #expect(states[0].renderingIntent == .defaultIntent)
        #expect(states[1].renderingIntent == .saturation)
        #expect(states[2].renderingIntent == .defaultIntent)
        #expect(states.allSatisfy { $0.destinationColorSpace == .deviceRGB })
    }

    @Test("Aggregated drawing operations preserve transformed parameters and state")
    func aggregatedDrawingOperationsPreserveState() {
        guard let context = createContext(),
              let image = createImage(),
              let gradient = CGGradient(colors: [.black, .white], locations: [0.0, 1.0]) else {
            #expect(Bool(false), "Failed to create aggregated test fixtures")
            return
        }

        let renderer = RecordingRenderer()
        context.rendererDelegate = renderer

        context.translateBy(x: 10, y: 20)
        context.beginPath()
        context.addRect(CGRect(x: 0, y: 0, width: 12, height: 8))
        context.clip(using: .evenOdd)
        context.setShadow(offset: CGSize(width: 2, height: 3), blur: 4, color: CGColor(gray: 0, alpha: 0.5))
        context.setShouldAntialias(false)
        context.setAlpha(0.25)
        context.setBlendMode(.multiply)
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 2, y: 3, width: 4, height: 5))

        context.setLineWidth(7)
        context.setLineCap(.round)
        context.setLineJoin(.bevel)
        context.setLineDash(phase: 1, lengths: [2, 3])
        context.stroke(CGRect(x: 1, y: 2, width: 3, height: 4))

        context.setInterpolationQuality(.high)
        context.draw(image, in: CGRect(x: 5, y: 6, width: 7, height: 8))
        context.clear(CGRect(x: 9, y: 10, width: 11, height: 12))

        context.scaleBy(x: 2, y: 3)
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 1, y: 2),
            end: CGPoint(x: 4, y: 5),
            options: [.drawsAfterEndLocation]
        )
        context.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: 2, y: 3),
            startRadius: 2,
            endCenter: CGPoint(x: 6, y: 7),
            endRadius: 5,
            options: [.drawsBeforeStartLocation]
        )

        let operations = renderer.snapshot()
        #expect(operations.count == 6)

        guard case let .fill(bounds, alpha, blendMode, rule, clipRules, shadowBlur, shouldAntialias) = operations[0] else {
            #expect(Bool(false), "Expected fill operation")
            return
        }
        #expect(bounds == CGRect(x: 12, y: 23, width: 4, height: 5))
        #expect(alpha == 0.25)
        #expect(blendMode == .multiply)
        #expect(rule == .winding)
        #expect(clipRules == [.evenOdd])
        #expect(shadowBlur == 4)
        #expect(shouldAntialias == false)

        guard case let .stroke(bounds, lineWidth, lineCap, lineJoin, dashPhase, dashLengths, alpha, blendMode, clipRules) = operations[1] else {
            #expect(Bool(false), "Expected stroke operation")
            return
        }
        #expect(bounds == CGRect(x: 11, y: 22, width: 3, height: 4))
        #expect(lineWidth == 7)
        #expect(lineCap == .round)
        #expect(lineJoin == .bevel)
        #expect(dashPhase == 1)
        #expect(dashLengths == [2, 3])
        #expect(alpha == 0.25)
        #expect(blendMode == .multiply)
        #expect(clipRules == [.evenOdd])

        guard case let .drawImage(rect, alpha, blendMode, interpolationQuality, clipRules) = operations[2] else {
            #expect(Bool(false), "Expected image draw operation")
            return
        }
        #expect(rect == CGRect(x: 15, y: 26, width: 7, height: 8))
        #expect(alpha == 0.25)
        #expect(blendMode == .multiply)
        #expect(interpolationQuality == .high)
        #expect(clipRules == [.evenOdd])

        guard case let .clear(rect, clipRules, shouldAntialias) = operations[3] else {
            #expect(Bool(false), "Expected clear operation")
            return
        }
        #expect(rect == CGRect(x: 19, y: 30, width: 11, height: 12))
        #expect(clipRules == [.evenOdd])
        #expect(shouldAntialias == false)

        guard case let .linearGradient(start, end, options) = operations[4] else {
            #expect(Bool(false), "Expected linear gradient operation")
            return
        }
        #expect(start == CGPoint(x: 12, y: 26))
        #expect(end == CGPoint(x: 18, y: 35))
        #expect(options == [.drawsAfterEndLocation])

        guard case let .radialGradient(startCenter, startRadius, endCenter, endRadius, options) = operations[5] else {
            #expect(Bool(false), "Expected radial gradient operation")
            return
        }
        #expect(startCenter == CGPoint(x: 14, y: 29))
        #expect(endCenter == CGPoint(x: 22, y: 41))
        let averageScale = CGFloat(sqrt(6.0))
        expectApproximatelyEqual(startRadius, averageScale * 2)
        expectApproximatelyEqual(endRadius, averageScale * 5)
        #expect(options == [.drawsBeforeStartLocation])
    }

    @Test("Clip stack preserves rule order across later drawing calls")
    func clipStackPreservesRuleOrder() {
        guard let context = createContext() else {
            #expect(Bool(false), "Failed to create context")
            return
        }

        let renderer = RecordingRenderer()
        context.rendererDelegate = renderer

        context.beginPath()
        context.addRect(CGRect(x: 0, y: 0, width: 30, height: 30))
        context.clip(using: .winding)

        context.beginPath()
        context.addRect(CGRect(x: 5, y: 5, width: 10, height: 10))
        context.clip(using: .evenOdd)

        context.fill(CGRect(x: 1, y: 1, width: 2, height: 2))

        let operations = renderer.snapshot()
        #expect(operations.count == 1)

        guard case let .fill(_, _, _, _, clipRules, _, _) = operations[0] else {
            #expect(Bool(false), "Expected fill operation")
            return
        }
        #expect(clipRules == [.winding, .evenOdd])
    }
}
