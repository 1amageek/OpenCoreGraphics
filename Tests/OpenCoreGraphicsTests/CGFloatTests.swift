//
//  CGFloatTests.swift
//  OpenCoreGraphics
//
//  Tests for CGFloat type
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = OpenCoreGraphics.CGFloat

@Suite("CGFloat Tests")
struct CGFloatTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Default initializer creates zero")
        func defaultInit() {
            let value = CGFloat()
            #expect(value.native == 0.0)
        }

        @Test("Init from Double")
        func initFromDouble() {
            let value = CGFloat(3.14159)
            #expect(value.native == 3.14159)
        }

        @Test("Init from Float")
        func initFromFloat() {
            let value = CGFloat(Float(2.5))
            #expect(abs(value.native - 2.5) < 0.0001)
        }

        @Test("Init from Int")
        func initFromInt() {
            let value = CGFloat(42)
            #expect(value.native == 42.0)
        }

        @Test("Init from UInt")
        func initFromUInt() {
            let value = CGFloat(UInt(100))
            #expect(value.native == 100.0)
        }

        @Test("Init from Int8")
        func initFromInt8() {
            let value = CGFloat(Int8(127))
            #expect(value.native == 127.0)
        }

        @Test("Init from Int16")
        func initFromInt16() {
            let value = CGFloat(Int16(1000))
            #expect(value.native == 1000.0)
        }

        @Test("Init from Int32")
        func initFromInt32() {
            let value = CGFloat(Int32(100000))
            #expect(value.native == 100000.0)
        }

        @Test("Init from Int64")
        func initFromInt64() {
            let value = CGFloat(Int64(1000000))
            #expect(value.native == 1000000.0)
        }

        @Test("Init from CGFloat copies value")
        func initFromCGFloat() {
            let original = CGFloat(99.5)
            let copy = CGFloat(original)
            #expect(copy.native == 99.5)
        }

        @Test("Init exactly succeeds for representable values")
        func initExactlySuccess() {
            let value = CGFloat(exactly: 42)
            #expect(value != nil)
            #expect(value?.native == 42.0)
        }

        @Test("Init from bit pattern")
        func initFromBitPattern() {
            let original = CGFloat(1.5)
            let reconstructed = CGFloat(bitPattern: original.bitPattern)
            #expect(reconstructed == original)
        }

        @Test("Float literal initialization")
        func floatLiteral() {
            let value: CGFloat = 3.14
            #expect(value.native == 3.14)
        }

        @Test("Integer literal initialization")
        func integerLiteral() {
            let value: CGFloat = 42
            #expect(value.native == 42.0)
        }
    }

    // MARK: - Static Properties Tests

    @Suite("Static Properties")
    struct StaticPropertiesTests {

        @Test("Zero value")
        func zeroValue() {
            #expect(CGFloat.zero.native == 0.0)
            #expect(CGFloat.zero.isZero)
        }

        @Test("NaN value")
        func nanValue() {
            #expect(CGFloat.nan.isNaN)
        }

        @Test("Signaling NaN value")
        func signalingNaN() {
            #expect(CGFloat.signalingNaN.isNaN)
            #expect(CGFloat.signalingNaN.isSignalingNaN)
        }

        @Test("Infinity value")
        func infinityValue() {
            #expect(CGFloat.infinity.isInfinite)
            #expect(CGFloat.infinity > CGFloat.greatestFiniteMagnitude)
        }

        @Test("Greatest finite magnitude")
        func greatestFiniteMagnitude() {
            #expect(CGFloat.greatestFiniteMagnitude.isFinite)
            #expect(CGFloat.greatestFiniteMagnitude > 0)
        }

        @Test("Pi value")
        func piValue() {
            #expect(abs(CGFloat.pi.native - Double.pi) < 0.0000001)
        }

        @Test("Least normal magnitude")
        func leastNormalMagnitude() {
            #expect(CGFloat.leastNormalMagnitude > 0)
            #expect(CGFloat.leastNormalMagnitude.isNormal)
        }

        @Test("Least nonzero magnitude")
        func leastNonzeroMagnitude() {
            #expect(CGFloat.leastNonzeroMagnitude > 0)
        }
    }

    // MARK: - Instance Properties Tests

    @Suite("Instance Properties")
    struct InstancePropertiesTests {

        @Test("isNormal for normal values")
        func isNormal() {
            #expect(CGFloat(1.0).isNormal)
            #expect(CGFloat(100.0).isNormal)
            #expect(!CGFloat(0.0).isNormal)
            #expect(!CGFloat.infinity.isNormal)
        }

        @Test("isFinite for finite values")
        func isFinite() {
            #expect(CGFloat(1.0).isFinite)
            #expect(CGFloat(0.0).isFinite)
            #expect(!CGFloat.infinity.isFinite)
            #expect(!CGFloat.nan.isFinite)
        }

        @Test("isZero for zero values")
        func isZeroProperty() {
            #expect(CGFloat(0.0).isZero)
            #expect(CGFloat(-0.0).isZero)
            #expect(!CGFloat(1.0).isZero)
        }

        @Test("isInfinite for infinite values")
        func isInfinite() {
            #expect(CGFloat.infinity.isInfinite)
            #expect((-CGFloat.infinity).isInfinite)
            #expect(!CGFloat(1.0).isInfinite)
        }

        @Test("isNaN for NaN values")
        func isNaNProperty() {
            #expect(CGFloat.nan.isNaN)
            #expect(!CGFloat(1.0).isNaN)
        }

        @Test("Sign property")
        func signProperty() {
            #expect(CGFloat(5.0).sign == .plus)
            #expect(CGFloat(-5.0).sign == .minus)
            #expect(CGFloat(0.0).sign == .plus)
        }

        @Test("Magnitude property")
        func magnitudeProperty() {
            #expect(CGFloat(5.0).magnitude.native == 5.0)
            #expect(CGFloat(-5.0).magnitude.native == 5.0)
        }

        @Test("Exponent property")
        func exponentProperty() {
            #expect(CGFloat(2.0).exponent == 1)
            #expect(CGFloat(4.0).exponent == 2)
        }

        @Test("Significand property")
        func significandProperty() {
            let value = CGFloat(3.0)
            #expect(value.significand.native == 1.5)
        }

        @Test("nextUp property")
        func nextUpProperty() {
            let value = CGFloat(1.0)
            #expect(value.nextUp > value)
        }

        @Test("ulp property")
        func ulpProperty() {
            let value = CGFloat(1.0)
            #expect(value.ulp > CGFloat(0))
            #expect(value.ulp < CGFloat(0.001))
        }
    }

    // MARK: - Arithmetic Operations Tests

    @Suite("Arithmetic Operations")
    struct ArithmeticTests {

        @Test("Addition")
        func addition() {
            let a = CGFloat(3.0)
            let b = CGFloat(2.0)
            #expect((a + b).native == 5.0)
        }

        @Test("Subtraction")
        func subtraction() {
            let a = CGFloat(5.0)
            let b = CGFloat(2.0)
            #expect((a - b).native == 3.0)
        }

        @Test("Multiplication")
        func multiplication() {
            let a = CGFloat(3.0)
            let b = CGFloat(4.0)
            #expect((a * b).native == 12.0)
        }

        @Test("Division")
        func division() {
            let a = CGFloat(10.0)
            let b = CGFloat(2.0)
            #expect((a / b).native == 5.0)
        }

        @Test("Compound addition")
        func compoundAddition() {
            var a = CGFloat(3.0)
            a += CGFloat(2.0)
            #expect(a.native == 5.0)
        }

        @Test("Compound subtraction")
        func compoundSubtraction() {
            var a = CGFloat(5.0)
            a -= CGFloat(2.0)
            #expect(a.native == 3.0)
        }

        @Test("Compound multiplication")
        func compoundMultiplication() {
            var a = CGFloat(3.0)
            a *= CGFloat(4.0)
            #expect(a.native == 12.0)
        }

        @Test("Compound division")
        func compoundDivision() {
            var a = CGFloat(10.0)
            a /= CGFloat(2.0)
            #expect(a.native == 5.0)
        }

        @Test("Unary minus")
        func unaryMinus() {
            let a = CGFloat(5.0)
            #expect((-a).native == -5.0)
            #expect((-(-a)).native == 5.0)
        }

        @Test("Negate mutating method")
        func negateMutating() {
            var a = CGFloat(5.0)
            a.negate()
            #expect(a.native == -5.0)
        }

        @Test("Division by zero")
        func divisionByZero() {
            let a = CGFloat(1.0)
            let b = CGFloat(0.0)
            #expect((a / b).isInfinite)
        }
    }

    // MARK: - Comparison Tests

    @Suite("Comparison Operations")
    struct ComparisonTests {

        @Test("Equality")
        func equality() {
            #expect(CGFloat(3.0) == CGFloat(3.0))
            #expect(CGFloat(3.0) != CGFloat(4.0))
        }

        @Test("Less than")
        func lessThan() {
            #expect(CGFloat(2.0) < CGFloat(3.0))
            #expect(!(CGFloat(3.0) < CGFloat(2.0)))
            #expect(!(CGFloat(3.0) < CGFloat(3.0)))
        }

        @Test("Greater than")
        func greaterThan() {
            #expect(CGFloat(3.0) > CGFloat(2.0))
            #expect(!(CGFloat(2.0) > CGFloat(3.0)))
        }

        @Test("Less than or equal")
        func lessThanOrEqual() {
            #expect(CGFloat(2.0) <= CGFloat(3.0))
            #expect(CGFloat(3.0) <= CGFloat(3.0))
            #expect(!(CGFloat(4.0) <= CGFloat(3.0)))
        }

        @Test("isEqual method")
        func isEqualMethod() {
            #expect(CGFloat(3.0).isEqual(to: CGFloat(3.0)))
            #expect(!CGFloat(3.0).isEqual(to: CGFloat(4.0)))
        }

        @Test("isLess method")
        func isLessMethod() {
            #expect(CGFloat(2.0).isLess(than: CGFloat(3.0)))
            #expect(!CGFloat(3.0).isLess(than: CGFloat(2.0)))
        }

        @Test("isLessThanOrEqualTo method")
        func isLessThanOrEqualToMethod() {
            #expect(CGFloat(2.0).isLessThanOrEqualTo(CGFloat(3.0)))
            #expect(CGFloat(3.0).isLessThanOrEqualTo(CGFloat(3.0)))
        }

        @Test("NaN comparison behavior")
        func nanComparison() {
            #expect(!(CGFloat.nan == CGFloat.nan))
            #expect(!(CGFloat.nan < CGFloat(1.0)))
            #expect(!(CGFloat.nan > CGFloat(1.0)))
        }
    }

    // MARK: - Floating Point Operations Tests

    @Suite("Floating Point Operations")
    struct FloatingPointOperationsTests {

        @Test("Round to nearest")
        func roundToNearest() {
            var value = CGFloat(2.7)
            value.round(.toNearestOrAwayFromZero)
            #expect(value.native == 3.0)
        }

        @Test("Round down")
        func roundDown() {
            var value = CGFloat(2.7)
            value.round(.down)
            #expect(value.native == 2.0)
        }

        @Test("Round up")
        func roundUp() {
            var value = CGFloat(2.3)
            value.round(.up)
            #expect(value.native == 3.0)
        }

        @Test("Round toward zero")
        func roundTowardZero() {
            var positive = CGFloat(2.7)
            positive.round(.towardZero)
            #expect(positive.native == 2.0)

            var negative = CGFloat(-2.7)
            negative.round(.towardZero)
            #expect(negative.native == -2.0)
        }

        @Test("formRemainder")
        func formRemainder() {
            var value = CGFloat(10.0)
            value.formRemainder(dividingBy: CGFloat(3.0))
            #expect(abs(value.native - 1.0) < 0.0001)
        }

        @Test("formTruncatingRemainder")
        func formTruncatingRemainder() {
            var value = CGFloat(10.0)
            value.formTruncatingRemainder(dividingBy: CGFloat(3.0))
            #expect(abs(value.native - 1.0) < 0.0001)
        }

        @Test("formSquareRoot")
        func formSquareRoot() {
            var value = CGFloat(9.0)
            value.formSquareRoot()
            #expect(abs(value.native - 3.0) < 0.0001)
        }

        @Test("addProduct")
        func addProduct() {
            var value = CGFloat(1.0)
            value.addProduct(CGFloat(2.0), CGFloat(3.0))
            #expect(value.native == 7.0) // 1 + 2*3 = 7
        }
    }

    // MARK: - Strideable Tests

    @Suite("Strideable Conformance")
    struct StrideableTests {

        @Test("Distance to")
        func distanceTo() {
            let a = CGFloat(3.0)
            let b = CGFloat(7.0)
            #expect(a.distance(to: b).native == 4.0)
        }

        @Test("Advanced by")
        func advancedBy() {
            let a = CGFloat(3.0)
            #expect(a.advanced(by: CGFloat(4.0)).native == 7.0)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Equal values have equal hashes")
        func equalValuesEqualHashes() {
            let a = CGFloat(3.14)
            let b = CGFloat(3.14)
            #expect(a.hashValue == b.hashValue)
        }

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGFloat>()
            set.insert(CGFloat(1.0))
            set.insert(CGFloat(2.0))
            set.insert(CGFloat(1.0))
            #expect(set.count == 2)
        }

        @Test("Can be used as Dictionary key")
        func dictionaryUsage() {
            var dict: [CGFloat: String] = [:]
            dict[CGFloat(1.0)] = "one"
            dict[CGFloat(2.0)] = "two"
            #expect(dict[CGFloat(1.0)] == "one")
        }
    }

    // MARK: - Codable Tests

    @Suite("Codable Conformance")
    struct CodableTests {

        @Test("Encode and decode")
        func encodeAndDecode() throws {
            let original = CGFloat(3.14159)
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGFloat.self, from: data)
            #expect(original == decoded)
        }

        @Test("Encode and decode zero")
        func encodeAndDecodeZero() throws {
            let original = CGFloat.zero
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGFloat.self, from: data)
            #expect(decoded.isZero)
        }

        @Test("Encode and decode negative")
        func encodeAndDecodeNegative() throws {
            let original = CGFloat(-42.5)
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGFloat.self, from: data)
            #expect(original == decoded)
        }
    }

    // MARK: - String Description Tests

    @Suite("String Descriptions")
    struct StringDescriptionTests {

        @Test("Description for integer-like value")
        func descriptionInteger() {
            let value = CGFloat(42.0)
            #expect(value.description == "42.0")
        }

        @Test("Description for decimal value")
        func descriptionDecimal() {
            let value = CGFloat(3.14)
            #expect(value.description.hasPrefix("3.14"))
        }

        @Test("Debug description")
        func debugDescription() {
            let value = CGFloat(3.14)
            #expect(!value.debugDescription.isEmpty)
        }
    }

    // MARK: - Binary Floating Point Tests

    @Suite("BinaryFloatingPoint Conformance")
    struct BinaryFloatingPointTests {

        @Test("Exponent bit count")
        func exponentBitCount() {
            #expect(CGFloat.exponentBitCount == Double.exponentBitCount)
        }

        @Test("Significand bit count")
        func significandBitCount() {
            #expect(CGFloat.significandBitCount == Double.significandBitCount)
        }

        @Test("Radix")
        func radix() {
            #expect(CGFloat.radix == 2)
        }

        @Test("Init from sign, exponent, and significand bit patterns")
        func initFromBitPatterns() {
            let original = CGFloat(1.5)
            let reconstructed = CGFloat(
                sign: original.sign,
                exponentBitPattern: original.exponentBitPattern,
                significandBitPattern: original.significandBitPattern
            )
            #expect(original == reconstructed)
        }

        @Test("Init from sign, exponent, and significand")
        func initFromComponents() {
            let original = CGFloat(3.0)
            let reconstructed = CGFloat(
                sign: original.sign,
                exponent: original.exponent,
                significand: original.significand
            )
            #expect(original == reconstructed)
        }

        @Test("Binade property")
        func binadeProperty() {
            let value = CGFloat(3.0)
            #expect(value.binade.native == 2.0)
        }
    }
}
