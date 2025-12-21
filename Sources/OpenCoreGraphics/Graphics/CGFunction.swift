//
//  CGFunction.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//


#if arch(wasm32)
import Foundation


// MARK: - CGFunctionCallbacks

/// Performs custom operations on the supplied input data to produce output data.
public typealias CGFunctionEvaluateCallback = (
    UnsafeMutableRawPointer?,           // info
    UnsafePointer<CGFloat>?,            // in
    UnsafeMutablePointer<CGFloat>?      // out
) -> Void

/// Performs custom clean-up tasks when Core Graphics deallocates a CGFunction object.
public typealias CGFunctionReleaseInfoCallback = (UnsafeMutableRawPointer?) -> Void

/// A structure that contains callbacks needed by a CGFunction object.
public struct CGFunctionCallbacks {
    /// The version of the structure. Set to 0.
    public var version: UInt32

    /// A pointer to the callback function that evaluates the function.
    public var evaluate: CGFunctionEvaluateCallback?

    /// A pointer to the callback function that releases private data.
    public var releaseInfo: CGFunctionReleaseInfoCallback?

    /// Creates function callbacks.
    public init(version: UInt32 = 0,
                evaluate: CGFunctionEvaluateCallback?,
                releaseInfo: CGFunctionReleaseInfoCallback?) {
        self.version = version
        self.evaluate = evaluate
        self.releaseInfo = releaseInfo
    }
}

// MARK: - CGFunction

/// A general facility for defining and using callback functions.
///
/// These functions can take an arbitrary number of floating-point input values
/// and pass back an arbitrary number of floating-point output values.
/// Core Graphics uses function objects to implement shadings.
public class CGFunction: @unchecked Sendable {

    /// The number of input values.
    public let domainDimension: Int

    /// The domain (valid input ranges) for the function.
    public let domain: [CGFloat]

    /// The number of output values.
    public let rangeDimension: Int

    /// The range (valid output ranges) for the function.
    public let range: [CGFloat]

    /// User-provided info pointer.
    internal let info: UnsafeMutableRawPointer?

    /// The callbacks for the function.
    internal let callbacks: CGFunctionCallbacks

    // MARK: - Initializers

    /// Creates a Core Graphics function.
    ///
    /// - Parameters:
    ///   - info: A pointer to data that you want passed to your callbacks.
    ///   - domainDimension: The number of input values to the function.
    ///   - domain: An array of 2 * domainDimension values specifying min/max for each input.
    ///   - rangeDimension: The number of output values from the function.
    ///   - range: An array of 2 * rangeDimension values specifying min/max for each output.
    ///   - callbacks: The callbacks for evaluating and releasing the function.
    public init?(info: UnsafeMutableRawPointer?,
                 domainDimension: Int,
                 domain: UnsafePointer<CGFloat>?,
                 rangeDimension: Int,
                 range: UnsafePointer<CGFloat>?,
                 callbacks: UnsafePointer<CGFunctionCallbacks>) {
        guard domainDimension >= 0, rangeDimension >= 0 else { return nil }
        guard callbacks.pointee.evaluate != nil else { return nil }

        self.info = info
        self.domainDimension = domainDimension
        self.rangeDimension = rangeDimension
        self.callbacks = callbacks.pointee

        // Copy domain values
        if let domain = domain, domainDimension > 0 {
            var domainArray: [CGFloat] = []
            for i in 0..<(domainDimension * 2) {
                domainArray.append(domain[i])
            }
            self.domain = domainArray
        } else {
            self.domain = []
        }

        // Copy range values
        if let range = range, rangeDimension > 0 {
            var rangeArray: [CGFloat] = []
            for i in 0..<(rangeDimension * 2) {
                rangeArray.append(range[i])
            }
            self.range = rangeArray
        } else {
            self.range = []
        }
    }

    deinit {
        callbacks.releaseInfo?(info)
    }

    // MARK: - Evaluation

    /// Evaluates the function with the given input values.
    ///
    /// - Parameters:
    ///   - input: The input values.
    ///   - output: The buffer to receive output values.
    public func evaluate(input: UnsafePointer<CGFloat>?, output: UnsafeMutablePointer<CGFloat>?) {
        callbacks.evaluate?(info, input, output)
    }

    /// Evaluates the function with the given input values and returns the output.
    ///
    /// - Parameter input: The input values.
    /// - Returns: The output values.
    public func evaluate(input: [CGFloat]) -> [CGFloat] {
        var output = [CGFloat](repeating: 0, count: rangeDimension)
        input.withUnsafeBufferPointer { inputPtr in
            output.withUnsafeMutableBufferPointer { outputPtr in
                callbacks.evaluate?(info, inputPtr.baseAddress, outputPtr.baseAddress)
            }
        }
        return output
    }

    // MARK: - Type ID

    /// Returns the type identifier for Core Graphics function objects.
    public class var typeID: UInt {
        return 0 // Placeholder
    }
}

// MARK: - Equatable

extension CGFunction: Equatable {
    public static func == (lhs: CGFunction, rhs: CGFunction) -> Bool {
        return lhs === rhs
    }
}

// MARK: - Hashable

extension CGFunction: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}


#endif
