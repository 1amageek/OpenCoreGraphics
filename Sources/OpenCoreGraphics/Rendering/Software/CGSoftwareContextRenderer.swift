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
    }

    private struct RGBA {
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat
        var alpha: CGFloat
    }

    private let storage: Mutex<Storage>

    init(pointer: UnsafeMutableRawPointer, width: Int, height: Int, bytesPerRow: Int) {
        self.storage = Mutex(Storage(
            pointerAddress: UInt(bitPattern: pointer),
            width: width,
            height: height,
            bytesPerRow: bytesPerRow
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
        let source = rgba(color: color, alpha: alpha)
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
        let strokedPath = path.copy(
            strokingWithWidth: lineWidth,
            lineCap: lineCap,
            lineJoin: lineJoin,
            miterLimit: miterLimit
        )
        let source = rgba(color: color, alpha: alpha)
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
                alpha: alpha
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

            for y in minY..<maxY {
                for x in minX..<maxX {
                    let point = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                    guard isVisible(point, state: state), let source = sourceAt(point) else { continue }
                    let offset = y * storage.bytesPerRow + x * 4
                    guard let pointer = UnsafeMutableRawPointer(bitPattern: storage.pointerAddress) else { return }
                    let bytes = pointer.assumingMemoryBound(to: UInt8.self)
                    let destination = RGBA(
                        red: CGFloat(bytes[offset]) / 255,
                        green: CGFloat(bytes[offset + 1]) / 255,
                        blue: CGFloat(bytes[offset + 2]) / 255,
                        alpha: CGFloat(bytes[offset + 3]) / 255
                    )
                    let output = blend(source: source, destination: destination, mode: blendMode())
                    bytes[offset] = byte(output.red)
                    bytes[offset + 1] = byte(output.green)
                    bytes[offset + 2] = byte(output.blue)
                    bytes[offset + 3] = byte(output.alpha)
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

    private func rgba(color: CGColor, alpha: CGFloat) -> RGBA {
        let converted = color.converted(to: .deviceRGB, intent: .defaultIntent, options: nil) ?? color
        let components = converted.components ?? [0, 0, 0, 1]
        if components.count >= 4 {
            return RGBA(
                red: components[0],
                green: components[1],
                blue: components[2],
                alpha: components[3] * alpha
            )
        }
        let gray = components.first ?? 0
        return RGBA(red: gray, green: gray, blue: gray, alpha: (components.last ?? 1) * alpha)
    }

    private func sample(
        image: CGImage,
        data: Data,
        u: CGFloat,
        v: CGFloat,
        linear: Bool,
        alpha: CGFloat
    ) -> RGBA? {
        guard image.bitsPerComponent == 8 else { return nil }
        let x = min(max(u, 0), 1) * CGFloat(max(image.width - 1, 0))
        let y = (1 - min(max(v, 0), 1)) * CGFloat(max(image.height - 1, 0))
        if !linear {
            return decode(image: image, data: data, x: Int(x.rounded()), y: Int(y.rounded()), alpha: alpha)
        }
        let x0 = Int(floor(x)), y0 = Int(floor(y))
        let x1 = min(x0 + 1, image.width - 1), y1 = min(y0 + 1, image.height - 1)
        guard let c00 = decode(image: image, data: data, x: x0, y: y0, alpha: alpha),
              let c10 = decode(image: image, data: data, x: x1, y: y0, alpha: alpha),
              let c01 = decode(image: image, data: data, x: x0, y: y1, alpha: alpha),
              let c11 = decode(image: image, data: data, x: x1, y: y1, alpha: alpha) else { return nil }
        return interpolate(
            interpolate(c00, c10, t: x - CGFloat(x0)),
            interpolate(c01, c11, t: x - CGFloat(x0)),
            t: y - CGFloat(y0)
        )
    }

    private func decode(image: CGImage, data: Data, x: Int, y: Int, alpha: CGFloat) -> RGBA? {
        guard x >= 0, x < image.width, y >= 0, y < image.height else { return nil }
        let bytesPerPixel = image.bitsPerPixel / 8
        guard bytesPerPixel == 3 || bytesPerPixel == 4 else { return nil }
        let offset = y * image.bytesPerRow + x * bytesPerPixel
        guard offset + bytesPerPixel <= data.count else { return nil }
        return data.withUnsafeBytes { raw -> RGBA? in
            guard let bytes = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            let firstAlpha = bytesPerPixel == 4 && (
                image.alphaInfo == .premultipliedFirst || image.alphaInfo == .first || image.alphaInfo == .noneSkipFirst
            )
            let redIndex = firstAlpha ? 1 : 0
            let imageAlpha: CGFloat
            if bytesPerPixel == 4 {
                imageAlpha = CGFloat(bytes[offset + (firstAlpha ? 0 : 3)]) / 255
            } else {
                imageAlpha = 1
            }
            return RGBA(
                red: CGFloat(bytes[offset + redIndex]) / 255,
                green: CGFloat(bytes[offset + redIndex + 1]) / 255,
                blue: CGFloat(bytes[offset + redIndex + 2]) / 255,
                alpha: imageAlpha * alpha
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

    private func byte(_ value: CGFloat) -> UInt8 {
        UInt8((min(max(value, 0), 1) * 255).rounded())
    }
}
