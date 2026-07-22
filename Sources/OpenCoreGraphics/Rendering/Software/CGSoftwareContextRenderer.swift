// CGSoftwareContextRenderer.swift
// OpenCoreGraphics

import Foundation
import Synchronization

/// CPU rasterizer for bitmap CGContext instances on native test platforms.
internal final class CGSoftwareContextRenderer: CGContextStatefulRendererDelegate {
    let storesPixelsInContextBuffer = true

    private struct Storage {
        let pointerAddress: UInt
        let width: Int
        let height: Int
        let bytesPerRow: Int
        let colorSpace: CGColorSpace
        let layout: CGColorBufferConverter.Layout
    }

    private struct RGBA {
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat
        var alpha: CGFloat
    }

    private let storage: Mutex<Storage>

    init?(
        pointer: UnsafeMutableRawPointer,
        width: Int,
        height: Int,
        bitsPerComponent: Int,
        bitsPerPixel: Int,
        bytesPerRow: Int,
        colorSpace: CGColorSpace,
        bitmapInfo: CGBitmapInfo
    ) {
        let format = CGColorBufferFormat(
            version: 0,
            bitmapInfo: bitmapInfo,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow
        )
        guard let layout = CGColorBufferConverter.Layout(
            format: format,
            colorSpace: colorSpace,
            width: width
        ) else {
            return nil
        }
        self.storage = Mutex(Storage(
            pointerAddress: UInt(bitPattern: pointer),
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            colorSpace: colorSpace,
            layout: layout
        ))
    }

    func fill(
        path: CGPath,
        color: CGColor,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule
    ) {
        fill(path: path, color: color, alpha: alpha, blendMode: blendMode, rule: rule, state: CGDrawingState())
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
        blendMode: CGBlendMode
    ) {
        stroke(
            path: path,
            color: color,
            lineWidth: lineWidth,
            lineCap: lineCap,
            lineJoin: lineJoin,
            miterLimit: miterLimit,
            dashPhase: dashPhase,
            dashLengths: dashLengths,
            alpha: alpha,
            blendMode: blendMode,
            state: CGDrawingState()
        )
    }

    func fill(
        path: CGPath,
        color: CGColor,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        rule: CGPathFillRule,
        state: CGDrawingState
    ) {
        guard let source = rgba(color: color, alpha: alpha, state: state) else { return }
        rasterize(bounds: path.boundingBoxOfPath, state: state) { point in
            path.contains(point, using: rule) ? source : nil
        } blendMode: { blendMode }
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
        guard lineWidth > 0 else { return }
        let sourcePath = dashLengths.isEmpty
            ? path
            : path.copy(dashingWithPhase: dashPhase, lengths: dashLengths)
        let strokedPath = sourcePath.copy(
            strokingWithWidth: lineWidth,
            lineCap: lineCap,
            lineJoin: lineJoin,
            miterLimit: miterLimit
        )
        guard let source = rgba(color: color, alpha: alpha, state: state) else { return }
        rasterize(bounds: strokedPath.boundingBoxOfPath, state: state) { point in
            strokedPath.contains(point) ? source : nil
        } blendMode: { blendMode }
    }

    func clear(rect: CGRect, state: CGDrawingState) {
        rasterize(bounds: rect, state: state) { point in
            rect.contains(point) ? RGBA(red: 0, green: 0, blue: 0, alpha: 0) : nil
        } blendMode: { .copy }
    }

    func draw(
        image: CGImage,
        in rect: CGRect,
        alpha: CGFloat,
        blendMode: CGBlendMode,
        interpolationQuality: CGInterpolationQuality,
        state: CGDrawingState
    ) {
        guard rect.width != 0, rect.height != 0,
              let data = image.data ?? image.dataProvider?.data else { return }

        rasterize(bounds: rect.standardized, state: state) { point in
            guard rect.standardized.contains(point) else { return nil }
            let u = (point.x - rect.minX) / rect.width
            let v = (point.y - rect.minY) / rect.height
            return self.sample(
                image: image,
                data: data,
                u: u,
                v: v,
                linear: interpolationQuality != .none && image.shouldInterpolate,
                alpha: alpha,
                state: state
            )
        } blendMode: { blendMode }
    }

    private func rasterize(
        bounds: CGRect,
        state: CGDrawingState,
        sourceAt: (CGPoint) -> RGBA?,
        blendMode: () -> CGBlendMode
    ) {
        storage.withLock { storage in
            let minX = max(0, Int(floor(bounds.minX)))
            let maxX = min(storage.width, Int(ceil(bounds.maxX)))
            let minY = max(0, Int(floor(bounds.minY)))
            let maxY = min(storage.height, Int(ceil(bounds.maxY)))
            guard minX < maxX, minY < maxY else { return }
            guard let pointer = UnsafeMutableRawPointer(bitPattern: storage.pointerAddress) else {
                return
            }
            let bytes = pointer.assumingMemoryBound(to: UInt8.self)

            for y in minY..<maxY {
                for x in minX..<maxX {
                    let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                    guard isVisible(point, state: state), let source = sourceAt(point) else { continue }
                    let offset = y * storage.bytesPerRow + x * storage.layout.bytesPerPixel
                    guard let decoded = CGColorBufferConverter.decodePixel(
                        UnsafePointer(bytes),
                        offset: offset,
                        layout: storage.layout
                    ), let destination = rgba(
                        components: decoded.components,
                        alpha: decoded.alpha,
                        colorSpace: storage.colorSpace
                    ) else { continue }
                    let output = blend(source: source, destination: destination, mode: blendMode())
                    let outputComponents: [CGFloat]
                    switch storage.colorSpace.model {
                    case .rgb:
                        outputComponents = [output.red, output.green, output.blue]
                    case .monochrome:
                        outputComponents = [output.red]
                    default:
                        continue
                    }
                    _ = CGColorBufferConverter.encodePixel(
                        outputComponents,
                        alpha: output.alpha,
                        into: bytes,
                        offset: offset,
                        layout: storage.layout
                    )
                }
            }
        }
    }

    private func isVisible(_ point: CGPoint, state: CGDrawingState) -> Bool {
        for clip in state.clipPaths where !clip.path.contains(point, using: clip.rule) {
            return false
        }
        return true
    }

    private func rgba(color: CGColor, alpha: CGFloat, state: CGDrawingState) -> RGBA? {
        guard let converted = state.convertedColor(color),
              let components = converted.components else {
            return nil
        }
        guard var result = rgba(
            components: Array(components.dropLast()),
            alpha: components.last ?? 1,
            colorSpace: state.destinationColorSpace
        ) else { return nil }
        result.alpha *= alpha
        return result
    }

    private func sample(
        image: CGImage,
        data: Data,
        u: CGFloat,
        v: CGFloat,
        linear: Bool,
        alpha: CGFloat,
        state: CGDrawingState
    ) -> RGBA? {
        let x = min(max(u, 0), 1) * CGFloat(max(image.width - 1, 0))
        let y = (1 - min(max(v, 0), 1)) * CGFloat(max(image.height - 1, 0))
        if !linear {
            return decode(
                image: image,
                data: data,
                x: Int(x.rounded()),
                y: Int(y.rounded()),
                alpha: alpha,
                state: state
            )
        }
        let x0 = Int(floor(x)), y0 = Int(floor(y))
        let x1 = min(x0 + 1, image.width - 1), y1 = min(y0 + 1, image.height - 1)
        guard let c00 = decode(image: image, data: data, x: x0, y: y0, alpha: alpha, state: state),
              let c10 = decode(image: image, data: data, x: x1, y: y0, alpha: alpha, state: state),
              let c01 = decode(image: image, data: data, x: x0, y: y1, alpha: alpha, state: state),
              let c11 = decode(image: image, data: data, x: x1, y: y1, alpha: alpha, state: state) else { return nil }
        return interpolate(
            interpolate(c00, c10, t: x - CGFloat(x0)),
            interpolate(c01, c11, t: x - CGFloat(x0)),
            t: y - CGFloat(y0)
        )
    }

    private func decode(
        image: CGImage,
        data: Data,
        x: Int,
        y: Int,
        alpha: CGFloat,
        state: CGDrawingState
    ) -> RGBA? {
        guard x >= 0, x < image.width, y >= 0, y < image.height,
              let sourceSpace = image.colorSpace,
              let layout = CGColorBufferConverter.Layout(
                format: CGColorBufferFormat(
                    version: 0,
                    bitmapInfo: image.bitmapInfo,
                    bitsPerComponent: image.bitsPerComponent,
                    bitsPerPixel: image.bitsPerPixel,
                    bytesPerRow: image.bytesPerRow
              ),
                colorSpace: sourceSpace,
                width: image.width
              ) else {
            return nil
        }
        let offset = y * layout.bytesPerRow + x * layout.bytesPerPixel
        guard offset >= 0, offset + layout.bytesPerPixel <= data.count else { return nil }
        return data.withUnsafeBytes { raw -> RGBA? in
            guard let bytes = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            guard let decoded = CGColorBufferConverter.decodePixel(
                bytes,
                offset: offset,
                layout: layout
            ) else { return nil }
            let source = CGColor(
                space: sourceSpace,
                componentArray: decoded.components + [decoded.alpha]
            )
            guard let converted = state.convertedColor(source, forSampledImage: true),
                  let components = converted.components,
                  let result = rgba(
                    components: Array(components.dropLast()),
                    alpha: components.last ?? decoded.alpha,
                    colorSpace: state.destinationColorSpace
                  ) else {
                return nil
            }
            return RGBA(
                red: result.red,
                green: result.green,
                blue: result.blue,
                alpha: result.alpha * alpha
            )
        }
    }

    private func interpolate(_ lhs: RGBA, _ rhs: RGBA, t: CGFloat) -> RGBA {
        RGBA(
            red: lhs.red + (rhs.red - lhs.red) * t,
            green: lhs.green + (rhs.green - lhs.green) * t,
            blue: lhs.blue + (rhs.blue - lhs.blue) * t,
            alpha: lhs.alpha + (rhs.alpha - lhs.alpha) * t
        )
    }

    private func blend(source: RGBA, destination: RGBA, mode: CGBlendMode) -> RGBA {
        if mode == .clear { return RGBA(red: 0, green: 0, blue: 0, alpha: 0) }
        if mode == .copy { return source }

        let blendedRGB: (CGFloat, CGFloat, CGFloat)
        switch mode {
        case .multiply:
            blendedRGB = (source.red * destination.red, source.green * destination.green, source.blue * destination.blue)
        case .screen:
            blendedRGB = (
                1 - (1 - source.red) * (1 - destination.red),
                1 - (1 - source.green) * (1 - destination.green),
                1 - (1 - source.blue) * (1 - destination.blue)
            )
        case .darken:
            blendedRGB = (min(source.red, destination.red), min(source.green, destination.green), min(source.blue, destination.blue))
        case .lighten:
            blendedRGB = (max(source.red, destination.red), max(source.green, destination.green), max(source.blue, destination.blue))
        case .difference:
            blendedRGB = (abs(destination.red - source.red), abs(destination.green - source.green), abs(destination.blue - source.blue))
        case .exclusion:
            blendedRGB = (
                destination.red + source.red - 2 * destination.red * source.red,
                destination.green + source.green - 2 * destination.green * source.green,
                destination.blue + source.blue - 2 * destination.blue * source.blue
            )
        case .plusLighter:
            blendedRGB = (min(1, source.red + destination.red), min(1, source.green + destination.green), min(1, source.blue + destination.blue))
        case .plusDarker:
            blendedRGB = (max(0, source.red + destination.red - 1), max(0, source.green + destination.green - 1), max(0, source.blue + destination.blue - 1))
        default:
            blendedRGB = (source.red, source.green, source.blue)
        }

        let sourceAlpha = min(max(source.alpha, 0), 1)
        let destinationAlpha = min(max(destination.alpha, 0), 1)
        let outputAlpha = sourceAlpha + destinationAlpha * (1 - sourceAlpha)
        guard outputAlpha > 0 else { return RGBA(red: 0, green: 0, blue: 0, alpha: 0) }
        return RGBA(
            red: (blendedRGB.0 * sourceAlpha + destination.red * destinationAlpha * (1 - sourceAlpha)) / outputAlpha,
            green: (blendedRGB.1 * sourceAlpha + destination.green * destinationAlpha * (1 - sourceAlpha)) / outputAlpha,
            blue: (blendedRGB.2 * sourceAlpha + destination.blue * destinationAlpha * (1 - sourceAlpha)) / outputAlpha,
            alpha: outputAlpha
        )
    }

    private func rgba(
        components: [CGFloat],
        alpha: CGFloat,
        colorSpace: CGColorSpace
    ) -> RGBA? {
        switch colorSpace.model {
        case .rgb where components.count == 3:
            return RGBA(
                red: components[0],
                green: components[1],
                blue: components[2],
                alpha: alpha
            )
        case .monochrome where components.count == 1:
            return RGBA(
                red: components[0],
                green: components[0],
                blue: components[0],
                alpha: alpha
            )
        default:
            return nil
        }
    }
}
