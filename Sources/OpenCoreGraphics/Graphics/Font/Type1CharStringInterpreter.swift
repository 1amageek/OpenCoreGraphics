//
//  Type1CharStringInterpreter.swift
//  OpenCoreGraphics
//
//  Adobe Type 1 CharString execution.
//

import Foundation

internal final class Type1CharStringInterpreter {
    private enum Control {
        case returned
        case ended
    }

    private let program: Type1FontProgram
    private let glyphIndex: Int
    private let activeGlyphs: Set<Int>
    private let path = CGMutablePath()
    private var stack: [CGFloat] = []
    private var otherSubroutineResults: [CGFloat] = []
    private var current = CGPoint.zero
    private var sideBearing = CGPoint.zero
    private var advance = CGSize.zero
    private var hasMetrics = false
    private var hasOpenContour = false
    private var flexStart: CGPoint?
    private var flexPoints: [CGPoint] = []
    private var isValid = true

    init(program: Type1FontProgram, glyphIndex: Int, activeGlyphs: Set<Int> = []) {
        self.program = program
        self.glyphIndex = glyphIndex
        self.activeGlyphs = activeGlyphs
    }

    func parse() -> Type1Glyph? {
        guard !activeGlyphs.contains(glyphIndex),
              let charString = program.decryptedCharString(at: glyphIndex),
              let control = execute(charString, depth: 0, isSubroutine: false),
              control == .ended, hasMetrics, isValid else {
            return nil
        }
        closeContour()
        guard let copiedPath = path.copy() else { return nil }
        return Type1Glyph(path: copiedPath, sideBearing: sideBearing, advance: advance)
    }

    private func execute(_ data: Data, depth: Int, isSubroutine: Bool) -> Control? {
        guard depth <= 10, data.count <= 65_535 else { return nil }
        var cursor = 0
        while cursor < data.count {
            let byte = data.readUInt8(at: cursor)
            if byte >= 32 || byte == 255 {
                guard stack.count < 24, let value = decodeNumber(data, cursor: &cursor) else { return nil }
                stack.append(value)
                continue
            }
            cursor += 1
            switch byte {
            case 1, 3:
                guard stack.count == 2 else { return nil }
                stack.removeAll(keepingCapacity: true)
            case 4:
                guard stack.count == 1 else { return nil }
                move(dx: 0, dy: stack[0])
                stack.removeAll(keepingCapacity: true)
            case 5:
                guard stack.count == 2 else { return nil }
                line(dx: stack[0], dy: stack[1])
                stack.removeAll(keepingCapacity: true)
            case 6:
                guard stack.count == 1 else { return nil }
                line(dx: stack[0], dy: 0)
                stack.removeAll(keepingCapacity: true)
            case 7:
                guard stack.count == 1 else { return nil }
                line(dx: 0, dy: stack[0])
                stack.removeAll(keepingCapacity: true)
            case 8:
                guard stack.count == 6 else { return nil }
                curve(stack)
                stack.removeAll(keepingCapacity: true)
            case 9:
                guard stack.isEmpty else { return nil }
                closeContour()
            case 10:
                guard let index = popInteger(),
                      let subroutine = program.decryptedSubroutine(at: index),
                      let control = execute(subroutine, depth: depth + 1, isSubroutine: true) else {
                    return nil
                }
                if control == .ended { return .ended }
            case 11:
                guard isSubroutine else { return nil }
                return .returned
            case 12:
                guard cursor < data.count else { return nil }
                let escaped = data.readUInt8(at: cursor)
                cursor += 1
                guard applyEscapedOperator(escaped) else { return nil }
            case 13:
                guard stack.count == 2 else { return nil }
                setMetrics(sideBearingX: stack[0], sideBearingY: 0, widthX: stack[1], widthY: 0)
                stack.removeAll(keepingCapacity: true)
            case 14:
                guard stack.isEmpty, !isSubroutine else { return nil }
                return .ended
            case 21:
                guard stack.count == 2 else { return nil }
                move(dx: stack[0], dy: stack[1])
                stack.removeAll(keepingCapacity: true)
            case 22:
                guard stack.count == 1 else { return nil }
                move(dx: stack[0], dy: 0)
                stack.removeAll(keepingCapacity: true)
            case 30:
                guard stack.count == 4 else { return nil }
                curve([0, stack[0], stack[1], stack[2], stack[3], 0])
                stack.removeAll(keepingCapacity: true)
            case 31:
                guard stack.count == 4 else { return nil }
                curve([stack[0], 0, stack[1], stack[2], 0, stack[3]])
                stack.removeAll(keepingCapacity: true)
            default:
                return nil
            }
            guard isValid, stack.count <= 24, stack.allSatisfy(\.isFinite) else { return nil }
        }
        return isSubroutine ? .returned : nil
    }

    private func decodeNumber(_ data: Data, cursor: inout Int) -> CGFloat? {
        guard cursor < data.count else { return nil }
        let byte = data.readUInt8(at: cursor)
        cursor += 1
        switch byte {
        case 32...246:
            return CGFloat(Int(byte) - 139)
        case 247...250:
            guard cursor < data.count else { return nil }
            let next = Int(data.readUInt8(at: cursor))
            cursor += 1
            return CGFloat((Int(byte) - 247) * 256 + next + 108)
        case 251...254:
            guard cursor < data.count else { return nil }
            let next = Int(data.readUInt8(at: cursor))
            cursor += 1
            return CGFloat(-((Int(byte) - 251) * 256) - next - 108)
        case 255:
            guard cursor <= data.count - 4 else { return nil }
            let value = data.readInt32BE(at: cursor)
            cursor += 4
            return CGFloat(value)
        default:
            return nil
        }
    }

    private func applyEscapedOperator(_ operation: UInt8) -> Bool {
        switch operation {
        case 0:
            guard stack.isEmpty else { return false }
        case 1, 2:
            guard stack.count == 6 else { return false }
            stack.removeAll(keepingCapacity: true)
        case 6:
            return applySeac()
        case 7:
            guard stack.count == 4 else { return false }
            setMetrics(
                sideBearingX: stack[0], sideBearingY: stack[1],
                widthX: stack[2], widthY: stack[3]
            )
            stack.removeAll(keepingCapacity: true)
        case 12:
            guard let divisor = stack.popLast(), let dividend = stack.popLast(), divisor != 0 else {
                return false
            }
            stack.append(dividend / divisor)
        case 16:
            return callOtherSubroutine()
        case 17:
            guard !otherSubroutineResults.isEmpty, stack.count < 24 else { return false }
            stack.append(otherSubroutineResults.removeFirst())
        case 33:
            guard stack.count == 2, stack[0].isFinite, stack[1].isFinite else { return false }
            current = CGPoint(x: stack[0], y: stack[1])
            stack.removeAll(keepingCapacity: true)
        default:
            return false
        }
        return true
    }

    private func applySeac() -> Bool {
        guard stack.count == 5,
              let baseCode = integer(stack[3]), let accentCode = integer(stack[4]),
              let baseName = Self.standardEncodingName(for: baseCode),
              let accentName = Self.standardEncodingName(for: accentCode),
              let baseIndex = program.glyphIndex(named: baseName),
              let accentIndex = program.glyphIndex(named: accentName),
              baseIndex != glyphIndex, accentIndex != glyphIndex,
              let base = Type1CharStringInterpreter(
                program: program,
                glyphIndex: baseIndex,
                activeGlyphs: activeGlyphs.union([glyphIndex])
              ).parse(),
              let accent = Type1CharStringInterpreter(
                program: program,
                glyphIndex: accentIndex,
                activeGlyphs: activeGlyphs.union([glyphIndex])
              ).parse() else {
            return false
        }
        closeContour()
        path.addPath(base.path)
        let transform = CGAffineTransform(
            translationX: stack[1] - stack[0] + accent.sideBearing.x,
            y: stack[2] + accent.sideBearing.y
        )
        path.addPath(accent.path, transform: transform)
        current = .zero
        stack.removeAll(keepingCapacity: true)
        return true
    }

    private func callOtherSubroutine() -> Bool {
        guard let subroutine = popInteger(), let argumentCount = popInteger(),
              argumentCount >= 0, argumentCount <= stack.count else { return false }
        let start = stack.count - argumentCount
        let arguments = Array(stack[start...])
        stack.removeSubrange(start...)
        switch subroutine {
        case 0:
            guard arguments.count == 3, flexStart != nil, flexPoints.count == 7,
                  hasOpenContour else { return false }
            path.addCurve(
                to: flexPoints[3],
                control1: flexPoints[1],
                control2: flexPoints[2]
            )
            path.addCurve(
                to: flexPoints[6],
                control1: flexPoints[4],
                control2: flexPoints[5]
            )
            current = flexPoints[6]
            hasOpenContour = true
            otherSubroutineResults = [arguments[1], arguments[2]]
            self.flexStart = nil
            flexPoints.removeAll(keepingCapacity: true)
        case 1:
            guard arguments.isEmpty, flexStart == nil else { return false }
            flexStart = current
            flexPoints.removeAll(keepingCapacity: true)
            otherSubroutineResults.removeAll(keepingCapacity: true)
        case 2:
            guard arguments.isEmpty, flexStart != nil, flexPoints.count < 7 else { return false }
            flexPoints.append(current)
            otherSubroutineResults.removeAll(keepingCapacity: true)
        case 3:
            otherSubroutineResults = arguments
        default:
            otherSubroutineResults = arguments
        }
        return true
    }

    private func setMetrics(
        sideBearingX: CGFloat,
        sideBearingY: CGFloat,
        widthX: CGFloat,
        widthY: CGFloat
    ) {
        guard !hasMetrics, sideBearingX.isFinite, sideBearingY.isFinite,
              widthX.isFinite, widthY.isFinite else {
            isValid = false
            return
        }
        sideBearing = CGPoint(x: sideBearingX, y: sideBearingY)
        advance = CGSize(width: widthX, height: widthY)
        current = sideBearing
        hasMetrics = true
    }

    private func move(dx: CGFloat, dy: CGFloat) {
        if flexStart == nil { closeContour() }
        current = CGPoint(x: current.x + dx, y: current.y + dy)
        guard current.x.isFinite, current.y.isFinite else {
            isValid = false
            return
        }
        if flexStart == nil {
            path.move(to: current)
            hasOpenContour = true
        }
    }

    private func line(dx: CGFloat, dy: CGFloat) {
        guard hasOpenContour, flexStart == nil else {
            isValid = false
            return
        }
        current = CGPoint(x: current.x + dx, y: current.y + dy)
        guard current.x.isFinite, current.y.isFinite else {
            isValid = false
            return
        }
        path.addLine(to: current)
    }

    private func curve(_ values: [CGFloat]) {
        guard values.count == 6, hasOpenContour, flexStart == nil else {
            isValid = false
            return
        }
        let control1 = CGPoint(x: current.x + values[0], y: current.y + values[1])
        let control2 = CGPoint(x: control1.x + values[2], y: control1.y + values[3])
        let end = CGPoint(x: control2.x + values[4], y: control2.y + values[5])
        guard control1.x.isFinite, control1.y.isFinite,
              control2.x.isFinite, control2.y.isFinite,
              end.x.isFinite, end.y.isFinite else {
            isValid = false
            return
        }
        path.addCurve(to: end, control1: control1, control2: control2)
        current = end
    }

    private func closeContour() {
        if hasOpenContour {
            path.closeSubpath()
            hasOpenContour = false
        }
    }

    private func popInteger() -> Int? {
        guard let value = stack.popLast() else { return nil }
        return integer(value)
    }

    private func integer(_ value: CGFloat) -> Int? {
        guard value.isFinite, value.rounded(.towardZero) == value,
              value >= CGFloat(Int.min), value <= CGFloat(Int.max) else { return nil }
        return Int(value)
    }

    private static func standardEncodingName(for code: Int) -> String? {
        guard (0...255).contains(code) else { return nil }
        if code == 32 { return "space" }
        if (33...126).contains(code) {
            return asciiNames[code - 33]
        }
        return extendedStandardEncoding[code]
    }

    private static let asciiNames = [
        "exclam", "quotedbl", "numbersign", "dollar", "percent", "ampersand", "quoteright",
        "parenleft", "parenright", "asterisk", "plus", "comma", "hyphen", "period", "slash",
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "colon", "semicolon", "less", "equal", "greater", "question", "at",
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
        "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "bracketleft", "backslash", "bracketright", "asciicircum", "underscore", "quoteleft",
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o",
        "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        "braceleft", "bar", "braceright", "asciitilde",
    ]

    private static let extendedStandardEncoding: [Int: String] = [
        161: "exclamdown", 162: "cent", 163: "sterling", 164: "fraction", 165: "yen",
        166: "florin", 167: "section", 168: "currency", 169: "quotesingle",
        170: "quotedblleft", 171: "guillemotleft", 172: "guilsinglleft",
        173: "guilsinglright", 174: "fi", 175: "fl", 177: "endash", 178: "dagger",
        179: "daggerdbl", 180: "periodcentered", 182: "paragraph", 183: "bullet",
        184: "quotesinglbase", 185: "quotedblbase", 186: "quotedblright",
        187: "guillemotright", 188: "ellipsis", 189: "perthousand", 191: "questiondown",
        193: "grave", 194: "acute", 195: "circumflex", 196: "tilde", 197: "macron",
        198: "breve", 199: "dotaccent", 200: "dieresis", 202: "ring", 203: "cedilla",
        205: "hungarumlaut", 206: "ogonek", 207: "caron", 208: "emdash",
        225: "AE", 227: "ordfeminine", 232: "Lslash", 233: "Oslash", 234: "OE",
        235: "ordmasculine", 241: "ae", 245: "dotlessi", 248: "lslash",
        249: "oslash", 250: "oe", 251: "germandbls",
    ]
}
