//
//  CGColorBufferConverter.swift
//  OpenCoreGraphics
//

import Foundation

/// Converts packed color buffers through the same color model conversion used by `CGColor`.
internal struct CGColorBufferConverter {
    struct Layout {
        let componentCount: Int
        let bytesPerComponent: Int
        let bytesPerPixel: Int
        let bytesPerRow: Int
        let alphaInfo: CGImageAlphaInfo
        let isFloat: Bool
        let byteOrder: CGImageByteOrderInfo
        let colorComponentCount: Int

        var isPremultiplied: Bool {
            alphaInfo == .premultipliedFirst || alphaInfo == .premultipliedLast
        }

        var hasAlpha: Bool {
            switch alphaInfo {
            case .premultipliedFirst, .premultipliedLast, .first, .last, .alphaOnly:
                return true
            case .none, .noneSkipFirst, .noneSkipLast:
                return false
            }
        }

        init?(format: CGColorBufferFormat, colorSpace: CGColorSpace, width: Int) {
            guard format.version == 0,
                  format.bitsPerComponent > 0,
                  format.bitsPerPixel > 0,
                  format.bitsPerPixel % format.bitsPerComponent == 0,
                  format.bitsPerComponent % 8 == 0,
                  format.bitmapInfo.pixelFormat == .packed else {
                return nil
            }

            let componentCount = format.bitsPerPixel / format.bitsPerComponent
            let expectedCount: Int
            switch format.bitmapInfo.alphaInfo {
            case .none:
                expectedCount = colorSpace.numberOfComponents
            case .premultipliedFirst, .premultipliedLast, .first, .last,
                 .noneSkipFirst, .noneSkipLast:
                expectedCount = colorSpace.numberOfComponents + 1
            case .alphaOnly:
                expectedCount = 1
            }

            guard componentCount == expectedCount else { return nil }

            let isFloat = format.bitmapInfo.isFloatComponents
            if isFloat {
                guard format.bitsPerComponent == 16 || format.bitsPerComponent == 32 else { return nil }
            } else {
                guard format.bitsPerComponent == 8 || format.bitsPerComponent == 16 else { return nil }
            }

            let bytesPerComponent = format.bitsPerComponent / 8
            let bytesPerPixel = format.bitsPerPixel / 8
            let minimumBytesPerRow = width * bytesPerPixel
            let bytesPerRow = format.bytesPerRow == 0 ? minimumBytesPerRow : format.bytesPerRow
            guard bytesPerRow >= minimumBytesPerRow else { return nil }

            self.componentCount = componentCount
            self.bytesPerComponent = bytesPerComponent
            self.bytesPerPixel = bytesPerPixel
            self.bytesPerRow = bytesPerRow
            self.alphaInfo = format.bitmapInfo.alphaInfo
            self.isFloat = isFloat
            self.byteOrder = format.bitmapInfo.byteOrderInfo
            self.colorComponentCount = colorSpace.numberOfComponents
        }
    }

    static func convert(
        width: Int,
        height: Int,
        destinationBuffer: UnsafeMutableRawPointer,
        destinationFormat: CGColorBufferFormat,
        destinationColorSpace: CGColorSpace,
        sourceBuffer: UnsafeRawPointer,
        sourceFormat: CGColorBufferFormat,
        sourceColorSpace: CGColorSpace,
        intent: CGColorRenderingIntent,
        options: [String: Any]?
    ) -> Bool {
        guard width > 0,
              height > 0,
              let sourceLayout = Layout(format: sourceFormat, colorSpace: sourceColorSpace, width: width),
              let destinationLayout = Layout(format: destinationFormat, colorSpace: destinationColorSpace, width: width),
              sourceLayout.alphaInfo != .alphaOnly,
              destinationLayout.alphaInfo != .alphaOnly else {
            return false
        }

        let sourceBytes = sourceBuffer.assumingMemoryBound(to: UInt8.self)
        let destinationBytes = destinationBuffer.assumingMemoryBound(to: UInt8.self)

        for y in 0..<height {
            for x in 0..<width {
                let sourceOffset = y * sourceLayout.bytesPerRow + x * sourceLayout.bytesPerPixel
                let destinationOffset = y * destinationLayout.bytesPerRow + x * destinationLayout.bytesPerPixel

                guard let decoded = decodePixel(sourceBytes, offset: sourceOffset, layout: sourceLayout),
                      let converted = convertColor(
                        decoded.components,
                        alpha: decoded.alpha,
                        sourceColorSpace: sourceColorSpace,
                        destinationColorSpace: destinationColorSpace,
                        intent: intent,
                        options: options
                      ),
                      encodePixel(
                        converted.components,
                        alpha: converted.alpha,
                        into: destinationBytes,
                        offset: destinationOffset,
                        layout: destinationLayout
                      ) else {
                    return false
                }
            }
        }

        return true
    }

    static func decodePixel(
        _ bytes: UnsafePointer<UInt8>,
        offset: Int,
        layout: Layout
    ) -> (components: [CGFloat], alpha: CGFloat)? {
        var stored = [CGFloat]()
        stored.reserveCapacity(layout.componentCount)
        for index in 0..<layout.componentCount {
            guard let value = readComponent(
                bytes,
                offset: offset + index * layout.bytesPerComponent,
                layout: layout
            ) else {
                return nil
            }
            stored.append(value)
        }
        stored = normalizePackedByteOrder(stored, layout: layout)

        let color: [CGFloat]
        let alpha: CGFloat
        switch layout.alphaInfo {
        case .none:
            color = stored
            alpha = 1
        case .premultipliedLast, .last:
            color = Array(stored.prefix(layout.colorComponentCount))
            alpha = stored.last ?? 1
        case .premultipliedFirst, .first:
            alpha = stored.first ?? 1
            color = Array(stored.dropFirst().prefix(layout.colorComponentCount))
        case .noneSkipLast:
            color = Array(stored.prefix(layout.colorComponentCount))
            alpha = 1
        case .noneSkipFirst:
            color = Array(stored.dropFirst().prefix(layout.colorComponentCount))
            alpha = 1
        case .alphaOnly:
            return nil
        }

        guard color.count == layout.colorComponentCount else { return nil }
        if layout.isPremultiplied, alpha > 0 {
            return (color.map { $0 / alpha }, alpha)
        }
        if layout.isPremultiplied, alpha == 0 {
            return ([CGFloat](repeating: 0, count: color.count), 0)
        }
        return (color, alpha)
    }

    private static func convertColor(
        _ components: [CGFloat],
        alpha: CGFloat,
        sourceColorSpace: CGColorSpace,
        destinationColorSpace: CGColorSpace,
        intent: CGColorRenderingIntent,
        options: [String: Any]?
    ) -> (components: [CGFloat], alpha: CGFloat)? {
        if sourceColorSpace == destinationColorSpace {
            return (components, alpha)
        }

        if sourceColorSpace.isDeviceDependent,
           sourceColorSpace.model == destinationColorSpace.model,
           components.count == destinationColorSpace.numberOfComponents {
            // Device components are already expressed for the current output
            // device. The caller supplies that device as destinationColorSpace.
            return (components, alpha)
        }

        let sourceColor = CGColor(
            space: sourceColorSpace,
            componentArray: components + [alpha]
        )
        guard let destinationColor = sourceColor.converted(
            to: destinationColorSpace,
            intent: intent,
            options: options
        ), let destinationComponents = destinationColor.components,
           destinationComponents.count >= destinationColorSpace.numberOfComponents else {
            return nil
        }

        return (
            Array(destinationComponents.prefix(destinationColorSpace.numberOfComponents)),
            destinationComponents.last ?? alpha
        )
    }

    private static func encodePixel(
        _ components: [CGFloat],
        alpha: CGFloat,
        into bytes: UnsafeMutablePointer<UInt8>,
        offset: Int,
        layout: Layout
    ) -> Bool {
        guard components.count == layout.colorComponentCount else { return false }
        let encodedColor = layout.isPremultiplied ? components.map { $0 * alpha } : components
        var stored: [CGFloat]
        switch layout.alphaInfo {
        case .none:
            stored = encodedColor
        case .premultipliedLast, .last:
            stored = encodedColor + [alpha]
        case .premultipliedFirst, .first:
            stored = [alpha] + encodedColor
        case .noneSkipLast:
            stored = encodedColor + [0]
        case .noneSkipFirst:
            stored = [0] + encodedColor
        case .alphaOnly:
            return false
        }
        stored = denormalizePackedByteOrder(stored, layout: layout)

        for index in 0..<stored.count {
            guard writeComponent(
                stored[index],
                into: bytes,
                offset: offset + index * layout.bytesPerComponent,
                layout: layout
            ) else {
                return false
            }
        }
        return true
    }

    private static func normalizePackedByteOrder(_ values: [CGFloat], layout: Layout) -> [CGFloat] {
        guard layout.bitsUsePackedLittleEndian else { return values }
        return values.reversed()
    }

    private static func denormalizePackedByteOrder(_ values: [CGFloat], layout: Layout) -> [CGFloat] {
        normalizePackedByteOrder(values, layout: layout)
    }

    private static func readComponent(
        _ bytes: UnsafePointer<UInt8>,
        offset: Int,
        layout: Layout
    ) -> CGFloat? {
        if layout.isFloat {
            if layout.bytesPerComponent == 2 {
                let bits = readUInt16(bytes, offset: offset, littleEndian: layout.usesLittleEndianComponents)
                return CGFloat(Float16(bitPattern: bits))
            }
            let bits = readUInt32(bytes, offset: offset, littleEndian: layout.usesLittleEndianComponents)
            return CGFloat(Float(bitPattern: bits))
        }

        if layout.bytesPerComponent == 1 {
            return CGFloat(bytes[offset]) / 255
        }
        let value = readUInt16(bytes, offset: offset, littleEndian: layout.usesLittleEndianComponents)
        return CGFloat(value) / 65_535
    }

    private static func writeComponent(
        _ value: CGFloat,
        into bytes: UnsafeMutablePointer<UInt8>,
        offset: Int,
        layout: Layout
    ) -> Bool {
        if layout.isFloat {
            if layout.bytesPerComponent == 2 {
                writeUInt16(Float16(value).bitPattern, into: bytes, offset: offset, littleEndian: layout.usesLittleEndianComponents)
                return true
            }
            writeUInt32(Float(value).bitPattern, into: bytes, offset: offset, littleEndian: layout.usesLittleEndianComponents)
            return true
        }

        let clamped = min(max(value, 0), 1)
        if layout.bytesPerComponent == 1 {
            bytes[offset] = UInt8((clamped * 255).rounded())
            return true
        }
        writeUInt16(UInt16((clamped * 65_535).rounded()), into: bytes, offset: offset, littleEndian: layout.usesLittleEndianComponents)
        return true
    }

    private static func readUInt16(_ bytes: UnsafePointer<UInt8>, offset: Int, littleEndian: Bool) -> UInt16 {
        let first = UInt16(bytes[offset])
        let second = UInt16(bytes[offset + 1])
        return littleEndian ? first | (second << 8) : (first << 8) | second
    }

    private static func readUInt32(_ bytes: UnsafePointer<UInt8>, offset: Int, littleEndian: Bool) -> UInt32 {
        var result: UInt32 = 0
        if littleEndian {
            for index in 0..<4 { result |= UInt32(bytes[offset + index]) << UInt32(index * 8) }
        } else {
            for index in 0..<4 { result = (result << 8) | UInt32(bytes[offset + index]) }
        }
        return result
    }

    private static func writeUInt16(
        _ value: UInt16,
        into bytes: UnsafeMutablePointer<UInt8>,
        offset: Int,
        littleEndian: Bool
    ) {
        if littleEndian {
            bytes[offset] = UInt8(truncatingIfNeeded: value)
            bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
        } else {
            bytes[offset] = UInt8(truncatingIfNeeded: value >> 8)
            bytes[offset + 1] = UInt8(truncatingIfNeeded: value)
        }
    }

    private static func writeUInt32(
        _ value: UInt32,
        into bytes: UnsafeMutablePointer<UInt8>,
        offset: Int,
        littleEndian: Bool
    ) {
        for index in 0..<4 {
            let shift = littleEndian ? index * 8 : (3 - index) * 8
            bytes[offset + index] = UInt8(truncatingIfNeeded: value >> UInt32(shift))
        }
    }
}

private extension CGColorBufferConverter.Layout {
    var usesLittleEndianComponents: Bool {
        switch byteOrder {
        case .order16Little, .order32Little:
            return true
        case .order16Big, .order32Big:
            return false
        case .orderDefault:
            #if _endian(little)
            return true
            #else
            return false
            #endif
        }
    }

    var bitsUsePackedLittleEndian: Bool {
        bytesPerComponent == 1 && componentCount == 4 && byteOrder == .order32Little
    }
}
