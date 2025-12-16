//
//  CGImageComponentInfo.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation

/// Information about the components in an image.
public enum CGImageComponentInfo: UInt32, Sendable, CaseIterable {
    /// Floating-point components.
    case float = 0

    /// Integer components.
    case integer = 1

    public init?(rawValue: UInt32) {
        switch rawValue {
        case 0: self = .float
        case 1: self = .integer
        default: return nil
        }
    }
}

// MARK: - Equatable

extension CGImageComponentInfo: Equatable {}

// MARK: - Hashable

extension CGImageComponentInfo: Hashable {}

// MARK: - CustomDebugStringConvertible

extension CGImageComponentInfo: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .float: return "CGImageComponentInfo.float"
        case .integer: return "CGImageComponentInfo.integer"
        }
    }
}
