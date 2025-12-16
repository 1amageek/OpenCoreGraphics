//
//  OpenCoreGraphics.swift
//  OpenCoreGraphics
//
//  A Swift library providing CoreGraphics API compatibility for WebAssembly environments.
//
//  This library provides implementations of CoreGraphics types that work in WASM
//  environments where Apple's CoreGraphics framework is not available.
//
//  Usage:
//  ```swift
//  #if canImport(CoreGraphics)
//  import CoreGraphics
//  #else
//  import OpenCoreGraphics
//  #endif
//  ```
//

// All types are defined in separate files and exported automatically.
// - CGFloat.swift
// - CGPoint.swift
// - CGSize.swift
// - CGRect.swift
// - CGVector.swift
