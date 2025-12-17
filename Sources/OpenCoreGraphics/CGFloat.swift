//
//  CGFloat.swift
//  OpenCoreGraphics
//
//  Created by OpenCoreGraphics contributors.
//

/// The basic type for floating-point scalar values in Core Graphics and related frameworks.
///
/// In this implementation, `CGFloat` is always a 64-bit IEEE double-precision floating point type,
/// equivalent to `Double`.
@frozen
public struct CGFloat: Sendable {

    /// The native type used to store the CGFloat, which is Double.
    public typealias NativeType = Double

    /// The native value.
    public var native: NativeType

    /// Create an instance initialized to zero.
    @inlinable
    public init() {
        self.native = 0.0
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: CGFloat) {
        self.native = value.native
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: Double) {
        self.native = value
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: Float) {
        self.native = Double(value)
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: Int) {
        self.native = Double(value)
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: UInt) {
        self.native = Double(value)
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: Int8) {
        self.native = Double(value)
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: Int16) {
        self.native = Double(value)
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: Int32) {
        self.native = Double(value)
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: Int64) {
        self.native = Double(value)
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: UInt8) {
        self.native = Double(value)
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: UInt16) {
        self.native = Double(value)
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: UInt32) {
        self.native = Double(value)
    }

    /// Create an instance initialized to `value`.
    @inlinable
    public init(_ value: UInt64) {
        self.native = Double(value)
    }

    /// Creates a new instance from the given integer, if it can be represented exactly.
    @inlinable
    public init?<Source: BinaryInteger>(exactly source: Source) {
        guard let native = Double(exactly: source) else { return nil }
        self.native = native
    }

    /// The bit pattern of the value's encoding.
    @inlinable
    public var bitPattern: UInt {
        return UInt(native.bitPattern)
    }

    /// Creates a new value with the given bit pattern.
    @inlinable
    public init(bitPattern: UInt) {
        self.native = Double(bitPattern: UInt64(bitPattern))
    }
}

// MARK: - Equatable

extension CGFloat: Equatable {
    @inlinable
    public static func == (lhs: CGFloat, rhs: CGFloat) -> Bool {
        return lhs.native == rhs.native
    }
}

// MARK: - Hashable

extension CGFloat: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(native)
    }
}

// MARK: - Comparable

extension CGFloat: Comparable {
    @inlinable
    public static func < (lhs: CGFloat, rhs: CGFloat) -> Bool {
        return lhs.native < rhs.native
    }
}

// MARK: - SignedNumeric

extension CGFloat: SignedNumeric {
    @inlinable
    public var magnitude: CGFloat {
        return CGFloat(native.magnitude)
    }

    @inlinable
    public init<T: BinaryInteger>(_ source: T) {
        self.native = Double(source)
    }

    @inlinable
    public static func * (lhs: CGFloat, rhs: CGFloat) -> CGFloat {
        return CGFloat(lhs.native * rhs.native)
    }

    @inlinable
    public static func *= (lhs: inout CGFloat, rhs: CGFloat) {
        lhs.native *= rhs.native
    }
}

// MARK: - Numeric

extension CGFloat: Numeric {
    public typealias Magnitude = CGFloat
}

// MARK: - AdditiveArithmetic

extension CGFloat: AdditiveArithmetic {
    @inlinable
    public static var zero: CGFloat {
        return CGFloat(0.0)
    }

    @inlinable
    public static func + (lhs: CGFloat, rhs: CGFloat) -> CGFloat {
        return CGFloat(lhs.native + rhs.native)
    }

    @inlinable
    public static func += (lhs: inout CGFloat, rhs: CGFloat) {
        lhs.native += rhs.native
    }

    @inlinable
    public static func - (lhs: CGFloat, rhs: CGFloat) -> CGFloat {
        return CGFloat(lhs.native - rhs.native)
    }

    @inlinable
    public static func -= (lhs: inout CGFloat, rhs: CGFloat) {
        lhs.native -= rhs.native
    }
}

// MARK: - Strideable

extension CGFloat: Strideable {
    public typealias Stride = CGFloat

    @inlinable
    public func distance(to other: CGFloat) -> CGFloat {
        return CGFloat(other.native - self.native)
    }

    @inlinable
    public func advanced(by n: CGFloat) -> CGFloat {
        return CGFloat(self.native + n.native)
    }
}

// MARK: - FloatingPoint

extension CGFloat: FloatingPoint {
    public typealias Exponent = Int

    @inlinable
    public static var radix: Int { Double.radix }

    @inlinable
    public static var nan: CGFloat { CGFloat(Double.nan) }

    @inlinable
    public static var signalingNaN: CGFloat { CGFloat(Double.signalingNaN) }

    @inlinable
    public static var infinity: CGFloat { CGFloat(Double.infinity) }

    @inlinable
    public static var greatestFiniteMagnitude: CGFloat { CGFloat(Double.greatestFiniteMagnitude) }

    @inlinable
    public static var pi: CGFloat { CGFloat(Double.pi) }

    @inlinable
    public static var leastNormalMagnitude: CGFloat { CGFloat(Double.leastNormalMagnitude) }

    @inlinable
    public static var leastNonzeroMagnitude: CGFloat { CGFloat(Double.leastNonzeroMagnitude) }

    @inlinable
    public var ulp: CGFloat { CGFloat(native.ulp) }

    @inlinable
    public static var ulpOfOne: CGFloat { CGFloat(Double.ulpOfOne) }

    @inlinable
    public var sign: FloatingPointSign { native.sign }

    @inlinable
    public var exponent: Int { native.exponent }

    @inlinable
    public var significand: CGFloat { CGFloat(native.significand) }

    @inlinable
    public init(sign: FloatingPointSign, exponent: Int, significand: CGFloat) {
        self.native = Double(sign: sign, exponent: exponent, significand: significand.native)
    }

    @inlinable
    public init(signOf: CGFloat, magnitudeOf: CGFloat) {
        self.native = Double(signOf: signOf.native, magnitudeOf: magnitudeOf.native)
    }

    @inlinable
    public var nextUp: CGFloat { CGFloat(native.nextUp) }

    @inlinable
    public var isNormal: Bool { native.isNormal }

    @inlinable
    public var isFinite: Bool { native.isFinite }

    @inlinable
    public var isZero: Bool { native.isZero }

    @inlinable
    public var isSubnormal: Bool { native.isSubnormal }

    @inlinable
    public var isInfinite: Bool { native.isInfinite }

    @inlinable
    public var isNaN: Bool { native.isNaN }

    @inlinable
    public var isSignalingNaN: Bool { native.isSignalingNaN }

    @inlinable
    public var isCanonical: Bool { native.isCanonical }

    @inlinable
    public mutating func round(_ rule: FloatingPointRoundingRule) {
        native.round(rule)
    }

    @inlinable
    public mutating func formRemainder(dividingBy other: CGFloat) {
        native.formRemainder(dividingBy: other.native)
    }

    @inlinable
    public mutating func formTruncatingRemainder(dividingBy other: CGFloat) {
        native.formTruncatingRemainder(dividingBy: other.native)
    }

    @inlinable
    public mutating func formSquareRoot() {
        native.formSquareRoot()
    }

    @inlinable
    public mutating func addProduct(_ lhs: CGFloat, _ rhs: CGFloat) {
        native.addProduct(lhs.native, rhs.native)
    }

    @inlinable
    public func isEqual(to other: CGFloat) -> Bool {
        return native.isEqual(to: other.native)
    }

    @inlinable
    public func isLess(than other: CGFloat) -> Bool {
        return native.isLess(than: other.native)
    }

    @inlinable
    public func isLessThanOrEqualTo(_ other: CGFloat) -> Bool {
        return native.isLessThanOrEqualTo(other.native)
    }

    @inlinable
    public func isTotallyOrdered(belowOrEqualTo other: CGFloat) -> Bool {
        return native.isTotallyOrdered(belowOrEqualTo: other.native)
    }

    @inlinable
    public static func / (lhs: CGFloat, rhs: CGFloat) -> CGFloat {
        return CGFloat(lhs.native / rhs.native)
    }

    @inlinable
    public static func /= (lhs: inout CGFloat, rhs: CGFloat) {
        lhs.native /= rhs.native
    }
}

// MARK: - BinaryFloatingPoint

extension CGFloat: BinaryFloatingPoint {
    public typealias RawSignificand = UInt64
    public typealias RawExponent = UInt

    @inlinable
    public static var exponentBitCount: Int { Double.exponentBitCount }

    @inlinable
    public static var significandBitCount: Int { Double.significandBitCount }

    @inlinable
    public var binade: CGFloat { CGFloat(native.binade) }

    @inlinable
    public var significandWidth: Int { native.significandWidth }

    @inlinable
    public var exponentBitPattern: UInt { native.exponentBitPattern }

    @inlinable
    public var significandBitPattern: UInt64 { native.significandBitPattern }

    @inlinable
    public init(sign: FloatingPointSign, exponentBitPattern: UInt, significandBitPattern: UInt64) {
        self.native = Double(sign: sign, exponentBitPattern: exponentBitPattern, significandBitPattern: significandBitPattern)
    }

    @inlinable
    public init<Source: BinaryFloatingPoint>(_ value: Source) {
        self.native = Double(value)
    }

    @inlinable
    public init?<Source: BinaryFloatingPoint>(exactly value: Source) {
        guard let native = Double(exactly: value) else { return nil }
        self.native = native
    }
}

// MARK: - ExpressibleByFloatLiteral

extension CGFloat: ExpressibleByFloatLiteral {
    public typealias FloatLiteralType = Double

    @inlinable
    public init(floatLiteral value: Double) {
        self.native = value
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension CGFloat: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Int

    @inlinable
    public init(integerLiteral value: Int) {
        self.native = Double(value)
    }
}

// MARK: - CustomStringConvertible

extension CGFloat: CustomStringConvertible {
    @inlinable
    public var description: String {
        return native.description
    }
}

// MARK: - CustomDebugStringConvertible

extension CGFloat: CustomDebugStringConvertible {
    @inlinable
    public var debugDescription: String {
        return native.debugDescription
    }
}

// MARK: - CustomReflectable

extension CGFloat: CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(reflecting: native)
    }
}

// MARK: - Codable

extension CGFloat: Codable {
    @inlinable
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.native = try container.decode(Double.self)
    }

    @inlinable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(native)
    }
}

// MARK: - Unary Minus

extension CGFloat {
    @inlinable
    public static prefix func - (x: CGFloat) -> CGFloat {
        return CGFloat(-x.native)
    }

    @inlinable
    public mutating func negate() {
        native.negate()
    }
}
