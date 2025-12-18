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

        @Test("Invert singular matrix returns identity")
        func invertSingular() {
            let singular = CGAffineTransform(scaleX: 0.0, y: 0.0)
            let inverted = singular.inverted()
            #expect(inverted == .identity)
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

    // MARK: - Mathematical Correctness Tests

    @Suite("Mathematical Correctness")
    struct MathematicalCorrectnessTests {

        private func isApproximatelyEqual(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 0.0001) -> Bool {
            return abs(a - b) < tolerance
        }

        @Test("Transform times inverse equals identity")
        func transformTimesInverseEqualsIdentity() {
            let transform = CGAffineTransform(translationX: 15, y: 25)
                .scaledBy(x: 2.0, y: 3.0)
                .rotated(by: CGFloat.pi / 6)

            let inverse = transform.inverted()
            let product = transform.concatenating(inverse)

            // Should be approximately identity matrix
            #expect(isApproximatelyEqual(product.a, 1.0))
            #expect(isApproximatelyEqual(product.b, 0.0))
            #expect(isApproximatelyEqual(product.c, 0.0))
            #expect(isApproximatelyEqual(product.d, 1.0))
            #expect(isApproximatelyEqual(product.tx, 0.0))
            #expect(isApproximatelyEqual(product.ty, 0.0))
        }

        @Test("Inverse times transform also equals identity")
        func inverseTimesTransformEqualsIdentity() {
            let transform = CGAffineTransform(rotationAngle: CGFloat.pi / 3)
                .scaledBy(x: 1.5, y: 2.5)
                .translatedBy(x: 100, y: 200)

            let inverse = transform.inverted()
            let product = inverse.concatenating(transform)

            #expect(isApproximatelyEqual(product.a, 1.0))
            #expect(isApproximatelyEqual(product.b, 0.0))
            #expect(isApproximatelyEqual(product.c, 0.0))
            #expect(isApproximatelyEqual(product.d, 1.0))
            #expect(isApproximatelyEqual(product.tx, 0.0))
            #expect(isApproximatelyEqual(product.ty, 0.0))
        }

        @Test("Decompose then recompose returns equivalent transform for simple transforms")
        func decomposeRecomposeEquivalent() {
            // Test with a simpler transform (scale only) which can be accurately decomposed
            let original = CGAffineTransform(scaleX: 2.0, y: 3.0)

            let components = original.decomposed()
            let recomposed = CGAffineTransform(components)

            // Test by applying both to the same point
            let testPoints = [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 10, y: 0),
                CGPoint(x: 0, y: 10),
                CGPoint(x: 10, y: 20)
            ]

            for point in testPoints {
                let p1 = point.applying(original)
                let p2 = point.applying(recomposed)
                #expect(isApproximatelyEqual(p1.x, p2.x), "Point \(point) x mismatch: \(p1.x) vs \(p2.x)")
                #expect(isApproximatelyEqual(p1.y, p2.y), "Point \(point) y mismatch: \(p1.y) vs \(p2.y)")
            }
        }

        @Test("Decompose returns valid scale components")
        func decomposeReturnsValidScale() {
            let transform = CGAffineTransform(scaleX: 2.5, y: 1.5)
            let components = transform.decomposed()

            #expect(isApproximatelyEqual(components.scale.width, 2.5))
            #expect(isApproximatelyEqual(components.scale.height, 1.5))
        }

        @Test("Decompose returns valid translation components")
        func decomposeReturnsValidTranslation() {
            let transform = CGAffineTransform(translationX: 15, y: 25)
            let components = transform.decomposed()

            #expect(isApproximatelyEqual(components.translation.dx, 15))
            #expect(isApproximatelyEqual(components.translation.dy, 25))
        }

        @Test("Horizontal shear transforms correctly")
        func horizontalShear() {
            // Shear matrix: [1, 0, shear, 1, 0, 0]
            // x' = x + shear * y
            // y' = y
            let shear: CGFloat = 0.5
            let transform = CGAffineTransform(a: 1, b: 0, c: shear, d: 1, tx: 0, ty: 0)

            let point = CGPoint(x: 0, y: 10)
            let transformed = point.applying(transform)

            // x' = 0 + 0.5 * 10 = 5
            #expect(isApproximatelyEqual(transformed.x, 5.0))
            #expect(isApproximatelyEqual(transformed.y, 10.0))
        }

        @Test("Vertical shear transforms correctly")
        func verticalShear() {
            // Shear matrix: [1, shear, 0, 1, 0, 0]
            // x' = x
            // y' = shear * x + y
            let shear: CGFloat = 0.5
            let transform = CGAffineTransform(a: 1, b: shear, c: 0, d: 1, tx: 0, ty: 0)

            let point = CGPoint(x: 10, y: 0)
            let transformed = point.applying(transform)

            #expect(isApproximatelyEqual(transformed.x, 10.0))
            // y' = 0.5 * 10 + 0 = 5
            #expect(isApproximatelyEqual(transformed.y, 5.0))
        }

        @Test("Singular matrix (zero determinant) inversion returns identity")
        func singularMatrixInversion() {
            // Singular matrix: det = a*d - b*c = 1*4 - 2*2 = 0
            let singular = CGAffineTransform(a: 1, b: 2, c: 2, d: 4, tx: 0, ty: 0)
            let inverted = singular.inverted()

            // When matrix is singular, implementation returns identity
            #expect(inverted == .identity)
        }

        @Test("Scaling by zero creates singular matrix")
        func zeroScaleSingular() {
            let zeroScale = CGAffineTransform(scaleX: 0, y: 0)
            let inverted = zeroScale.inverted()

            // Singular matrix inversion returns identity
            #expect(inverted == .identity)
        }

        @Test("Matrix multiplication is associative")
        func matrixMultiplicationAssociative() {
            let a = CGAffineTransform(translationX: 10, y: 20)
            let b = CGAffineTransform(scaleX: 2, y: 3)
            let c = CGAffineTransform(rotationAngle: CGFloat.pi / 4)

            // (A * B) * C should equal A * (B * C)
            let ab_c = a.concatenating(b).concatenating(c)
            let a_bc = a.concatenating(b.concatenating(c))

            let testPoint = CGPoint(x: 5, y: 7)
            let p1 = testPoint.applying(ab_c)
            let p2 = testPoint.applying(a_bc)

            #expect(isApproximatelyEqual(p1.x, p2.x))
            #expect(isApproximatelyEqual(p1.y, p2.y))
        }

        @Test("Rotation preserves distance from origin")
        func rotationPreservesDistance() {
            let point = CGPoint(x: 3, y: 4)  // distance = 5
            let originalDistance = sqrt(point.x * point.x + point.y * point.y)

            let angles: [CGFloat] = [0.0, CGFloat.pi / 6, CGFloat.pi / 4, CGFloat.pi / 3, CGFloat.pi / 2, CGFloat.pi]

            for angle in angles {
                let transform = CGAffineTransform(rotationAngle: angle)
                let rotated = point.applying(transform)
                let newDistance = sqrt(rotated.x * rotated.x + rotated.y * rotated.y)

                #expect(isApproximatelyEqual(originalDistance, newDistance),
                       "Rotation by \(angle) changed distance from \(originalDistance) to \(newDistance)")
            }
        }

        @Test("Scale changes distance proportionally")
        func scaleChangesDistanceProportionally() {
            let point = CGPoint(x: 3, y: 4)  // distance = 5
            let uniformScale: CGFloat = 2.0

            let transform = CGAffineTransform(scaleX: uniformScale, y: uniformScale)
            let scaled = point.applying(transform)

            let originalDistance = sqrt(point.x * point.x + point.y * point.y)
            let newDistance = sqrt(scaled.x * scaled.x + scaled.y * scaled.y)

            #expect(isApproximatelyEqual(newDistance, originalDistance * uniformScale))
        }

        @Test("Translation does not change shape")
        func translationPreservesVectors() {
            let p1 = CGPoint(x: 0, y: 0)
            let p2 = CGPoint(x: 10, y: 0)
            let p3 = CGPoint(x: 0, y: 10)

            let transform = CGAffineTransform(translationX: 100, y: 200)

            let t1 = p1.applying(transform)
            let t2 = p2.applying(transform)
            let t3 = p3.applying(transform)

            // Vector from t1 to t2 should be same as p1 to p2
            let vec12_original = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
            let vec12_transformed = CGPoint(x: t2.x - t1.x, y: t2.y - t1.y)
            #expect(isApproximatelyEqual(vec12_original.x, vec12_transformed.x))
            #expect(isApproximatelyEqual(vec12_original.y, vec12_transformed.y))

            // Vector from t1 to t3 should be same as p1 to p3
            let vec13_original = CGPoint(x: p3.x - p1.x, y: p3.y - p1.y)
            let vec13_transformed = CGPoint(x: t3.x - t1.x, y: t3.y - t1.y)
            #expect(isApproximatelyEqual(vec13_original.x, vec13_transformed.x))
            #expect(isApproximatelyEqual(vec13_original.y, vec13_transformed.y))
        }
    }

    // MARK: - Apply Operations Tests

    @Suite("Apply Operations")
    struct ApplyOperationsTests {

        private func isApproximatelyEqual(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 0.0001) -> Bool {
            return abs(a - b) < tolerance
        }

        @Test("Apply transform to CGSize scales correctly")
        func applySizeScaling() {
            let size = CGSize(width: 10, height: 20)
            let transform = CGAffineTransform(scaleX: 2, y: 3)

            let transformed = size.applying(transform)

            #expect(isApproximatelyEqual(transformed.width, 20))
            #expect(isApproximatelyEqual(transformed.height, 60))
        }

        @Test("Apply rotation to CGSize")
        func applySizeRotation() {
            let size = CGSize(width: 10, height: 0)
            let transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)

            let transformed = size.applying(transform)

            // After 90 degree rotation, width becomes height
            #expect(isApproximatelyEqual(transformed.width, 0))
            #expect(isApproximatelyEqual(transformed.height, 10))
        }

        @Test("Apply identity to CGRect returns same rect")
        func applyIdentityToRect() {
            let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
            let transformed = rect.applying(CGAffineTransform.identity)

            #expect(transformed == rect)
        }

        @Test("Apply translation to CGRect moves origin")
        func applyTranslationToRect() {
            let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
            let transform = CGAffineTransform(translationX: 100, y: 200)

            let transformed = rect.applying(transform)

            #expect(isApproximatelyEqual(transformed.origin.x, 110))
            #expect(isApproximatelyEqual(transformed.origin.y, 220))
            #expect(isApproximatelyEqual(transformed.size.width, 30))
            #expect(isApproximatelyEqual(transformed.size.height, 40))
        }

        @Test("Apply scale to CGRect scales both origin and size")
        func applyScaleToRect() {
            let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
            let transform = CGAffineTransform(scaleX: 2, y: 2)

            let transformed = rect.applying(transform)

            #expect(isApproximatelyEqual(transformed.origin.x, 20))
            #expect(isApproximatelyEqual(transformed.origin.y, 40))
            #expect(isApproximatelyEqual(transformed.size.width, 60))
            #expect(isApproximatelyEqual(transformed.size.height, 80))
        }
    }

    // MARK: - Sendable Conformance Tests

    @Suite("Sendable Conformance")
    struct SendableTests {

        @Test("CGAffineTransform can be sent across actor boundaries")
        func sendableConformance() async {
            let transform = CGAffineTransform(translationX: 10, y: 20)
            let result = await Task {
                return transform.tx
            }.value
            #expect(result == 10.0)
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
