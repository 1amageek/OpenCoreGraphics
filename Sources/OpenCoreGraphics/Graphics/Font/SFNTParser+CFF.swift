//
//  SFNTParser+CFF.swift
//  OpenCoreGraphics
//

import Foundation

extension SFNTParser {
    func parseCFFFontProgram() -> CFFFontProgram? {
        guard let cffData = tableData(for: FontTableTag.CFF) else { return nil }
        return CFFFontProgram(data: cffData)
    }
}
