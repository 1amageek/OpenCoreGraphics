//
//  CGImageMaskClipTests.swift
//  OpenCoreGraphics
//

import Foundation
import Synchronization
import Testing
@testable import OpenCoreGraphics

private typealias CGAffineTransform = OpenCoreGraphics.CGAffineTransform
private typealias CGBitmapInfo = OpenCoreGraphics.CGBitmapInfo
private typealias CGBlendMode = OpenCoreGraphics.CGBlendMode
private typealias CGColor = OpenCoreGraphics.CGColor
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace
private typealias CGContext = OpenCoreGraphics.CGContext
private typealias CGGradient = OpenCoreGraphics.CGGradient
private typealias CGGradientDrawingOptions = OpenCoreGraphics.CGGradientDrawingOptions
private typealias CGImage = OpenCoreGraphics.CGImage
private typealias CGImageAlphaInfo = OpenCoreGraphics.CGImageAlphaInfo
private typealias CGInterpolationQuality = OpenCoreGraphics.CGInterpolationQuality
private typealias CGLineCap = OpenCoreGraphics.CGLineCap
private typealias CGLineJoin = OpenCoreGraphics.CGLineJoin
private typealias CGPath = OpenCoreGraphics.CGPath
private typealias CGPathFillRule = OpenCoreGraphics.CGPathFillRule
private typealias CGPattern = OpenCoreGraphics.CGPattern
private typealias CGShading = OpenCoreGraphics.CGShading
private typealias CGFloat = Foundation.CGFloat
private typealias CGPoint = Foundation.CGPoint
private typealias CGRect = Foundation.CGRect
private typealias CGSize = Foundation.CGSize

@Suite("CGImage Mask Clip Tests")
struct CGImageMaskClipTests {
    private func makeMask(
        data: Data,
        width: Int,
        height: Int,
        bitsPerComponent: Int = 8,
        decode: [CGFloat]? = nil,
        shouldInterpolate: Bool = false
    ) -> CGImage? {
        let provider = CGDataProvider(data: data)
        let bitsPerRow = width * bitsPerComponent
        let bytesPerRow = (bitsPerRow + 7) / 8

        if let decode = decode {
            return decode.withUnsafeBufferPointer { buffer in
                CGImage(
                    maskWidth: width,
                    height: height,
                    bitsPerComponent: bitsPerComponent,
                    bitsPerPixel: bitsPerComponent,
                    bytesPerRow: bytesPerRow,
                    provider: provider,
                    decode: buffer.baseAddress,
                    shouldInterpolate: shouldInterpolate
                )
            }
        }

        return CGImage(
            maskWidth: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            provider: provider,
            decode: nil,
            shouldInterpolate: shouldInterpolate
        )
    }

    private func makeGrayImage(data: Data, width: Int, height: Int) -> CGImage? {
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: .deviceGray,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: CGDataProvider(data: data),
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    @Test("Image masks use inverse alpha while gray images use direct alpha")
    func maskPolarity() throws {
        let imageMask = try #require(makeMask(data: Data([0, 255]), width: 2, height: 1))
        let grayImage = try #require(makeGrayImage(data: Data([0, 255]), width: 2, height: 1))
        let rect = CGRect(x: 0, y: 0, width: 2, height: 1)

        let inverse = try #require(CGImageMaskBuffer(
            width: 2,
            height: 1,
            clips: [CGImageMaskClip(rect: rect, transform: .identity, image: imageMask)]
        ))
        let direct = try #require(CGImageMaskBuffer(
            width: 2,
            height: 1,
            clips: [CGImageMaskClip(rect: rect, transform: .identity, image: grayImage)]
        ))

        #expect(Array(inverse.rgba8) == [255, 255, 255, 255, 0, 0, 0, 0])
        #expect(Array(direct.rgba8) == [0, 0, 0, 0, 255, 255, 255, 255])
    }

    @Test("Decode arrays and successive masks compose multiplicatively")
    func decodeAndComposition() throws {
        let reversedMask = try #require(makeMask(
            data: Data([0, 255]),
            width: 2,
            height: 1,
            decode: [1, 0]
        ))
        let halfGray = try #require(makeGrayImage(data: Data([128, 128]), width: 2, height: 1))
        let rect = CGRect(x: 0, y: 0, width: 2, height: 1)
        let buffer = try #require(CGImageMaskBuffer(
            width: 2,
            height: 1,
            clips: [
                CGImageMaskClip(rect: rect, transform: .identity, image: reversedMask),
                CGImageMaskClip(rect: rect, transform: .identity, image: halfGray)
            ]
        ))

        #expect(Array(buffer.rgba8) == [0, 0, 0, 0, 128, 128, 128, 128])
    }

    @Test("Mask mapping preserves the clip-time transform")
    func transformedMapping() throws {
        let mask = try #require(makeMask(data: Data([0]), width: 1, height: 1))
        let clip = CGImageMaskClip(
            rect: CGRect(x: 0, y: 0, width: 1, height: 1),
            transform: CGAffineTransform(translationX: 1, y: 0),
            image: mask
        )
        let buffer = try #require(CGImageMaskBuffer(width: 2, height: 1, clips: [clip]))

        #expect(Array(buffer.rgba8) == [0, 0, 0, 0, 255, 255, 255, 255])
    }

    @Test("Context forwards image-mask clips without replacing them by rectangles")
    func contextStateContainsImageMask() throws {
        final class Renderer: CGContextStatefulRendererDelegate {
            private let maskClips = Mutex<[CGImageMaskClip]>([])

            func receivedMaskClips() -> [CGImageMaskClip] {
                return maskClips.withLock { $0 }
            }

            func fill(path: CGPath, color: CGColor, alpha: CGFloat, blendMode: CGBlendMode, rule: CGPathFillRule) {}
            func stroke(path: CGPath, color: CGColor, lineWidth: CGFloat, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: CGFloat, dashPhase: CGFloat, dashLengths: [CGFloat], alpha: CGFloat, blendMode: CGBlendMode) {}
            func clear(rect: CGRect) {}
            func draw(image: CGImage, in rect: CGRect, alpha: CGFloat, blendMode: CGBlendMode, interpolationQuality: CGInterpolationQuality) {}
            func drawLinearGradient(_ gradient: CGGradient, start: CGPoint, end: CGPoint, options: CGGradientDrawingOptions) {}
            func drawRadialGradient(_ gradient: CGGradient, startCenter: CGPoint, startRadius: CGFloat, endCenter: CGPoint, endRadius: CGFloat, options: CGGradientDrawingOptions) {}
            func drawShading(_ shading: CGShading, alpha: CGFloat, blendMode: CGBlendMode) {}
            func fillWithPattern(path: CGPath, pattern: CGPattern, patternSpace: CGColorSpace, colorComponents: [CGFloat]?, patternPhase: CGSize, alpha: CGFloat, blendMode: CGBlendMode, rule: CGPathFillRule) {}
            func strokeWithPattern(path: CGPath, pattern: CGPattern, patternSpace: CGColorSpace, colorComponents: [CGFloat]?, patternPhase: CGSize, lineWidth: CGFloat, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: CGFloat, dashPhase: CGFloat, dashLengths: [CGFloat], alpha: CGFloat, blendMode: CGBlendMode) {}

            func fill(path: CGPath, color: CGColor, alpha: CGFloat, blendMode: CGBlendMode, rule: CGPathFillRule, state: CGDrawingState) {
                maskClips.withLock { $0 = state.imageMaskClips }
            }
        }

        let context = try #require(CGContext(
            data: nil,
            width: 4,
            height: 4,
            bitsPerComponent: 8,
            bytesPerRow: 16,
            space: .deviceRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        ))
        let mask = try #require(makeMask(data: Data([0]), width: 1, height: 1))
        let renderer = Renderer()
        context.rendererDelegate = renderer
        context.translateBy(x: 1, y: 2)
        context.clip(to: CGRect(x: 0, y: 0, width: 2, height: 2), mask: mask)
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))

        let clips = renderer.receivedMaskClips()
        #expect(clips.count == 1)
        #expect(clips[0].rect == CGRect(x: 0, y: 0, width: 2, height: 2))
        #expect(clips[0].transform == CGAffineTransform(translationX: 1, y: 2))
    }
}
