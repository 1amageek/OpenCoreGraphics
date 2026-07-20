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

    func parseCFF2FontProgram(axisCount: Int, unitsPerEm: Int) -> CFF2FontProgram? {
        guard let cffData = tableData(for: FontTableTag.CFF2) else { return nil }
        return CFF2FontProgram(data: cffData, axisCount: axisCount, unitsPerEm: unitsPerEm)
    }
}
