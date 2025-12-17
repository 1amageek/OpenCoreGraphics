//
//  CGError.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

import Foundation


/// A uniform type for result codes returned by functions in Core Graphics.
public enum CGError: Int32, Sendable, Error {
    /// The operation was completed successfully.
    case success = 0

    /// The operation failed.
    case failure = 1000

    /// One or more of the parameters passed to a function were invalid.
    case illegalArgument = 1001

    /// The parameter representing a connection to the window server is invalid.
    case invalidConnection = 1002

    /// A parameter passed to a function was out of range.
    case invalidContext = 1003

    /// The application doesn't have permission to perform the requested operation.
    case cannotComplete = 1004

    /// The specified display is not accessible.
    case notImplemented = 1006

    /// One of the parameters represents a value that is outside of the allowable range.
    case rangeCheck = 1007

    /// A configuration change has been made to the display.
    case typeCheck = 1008

    /// No display matching the requested criteria was found.
    case invalidOperation = 1010

    /// The display is in an unusable state.
    case noneAvailable = 1011

    public init?(rawValue: Int32) {
        switch rawValue {
        case 0: self = .success
        case 1000: self = .failure
        case 1001: self = .illegalArgument
        case 1002: self = .invalidConnection
        case 1003: self = .invalidContext
        case 1004: self = .cannotComplete
        case 1006: self = .notImplemented
        case 1007: self = .rangeCheck
        case 1008: self = .typeCheck
        case 1010: self = .invalidOperation
        case 1011: self = .noneAvailable
        default: return nil
        }
    }
}

// MARK: - Equatable

extension CGError: Equatable {}

// MARK: - Hashable

extension CGError: Hashable {}

