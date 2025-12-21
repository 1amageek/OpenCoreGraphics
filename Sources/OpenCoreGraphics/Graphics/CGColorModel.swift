//
//  CGColorModel.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

#if arch(wasm32)

import Foundation


/// A set of color models that can be combined to describe content characteristics.
public struct CGColorModel: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    // MARK: - Color Model Options

    /// Grayscale color model.
    public static let gray = CGColorModel(rawValue: 1 << 0)

    /// RGB color model.
    public static let rgb = CGColorModel(rawValue: 1 << 1)

    /// CMYK color model.
    public static let cmyk = CGColorModel(rawValue: 1 << 2)

    /// LAB color model.
    public static let lab = CGColorModel(rawValue: 1 << 3)

    /// DeviceN color model.
    public static let deviceN = CGColorModel(rawValue: 1 << 4)
}

// MARK: - Equatable

extension CGColorModel: Equatable {}

// MARK: - Hashable

extension CGColorModel: Hashable {}

// MARK: - ExpressibleByArrayLiteral

extension CGColorModel: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: CGColorModel...) {
        self = elements.reduce(CGColorModel(rawValue: 0)) { $0.union($1) }
    }
}

#endif

