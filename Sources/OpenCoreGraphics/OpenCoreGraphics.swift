//
//  OpenCoreGraphics.swift
//  OpenCoreGraphics
//
//  Re-export Foundation for geometry types (CGFloat, CGPoint, CGSize, CGRect)
//  and CGExtensions for protocol conformances on Darwin platforms.
//

@_exported import Foundation
@_exported import CGExtensions

#if arch(wasm32)
import SwiftWebGPU
import JavaScriptKit

/// Initializes WebGPU for graphics rendering.
///
/// Call this function once at application startup before creating any `CGContext`.
/// This performs asynchronous WebGPU initialization (adapter and device creation).
///
/// ```swift
/// @main
/// struct MyApp {
///     static func main() async throws {
///         // Initialize WebGPU
///         try await setupGraphicsContext()
///
///         // Now CGContext works normally
///         let context = CGContext(...)!
///         context.setFillColor(.red)
///         context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
///
///         let image = await context.makeImageAsync()
///     }
/// }
/// ```
///
/// - Throws: `GraphicsContextError` if WebGPU is not supported or initialization fails.
public func setupGraphicsContext() async throws {
    // Check WebGPU support
    let gpu = JSObject.global.navigator.gpu
    guard !gpu.isUndefined else {
        throw GraphicsContextError.webGPUNotSupported
    }

    // Request adapter
    let adapterPromise = gpu.requestAdapter()
    let adapter = try await JSPromise(adapterPromise.object!)!.value

    guard !adapter.isUndefined && !adapter.isNull else {
        throw GraphicsContextError.adapterNotAvailable
    }

    // Request device
    let devicePromise = adapter.requestDevice()
    let device = try await JSPromise(devicePromise.object!)!.value

    guard !device.isUndefined && !device.isNull else {
        throw GraphicsContextError.deviceNotAvailable
    }

    // Store device globally for CGContext to access
    JSObject.global.__cgDevice = device
}

/// Errors that can occur during graphics context initialization.
public enum GraphicsContextError: Error, CustomStringConvertible {
    /// WebGPU is not supported in this browser.
    case webGPUNotSupported
    /// Failed to obtain a WebGPU adapter.
    case adapterNotAvailable
    /// Failed to obtain a WebGPU device.
    case deviceNotAvailable

    public var description: String {
        switch self {
        case .webGPUNotSupported:
            return "WebGPU is not supported in this browser"
        case .adapterNotAvailable:
            return "Failed to obtain WebGPU adapter"
        case .deviceNotAvailable:
            return "Failed to obtain WebGPU device"
        }
    }
}
#endif
