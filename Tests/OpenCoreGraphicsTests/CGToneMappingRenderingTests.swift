//
//  CGToneMappingRenderingTests.swift
//  OpenCoreGraphics
//

import Foundation
import Testing
@testable import OpenCoreGraphics

private typealias CGContext = OpenCoreGraphics.CGContext
private typealias CGImage = OpenCoreGraphics.CGImage
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace
private typealias CGBitmapInfo = OpenCoreGraphics.CGBitmapInfo
private typealias CGImageAlphaInfo = OpenCoreGraphics.CGImageAlphaInfo
private typealias CGToneMapping = OpenCoreGraphics.CGToneMapping

@Suite("CG tone mapping rendering")
struct CGToneMappingRenderingTests {
    @Test("Reference-white mapping renders extended linear pixels")
    func referenceWhiteMapping() {
        let image = makeExtendedLinearImage(values: [0.5, 1, 2, 4], headroom: 4)
        #expect(image != nil)
        guard let image else { return }

        var output = [UInt8](repeating: 0, count: 16)
        let result = output.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = makeSDRContext(buffer.baseAddress, width: 4) else { return false }
            return context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: 4, height: 1),
                by: .referenceWhiteBased,
                options: nil
            )
        }

        #expect(result)
        let expectedAppleLuma: [Int] = [148, 198, 233, 255]
        for pixel in 0..<4 {
            let offset = pixel * 4
            #expect(abs(Int(output[offset]) - expectedAppleLuma[pixel]) <= 6)
            #expect(output[offset] == output[offset + 1])
            #expect(output[offset] == output[offset + 2])
            #expect(output[offset + 3] == 255)
        }
    }

    @Test("No mapping clips extended values to SDR")
    func noMappingClips() {
        let image = makeExtendedLinearImage(values: [0.5, 1, 2, 4], headroom: 4)
        #expect(image != nil)
        guard let image else { return }

        var output = [UInt8](repeating: 0, count: 16)
        let result = output.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = makeSDRContext(buffer.baseAddress, width: 4) else { return false }
            return context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: 4, height: 1),
                by: .none,
                options: [kCGEXRToneMappingGammaExposure: "ignored for this method"]
            )
        }

        #expect(result)
        #expect(Array(output.enumerated().compactMap { $0.offset % 4 == 0 ? $0.element : nil }) == [188, 255, 255, 255])
    }

    @Test("EXR gamma validates options and applies exposure")
    func exrGammaOptions() {
        let image = makeExtendedLinearImage(values: [0.5, 1, 2, 4], headroom: 4)
        #expect(image != nil)
        guard let image else { return }

        var baseline = [UInt8](repeating: 0, count: 16)
        let baselineResult = baseline.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = makeSDRContext(buffer.baseAddress, width: 4) else { return false }
            return context.draw(image, in: CGRect(x: 0, y: 0, width: 4, height: 1), by: .exrGamma, options: nil)
        }
        #expect(baselineResult)
        let expectedAppleLuma: [Int] = [130, 166, 202, 237]
        for pixel in 0..<4 {
            #expect(abs(Int(baseline[pixel * 4]) - expectedAppleLuma[pixel]) <= 5)
        }

        var exposed = [UInt8](repeating: 0, count: 16)
        let exposureResult = exposed.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = makeSDRContext(buffer.baseAddress, width: 4) else { return false }
            return context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: 4, height: 1),
                by: .exrGamma,
                options: [kCGEXRToneMappingGammaExposure: 1.0]
            )
        }
        #expect(exposureResult)
        #expect(exposed[0] > baseline[0])

        var rejected = [UInt8](repeating: 0, count: 16)
        let invalidResult = rejected.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = makeSDRContext(buffer.baseAddress, width: 4) else { return false }
            return context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: 4, height: 1),
                by: .exrGamma,
                options: [kCGEXRToneMappingGammaExposure: 11.0]
            )
        }
        #expect(!invalidResult)
        #expect(rejected.allSatisfy { $0 == 0 })
    }

    @Test("Context tone-mapping state controls ordinary image drawing")
    func contextToneMappingState() {
        let image = makeExtendedLinearImage(values: [0.5, 1, 2, 4], headroom: 4)
        #expect(image != nil)
        guard let image else { return }

        var output = [UInt8](repeating: 0, count: 16)
        output.withUnsafeMutableBytes { buffer in
            guard let context = makeSDRContext(buffer.baseAddress, width: 4) else { return }
            context.contentToneMappingInfo = .exrGamma(.init())
            context.draw(image, in: CGRect(x: 0, y: 0, width: 4, height: 1))
        }

        let expectedAppleLuma: [Int] = [130, 166, 202, 237]
        for pixel in 0..<4 {
            #expect(abs(Int(output[pixel * 4]) - expectedAppleLuma[pixel]) <= 5)
        }
    }

    @Test("Image-specific mapping does not treat HDR statistics as a gain map")
    func imageSpecificRequiresGainMap() {
        let image = makeExtendedLinearImage(values: [1], headroom: 4)
        #expect(image != nil)
        guard let image else { return }
        #expect(!image.containsImageSpecificToneMappingMetadata)

        var output = [UInt8](repeating: 0, count: 4)
        let result = output.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = makeSDRContext(buffer.baseAddress, width: 1) else { return false }
            return context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: 1, height: 1),
                by: .imageSpecificLumaScaling,
                options: nil
            )
        }
        #expect(!result)
        #expect(output == [0, 0, 0, 0])
    }

    @Test("EDR headroom reports unsupported and supported context formats")
    func edrTargetHeadroomContract() {
        var sdr = [UInt8](repeating: 0, count: 4)
        sdr.withUnsafeMutableBytes { buffer in
            let context = makeSDRContext(buffer.baseAddress, width: 1)
            #expect(context != nil)
            #expect(context?.setEDRTargetHeadroom(4) == false)
        }

        let extended = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        #expect(extended != nil)
        guard let extended else { return }
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 16,
            bytesPerRow: 8,
            space: extended,
            bitmapInfo: CGBitmapInfo(rawValue:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.floatComponents.rawValue
                | CGBitmapInfo.byteOrder16Little.rawValue)
        )
        #expect(context != nil)
        #expect(context?.setEDRTargetHeadroom(.nan) == true)
        #expect(context?.setEDRTargetHeadroom(0.5) == true)
        #expect(context?.setEDRTargetHeadroom(4) == true)
    }

    private func makeExtendedLinearImage(values: [Float16], headroom: Float) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else { return nil }
        var data = Data()
        for value in values {
            for component in [value, value, value, Float16(1)] {
                var bits = component.bitPattern.littleEndian
                withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
            }
        }
        return CGImage(
            headroom: headroom,
            width: values.count,
            height: 1,
            bitsPerComponent: 16,
            bitsPerPixel: 64,
            bytesPerRow: values.count * 8,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue:
                CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.floatComponents.rawValue
                | CGBitmapInfo.byteOrder16Little.rawValue),
            provider: CGDataProvider(data: data),
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private func makeSDRContext(_ pointer: UnsafeMutableRawPointer?, width: Int) -> CGContext? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGContext(
            data: pointer,
            width: width,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )
    }
}
