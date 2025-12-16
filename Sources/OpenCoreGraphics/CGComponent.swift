//
//  CGComponent.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation

/// Component type and bit depth information.
public enum CGComponent: UInt32, Sendable {
    /// Unknown component type.
    case unknown = 0

    /// 8-bit integer component.
    case integer8Bit = 1

    /// 10-bit integer component.
    case integer10Bit = 2

    /// 16-bit integer component.
    case integer16Bit = 3

    /// 32-bit integer component.
    case integer32Bit = 4

    /// 16-bit floating-point component (half precision).
    case float16Bit = 5

    /// 32-bit floating-point component (single precision).
    case float32Bit = 6

    public init?(rawValue: UInt32) {
        switch rawValue {
        case 0: self = .unknown
        case 1: self = .integer8Bit
        case 2: self = .integer10Bit
        case 3: self = .integer16Bit
        case 4: self = .integer32Bit
        case 5: self = .float16Bit
        case 6: self = .float32Bit
        default: return nil
        }
    }
}

// MARK: - Equatable

extension CGComponent: Equatable {}

// MARK: - Hashable

extension CGComponent: Hashable {}
