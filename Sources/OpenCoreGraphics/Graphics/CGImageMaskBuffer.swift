//
//  CGImageMaskBuffer.swift
//  OpenCoreGraphics
//

import Foundation

/// A device-sized, multiplicatively composed image-mask clip buffer.
internal struct CGImageMaskBuffer: Sendable {
    let width: Int
    let height: Int
    let rgba8: Data

    init?(width: Int, height: Int, clips: [CGImageMaskClip]) {
        guard width > 0, height > 0, !clips.isEmpty else { return nil }

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            let deviceY = CGFloat(height) - CGFloat(row) - 0.5
            for column in 0..<width {
                let devicePoint = CGPoint(x: CGFloat(column) + 0.5, y: deviceY)
                var coverage: CGFloat = 1

                for clip in clips {
                    coverage *= Self.coverage(of: clip, at: devicePoint)
                    if coverage <= 0 { break }
                }

                let value = UInt8((min(max(coverage, 0), 1) * 255).rounded())
                let offset = (row * width + column) * 4
                bytes[offset] = value
                bytes[offset + 1] = value
                bytes[offset + 2] = value
                bytes[offset + 3] = value
            }
        }

        self.width = width
        self.height = height
        self.rgba8 = Data(bytes)
    }

    private static func coverage(of clip: CGImageMaskClip, at devicePoint: CGPoint) -> CGFloat {
        let determinant = clip.transform.a * clip.transform.d - clip.transform.b * clip.transform.c
        guard determinant != 0 else { return 0 }

        let rect = clip.rect.standardized
        guard rect.width > 0, rect.height > 0 else { return 0 }

        let userPoint = devicePoint.applying(clip.transform.inverted())
        guard userPoint.x >= rect.minX,
              userPoint.x <= rect.maxX,
              userPoint.y >= rect.minY,
              userPoint.y <= rect.maxY else {
            return 0
        }

        let u = (userPoint.x - rect.minX) / rect.width
        let v = (userPoint.y - rect.minY) / rect.height
        let sourceX = u * CGFloat(clip.image.width) - 0.5
        let sourceY = (1 - v) * CGFloat(clip.image.height) - 0.5

        let sample: CGFloat
        if clip.image.shouldInterpolate {
            sample = bilinearSample(image: clip.image, x: sourceX, y: sourceY)
        } else {
            sample = rawSample(
                image: clip.image,
                x: min(max(Int(floor(u * CGFloat(clip.image.width))), 0), clip.image.width - 1),
                y: min(max(Int(floor((1 - v) * CGFloat(clip.image.height))), 0), clip.image.height - 1)
            )
        }

        let decoded = decodedSample(sample, image: clip.image)
        return clip.image.isMask ? 1 - decoded : decoded
    }

    private static func bilinearSample(image: CGImage, x: CGFloat, y: CGFloat) -> CGFloat {
        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let x1 = x0 + 1
        let y1 = y0 + 1
        let tx = x - CGFloat(x0)
        let ty = y - CGFloat(y0)

        let s00 = rawSample(image: image, x: clamped(x0, upperBound: image.width), y: clamped(y0, upperBound: image.height))
        let s10 = rawSample(image: image, x: clamped(x1, upperBound: image.width), y: clamped(y0, upperBound: image.height))
        let s01 = rawSample(image: image, x: clamped(x0, upperBound: image.width), y: clamped(y1, upperBound: image.height))
        let s11 = rawSample(image: image, x: clamped(x1, upperBound: image.width), y: clamped(y1, upperBound: image.height))
        let top = s00 + (s10 - s00) * tx
        let bottom = s01 + (s11 - s01) * tx
        return top + (bottom - top) * ty
    }

    private static func clamped(_ value: Int, upperBound: Int) -> Int {
        return min(max(value, 0), upperBound - 1)
    }

    private static func decodedSample(_ sample: CGFloat, image: CGImage) -> CGFloat {
        guard let decode = image.decode else { return min(max(sample, 0), 1) }
        return min(max(decode[0] + sample * (decode[1] - decode[0]), 0), 1)
    }

    private static func rawSample(image: CGImage, x: Int, y: Int) -> CGFloat {
        guard let data = image.data ?? image.dataProvider?.data,
              x >= 0,
              y >= 0,
              x < image.width,
              y < image.height else {
            return 0
        }

        let bitOffset = y * image.bytesPerRow * 8 + x * image.bitsPerPixel
        return data.withUnsafeBytes { rawBuffer in
            guard let bytes = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }

            switch image.bitsPerComponent {
            case 1, 2, 4:
                let byteOffset = bitOffset / 8
                guard byteOffset < data.count else { return 0 }
                let shift = 8 - image.bitsPerComponent - (bitOffset % 8)
                guard shift >= 0 else { return 0 }
                let mask = UInt8((1 << image.bitsPerComponent) - 1)
                let value = (bytes[byteOffset] >> shift) & mask
                return CGFloat(value) / CGFloat(mask)

            case 8:
                let byteOffset = bitOffset / 8
                guard byteOffset < data.count else { return 0 }
                return CGFloat(bytes[byteOffset]) / 255

            case 16:
                let byteOffset = bitOffset / 8
                guard byteOffset + 1 < data.count else { return 0 }
                let value: UInt16
                if image.byteOrderInfo == .order16Little {
                    value = UInt16(bytes[byteOffset]) | UInt16(bytes[byteOffset + 1]) << 8
                } else {
                    value = UInt16(bytes[byteOffset]) << 8 | UInt16(bytes[byteOffset + 1])
                }
                return CGFloat(value) / CGFloat(UInt16.max)

            case 32 where image.bitmapInfo.contains(.floatComponents):
                let byteOffset = bitOffset / 8
                guard byteOffset + 3 < data.count else { return 0 }
                var bits: UInt32
                if image.byteOrderInfo == .order32Little {
                    bits = UInt32(bytes[byteOffset])
                        | UInt32(bytes[byteOffset + 1]) << 8
                        | UInt32(bytes[byteOffset + 2]) << 16
                        | UInt32(bytes[byteOffset + 3]) << 24
                } else {
                    bits = UInt32(bytes[byteOffset]) << 24
                        | UInt32(bytes[byteOffset + 1]) << 16
                        | UInt32(bytes[byteOffset + 2]) << 8
                        | UInt32(bytes[byteOffset + 3])
                }
                return CGFloat(Float(bitPattern: bits))

            default:
                return 0
            }
        }
    }
}
