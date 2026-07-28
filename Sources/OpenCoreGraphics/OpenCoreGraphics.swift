//
//  OpenCoreGraphics.swift
//  OpenCoreGraphics
//
//  Re-export Foundation for geometry types (CGFloat, CGPoint, CGSize, CGRect)
//  and CGExtensions for protocol conformances on Darwin platforms.
//

@_exported import OpenCoreGraphicsSupport

#if arch(wasm32)
@_spi(JavaScriptOwner) import SwiftWebGPU
import JavaScriptKit

private let cgDeviceGlobalKey = "__openCoreGraphicsGPUDevice"

/// Returns the WebGPU device owned by the current JavaScript execution context.
/// - Returns: The device set by `setupGraphicsContext()` on this JavaScript owner.
public func getGlobalDevice() -> GPUDevice? {
    guard let jsObject = JSObject.global[cgDeviceGlobalKey].object else {
        return nil
    }
    return GPUDevice(jsObject: jsObject)
}

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
public nonisolated(nonsending) func setupGraphicsContext() async throws {
    // Check WebGPU support
    guard let gpu = GPU.shared else {
        throw GraphicsContextError.webGPUNotSupported
    }

    // Request adapter
    do {
        guard let adapter = try await gpu.requestAdapter() else {
            throw GraphicsContextError.adapterNotAvailable
        }
        let device = try await adapter.requestDevice()
        JSObject.global[cgDeviceGlobalKey] = device.ownerBoundJSObject.jsValue
    } catch let error as GraphicsContextError {
        throw error
    } catch {
        throw GraphicsContextError.deviceNotAvailable
    }
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
