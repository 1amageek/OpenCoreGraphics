//
//  CGFunctionTests.swift
//  OpenCoreGraphics
//
//  Tests for CGFunction and CGFunctionCallbacks
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = Foundation.CGFloat
private typealias CGFunction = OpenCoreGraphics.CGFunction
private typealias CGFunctionCallbacks = OpenCoreGraphics.CGFunctionCallbacks

@Suite("CGFunction Tests")
struct CGFunctionTests {

    // MARK: - Callbacks Structure Tests

    @Suite("CGFunctionCallbacks")
    struct CallbacksTests {

        @Test("Create callbacks structure")
        func createCallbacksStructure() {
            let callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: { _, _, _ in },
                releaseInfo: nil
            )

            #expect(callbacks.version == 0)
            #expect(callbacks.evaluate != nil)
            #expect(callbacks.releaseInfo == nil)
        }

        @Test("Create callbacks with all fields")
        func createCallbacksWithAllFields() {
            let callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: { _, _, _ in },
                releaseInfo: { _ in }
            )

            #expect(callbacks.evaluate != nil)
            #expect(callbacks.releaseInfo != nil)
        }
    }

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Init with valid parameters")
        func initWithValidParameters() {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
            var callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: { _, input, output in
                    guard let input = input, let output = output else { return }
                    output[0] = input[0]
                    output[1] = input[0]
                    output[2] = input[0]
                },
                releaseInfo: nil
            )

            let function = domain.withUnsafeBufferPointer { domainPtr in
                range.withUnsafeBufferPointer { rangePtr in
                    withUnsafePointer(to: &callbacks) { callbacksPtr in
                        CGFunction(
                            info: nil,
                            domainDimension: 1,
                            domain: domainPtr.baseAddress,
                            rangeDimension: 3,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }

            #expect(function != nil)
            #expect(function?.domainDimension == 1)
            #expect(function?.rangeDimension == 3)
        }

        @Test("Init without evaluate callback returns nil")
        func initWithoutEvaluate() {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0]
            var callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: nil,
                releaseInfo: nil
            )

            let function = domain.withUnsafeBufferPointer { domainPtr in
                range.withUnsafeBufferPointer { rangePtr in
                    withUnsafePointer(to: &callbacks) { callbacksPtr in
                        CGFunction(
                            info: nil,
                            domainDimension: 1,
                            domain: domainPtr.baseAddress,
                            rangeDimension: 1,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }

            #expect(function == nil)
        }

        @Test("Init with negative domain dimension returns nil")
        func initWithNegativeDomainDimension() {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0]
            var callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: { _, _, _ in },
                releaseInfo: nil
            )

            let function = domain.withUnsafeBufferPointer { domainPtr in
                range.withUnsafeBufferPointer { rangePtr in
                    withUnsafePointer(to: &callbacks) { callbacksPtr in
                        CGFunction(
                            info: nil,
                            domainDimension: -1,
                            domain: domainPtr.baseAddress,
                            rangeDimension: 1,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }

            #expect(function == nil)
        }

        @Test("Init with zero dimensions")
        func initWithZeroDimensions() {
            var callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: { _, _, _ in },
                releaseInfo: nil
            )

            let function = withUnsafePointer(to: &callbacks) { callbacksPtr in
                CGFunction(
                    info: nil,
                    domainDimension: 0,
                    domain: nil,
                    rangeDimension: 0,
                    range: nil,
                    callbacks: callbacksPtr
                )
            }

            #expect(function != nil)
            #expect(function?.domainDimension == 0)
            #expect(function?.rangeDimension == 0)
        }
    }

    // MARK: - Properties Tests

    @Suite("Properties")
    struct PropertiesTests {

        fileprivate func createTestFunction() -> CGFunction? {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0, 0.0, 1.0]
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
                            rangeDimension: 2,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }
        }

        @Test("Domain dimension")
        func domainDimension() {
            let function = createTestFunction()
            #expect(function?.domainDimension == 1)
        }

        @Test("Range dimension")
        func rangeDimension() {
            let function = createTestFunction()
            #expect(function?.rangeDimension == 2)
        }

        @Test("Domain array")
        func domainArray() {
            let function = createTestFunction()
            #expect(function?.domain.count == 2)
            #expect(function?.domain[0] == 0.0)
            #expect(function?.domain[1] == 1.0)
        }

        @Test("Range array")
        func rangeArray() {
            let function = createTestFunction()
            #expect(function?.range.count == 4)
        }

        @Test("Type ID")
        func typeID() {
            let _ = CGFunction.typeID
        }
    }

    // MARK: - Evaluation Tests

    @Suite("Evaluation")
    struct EvaluationTests {

        @Test("Evaluate with array input")
        func evaluateWithArrayInput() {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
            var callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: { _, input, output in
                    guard let input = input, let output = output else { return }
                    let t = input[0]
                    output[0] = CGFloat(t)
                    output[1] = CGFloat(t * 0.5)
                    output[2] = CGFloat(1.0 - t)
                },
                releaseInfo: nil
            )

            let function = domain.withUnsafeBufferPointer { domainPtr in
                range.withUnsafeBufferPointer { rangePtr in
                    withUnsafePointer(to: &callbacks) { callbacksPtr in
                        CGFunction(
                            info: nil,
                            domainDimension: 1,
                            domain: domainPtr.baseAddress,
                            rangeDimension: 3,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }

            let input: [CGFloat] = [0.5]
            let output = function?.evaluate(input: input)

            #expect(output?.count == 3)
            #expect(output?[0] == 0.5)
            #expect(output?[1] == 0.25)
            #expect(output?[2] == 0.5)
        }

        @Test("Evaluate at boundary values")
        func evaluateAtBoundaryValues() {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0]
            var callbacks = CGFunctionCallbacks(
                version: 0,
                evaluate: { _, input, output in
                    guard let input = input, let output = output else { return }
                    output[0] = input[0]
                },
                releaseInfo: nil
            )

            let function = domain.withUnsafeBufferPointer { domainPtr in
                range.withUnsafeBufferPointer { rangePtr in
                    withUnsafePointer(to: &callbacks) { callbacksPtr in
                        CGFunction(
                            info: nil,
                            domainDimension: 1,
                            domain: domainPtr.baseAddress,
                            rangeDimension: 1,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }

            let output0 = function?.evaluate(input: [0.0])
            let output1 = function?.evaluate(input: [1.0])

            #expect(output0?[0] == 0.0)
            #expect(output1?[0] == 1.0)
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable Conformance")
    struct EquatableTests {

        fileprivate func createTestFunction() -> CGFunction? {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0]
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
                            rangeDimension: 1,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }
        }

        @Test("Same instance is equal")
        func sameInstanceEqual() {
            let function = createTestFunction()
            #expect(function == function)
        }

        @Test("Different instances are not equal")
        func differentInstancesNotEqual() {
            let function1 = createTestFunction()
            let function2 = createTestFunction()
            #expect(function1 != function2)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable Conformance")
    struct HashableTests {

        fileprivate func createTestFunction() -> CGFunction? {
            let domain: [CGFloat] = [0.0, 1.0]
            let range: [CGFloat] = [0.0, 1.0]
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
                            rangeDimension: 1,
                            range: rangePtr.baseAddress,
                            callbacks: callbacksPtr
                        )
                    }
                }
            }
        }

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGFunction>()
            if let f1 = createTestFunction(), let f2 = createTestFunction() {
                set.insert(f1)
                set.insert(f2)
                set.insert(f1)  // Duplicate
                #expect(set.count == 2)
            }
        }
    }
}
