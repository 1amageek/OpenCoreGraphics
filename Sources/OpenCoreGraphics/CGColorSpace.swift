//
//  CGColorSpace.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation

// MARK: - CGColorSpaceModel

/// Models for color spaces.
public enum CGColorSpaceModel: Int32, Sendable {
    /// An unknown color space model.
    case unknown = -1

    /// A monochrome color space model.
    case monochrome = 0

    /// An RGB color space model.
    case rgb = 1

    /// A CMYK color space model.
    case cmyk = 2

    /// A Lab color space model.
    case lab = 3

    /// A DeviceN color space model.
    case deviceN = 4

    /// An indexed color space model.
    case indexed = 5

    /// A pattern color space model.
    case pattern = 6

    /// An XYZ color space model.
    case XYZ = 7
}

// MARK: - CGColorRenderingIntent

/// Handling options for colors that are not located within the destination
/// color space of a graphics context.
public enum CGColorRenderingIntent: Int32, Sendable {
    /// The default rendering intent for the graphics context.
    case defaultIntent = 0
    /// Map colors outside of the gamut of the output device to the closest
    /// possible match inside the gamut of the output device.
    case absoluteColorimetric = 1
    /// Preserve the visual relationship between colors by compressing the
    /// gamut of the graphics context to fit inside the gamut of the output device.
    case relativeColorimetric = 2
    /// Preserve the relative saturation value of the colors when converting
    /// into the gamut of the output device.
    case perceptual = 3
    /// Preserve the relative saturation of colors.
    case saturation = 4
}

// MARK: - CGColorSpace

/// A profile that specifies how to interpret a color value for display.
public final class CGColorSpace: Hashable, Equatable, @unchecked Sendable {

    /// The color space model.
    public let model: CGColorSpaceModel

    /// The name of the color space.
    public let name: CFString?

    /// The number of color components in the color space.
    public let numberOfComponents: Int

    /// The base color space for indexed or pattern color spaces.
    public let baseColorSpace: CGColorSpace?

    /// The color table for indexed color spaces.
    public let colorTable: [UInt8]?

    /// ICC profile data.
    private let iccProfileData: Data?

    /// White point for calibrated color spaces.
    private let whitePoint: [CGFloat]?

    /// Black point for calibrated color spaces.
    private let blackPoint: [CGFloat]?

    /// Gamma value for calibrated grayscale color spaces.
    private let gamma: CGFloat?

    /// Internal initializer
    internal init(
        model: CGColorSpaceModel,
        name: CFString?,
        numberOfComponents: Int,
        baseColorSpace: CGColorSpace? = nil,
        colorTable: [UInt8]? = nil,
        iccProfileData: Data? = nil,
        whitePoint: [CGFloat]? = nil,
        blackPoint: [CGFloat]? = nil,
        gamma: CGFloat? = nil
    ) {
        self.model = model
        self.name = name
        self.numberOfComponents = numberOfComponents
        self.baseColorSpace = baseColorSpace
        self.colorTable = colorTable
        self.iccProfileData = iccProfileData
        self.whitePoint = whitePoint
        self.blackPoint = blackPoint
        self.gamma = gamma
    }

    // MARK: - System-Defined Color Space Names (class let)

    /// The Display P3 color space, created by Apple.
    nonisolated(unsafe) public static let displayP3: CFString = "kCGColorSpaceDisplayP3" as CFString

    /// The Display P3 color space, using the HLG transfer function.
    nonisolated(unsafe) public static let displayP3_HLG: CFString = "kCGColorSpaceDisplayP3_HLG" as CFString

    /// The Display P3 color space, using the PQ transfer function.
    nonisolated(unsafe) public static let displayP3_PQ: CFString = "kCGColorSpaceDisplayP3_PQ" as CFString

    /// The Display P3 color space with a linear transfer function and extended-range values.
    nonisolated(unsafe) public static let extendedLinearDisplayP3: CFString = "kCGColorSpaceExtendedLinearDisplayP3" as CFString

    /// The extended Display P3 color space.
    nonisolated(unsafe) public static let extendedDisplayP3: CFString = "kCGColorSpaceExtendedDisplayP3" as CFString

    /// The Display P3 color space with a linear transfer function.
    nonisolated(unsafe) public static let linearDisplayP3: CFString = "kCGColorSpaceLinearDisplayP3" as CFString

    /// The standard Red Green Blue (sRGB) color space.
    nonisolated(unsafe) public static let sRGB: CFString = "kCGColorSpaceSRGB" as CFString

    /// The sRGB color space with a linear transfer function.
    nonisolated(unsafe) public static let linearSRGB: CFString = "kCGColorSpaceLinearSRGB" as CFString

    /// The extended sRGB color space.
    nonisolated(unsafe) public static let extendedSRGB: CFString = "kCGColorSpaceExtendedSRGB" as CFString

    /// The sRGB color space with a linear transfer function and extended-range values.
    nonisolated(unsafe) public static let extendedLinearSRGB: CFString = "kCGColorSpaceExtendedLinearSRGB" as CFString

    /// The generic gray color space that has an exponential transfer function with a power of 2.2.
    nonisolated(unsafe) public static let genericGrayGamma2_2: CFString = "kCGColorSpaceGenericGrayGamma2_2" as CFString

    /// The extended gray color space.
    nonisolated(unsafe) public static let extendedGray: CFString = "kCGColorSpaceExtendedGray" as CFString

    /// The gray color space using a linear transfer function.
    nonisolated(unsafe) public static let linearGray: CFString = "kCGColorSpaceLinearGray" as CFString

    /// The extended gray color space with a linear transfer function.
    nonisolated(unsafe) public static let extendedLinearGray: CFString = "kCGColorSpaceExtendedLinearGray" as CFString

    /// The generic CMYK color space.
    nonisolated(unsafe) public static let genericCMYK: CFString = "kCGColorSpaceGenericCMYK" as CFString

    /// The generic RGB color space with a linear transfer function.
    nonisolated(unsafe) public static let genericRGBLinear: CFString = "kCGColorSpaceGenericRGBLinear" as CFString

    /// The XYZ color space, as defined by the CIE 1931 standard.
    nonisolated(unsafe) public static let genericXYZ: CFString = "kCGColorSpaceGenericXYZ" as CFString

    /// The generic LAB color space.
    nonisolated(unsafe) public static let genericLab: CFString = "kCGColorSpaceGenericLab" as CFString

    /// The ACEScg color space.
    nonisolated(unsafe) public static let acescgLinear: CFString = "kCGColorSpaceACESCGLinear" as CFString

    /// The Adobe RGB (1998) color space.
    nonisolated(unsafe) public static let adobeRGB1998: CFString = "kCGColorSpaceAdobeRGB1998" as CFString

    /// The DCI P3 color space, which is the digital cinema standard.
    nonisolated(unsafe) public static let dcip3: CFString = "kCGColorSpaceDCIP3" as CFString

    /// The Reference Output Medium Metric (ROMM) RGB color space.
    nonisolated(unsafe) public static let rommrgb: CFString = "kCGColorSpaceROMMRGB" as CFString

    /// The recommendation of the International Telecommunication Union (ITU) Radiocommunication sector for the BT.709 color space.
    nonisolated(unsafe) public static let itur_709: CFString = "kCGColorSpaceITUR_709" as CFString

    /// The ITU-R BT.709 color space with HLG transfer function.
    nonisolated(unsafe) public static let itur_709_HLG: CFString = "kCGColorSpaceITUR_709_HLG" as CFString

    /// The ITU-R BT.709 color space with PQ transfer function.
    nonisolated(unsafe) public static let itur_709_PQ: CFString = "kCGColorSpaceITUR_709_PQ" as CFString

    /// The recommendation of the International Telecommunication Union (ITU) Radiocommunication sector for the BT.2020 color space.
    nonisolated(unsafe) public static let itur_2020: CFString = "kCGColorSpaceITUR_2020" as CFString

    /// The ITU-R BT.2020 color space with sRGB gamma.
    nonisolated(unsafe) public static let itur_2020_sRGBGamma: CFString = "kCGColorSpaceITUR_2020_sRGBGamma" as CFString

    /// The ITU-R BT.2020 color space with a linear transfer function and extended range values.
    nonisolated(unsafe) public static let extendedLinearITUR_2020: CFString = "kCGColorSpaceExtendedLinearITUR_2020" as CFString

    /// The extended ITU-R BT.2020 color space.
    nonisolated(unsafe) public static let extendedITUR_2020: CFString = "kCGColorSpaceExtendedITUR_2020" as CFString

    /// The ITU-R BT.2020 color space with a linear transfer function.
    nonisolated(unsafe) public static let linearITUR_2020: CFString = "kCGColorSpaceLinearITUR_2020" as CFString

    /// The ITU-R BT.2100 color space with HLG transfer function.
    nonisolated(unsafe) public static let itur_2100_HLG: CFString = "kCGColorSpaceITUR_2100_HLG" as CFString

    /// The ITU-R BT.2100 color space with PQ transfer function.
    nonisolated(unsafe) public static let itur_2100_PQ: CFString = "kCGColorSpaceITUR_2100_PQ" as CFString

    /// The Core Media 709 color space.
    nonisolated(unsafe) public static let coreMedia709: CFString = "kCGColorSpaceCoreMedia709" as CFString

    // MARK: - Core Foundation Type ID

    /// Returns the Core Foundation type identifier for Quartz color spaces.
    public static var typeID: CFTypeID {
        // In a real implementation, this would return the actual CF type ID
        return 0
    }

    // MARK: - Creating Color Spaces

    /// Creates a specified type of Quartz color space.
    public convenience init?(name: CFString) {
        let nameString = name as String
        switch nameString {
        case "kCGColorSpaceSRGB", "sRGB":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceDisplayP3":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceDisplayP3_HLG":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceDisplayP3_PQ":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceExtendedLinearDisplayP3":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceExtendedDisplayP3":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceLinearDisplayP3":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceLinearSRGB":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceExtendedSRGB":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceExtendedLinearSRGB":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceGenericGrayGamma2_2":
            self.init(model: .monochrome, name: name, numberOfComponents: 1)
        case "kCGColorSpaceExtendedGray":
            self.init(model: .monochrome, name: name, numberOfComponents: 1)
        case "kCGColorSpaceLinearGray":
            self.init(model: .monochrome, name: name, numberOfComponents: 1)
        case "kCGColorSpaceExtendedLinearGray":
            self.init(model: .monochrome, name: name, numberOfComponents: 1)
        case "kCGColorSpaceGenericCMYK":
            self.init(model: .cmyk, name: name, numberOfComponents: 4)
        case "kCGColorSpaceGenericRGBLinear":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceGenericLab":
            self.init(model: .lab, name: name, numberOfComponents: 3)
        case "kCGColorSpaceGenericXYZ":
            self.init(model: .XYZ, name: name, numberOfComponents: 3)
        case "kCGColorSpaceACESCGLinear":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceAdobeRGB1998":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceDCIP3":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceROMMRGB":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceITUR_709":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceITUR_709_HLG":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceITUR_709_PQ":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceITUR_2020":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceITUR_2020_sRGBGamma":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceExtendedLinearITUR_2020":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceExtendedITUR_2020":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceLinearITUR_2020":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceITUR_2100_HLG":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceITUR_2100_PQ":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        case "kCGColorSpaceCoreMedia709":
            self.init(model: .rgb, name: name, numberOfComponents: 3)
        default:
            return nil
        }
    }

    /// Creates a calibrated grayscale color space.
    public convenience init?(
        calibratedGrayWhitePoint whitePoint: UnsafePointer<CGFloat>,
        blackPoint: UnsafePointer<CGFloat>?,
        gamma: CGFloat
    ) {
        let wp = [whitePoint[0], whitePoint[1], whitePoint[2]]
        let bp: [CGFloat]? = blackPoint.map { [$0[0], $0[1], $0[2]] }

        self.init(
            model: .monochrome,
            name: nil,
            numberOfComponents: 1,
            whitePoint: wp,
            blackPoint: bp,
            gamma: gamma
        )
    }

    /// Creates a calibrated RGB color space.
    public convenience init?(
        calibratedRGBWhitePoint whitePoint: UnsafePointer<CGFloat>,
        blackPoint: UnsafePointer<CGFloat>?,
        gamma: UnsafePointer<CGFloat>?,
        matrix: UnsafePointer<CGFloat>?
    ) {
        let wp = [whitePoint[0], whitePoint[1], whitePoint[2]]
        let bp: [CGFloat]? = blackPoint.map { [$0[0], $0[1], $0[2]] }

        self.init(
            model: .rgb,
            name: nil,
            numberOfComponents: 3,
            whitePoint: wp,
            blackPoint: bp
        )
    }

    /// Creates a device-independent color space that is defined according to the ICC color profile specification.
    public convenience init?(
        iccBasedNComponents nComponents: Int,
        range: UnsafePointer<CGFloat>?,
        profile: CGDataProvider,
        alternate: CGColorSpace?
    ) {
        guard nComponents > 0 && nComponents <= 4 else { return nil }

        let model: CGColorSpaceModel
        switch nComponents {
        case 1: model = .monochrome
        case 3: model = .rgb
        case 4: model = .cmyk
        default: model = .unknown
        }

        self.init(
            model: model,
            name: nil,
            numberOfComponents: nComponents,
            baseColorSpace: alternate
        )
    }

    /// Creates an indexed color space, consisting of colors specified by a color lookup table.
    public convenience init?(
        indexedBaseSpace baseSpace: CGColorSpace,
        last: Int,
        colorTable: UnsafePointer<UInt8>
    ) {
        guard last >= 0 && last <= 255 else { return nil }

        let tableSize = (last + 1) * baseSpace.numberOfComponents
        var table = [UInt8](repeating: 0, count: tableSize)
        for i in 0..<tableSize {
            table[i] = colorTable[i]
        }

        self.init(
            model: .indexed,
            name: nil,
            numberOfComponents: 1,
            baseColorSpace: baseSpace,
            colorTable: table
        )
    }

    /// Creates a device-independent color space that is relative to human color perception,
    /// according to the CIE L*a*b* standard.
    public convenience init?(
        labWhitePoint whitePoint: UnsafePointer<CGFloat>,
        blackPoint: UnsafePointer<CGFloat>?,
        range: UnsafePointer<CGFloat>?
    ) {
        let wp = [whitePoint[0], whitePoint[1], whitePoint[2]]
        let bp: [CGFloat]? = blackPoint.map { [$0[0], $0[1], $0[2]] }

        self.init(
            model: .lab,
            name: nil,
            numberOfComponents: 3,
            whitePoint: wp,
            blackPoint: bp
        )
    }

    /// Creates a pattern color space.
    public convenience init?(patternBaseSpace baseSpace: CGColorSpace?) {
        self.init(
            model: .pattern,
            name: nil,
            numberOfComponents: baseSpace?.numberOfComponents ?? 0,
            baseColorSpace: baseSpace
        )
    }

    /// Creates an ICC-based color space using the ICC profile contained in the specified data.
    public convenience init?(iccData: CFTypeRef) {
        // Check if the CFTypeRef is actually CFData by comparing type IDs
        guard CFGetTypeID(iccData) == CFDataGetTypeID() else { return nil }
        let cfData = iccData as! CFData
        let data = cfData as Data

        // Parse ICC profile header to determine color space type
        // For now, default to RGB
        self.init(
            model: .rgb,
            name: nil,
            numberOfComponents: 3,
            iccProfileData: data
        )
    }

    /// Creates a color space from a property list.
    public convenience init?(propertyListPlist plist: CFPropertyList) {
        guard let dict = plist as? [String: Any],
              let modelValue = dict["model"] as? Int32,
              let model = CGColorSpaceModel(rawValue: modelValue),
              let components = dict["numberOfComponents"] as? Int else {
            return nil
        }

        let name = dict["name"] as? String

        self.init(
            model: model,
            name: name.map { $0 as CFString },
            numberOfComponents: components
        )
    }

    // MARK: - Examining a Color Space

    /// Returns whether the color space can be used as a destination color space.
    public var supportsOutput: Bool {
        switch model {
        case .monochrome, .rgb, .cmyk, .lab, .XYZ:
            return true
        default:
            return false
        }
    }

    /// Returns whether the RGB color space covers a significant portion of the NTSC color gamut.
    public var isWideGamutRGB: Bool {
        guard model == .rgb, let name = name as String? else { return false }
        return name.contains("DisplayP3") ||
               name.contains("ExtendedSRGB") ||
               name.contains("ITUR_2020") ||
               name.contains("ITUR_2100") ||
               name.contains("AdobeRGB") ||
               name.contains("DCIP3")
    }

    /// Returns whether this is an HDR color space.
    public func isHDR() -> Bool {
        guard let name = name as String? else { return false }
        return name.contains("HLG") ||
               name.contains("PQ") ||
               name.contains("2100")
    }

    /// Returns a copy of the ICC profile data of the provided color space.
    public func copyICCData() -> CFData? {
        return iccProfileData.map { $0 as CFData }
    }

    /// Returns a copy of the color space's properties.
    public func copyPropertyList() -> CFPropertyList? {
        var dict: [String: Any] = [
            "model": model.rawValue,
            "numberOfComponents": numberOfComponents
        ]
        if let name = name {
            dict["name"] = name as String
        }
        return dict as CFPropertyList
    }

    // MARK: - Equatable

    public static func == (lhs: CGColorSpace, rhs: CGColorSpace) -> Bool {
        return lhs.model == rhs.model &&
               lhs.name as String? == rhs.name as String? &&
               lhs.numberOfComponents == rhs.numberOfComponents
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(model)
        hasher.combine(name as String?)
        hasher.combine(numberOfComponents)
    }
}

// MARK: - Factory Functions

/// Creates a device-dependent RGB color space.
public func CGColorSpaceCreateDeviceRGB() -> CGColorSpace {
    return CGColorSpace(
        model: .rgb,
        name: "DeviceRGB" as CFString,
        numberOfComponents: 3
    )
}

/// Creates a device-dependent CMYK color space.
public func CGColorSpaceCreateDeviceCMYK() -> CGColorSpace {
    return CGColorSpace(
        model: .cmyk,
        name: "DeviceCMYK" as CFString,
        numberOfComponents: 4
    )
}

/// Creates a device-dependent grayscale color space.
public func CGColorSpaceCreateDeviceGray() -> CGColorSpace {
    return CGColorSpace(
        model: .monochrome,
        name: "DeviceGray" as CFString,
        numberOfComponents: 1
    )
}
