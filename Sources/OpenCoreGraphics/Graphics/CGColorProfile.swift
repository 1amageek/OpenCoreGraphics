//
//  CGColorProfile.swift
//  OpenCoreGraphics
//

import Foundation

internal struct CGColorVector: Hashable, Sendable {
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat

    static let d50 = CGColorVector(x: 0.9642, y: 1.0, z: 0.8249)
    static let d60 = CGColorVector(x: 0.952646, y: 1.0, z: 1.008825)
    static let d65 = CGColorVector(x: 0.95047, y: 1.0, z: 1.08883)

    static func * (lhs: CGColorVector, rhs: CGFloat) -> CGColorVector {
        CGColorVector(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }
}

internal struct CGColorMatrix: Hashable, Sendable {
    let m00: CGFloat
    let m01: CGFloat
    let m02: CGFloat
    let m10: CGFloat
    let m11: CGFloat
    let m12: CGFloat
    let m20: CGFloat
    let m21: CGFloat
    let m22: CGFloat

    static let identity = CGColorMatrix(
        m00: 1, m01: 0, m02: 0,
        m10: 0, m11: 1, m12: 0,
        m20: 0, m21: 0, m22: 1
    )

    func applying(to value: CGColorVector) -> CGColorVector {
        CGColorVector(
            x: m00 * value.x + m01 * value.y + m02 * value.z,
            y: m10 * value.x + m11 * value.y + m12 * value.z,
            z: m20 * value.x + m21 * value.y + m22 * value.z
        )
    }

    func concatenating(_ rhs: CGColorMatrix) -> CGColorMatrix {
        CGColorMatrix(
            m00: m00 * rhs.m00 + m01 * rhs.m10 + m02 * rhs.m20,
            m01: m00 * rhs.m01 + m01 * rhs.m11 + m02 * rhs.m21,
            m02: m00 * rhs.m02 + m01 * rhs.m12 + m02 * rhs.m22,
            m10: m10 * rhs.m00 + m11 * rhs.m10 + m12 * rhs.m20,
            m11: m10 * rhs.m01 + m11 * rhs.m11 + m12 * rhs.m21,
            m12: m10 * rhs.m02 + m11 * rhs.m12 + m12 * rhs.m22,
            m20: m20 * rhs.m00 + m21 * rhs.m10 + m22 * rhs.m20,
            m21: m20 * rhs.m01 + m21 * rhs.m11 + m22 * rhs.m21,
            m22: m20 * rhs.m02 + m21 * rhs.m12 + m22 * rhs.m22
        )
    }

    func inverted() -> CGColorMatrix? {
        let c00 = m11 * m22 - m12 * m21
        let c01 = m02 * m21 - m01 * m22
        let c02 = m01 * m12 - m02 * m11
        let c10 = m12 * m20 - m10 * m22
        let c11 = m00 * m22 - m02 * m20
        let c12 = m02 * m10 - m00 * m12
        let c20 = m10 * m21 - m11 * m20
        let c21 = m01 * m20 - m00 * m21
        let c22 = m00 * m11 - m01 * m10
        let determinant = m00 * c00 + m01 * c10 + m02 * c20
        guard determinant.isFinite, abs(determinant) > 1e-12 else { return nil }
        let scale = 1 / determinant
        return CGColorMatrix(
            m00: c00 * scale, m01: c01 * scale, m02: c02 * scale,
            m10: c10 * scale, m11: c11 * scale, m12: c12 * scale,
            m20: c20 * scale, m21: c21 * scale, m22: c22 * scale
        )
    }

    static func chromaticAdaptation(from source: CGColorVector, to destination: CGColorVector) -> CGColorMatrix? {
        guard source.x > 0, source.y > 0, source.z > 0,
              destination.x > 0, destination.y > 0, destination.z > 0 else {
            return nil
        }

        let bradford = CGColorMatrix(
            m00: 0.8951, m01: 0.2664, m02: -0.1614,
            m10: -0.7502, m11: 1.7135, m12: 0.0367,
            m20: 0.0389, m21: -0.0685, m22: 1.0296
        )
        guard let inverse = bradford.inverted() else { return nil }
        let sourceCone = bradford.applying(to: source)
        let destinationCone = bradford.applying(to: destination)
        guard abs(sourceCone.x) > 1e-12, abs(sourceCone.y) > 1e-12, abs(sourceCone.z) > 1e-12 else {
            return nil
        }
        let scale = CGColorMatrix(
            m00: destinationCone.x / sourceCone.x, m01: 0, m02: 0,
            m10: 0, m11: destinationCone.y / sourceCone.y, m12: 0,
            m20: 0, m21: 0, m22: destinationCone.z / sourceCone.z
        )
        return inverse.concatenating(scale).concatenating(bradford)
    }
}

internal enum CGTransferCurve: Hashable, Sendable {
    case identity
    case gamma(CGFloat)
    case sRGB
    case bt709
    case coreMedia709
    case pq
    case table([CGFloat])
    case parametric(function: UInt16, parameters: [CGFloat])

    func decoded(_ encoded: CGFloat, extended: Bool) -> CGFloat? {
        guard encoded.isFinite else { return nil }
        let sign: CGFloat = extended && encoded < 0 ? -1 : 1
        let value = extended ? abs(encoded) : min(max(encoded, 0), 1)
        let result: CGFloat
        switch self {
        case .identity:
            result = value
        case .gamma(let gamma):
            guard gamma > 0, gamma.isFinite else { return nil }
            result = pow(value, gamma)
        case .sRGB:
            result = value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        case .bt709:
            result = value < 0.081 ? value / 4.5 : pow((value + 0.099) / 1.099, 1 / 0.45)
        case .coreMedia709:
            result = value < 0.055 ? value / 16 : pow(value, 1.961)
        case .pq:
            let m1: CGFloat = 2610 / 16384
            let m2: CGFloat = 2523 / 32
            let c1: CGFloat = 3424 / 4096
            let c2: CGFloat = 2413 / 128
            let c3: CGFloat = 2392 / 128
            let powered = pow(value, 1 / m2)
            let numerator = max(powered - c1, 0)
            let denominator = c2 - c3 * powered
            guard denominator > 0 else { return nil }
            result = pow(numerator / denominator, 1 / m1) * (10_000 / 203)
        case .table(let samples):
            guard !samples.isEmpty else { return nil }
            if samples.count == 1 { result = samples[0] }
            else {
                let position = min(max(value, 0), 1) * CGFloat(samples.count - 1)
                let lower = min(Int(position), samples.count - 1)
                let upper = min(lower + 1, samples.count - 1)
                let fraction = position - CGFloat(lower)
                result = samples[lower] + (samples[upper] - samples[lower]) * fraction
            }
        case .parametric(let function, let parameters):
            guard let evaluated = Self.evaluateParametric(function: function, parameters: parameters, value: value) else {
                return nil
            }
            result = evaluated
        }
        return result.isFinite ? sign * result : nil
    }

    func encoded(_ linear: CGFloat, extended: Bool) -> CGFloat? {
        guard linear.isFinite else { return nil }
        let sign: CGFloat = extended && linear < 0 ? -1 : 1
        let value = extended ? abs(linear) : min(max(linear, 0), 1)
        let result: CGFloat
        switch self {
        case .identity:
            result = value
        case .gamma(let gamma):
            guard gamma > 0, gamma.isFinite else { return nil }
            result = pow(value, 1 / gamma)
        case .sRGB:
            result = value <= 0.0031308 ? 12.92 * value : 1.055 * pow(value, 1 / 2.4) - 0.055
        case .bt709:
            result = value < 0.018 ? 4.5 * value : 1.099 * pow(value, 0.45) - 0.099
        case .coreMedia709:
            result = value < 0.055 / 16 ? value * 16 : pow(value, 1 / 1.961)
        case .pq:
            let m1: CGFloat = 2610 / 16384
            let m2: CGFloat = 2523 / 32
            let c1: CGFloat = 3424 / 4096
            let c2: CGFloat = 2413 / 128
            let c3: CGFloat = 2392 / 128
            let powered = pow(value * (203 / 10_000), m1)
            result = pow((c1 + c2 * powered) / (1 + c3 * powered), m2)
        case .table, .parametric:
            guard let inverse = inverseByBisection(value) else { return nil }
            result = inverse
        }
        return result.isFinite ? sign * result : nil
    }

    private func inverseByBisection(_ target: CGFloat) -> CGFloat? {
        guard let first = decoded(0, extended: false),
              let last = decoded(1, extended: false),
              target >= first - 1e-7,
              target <= last + 1e-7 else {
            return nil
        }
        var lower: CGFloat = 0
        var upper: CGFloat = 1
        for _ in 0..<32 {
            let middle = (lower + upper) / 2
            guard let value = decoded(middle, extended: false) else { return nil }
            if value < target { lower = middle } else { upper = middle }
        }
        return (lower + upper) / 2
    }

    private static func evaluateParametric(function: UInt16, parameters: [CGFloat], value: CGFloat) -> CGFloat? {
        switch function {
        case 0 where parameters.count == 1:
            return pow(value, parameters[0])
        case 1 where parameters.count == 3:
            let (g, a, b) = (parameters[0], parameters[1], parameters[2])
            guard a != 0 else { return nil }
            return value >= -b / a ? pow(a * value + b, g) : 0
        case 2 where parameters.count == 4:
            let (g, a, b, c) = (parameters[0], parameters[1], parameters[2], parameters[3])
            guard a != 0 else { return nil }
            return value >= -b / a ? pow(a * value + b, g) + c : c
        case 3 where parameters.count == 5:
            let (g, a, b, c, d) = (parameters[0], parameters[1], parameters[2], parameters[3], parameters[4])
            return value >= d ? pow(a * value + b, g) : c * value
        case 4 where parameters.count == 7:
            let (g, a, b, c, d, e, f) = (
                parameters[0], parameters[1], parameters[2], parameters[3],
                parameters[4], parameters[5], parameters[6]
            )
            return value >= d ? pow(a * value + b, g) + e : c * value + f
        default:
            return nil
        }
    }

    var isValid: Bool {
        guard let start = decoded(0, extended: false), start.isFinite else { return false }
        var previous = start
        for index in 1...256 {
            guard let value = decoded(CGFloat(index) / 256, extended: false),
                  value.isFinite,
                  value + 1e-8 >= previous else {
                return false
            }
            previous = value
        }
        return true
    }
}

internal struct CGColorProfile: Hashable, Sendable {
    enum Model: Hashable, Sendable {
        case rgb(matrix: CGColorMatrix, curves: [CGTransferCurve])
        case gray(curve: CGTransferCurve)
        case hlg(matrix: CGColorMatrix, luminance: CGColorVector)
        case device(componentCount: Int)
    }

    let model: Model
    let whitePoint: CGColorVector
    let extendedRange: Bool
    let iccTransforms: CGICCTransformSet?

    init(
        model: Model,
        whitePoint: CGColorVector,
        extendedRange: Bool,
        iccTransforms: CGICCTransformSet? = nil
    ) {
        self.model = model
        self.whitePoint = whitePoint
        self.extendedRange = extendedRange
        self.iccTransforms = iccTransforms
    }

    func toPCS(_ components: [CGFloat], intent: CGColorRenderingIntent) -> CGColorVector? {
        if let iccTransforms, iccTransforms.hasToPCS(intent: intent) {
            return iccTransforms.toPCS(components, intent: intent)
        }
        let nativeXYZ: CGColorVector
        switch model {
        case .rgb(let matrix, let curves):
            guard components.count >= 3, curves.count == 3,
                  let red = curves[0].decoded(components[0], extended: extendedRange),
                  let green = curves[1].decoded(components[1], extended: extendedRange),
                  let blue = curves[2].decoded(components[2], extended: extendedRange) else {
                return nil
            }
            nativeXYZ = matrix.applying(to: CGColorVector(x: red, y: green, z: blue))
        case .gray(let curve):
            guard let gray = components.first,
                  let linear = curve.decoded(gray, extended: extendedRange) else {
                return nil
            }
            nativeXYZ = whitePoint * linear
        case .hlg(let matrix, let luminance):
            guard components.count >= 3,
                  let linear = CGHLGTransfer.decoded(
                    CGColorVector(x: components[0], y: components[1], z: components[2]),
                    luminance: luminance
                  ) else {
                return nil
            }
            nativeXYZ = matrix.applying(to: linear)
        case .device:
            return nil
        }
        guard let adaptation = CGColorMatrix.chromaticAdaptation(from: whitePoint, to: .d50) else { return nil }
        return adaptation.applying(to: nativeXYZ)
    }

    func supportsToPCS(intent: CGColorRenderingIntent) -> Bool {
        if let iccTransforms, iccTransforms.hasToPCS(intent: intent) { return true }
        switch model {
        case .rgb, .gray, .hlg: return true
        case .device: return false
        }
    }

    func fromPCS(_ pcs: CGColorVector, intent: CGColorRenderingIntent) -> [CGFloat]? {
        if let iccTransforms, iccTransforms.hasFromPCS(intent: intent) {
            return iccTransforms.fromPCS(pcs, intent: intent)
        }
        guard let adaptation = CGColorMatrix.chromaticAdaptation(from: .d50, to: whitePoint) else { return nil }
        let nativeXYZ = adaptation.applying(to: pcs)
        switch model {
        case .rgb(let matrix, let curves):
            guard curves.count == 3, let inverse = matrix.inverted() else { return nil }
            let linear = inverse.applying(to: nativeXYZ)
            guard let red = curves[0].encoded(linear.x, extended: extendedRange),
                  let green = curves[1].encoded(linear.y, extended: extendedRange),
                  let blue = curves[2].encoded(linear.z, extended: extendedRange) else {
                return nil
            }
            if extendedRange { return [red, green, blue] }
            return [min(max(red, 0), 1), min(max(green, 0), 1), min(max(blue, 0), 1)]
        case .gray(let curve):
            guard whitePoint.y > 0,
                  let gray = curve.encoded(nativeXYZ.y / whitePoint.y, extended: extendedRange) else {
                return nil
            }
            return [extendedRange ? gray : min(max(gray, 0), 1)]
        case .hlg(let matrix, let luminance):
            guard let inverse = matrix.inverted(),
                  let encoded = CGHLGTransfer.encoded(inverse.applying(to: nativeXYZ), luminance: luminance) else {
                return nil
            }
            return [encoded.x, encoded.y, encoded.z]
        case .device:
            return nil
        }
    }

    func supportsFromPCS(intent: CGColorRenderingIntent) -> Bool {
        if let iccTransforms, iccTransforms.hasFromPCS(intent: intent) { return true }
        switch model {
        case .rgb, .gray, .hlg: return true
        case .device: return false
        }
    }
}

internal enum CGNamedColorProfile {
    private static let sRGBMatrix = CGColorMatrix(
        m00: 0.4124564, m01: 0.3575761, m02: 0.1804375,
        m10: 0.2126729, m11: 0.7151522, m12: 0.0721750,
        m20: 0.0193339, m21: 0.1191920, m22: 0.9503041
    )
    private static let displayP3Matrix = CGColorMatrix(
        m00: 0.48657095, m01: 0.26566769, m02: 0.19821729,
        m10: 0.22897456, m11: 0.69173852, m12: 0.07928691,
        m20: 0, m21: 0.04511338, m22: 1.04394437
    )
    private static let genericRGBLinearMatrix = CGColorMatrix(
        m00: 0.42950898, m01: 0.32774201, m02: 0.19321900,
        m10: 0.23238173, m11: 0.67271825, m12: 0.09490014,
        m20: 0.02033629, m21: 0.11084371, m22: 0.95764996
    )
    private static let rec2020Matrix = CGColorMatrix(
        m00: 0.63695805, m01: 0.14461690, m02: 0.16888098,
        m10: 0.26270021, m11: 0.67799807, m12: 0.05930172,
        m20: 0, m21: 0.02807269, m22: 1.06098506
    )
    private static let acescgMatrix = CGColorMatrix(
        m00: 0.66245418, m01: 0.13400421, m02: 0.15618769,
        m10: 0.27222872, m11: 0.67408177, m12: 0.05368952,
        m20: -0.00557465, m21: 0.00406073, m22: 1.01033910
    )
    private static let adobeRGBMatrix = CGColorMatrix(
        m00: 0.5767309, m01: 0.1855540, m02: 0.1881852,
        m10: 0.2973769, m11: 0.6273491, m12: 0.0752741,
        m20: 0.0270343, m21: 0.0706872, m22: 0.9911085
    )
    private static let rommRGBMatrix = CGColorMatrix(
        m00: 0.7976749, m01: 0.1351917, m02: 0.0313534,
        m10: 0.2880402, m11: 0.7118741, m12: 0.0000857,
        m20: 0, m21: 0, m22: 0.8252100
    )
    private static let dciP3Matrix = CGColorMatrix(
        m00: 0.4451698, m01: 0.2771344, m02: 0.1722827,
        m10: 0.2094917, m11: 0.7215953, m12: 0.0689131,
        m20: 0, m21: 0.0470606, m22: 0.9073554
    )
    private static let dciWhite = CGColorVector(x: 0.8945869, y: 1, z: 0.9544159)

    static func profile(named name: String) -> CGColorProfile? {
        let extended = name.contains("Extended")
        let matrix: CGColorMatrix
        let white: CGColorVector
        let curve: CGTransferCurve

        switch name {
        case CGColorSpace.sRGB, "sRGB", CGColorSpace.extendedSRGB:
            (matrix, white, curve) = (sRGBMatrix, .d65, .sRGB)
        case CGColorSpace.linearSRGB, CGColorSpace.extendedLinearSRGB:
            (matrix, white, curve) = (sRGBMatrix, .d65, .identity)
        case CGColorSpace.genericRGBLinear:
            (matrix, white, curve) = (genericRGBLinearMatrix, .d65, .identity)
        case CGColorSpace.displayP3, CGColorSpace.extendedDisplayP3:
            (matrix, white, curve) = (displayP3Matrix, .d65, .sRGB)
        case CGColorSpace.linearDisplayP3, CGColorSpace.extendedLinearDisplayP3:
            (matrix, white, curve) = (displayP3Matrix, .d65, .identity)
        case CGColorSpace.displayP3_HLG:
            return hlgProfile(matrix: displayP3Matrix, luminance: CGColorVector(
                x: displayP3Matrix.m10,
                y: displayP3Matrix.m11,
                z: displayP3Matrix.m12
            ))
        case CGColorSpace.displayP3_PQ:
            (matrix, white, curve) = (displayP3Matrix, .d65, .pq)
        case CGColorSpace.itur_709:
            (matrix, white, curve) = (sRGBMatrix, .d65, .gamma(2.4))
        case CGColorSpace.coreMedia709:
            (matrix, white, curve) = (sRGBMatrix, .d65, .coreMedia709)
        case CGColorSpace.itur_709_HLG:
            return hlgProfile(matrix: sRGBMatrix, luminance: CGColorVector(x: 0.2126, y: 0.7152, z: 0.0722))
        case CGColorSpace.itur_709_PQ:
            (matrix, white, curve) = (sRGBMatrix, .d65, .pq)
        case CGColorSpace.itur_2020, CGColorSpace.extendedITUR_2020:
            (matrix, white, curve) = (rec2020Matrix, .d65, .gamma(2.4))
        case CGColorSpace.itur_2020_sRGBGamma:
            (matrix, white, curve) = (rec2020Matrix, .d65, .sRGB)
        case CGColorSpace.linearITUR_2020, CGColorSpace.extendedLinearITUR_2020:
            (matrix, white, curve) = (rec2020Matrix, .d65, .identity)
        case CGColorSpace.itur_2100_HLG:
            return hlgProfile(matrix: rec2020Matrix, luminance: CGColorVector(x: 0.2627, y: 0.6780, z: 0.0593))
        case CGColorSpace.itur_2100_PQ:
            (matrix, white, curve) = (rec2020Matrix, .d65, .pq)
        case CGColorSpace.acescgLinear:
            (matrix, white, curve) = (acescgMatrix, .d60, .identity)
        case CGColorSpace.adobeRGB1998:
            (matrix, white, curve) = (adobeRGBMatrix, .d65, .gamma(563 / 256))
        case CGColorSpace.rommrgb:
            (matrix, white, curve) = (rommRGBMatrix, .d50, .gamma(1.8))
        case CGColorSpace.dcip3:
            (matrix, white, curve) = (dciP3Matrix, dciWhite, .gamma(2.6))
        case CGColorSpace.genericGrayGamma2_2:
            return CGColorProfile(model: .gray(curve: .gamma(2.2)), whitePoint: .d50, extendedRange: false)
        case CGColorSpace.linearGray, CGColorSpace.extendedLinearGray:
            return CGColorProfile(model: .gray(curve: .identity), whitePoint: .d50, extendedRange: extended)
        case CGColorSpace.extendedGray:
            return CGColorProfile(model: .gray(curve: .gamma(2.2)), whitePoint: .d50, extendedRange: true)
        default:
            return nil
        }

        return CGColorProfile(
            model: .rgb(matrix: matrix, curves: [curve, curve, curve]),
            whitePoint: white,
            extendedRange: extended
        )
    }

    private static func hlgProfile(matrix: CGColorMatrix, luminance: CGColorVector) -> CGColorProfile {
        CGColorProfile(
            model: .hlg(matrix: matrix, luminance: luminance),
            whitePoint: .d65,
            extendedRange: false
        )
    }
}

internal enum CGICCProfileParser {
    struct Result {
        let model: CGColorSpaceModel
        let componentCount: Int
        let profile: CGColorProfile?
    }

    private struct Tag {
        let offset: Int
        let size: Int
    }

    static func parse(_ data: Data) -> Result? {
        guard data.count >= 132,
              let declaredSize = readUInt32(data, at: 0).flatMap(Int.init),
              declaredSize >= 132,
              declaredSize <= data.count,
              readUInt32(data, at: 36) == signature("acsp"),
              let colorSignature = readUInt32(data, at: 16),
              let pcsSignature = readUInt32(data, at: 20),
              let tagCountValue = readUInt32(data, at: 128) else {
            return nil
        }

        guard let colorInfo = colorModel(for: colorSignature) else { return nil }
        let tagCount = Int(tagCountValue)
        guard tagCount <= (declaredSize - 132) / 12 else { return nil }

        var tags: [UInt32: Tag] = [:]
        for index in 0..<tagCount {
            let entry = 132 + index * 12
            guard let tagSignature = readUInt32(data, at: entry),
                  let offsetValue = readUInt32(data, at: entry + 4),
                  let sizeValue = readUInt32(data, at: entry + 8) else {
                return nil
            }
            let offset = Int(offsetValue)
            let size = Int(sizeValue)
            guard tags[tagSignature] == nil,
                  offset >= 128,
                  offset.isMultiple(of: 4),
                  size >= 8,
                  offset <= declaredSize,
                  size <= declaredSize - offset else {
                return nil
            }
            tags[tagSignature] = Tag(offset: offset, size: size)
        }

        let matrixProfile: CGColorProfile?
        switch colorInfo.model {
        case .rgb where pcsSignature == signature("XYZ "):
            matrixProfile = parseRGB(data, tags: tags)
        case .monochrome where pcsSignature == signature("XYZ "):
            matrixProfile = parseGray(data, tags: tags)
        default:
            matrixProfile = nil
        }
        let profile: CGColorProfile?
        switch parseCICP(data, tag: tags[signature("cicp")], colorInfo: colorInfo) {
        case .profile(let cicpProfile):
            profile = cicpProfile
        case .invalid:
            return nil
        case .absentOrUnsupported:
            let transformResult = CGICCTransformParser.parse(
                data,
                tags: tags.mapValues { (offset: $0.offset, size: $0.size) },
                deviceComponentCount: colorInfo.count,
                pcsSignature: pcsSignature,
                mediaWhitePoint: parseXYZ(data, tag: tags[signature("wtpt")]) ?? .d50
            )
            switch transformResult {
            case .valid(let transforms):
                profile = CGColorProfile(
                    model: matrixProfile?.model ?? .device(componentCount: colorInfo.count),
                    whitePoint: .d50,
                    extendedRange: false,
                    iccTransforms: transforms
                )
            case .absent:
                profile = matrixProfile
            case .invalid:
                return nil
            }
        }
        return Result(model: colorInfo.model, componentCount: colorInfo.count, profile: profile)
    }

    private enum CICPResult {
        case absentOrUnsupported
        case profile(CGColorProfile)
        case invalid
    }

    private static func parseCICP(
        _ data: Data,
        tag: Tag?,
        colorInfo: (model: CGColorSpaceModel, count: Int)
    ) -> CICPResult {
        guard let tag else { return .absentOrUnsupported }
        guard tag.size >= 12,
              readUInt32(data, at: tag.offset) == signature("cicp"),
              data[tag.offset + 4..<tag.offset + 8].allSatisfy({ $0 == 0 }),
              colorInfo.model == .rgb,
              colorInfo.count == 3,
              data[tag.offset + 10] == 0,
              data[tag.offset + 11] <= 1 else {
            return .invalid
        }

        let primaries = data[tag.offset + 8]
        let transfer = data[tag.offset + 9]
        let name: String
        switch (primaries, transfer) {
        case (1, 18): name = CGColorSpace.itur_709_HLG
        case (9, 18): name = CGColorSpace.itur_2100_HLG
        case (12, 18): name = CGColorSpace.displayP3_HLG
        case (1, 16): name = CGColorSpace.itur_709_PQ
        case (9, 16): name = CGColorSpace.itur_2100_PQ
        case (12, 16): name = CGColorSpace.displayP3_PQ
        default: return .absentOrUnsupported
        }
        guard let profile = CGNamedColorProfile.profile(named: name) else { return .invalid }
        return .profile(profile)
    }

    private static func parseRGB(_ data: Data, tags: [UInt32: Tag]) -> CGColorProfile? {
        guard let redXYZ = parseXYZ(data, tag: tags[signature("rXYZ")]),
              let greenXYZ = parseXYZ(data, tag: tags[signature("gXYZ")]),
              let blueXYZ = parseXYZ(data, tag: tags[signature("bXYZ")]),
              let redCurve = parseCurve(data, tag: tags[signature("rTRC")]),
              let greenCurve = parseCurve(data, tag: tags[signature("gTRC")]),
              let blueCurve = parseCurve(data, tag: tags[signature("bTRC")]),
              redCurve.isValid, greenCurve.isValid, blueCurve.isValid else {
            return nil
        }
        let matrix = CGColorMatrix(
            m00: redXYZ.x, m01: greenXYZ.x, m02: blueXYZ.x,
            m10: redXYZ.y, m11: greenXYZ.y, m12: blueXYZ.y,
            m20: redXYZ.z, m21: greenXYZ.z, m22: blueXYZ.z
        )
        guard matrix.inverted() != nil else { return nil }
        return CGColorProfile(
            model: .rgb(matrix: matrix, curves: [redCurve, greenCurve, blueCurve]),
            whitePoint: .d50,
            extendedRange: false
        )
    }

    private static func parseGray(_ data: Data, tags: [UInt32: Tag]) -> CGColorProfile? {
        guard let curve = parseCurve(data, tag: tags[signature("kTRC")]), curve.isValid else { return nil }
        return CGColorProfile(model: .gray(curve: curve), whitePoint: .d50, extendedRange: false)
    }

    private static func parseXYZ(_ data: Data, tag: Tag?) -> CGColorVector? {
        guard let tag, tag.size >= 20,
              readUInt32(data, at: tag.offset) == signature("XYZ "),
              let x = readS15Fixed16(data, at: tag.offset + 8),
              let y = readS15Fixed16(data, at: tag.offset + 12),
              let z = readS15Fixed16(data, at: tag.offset + 16) else {
            return nil
        }
        return CGColorVector(x: x, y: y, z: z)
    }

    private static func parseCurve(_ data: Data, tag: Tag?) -> CGTransferCurve? {
        guard let tag, let type = readUInt32(data, at: tag.offset) else { return nil }
        switch type {
        case signature("curv"):
            guard tag.size >= 12, let countValue = readUInt32(data, at: tag.offset + 8) else { return nil }
            let count = Int(countValue)
            guard count <= (tag.size - 12) / 2 else { return nil }
            if count == 0 { return .identity }
            if count == 1 {
                guard let raw = readUInt16(data, at: tag.offset + 12) else { return nil }
                return .gamma(CGFloat(raw) / 256)
            }
            var samples: [CGFloat] = []
            samples.reserveCapacity(count)
            for index in 0..<count {
                guard let raw = readUInt16(data, at: tag.offset + 12 + index * 2) else { return nil }
                samples.append(CGFloat(raw) / 65535)
            }
            return .table(samples)
        case signature("para"):
            guard tag.size >= 16,
                  let function = readUInt16(data, at: tag.offset + 8),
                  function <= 4 else {
                return nil
            }
            let parameterCount = [1, 3, 4, 5, 7][Int(function)]
            guard tag.size >= 12 + parameterCount * 4 else { return nil }
            var parameters: [CGFloat] = []
            parameters.reserveCapacity(parameterCount)
            for index in 0..<parameterCount {
                guard let parameter = readS15Fixed16(data, at: tag.offset + 12 + index * 4) else { return nil }
                parameters.append(parameter)
            }
            return .parametric(function: function, parameters: parameters)
        default:
            return nil
        }
    }

    private static func colorModel(for signatureValue: UInt32) -> (model: CGColorSpaceModel, count: Int)? {
        switch signatureValue {
        case signature("GRAY"): return (.monochrome, 1)
        case signature("RGB "): return (.rgb, 3)
        case signature("CMYK"): return (.cmyk, 4)
        case signature("Lab "): return (.lab, 3)
        case signature("XYZ "): return (.XYZ, 3)
        default:
            let first = UInt8((signatureValue >> 24) & 0xff)
            let suffix = signatureValue & 0x00ff_ffff
            let count: Int
            if first >= 0x32 && first <= 0x39 { count = Int(first - 0x30) }
            else if first >= 0x41 && first <= 0x46 { count = Int(first - 0x41 + 10) }
            else { return nil }
            guard suffix == 0x0043_4c52, (2...15).contains(count) else { return nil }
            return (.deviceN, count)
        }
    }

    private static func signature(_ value: String) -> UInt32 {
        value.utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, offset <= data.count - 2 else { return nil }
        return UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset <= data.count - 4 else { return nil }
        return UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }

    private static func readS15Fixed16(_ data: Data, at offset: Int) -> CGFloat? {
        guard let bits = readUInt32(data, at: offset) else { return nil }
        return CGFloat(Int32(bitPattern: bits)) / 65536
    }
}
