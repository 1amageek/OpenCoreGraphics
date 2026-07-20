//
//  CGICCMultiProcessPipeline.swift
//  OpenCoreGraphics
//

import Foundation

internal struct CGICCMultiProcessPipeline: Hashable, Sendable {
    let inputChannels: Int
    let outputChannels: Int
    let elements: [CGICCMultiProcessElement]

    func apply(_ input: [CGFloat]) -> [CGFloat]? {
        guard input.count >= inputChannels else { return nil }
        var values = Array(input.prefix(inputChannels))
        for element in elements {
            guard let output = element.apply(values) else { return nil }
            values = output
        }
        return values.count == outputChannels ? values : nil
    }
}
