//
//  CGShadingTests.swift
//  OpenCoreGraphics
//
//  Tests for CGShading
//

import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGShading = OpenCoreGraphics.CGShading
private typealias CGFunction = OpenCoreGraphics.CGFunction
private typealias CGFunctionCallbacks = OpenCoreGraphics.CGFunctionCallbacks
private typealias CGColorSpace = OpenCoreGraphics.CGColorSpace

@Suite("CGShading Tests")
struct CGShadingTests {

    // MARK: - Helper Methods

    fileprivate func createTestFunction() -> CGFunction? {
        let domain: [CGFloat] = [0.0, 1.0]
        let range: [CGFloat] = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0]  // RGBA
        var callbacks = CGFunctionCallbacks(
            version: 0,
            evaluate: { _, input, output in
                guard let input = input, let output = output else { return }
                let t = Double(input[0])
                output[0] = CGFloat(t)       // R
                output[1] = CGFloat(0.0)     // G
                output[2] = CGFloat(1.0 - t) // B
                output[3] = CGFloat(1.0)     // A
            },
            releaseInfo: nil
        )

        return domain.withUnsafeBufferPointer { domainPtr in
            range.withUnsafeBufferPointer { rangePtr in
                withUnsafePointer(to: &callbacks) { callbacksPtr in
                    CGFunction(
                        info: nil,
                        domainDimension: 1,
                        domain: domainPtr.baseAddress,
                        rangeDimension: 4,
                        range: rangePtr.baseAddress,
                        callbacks: callbacksPtr
                    )
                }
            }
        }
    }

    // MARK: - Axial Shading Tests

    @Suite("Axial Shading")
    struct AxialShadingTests {

        fileprivate func createTestFunction() -> CGFunction? {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
            var callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: { _, _, _ in },
                releaseInfo: nil
            )

            return domain.withUnsafeBufferPointer { domainPtr in
                range.withUnsafeBufferPointer { rangePtr in
                    withUnsafePointer(to: &callbacks) { callbacksPtr in
                        CGFunction(
                            info: nil,
                            domainDimension: 1,
                            domain: domainPtr.baseAddress,
                            rangeDimension: 4,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }
        }

        @Test("Init axial shading")
        func initAxialShading() {
            guard let function = createTestFunction() else {
                #expect(Bool(false), "Failed to create function")
                return
            }

            let colorSpace = CGColorSpace.deviceRGB
            let shading = CGShading(
                axialSpace: colorSpace,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 100, y: 100),
                function: function,
                extendStart: true,
                extendEnd: true
            )

            #expect(shading != nil)
            #expect(shading?.type == .axial)
            #expect(shading?.startPoint.x == 0)
            #expect(shading?.endPoint.x == 100)
            #expect(shading?.extendStart == true)
            #expect(shading?.extendEnd == true)
        }

        @Test("Axial shading with headroom")
        func axialShadingWithHeadroom() {
            guard let function = createTestFunction() else {
                #expect(Bool(false), "Failed to create function")
                return
            }

            let colorSpace = CGColorSpace.deviceRGB
            let shading = CGShading(
                axialHeadroom: 2.0,
                space: colorSpace,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 100, y: 0),
                function: function,
                extendStart: false,
                extendEnd: false
            )

            #expect(shading != nil)
            #expect(shading?.contentHeadroom == 2.0)
        }

        @Test("Axial shading radii are zero")
        func axialShadingRadiiAreZero() {
            guard let function = createTestFunction() else {
                #expect(Bool(false), "Failed to create function")
                return
            }

            let colorSpace = CGColorSpace.deviceRGB
            let shading = CGShading(
                axialSpace: colorSpace,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 100, y: 0),
                function: function,
                extendStart: true,
                extendEnd: true
            )

            #expect(shading?.startRadius == 0)
            #expect(shading?.endRadius == 0)
        }
    }

    // MARK: - Radial Shading Tests

    @Suite("Radial Shading")
    struct RadialShadingTests {

        fileprivate func createTestFunction() -> CGFunction? {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
            var callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: { _, _, _ in },
                releaseInfo: nil
            )

            return domain.withUnsafeBufferPointer { domainPtr in
                range.withUnsafeBufferPointer { rangePtr in
                    withUnsafePointer(to: &callbacks) { callbacksPtr in
                        CGFunction(
                            info: nil,
                            domainDimension: 1,
                            domain: domainPtr.baseAddress,
                            rangeDimension: 4,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }
        }

        @Test("Init radial shading")
        func initRadialShading() {
            guard let function = createTestFunction() else {
                #expect(Bool(false), "Failed to create function")
                return
            }

            let colorSpace = CGColorSpace.deviceRGB
            let shading = CGShading(
                radialSpace: colorSpace,
                start: CGPoint(x: 50, y: 50),
                startRadius: 0,
                end: CGPoint(x: 50, y: 50),
                endRadius: 100,
                function: function,
                extendStart: false,
                extendEnd: true
            )

            #expect(shading != nil)
            #expect(shading?.type == .radial)
            #expect(shading?.startRadius == 0)
            #expect(shading?.endRadius == 100)
        }

        @Test("Radial shading with headroom")
        func radialShadingWithHeadroom() {
            guard let function = createTestFunction() else {
                #expect(Bool(false), "Failed to create function")
                return
            }

            let colorSpace = CGColorSpace.deviceRGB
            let shading = CGShading(
                radialHeadroom: 1.5,
                space: colorSpace,
                start: CGPoint(x: 50, y: 50),
                startRadius: 10,
                end: CGPoint(x: 50, y: 50),
                endRadius: 50,
                function: function,
                extendStart: true,
                extendEnd: true
            )

            #expect(shading != nil)
            #expect(shading?.contentHeadroom == 1.5)
        }

        @Test("Radial shading different centers")
        func radialShadingDifferentCenters() {
            guard let function = createTestFunction() else {
                #expect(Bool(false), "Failed to create function")
                return
            }

            let colorSpace = CGColorSpace.deviceRGB
            let shading = CGShading(
                radialSpace: colorSpace,
                start: CGPoint(x: 25, y: 25),
                startRadius: 5,
                end: CGPoint(x: 75, y: 75),
                endRadius: 50,
                function: function,
                extendStart: true,
                extendEnd: true
            )

            #expect(shading?.startPoint.x == 25)
            #expect(shading?.startPoint.y == 25)
            #expect(shading?.endPoint.x == 75)
            #expect(shading?.endPoint.y == 75)
        }
    }

    // MARK: - Properties Tests

    @Suite("Properties")
    struct PropertiesTests {

        fileprivate func createTestFunction() -> CGFunction? {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
            var callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: { _, _, _ in },
                releaseInfo: nil
            )

            return domain.withUnsafeBufferPointer { domainPtr in
                range.withUnsafeBufferPointer { rangePtr in
                    withUnsafePointer(to: &callbacks) { callbacksPtr in
                        CGFunction(
                            info: nil,
                            domainDimension: 1,
                            domain: domainPtr.baseAddress,
                            rangeDimension: 4,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }
        }

        @Test("Color space property")
        func colorSpaceProperty() {
            guard let function = createTestFunction() else {
                #expect(Bool(false), "Failed to create function")
                return
            }

            let colorSpace = CGColorSpace.deviceRGB
            let shading = CGShading(
                axialSpace: colorSpace,
                start: .zero,
                end: CGPoint(x: 100, y: 0),
                function: function,
                extendStart: true,
                extendEnd: true
            )

            #expect(shading?.colorSpace.model == .rgb)
        }

        @Test("Function property")
        func functionProperty() {
            guard let function = createTestFunction() else {
                #expect(Bool(false), "Failed to create function")
                return
            }

            let colorSpace = CGColorSpace.deviceRGB
            let shading = CGShading(
                axialSpace: colorSpace,
                start: .zero,
                end: CGPoint(x: 100, y: 0),
                function: function,
                extendStart: true,
                extendEnd: true
            )

            #expect(shading?.function === function)
        }

        @Test("Type ID")
        func typeID() {
            let _ = CGShading.typeID
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        fileprivate func createTestShading() -> CGShading? {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
            var callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: { _, _, _ in },
                releaseInfo: nil
            )

            guard let function = domain.withUnsafeBufferPointer({ domainPtr in
                range.withUnsafeBufferPointer { rangePtr in
                    withUnsafePointer(to: &callbacks) { callbacksPtr in
                        CGFunction(
                            info: nil,
                            domainDimension: 1,
                            domain: domainPtr.baseAddress,
                            rangeDimension: 4,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }) else { return nil }

            let colorSpace = CGColorSpace.deviceRGB
            return CGShading(
                axialSpace: colorSpace,
                start: .zero,
                end: CGPoint(x: 100, y: 0),
                function: function,
                extendStart: true,
                extendEnd: true
            )
        }

        @Test("Same instance is equal")
        func sameInstanceEqual() {
            let shading = createTestShading()
            #expect(shading == shading)
        }

        @Test("Different instances are not equal")
        func differentInstancesNotEqual() {
            let shading1 = createTestShading()
            let shading2 = createTestShading()
            #expect(shading1 != shading2)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        fileprivate func createTestShading() -> CGShading? {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
            var callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: { _, _, _ in },
                releaseInfo: nil
            )

            guard let function = domain.withUnsafeBufferPointer({ domainPtr in
                range.withUnsafeBufferPointer { rangePtr in
                    withUnsafePointer(to: &callbacks) { callbacksPtr in
                        CGFunction(
                            info: nil,
                            domainDimension: 1,
                            domain: domainPtr.baseAddress,
                            rangeDimension: 4,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }) else { return nil }

            let colorSpace = CGColorSpace.deviceRGB
            return CGShading(
                axialSpace: colorSpace,
                start: .zero,
                end: CGPoint(x: 100, y: 0),
                function: function,
                extendStart: true,
                extendEnd: true
            )
        }

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGShading>()
            if let s1 = createTestShading(), let s2 = createTestShading() {
                set.insert(s1)
                set.insert(s2)
                set.insert(s1)  // Duplicate
                #expect(set.count == 2)
            }
        }
    }
}
