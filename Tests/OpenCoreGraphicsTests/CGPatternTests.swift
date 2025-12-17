//
//  CGPatternTests.swift
//  OpenCoreGraphics
//
//  Tests for CGPattern and CGPatternTiling
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = Foundation.CGFloat
private typealias CGPattern = OpenCoreGraphics.CGPattern
private typealias CGPatternTiling = OpenCoreGraphics.CGPatternTiling
private typealias CGPatternCallbacks = OpenCoreGraphics.CGPatternCallbacks
private typealias CGRect = Foundation.CGRect
private typealias CGAffineTransform = OpenCoreGraphics.CGAffineTransform

// MARK: - CGPatternTiling Tests

@Suite("CGPatternTiling Tests")
struct CGPatternTilingTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGPatternTiling.noDistortion.rawValue == 0)
        #expect(CGPatternTiling.constantSpacingMinimalDistortion.rawValue == 1)
        #expect(CGPatternTiling.constantSpacing.rawValue == 2)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGPatternTiling(rawValue: 0) == .noDistortion)
        #expect(CGPatternTiling(rawValue: 1) == .constantSpacingMinimalDistortion)
        #expect(CGPatternTiling(rawValue: 2) == .constantSpacing)
        #expect(CGPatternTiling(rawValue: 100) == nil)
    }
}

// MARK: - CGPatternCallbacks Tests

@Suite("CGPatternCallbacks Tests")
struct CGPatternCallbacksTests {

    @Test("Create callbacks structure")
    func createCallbacksStructure() {
        let callbacks = CGPatternCallbacks(
            version: 0,
            drawPattern: { _, _ in },
            releaseInfo: nil
        )

        #expect(callbacks.version == 0)
        #expect(callbacks.drawPattern != nil)
        #expect(callbacks.releaseInfo == nil)
    }

    @Test("Create callbacks with all fields")
    func createCallbacksWithAllFields() {
        let callbacks = CGPatternCallbacks(
            version: 0,
            drawPattern: { _, _ in },
            releaseInfo: { _ in }
        )

        #expect(callbacks.drawPattern != nil)
        #expect(callbacks.releaseInfo != nil)
    }
}

// MARK: - CGPattern Tests

@Suite("CGPattern Tests")
struct CGPatternTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Init with valid parameters")
        func initWithValidParameters() {
            var callbacks = CGPatternCallbacks(
                version: 0,
                drawPattern: { _, _ in },
                releaseInfo: nil
            )

            let pattern = withUnsafePointer(to: &callbacks) { callbacksPtr in
                CGPattern(
                    info: nil,
                    bounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                    matrix: .identity,
                    xStep: 10,
                    yStep: 10,
                    tiling: .noDistortion,
                    isColored: true,
                    callbacks: callbacksPtr
                )
            }

            #expect(pattern != nil)
            #expect(pattern?.bounds == CGRect(x: 0, y: 0, width: 10, height: 10))
            #expect(pattern?.xStep == 10)
            #expect(pattern?.yStep == 10)
            #expect(pattern?.isColored == true)
        }

        @Test("Init without drawPattern callback returns nil")
        func initWithoutDrawPattern() {
            var callbacks = CGPatternCallbacks(
                version: 0,
                drawPattern: nil,
                releaseInfo: nil
            )

            let pattern = withUnsafePointer(to: &callbacks) { callbacksPtr in
                CGPattern(
                    info: nil,
                    bounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                    matrix: .identity,
                    xStep: 10,
                    yStep: 10,
                    tiling: .noDistortion,
                    isColored: true,
                    callbacks: callbacksPtr
                )
            }

            #expect(pattern == nil)
        }

        @Test("Init with zero xStep returns nil")
        func initWithZeroXStep() {
            var callbacks = CGPatternCallbacks(
                version: 0,
                drawPattern: { _, _ in },
                releaseInfo: nil
            )

            let pattern = withUnsafePointer(to: &callbacks) { callbacksPtr in
                CGPattern(
                    info: nil,
                    bounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                    matrix: .identity,
                    xStep: 0,
                    yStep: 10,
                    tiling: .noDistortion,
                    isColored: true,
                    callbacks: callbacksPtr
                )
            }

            #expect(pattern == nil)
        }

        @Test("Init with zero yStep returns nil")
        func initWithZeroYStep() {
            var callbacks = CGPatternCallbacks(
                version: 0,
                drawPattern: { _, _ in },
                releaseInfo: nil
            )

            let pattern = withUnsafePointer(to: &callbacks) { callbacksPtr in
                CGPattern(
                    info: nil,
                    bounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                    matrix: .identity,
                    xStep: 10,
                    yStep: 0,
                    tiling: .noDistortion,
                    isColored: true,
                    callbacks: callbacksPtr
                )
            }

            #expect(pattern == nil)
        }

        @Test("Init uncolored pattern")
        func initUncoloredPattern() {
            var callbacks = CGPatternCallbacks(
                version: 0,
                drawPattern: { _, _ in },
                releaseInfo: nil
            )

            let pattern = withUnsafePointer(to: &callbacks) { callbacksPtr in
                CGPattern(
                    info: nil,
                    bounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                    matrix: .identity,
                    xStep: 10,
                    yStep: 10,
                    tiling: .noDistortion,
                    isColored: false,
                    callbacks: callbacksPtr
                )
            }

            #expect(pattern != nil)
            #expect(pattern?.isColored == false)
        }
    }

    // MARK: - Properties Tests

    @Suite("Properties")
    struct PropertiesTests {

        fileprivate func createTestPattern() -> CGPattern? {
            var callbacks = CGPatternCallbacks(
                version: 0,
                drawPattern: { _, _ in },
                releaseInfo: nil
            )

            return withUnsafePointer(to: &callbacks) { callbacksPtr in
                CGPattern(
                    info: nil,
                    bounds: CGRect(x: 0, y: 0, width: 20, height: 30),
                    matrix: CGAffineTransform(translationX: 5, y: 10),
                    xStep: 25,
                    yStep: 35,
                    tiling: .constantSpacing,
                    isColored: true,
                    callbacks: callbacksPtr
                )
            }
        }

        @Test("Bounds property")
        func boundsProperty() {
            let pattern = createTestPattern()
            #expect(pattern?.bounds.width == 20)
            #expect(pattern?.bounds.height == 30)
        }

        @Test("Matrix property")
        func matrixProperty() {
            let pattern = createTestPattern()
            #expect(pattern?.matrix.tx == 5)
            #expect(pattern?.matrix.ty == 10)
        }

        @Test("Step properties")
        func stepProperties() {
            let pattern = createTestPattern()
            #expect(pattern?.xStep == 25)
            #expect(pattern?.yStep == 35)
        }

        @Test("Tiling property")
        func tilingProperty() {
            let pattern = createTestPattern()
            #expect(pattern?.tiling == .constantSpacing)
        }

        @Test("Type ID")
        func typeID() {
            let _ = CGPattern.typeID
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        fileprivate func createTestPattern() -> CGPattern? {
            var callbacks = CGPatternCallbacks(
                version: 0,
                drawPattern: { _, _ in },
                releaseInfo: nil
            )

            return withUnsafePointer(to: &callbacks) { callbacksPtr in
                CGPattern(
                    info: nil,
                    bounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                    matrix: .identity,
                    xStep: 10,
                    yStep: 10,
                    tiling: .noDistortion,
                    isColored: true,
                    callbacks: callbacksPtr
                )
            }
        }

        @Test("Same instance is equal")
        func sameInstanceEqual() {
            let pattern = createTestPattern()
            #expect(pattern == pattern)
        }

        @Test("Different instances are not equal")
        func differentInstancesNotEqual() {
            let pattern1 = createTestPattern()
            let pattern2 = createTestPattern()
            #expect(pattern1 != pattern2)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        fileprivate func createTestPattern() -> CGPattern? {
            var callbacks = CGPatternCallbacks(
                version: 0,
                drawPattern: { _, _ in },
                releaseInfo: nil
            )

            return withUnsafePointer(to: &callbacks) { callbacksPtr in
                CGPattern(
                    info: nil,
                    bounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                    matrix: .identity,
                    xStep: 10,
                    yStep: 10,
                    tiling: .noDistortion,
                    isColored: true,
                    callbacks: callbacksPtr
                )
            }
        }

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGPattern>()
            if let p1 = createTestPattern(), let p2 = createTestPattern() {
                set.insert(p1)
                set.insert(p2)
                set.insert(p1)  // Duplicate
                #expect(set.count == 2)
            }
        }
    }

    // MARK: - Different Tiling Modes

    @Suite("Tiling Modes")
    struct TilingModesTests {

        fileprivate func createPatternWithTiling(_ tiling: CGPatternTiling) -> CGPattern? {
            var callbacks = CGPatternCallbacks(
                version: 0,
                drawPattern: { _, _ in },
                releaseInfo: nil
            )

            return withUnsafePointer(to: &callbacks) { callbacksPtr in
                CGPattern(
                    info: nil,
                    bounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                    matrix: .identity,
                    xStep: 10,
                    yStep: 10,
                    tiling: tiling,
                    isColored: true,
                    callbacks: callbacksPtr
                )
            }
        }

        @Test("No distortion tiling")
        func noDistortionTiling() {
            let pattern = createPatternWithTiling(.noDistortion)
            #expect(pattern?.tiling == .noDistortion)
        }

        @Test("Constant spacing minimal distortion tiling")
        func constantSpacingMinimalDistortionTiling() {
            let pattern = createPatternWithTiling(.constantSpacingMinimalDistortion)
            #expect(pattern?.tiling == .constantSpacingMinimalDistortion)
        }

        @Test("Constant spacing tiling")
        func constantSpacingTiling() {
            let pattern = createPatternWithTiling(.constantSpacing)
            #expect(pattern?.tiling == .constantSpacing)
        }
    }
}
