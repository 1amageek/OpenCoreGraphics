//
//  CGAffineTransformTests.swift
//  OpenCoreGraphics
//
//  Tests for CGAffineTransform and CGAffineTransformComponents types
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = Foundation.CGFloat
private typealias CGPoint = Foundation.CGPoint
private typealias CGSize = Foundation.CGSize
private typealias CGVector = OpenCoreGraphics.CGVector
private typealias CGAffineTransform = OpenCoreGraphics.CGAffineTransform
private typealias CGAffineTransformComponents = OpenCoreGraphics.CGAffineTransformComponents

@Suite("CGAffineTransform Tests")
struct CGAffineTransformTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Default initializer creates zero matrix")
        func defaultInit() {
            let transform = CGAffineTransform()
            #expect(transform.a == 0.0)
            #expect(transform.b == 0.0)
            #expect(transform.c == 0.0)
            #expect(transform.d == 0.0)
            #expect(transform.tx == 0.0)
            #expect(transform.ty == 0.0)
        }

        @Test("Init with named parameters")
        func initWithNamedParameters() {
            let transform = CGAffineTransform(a: 1.0, b: 2.0, c: 3.0, d: 4.0, tx: 5.0, ty: 6.0)
            #expect(transform.a == 1.0)
            #expect(transform.b == 2.0)
            #expect(transform.c == 3.0)
            #expect(transform.d == 4.0)
            #expect(transform.tx == 5.0)
            #expect(transform.ty == 6.0)
        }

        @Test("Init with positional parameters")
        func initWithPositionalParameters() {
            let transform = CGAffineTransform(1.0, 2.0, 3.0, 4.0, 5.0, 6.0)
            #expect(transform.a == 1.0)
            #expect(transform.b == 2.0)
            #expect(transform.c == 3.0)
            #expect(transform.d == 4.0)
            #expect(transform.tx == 5.0)
            #expect(transform.ty == 6.0)
        }

        @Test("Init translation")
        func initTranslation() {
            let transform = CGAffineTransform(translationX: 10.0, y: 20.0)
            #expect(transform.a == 1.0)
            #expect(transform.b == 0.0)
            #expect(transform.c == 0.0)
            #expect(transform.d == 1.0)
            #expect(transform.tx == 10.0)
            #expect(transform.ty == 20.0)
        }

        @Test("Init scale")
        func initScale() {
            let transform = CGAffineTransform(scaleX: 2.0, y: 3.0)
            #expect(transform.a == 2.0)
            #expect(transform.b == 0.0)
            #expect(transform.c == 0.0)
            #expect(transform.d == 3.0)
            #expect(transform.tx == 0.0)
            #expect(transform.ty == 0.0)
        }

        @Test("Init rotation 90 degrees")
        func initRotation90() {
            let transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
            #expect(abs(transform.a - 0.0) < 0.0001)
            #expect(abs(transform.b - 1.0) < 0.0001)
            #expect(abs(transform.c - (-1.0)) < 0.0001)
            #expect(abs(transform.d - 0.0) < 0.0001)
        }

        @Test("Init rotation 180 degrees")
        func initRotation180() {
            let transform = CGAffineTransform(rotationAngle: CGFloat.pi)
            #expect(abs(transform.a - (-1.0)) < 0.0001)
            #expect(abs(transform.b - 0.0) < 0.0001)
            #expect(abs(transform.c - 0.0) < 0.0001)
            #expect(abs(transform.d - (-1.0)) < 0.0001)
        }

        @Test("Init rotation 0 degrees")
        func initRotation0() {
            let transform = CGAffineTransform(rotationAngle: 0.0)
            #expect(abs(transform.a - 1.0) < 0.0001)
            #expect(abs(transform.b - 0.0) < 0.0001)
            #expect(abs(transform.c - 0.0) < 0.0001)
            #expect(abs(transform.d - 1.0) < 0.0001)
        }
    }

    // MARK: - Identity Transform Tests

    @Suite("Identity Transform")
    struct IdentityTests {

        @Test("Identity transform values")
        func identityValues() {
            let identity = CGAffineTransform.identity
            #expect(identity.a == 1.0)
            #expect(identity.b == 0.0)
            #expect(identity.c == 0.0)
            #expect(identity.d == 1.0)
            #expect(identity.tx == 0.0)
            #expect(identity.ty == 0.0)
        }

        @Test("isIdentity property")
        func isIdentityProperty() {
            #expect(CGAffineTransform.identity.isIdentity)
            #expect(!CGAffineTransform(translationX: 1.0, y: 0.0).isIdentity)
            #expect(!CGAffineTransform(scaleX: 2.0, y: 1.0).isIdentity)
        }

        @Test("Identity applied to point")
        func identityAppliedToPoint() {
            let point = CGPoint(x: 10.0, y: 20.0)
            let transformed = point.applying(CGAffineTransform.identity)
            #expect(transformed == point)
        }
    }

    // MARK: - Translation Tests

    @Suite("Translation Operations")
    struct TranslationTests {

        @Test("Translate by positive values")
        func translateByPositive() {
            let transform = CGAffineTransform.identity.translatedBy(x: 10.0, y: 20.0)
            let point = CGPoint(x: 5.0, y: 5.0)
            let transformed = point.applying(transform)
            #expect(transformed.x == 15.0)
            #expect(transformed.y == 25.0)
        }

        @Test("Translate by negative values")
        func translateByNegative() {
            let transform = CGAffineTransform.identity.translatedBy(x: -10.0, y: -20.0)
            let point = CGPoint(x: 15.0, y: 25.0)
            let transformed = point.applying(transform)
            #expect(transformed.x == 5.0)
            #expect(transformed.y == 5.0)
        }

        @Test("Chain translations")
        func chainTranslations() {
            let transform = CGAffineTransform.identity
                .translatedBy(x: 10.0, y: 0.0)
                .translatedBy(x: 0.0, y: 20.0)
            let point = CGPoint.zero
            let transformed = point.applying(transform)
            #expect(transformed.x == 10.0)
            #expect(transformed.y == 20.0)
        }
    }

    // MARK: - Scale Tests

    @Suite("Scale Operations")
    struct ScaleTests {

        @Test("Scale by uniform factor")
        func scaleUniform() {
            let transform = CGAffineTransform.identity.scaledBy(x: 2.0, y: 2.0)
            let point = CGPoint(x: 10.0, y: 20.0)
            let transformed = point.applying(transform)
            #expect(transformed.x == 20.0)
            #expect(transformed.y == 40.0)
        }

        @Test("Scale by non-uniform factor")
        func scaleNonUniform() {
            let transform = CGAffineTransform.identity.scaledBy(x: 2.0, y: 3.0)
            let point = CGPoint(x: 10.0, y: 10.0)
            let transformed = point.applying(transform)
            #expect(transformed.x == 20.0)
            #expect(transformed.y == 30.0)
        }

        @Test("Scale by negative factor flips")
        func scaleNegative() {
            let transform = CGAffineTransform.identity.scaledBy(x: -1.0, y: 1.0)
            let point = CGPoint(x: 10.0, y: 20.0)
            let transformed = point.applying(transform)
            #expect(transformed.x == -10.0)
            #expect(transformed.y == 20.0)
        }

        @Test("Scale by zero")
        func scaleByZero() {
            let transform = CGAffineTransform.identity.scaledBy(x: 0.0, y: 0.0)
            let point = CGPoint(x: 10.0, y: 20.0)
            let transformed = point.applying(transform)
            #expect(transformed.x == 0.0)
            #expect(transformed.y == 0.0)
        }
    }

    // MARK: - Rotation Tests

    @Suite("Rotation Operations")
    struct RotationTests {

        @Test("Rotate 90 degrees")
        func rotate90() {
            let transform = CGAffineTransform.identity.rotated(by: CGFloat.pi / 2)
            let point = CGPoint(x: 1.0, y: 0.0)
            let transformed = point.applying(transform)
            #expect(abs(transformed.x - 0.0) < 0.0001)
            #expect(abs(transformed.y - 1.0) < 0.0001)
        }

        @Test("Rotate 180 degrees")
        func rotate180() {
            let transform = CGAffineTransform.identity.rotated(by: CGFloat.pi)
            let point = CGPoint(x: 1.0, y: 0.0)
            let transformed = point.applying(transform)
            #expect(abs(transformed.x - (-1.0)) < 0.0001)
            #expect(abs(transformed.y - 0.0) < 0.0001)
        }

        @Test("Rotate 360 degrees returns to original")
        func rotate360() {
            let transform = CGAffineTransform.identity.rotated(by: CGFloat.pi * 2)
            let point = CGPoint(x: 1.0, y: 0.0)
            let transformed = point.applying(transform)
            #expect(abs(transformed.x - 1.0) < 0.0001)
            #expect(abs(transformed.y - 0.0) < 0.0001)
        }

        @Test("Rotate negative angle")
        func rotateNegative() {
            let transform = CGAffineTransform.identity.rotated(by: -CGFloat.pi / 2)
            let point = CGPoint(x: 1.0, y: 0.0)
            let transformed = point.applying(transform)
            #expect(abs(transformed.x - 0.0) < 0.0001)
            #expect(abs(transformed.y - (-1.0)) < 0.0001)
        }
    }

    // MARK: - Concatenation Tests

    @Suite("Concatenation Operations")
    struct ConcatenationTests {

        @Test("Concatenate with identity")
        func concatenateWithIdentity() {
            let transform = CGAffineTransform(translationX: 10.0, y: 20.0)
            let concatenated = transform.concatenating(CGAffineTransform.identity)
            #expect(concatenated.tx == 10.0)
            #expect(concatenated.ty == 20.0)
        }

        @Test("Concatenate scale then translate")
        func concatenateScaleThenTranslate() {
            let scale = CGAffineTransform(scaleX: 2.0, y: 2.0)
            let translate = CGAffineTransform(translationX: 10.0, y: 10.0)
            let combined = scale.concatenating(translate)
            let point = CGPoint(x: 5.0, y: 5.0)
            let transformed = point.applying(combined)
            #expect(transformed.x == 20.0) // 5*2 + 10 = 20
            #expect(transformed.y == 20.0) // 5*2 + 10 = 20
        }

        @Test("Order matters for concatenation")
        func concatenationOrderMatters() {
            let scale = CGAffineTransform(scaleX: 2.0, y: 2.0)
            let translate = CGAffineTransform(translationX: 10.0, y: 10.0)
            let scaleThenTranslate = scale.concatenating(translate)
            let translateThenScale = translate.concatenating(scale)

            let point = CGPoint(x: 5.0, y: 5.0)
            let t1 = point.applying(scaleThenTranslate)
            let t2 = point.applying(translateThenScale)

            #expect(t1 != t2)
        }
    }

    // MARK: - Inversion Tests

    @Suite("Inversion Operations")
    struct InversionTests {

        @Test("Invert identity is identity")
        func invertIdentity() {
            let inverted = CGAffineTransform.identity.inverted()
            #expect(inverted.isIdentity)
        }

        @Test("Invert translation")
        func invertTranslation() {
            let transform = CGAffineTransform(translationX: 10.0, y: 20.0)
            let inverted = transform.inverted()
            let point = CGPoint(x: 15.0, y: 25.0)
            let original = point.applying(inverted)
            #expect(abs(original.x - 5.0) < 0.0001)
            #expect(abs(original.y - 5.0) < 0.0001)
        }

        @Test("Invert scale")
        func invertScale() {
            let transform = CGAffineTransform(scaleX: 2.0, y: 4.0)
            let inverted = transform.inverted()
            let point = CGPoint(x: 20.0, y: 40.0)
            let original = point.applying(inverted)
            #expect(abs(original.x - 10.0) < 0.0001)
            #expect(abs(original.y - 10.0) < 0.0001)
        }

        @Test("Transform then inverse returns original")
        func transformThenInverse() {
            let transform = CGAffineTransform(translationX: 10.0, y: 20.0)
                .scaledBy(x: 2.0, y: 3.0)
                .rotated(by: CGFloat.pi / 4)
            let inverted = transform.inverted()

            let original = CGPoint(x: 5.0, y: 7.0)
            let transformed = original.applying(transform)
            let restored = transformed.applying(inverted)

            #expect(abs(restored.x - original.x) < 0.0001)
            #expect(abs(restored.y - original.y) < 0.0001)
        }

        @Test("Invert singular matrix returns self")
        func invertSingular() {
            let singular = CGAffineTransform(scaleX: 0.0, y: 0.0)
            let inverted = singular.inverted()
            #expect(inverted == singular)
        }
    }

    // MARK: - Decomposition Tests

    @Suite("Decomposition")
    struct DecompositionTests {

        @Test("Decompose identity")
        func decomposeIdentity() {
            let components = CGAffineTransform.identity.decomposed()
            #expect(components.scale.width == 1.0)
            #expect(components.scale.height == 1.0)
            #expect(abs(components.rotation - 0.0) < 0.0001)
            #expect(abs(components.horizontalShear - 0.0) < 0.0001)
            #expect(components.translation.dx == 0.0)
            #expect(components.translation.dy == 0.0)
        }

        @Test("Decompose translation")
        func decomposeTranslation() {
            let transform = CGAffineTransform(translationX: 10.0, y: 20.0)
            let components = transform.decomposed()
            #expect(components.translation.dx == 10.0)
            #expect(components.translation.dy == 20.0)
        }

        @Test("Decompose scale")
        func decomposeScale() {
            let transform = CGAffineTransform(scaleX: 2.0, y: 3.0)
            let components = transform.decomposed()
            #expect(abs(components.scale.width - 2.0) < 0.0001)
            #expect(abs(components.scale.height - 3.0) < 0.0001)
        }

        @Test("Init from components")
        func initFromComponents() {
            let components = CGAffineTransformComponents(
                scale: CGSize(width: 2.0, height: 2.0),
                horizontalShear: 0.0,
                rotation: 0.0,
                translation: CGVector(dx: 10.0, dy: 20.0)
            )
            let transform = CGAffineTransform(components)
            let point = CGPoint(x: 5.0, y: 5.0)
            let transformed = point.applying(transform)
            #expect(abs(transformed.x - 20.0) < 0.0001)
            #expect(abs(transformed.y - 30.0) < 0.0001)
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Equal transforms")
        func equalTransforms() {
            let t1 = CGAffineTransform(a: 1.0, b: 2.0, c: 3.0, d: 4.0, tx: 5.0, ty: 6.0)
            let t2 = CGAffineTransform(a: 1.0, b: 2.0, c: 3.0, d: 4.0, tx: 5.0, ty: 6.0)
            #expect(t1 == t2)
        }

        @Test("Unequal transforms")
        func unequalTransforms() {
            let t1 = CGAffineTransform.identity
            let t2 = CGAffineTransform(translationX: 1.0, y: 0.0)
            #expect(t1 != t2)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Equal transforms have equal hashes")
        func equalTransformsEqualHashes() {
            let t1 = CGAffineTransform(translationX: 10.0, y: 20.0)
            let t2 = CGAffineTransform(translationX: 10.0, y: 20.0)
            #expect(t1.hashValue == t2.hashValue)
        }

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGAffineTransform>()
            set.insert(CGAffineTransform.identity)
            set.insert(CGAffineTransform(translationX: 10.0, y: 20.0))
            set.insert(CGAffineTransform.identity)
            #expect(set.count == 2)
        }
    }

    // MARK: - Codable Tests

    @Suite("Codable Conformance")
    struct CodableTests {

        @Test("Encode and decode")
        func encodeAndDecode() throws {
            let original = CGAffineTransform(a: 1.0, b: 2.0, c: 3.0, d: 4.0, tx: 5.0, ty: 6.0)
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGAffineTransform.self, from: data)
            #expect(original == decoded)
        }

        @Test("Encode and decode identity")
        func encodeAndDecodeIdentity() throws {
            let original = CGAffineTransform.identity
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGAffineTransform.self, from: data)
            #expect(decoded.isIdentity)
        }
    }
}

// MARK: - CGAffineTransformComponents Tests

@Suite("CGAffineTransformComponents Tests")
struct CGAffineTransformComponentsTests {

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Default initializer creates identity components")
        func defaultInit() {
            let components = CGAffineTransformComponents()
            #expect(components.scale.width == 1.0)
            #expect(components.scale.height == 1.0)
            #expect(components.horizontalShear == 0.0)
            #expect(components.rotation == 0.0)
            #expect(components.translation.dx == 0.0)
            #expect(components.translation.dy == 0.0)
        }

        @Test("Init with CGFloat values")
        func initWithCGFloat() {
            let components = CGAffineTransformComponents(
                scale: CGSize(width: 2.0, height: 3.0),
                horizontalShear: CGFloat(0.5),
                rotation: CGFloat.pi / 4,
                translation: CGVector(dx: 10.0, dy: 20.0)
            )
            #expect(components.scale.width == 2.0)
            #expect(components.scale.height == 3.0)
            #expect(components.horizontalShear == 0.5)
            #expect(abs(components.rotation - Double.pi / 4) < 0.0001)
            #expect(components.translation.dx == 10.0)
            #expect(components.translation.dy == 20.0)
        }

        @Test("Init with Double values")
        func initWithDouble() {
            let components = CGAffineTransformComponents(
                scale: CGSize(width: 2.0, height: 3.0),
                horizontalShear: 0.5,
                rotation: Double.pi / 4,
                translation: CGVector(dx: 10.0, dy: 20.0)
            )
            #expect(components.horizontalShear == 0.5)
            #expect(abs(components.rotation - Double.pi / 4) < 0.0001)
        }
    }

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Equal components")
        func equalComponents() {
            let c1 = CGAffineTransformComponents(
                scale: CGSize(width: 2.0, height: 2.0),
                horizontalShear: CGFloat(0.5),
                rotation: CGFloat(1.0),
                translation: CGVector(dx: 10.0, dy: 20.0)
            )
            let c2 = CGAffineTransformComponents(
                scale: CGSize(width: 2.0, height: 2.0),
                horizontalShear: CGFloat(0.5),
                rotation: CGFloat(1.0),
                translation: CGVector(dx: 10.0, dy: 20.0)
            )
            #expect(c1 == c2)
        }

        @Test("Unequal components")
        func unequalComponents() {
            let c1 = CGAffineTransformComponents()
            let c2 = CGAffineTransformComponents(
                scale: CGSize(width: 2.0, height: 2.0),
                horizontalShear: CGFloat(0.0),
                rotation: CGFloat(0.0),
                translation: CGVector(dx: 0.0, dy: 0.0)
            )
            #expect(c1 != c2)
        }
    }

    @Suite("Codable Conformance")
    struct CodableTests {

        @Test("Encode and decode")
        func encodeAndDecode() throws {
            let original = CGAffineTransformComponents(
                scale: CGSize(width: 2.0, height: 3.0),
                horizontalShear: CGFloat(0.5),
                rotation: CGFloat(1.0),
                translation: CGVector(dx: 10.0, dy: 20.0)
            )
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(CGAffineTransformComponents.self, from: data)
            #expect(original == decoded)
        }
    }
}
