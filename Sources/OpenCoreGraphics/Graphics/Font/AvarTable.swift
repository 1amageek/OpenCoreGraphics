//
//  AvarTable.swift
//  OpenCoreGraphics
//

import Foundation

internal struct AvarTable: Sendable {
    struct Mapping: Sendable {
        let from: CGFloat
        let to: CGFloat
    }

    let mappingsByAxis: [[Mapping]]

    func map(_ coordinate: CGFloat, axisIndex: Int) -> CGFloat? {
        guard mappingsByAxis.indices.contains(axisIndex) else { return nil }
        let mappings = mappingsByAxis[axisIndex]
        if coordinate <= mappings[0].from { return mappings[0].to }
        if coordinate >= mappings[mappings.count - 1].from { return mappings[mappings.count - 1].to }
        for index in 0..<(mappings.count - 1) {
            let lower = mappings[index]
            let upper = mappings[index + 1]
            if coordinate == lower.from { return lower.to }
            if coordinate < upper.from {
                let fraction = (coordinate - lower.from) / (upper.from - lower.from)
                return lower.to + fraction * (upper.to - lower.to)
            }
        }
        return nil
    }
}

extension SFNTParser {
    func parseAvarTable(axisCount: Int) throws -> AvarTable? {
        guard let tableData = tableData(for: FontTableTag.avar) else { return nil }
        guard axisCount > 0, tableData.count >= 8,
              tableData.readUInt16BE(at: 0) == 1,
              tableData.readUInt16BE(at: 2) <= 1,
              tableData.readUInt16BE(at: 4) == 0,
              Int(tableData.readUInt16BE(at: 6)) == axisCount else {
            throw FontParserError.invalidTableFormat("avar")
        }
        var cursor = 8
        var mappingsByAxis: [[AvarTable.Mapping]] = []
        mappingsByAxis.reserveCapacity(axisCount)
        for _ in 0..<axisCount {
            guard cursor <= tableData.count - 2 else {
                throw FontParserError.invalidTableFormat("avar")
            }
            let count = Int(tableData.readUInt16BE(at: cursor))
            cursor += 2
            guard count >= 3, count <= (tableData.count - cursor) / 4 else {
                throw FontParserError.invalidTableFormat("avar")
            }
            var mappings: [AvarTable.Mapping] = []
            mappings.reserveCapacity(count)
            for _ in 0..<count {
                mappings.append(AvarTable.Mapping(
                    from: tableData.readF2Dot14(at: cursor),
                    to: tableData.readF2Dot14(at: cursor + 2)
                ))
                cursor += 4
            }
            guard mappings.first?.from == -1, mappings.first?.to == -1,
                  mappings.last?.from == 1, mappings.last?.to == 1,
                  mappings.contains(where: { $0.from == 0 && $0.to == 0 }),
                  zip(mappings, mappings.dropFirst()).allSatisfy({ $0.from < $1.from }),
                  mappings.allSatisfy({ (-1...1).contains($0.from) && (-1...1).contains($0.to) }) else {
                throw FontParserError.invalidTableFormat("avar")
            }
            mappingsByAxis.append(mappings)
        }
        return AvarTable(mappingsByAxis: mappingsByAxis)
    }
}
