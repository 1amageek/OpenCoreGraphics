//
//  CGImageComponentInfo.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


import Foundation


/// Information about the components in an image.
public enum CGImageComponentInfo: UInt32, Sendable, CaseIterable {
    /// Integer components.
    case integer = 0

    /// Floating-point components.
    case float = 256

    public init?(rawValue: UInt32) {
        switch rawValue {
        case 0: self = .integer
        case 256: self = .float
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
        case .integer: return "CGImageComponentInfo.integer"
        case .float: return "CGImageComponentInfo.float"
        }
    }
}


