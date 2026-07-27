#if hasFeature(Embedded)
public struct CGRect: Equatable, Hashable, Sendable, CustomDebugStringConvertible {
    public var origin: CGPoint
    public var size: CGSize

    public init(origin: CGPoint, size: CGSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.init(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
    }

    public static let zero = CGRect(origin: .zero, size: .zero)
    public static let null = CGRect(
        origin: CGPoint(x: .infinity, y: .infinity),
        size: .zero
    )
    public static let infinite = CGRect(
        x: -.greatestFiniteMagnitude / 2,
        y: -.greatestFiniteMagnitude / 2,
        width: .greatestFiniteMagnitude,
        height: .greatestFiniteMagnitude
    )

    public var width: CGFloat { size.width }
    public var height: CGFloat { size.height }
    public var minX: CGFloat { Swift.min(origin.x, origin.x + size.width) }
    public var minY: CGFloat { Swift.min(origin.y, origin.y + size.height) }
    public var midX: CGFloat { (minX + maxX) / 2 }
    public var midY: CGFloat { (minY + maxY) / 2 }
    public var maxX: CGFloat { Swift.max(origin.x, origin.x + size.width) }
    public var maxY: CGFloat { Swift.max(origin.y, origin.y + size.height) }

    public var isNull: Bool {
        origin.x == .infinity || origin.y == .infinity
    }

    public var isInfinite: Bool {
        self == .infinite
    }

    public var isEmpty: Bool {
        isNull || size.width == 0 || size.height == 0
    }

    public var standardized: CGRect {
        guard !isNull else { return .null }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public var integral: CGRect {
        guard !isNull, !isInfinite else { return self }
        let standardized = standardized
        let x = floor(standardized.minX)
        let y = floor(standardized.minY)
        return CGRect(
            x: x,
            y: y,
            width: ceil(standardized.maxX) - x,
            height: ceil(standardized.maxY) - y
        )
    }

    public func equalTo(_ rect: CGRect) -> Bool {
        self == rect
    }

    public func contains(_ point: CGPoint) -> Bool {
        guard !isNull, !isEmpty else { return false }
        return point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    public func contains(_ rect: CGRect) -> Bool {
        guard !isNull, !rect.isNull else { return false }
        if rect.isEmpty { return true }
        return rect.minX >= minX && rect.maxX <= maxX && rect.minY >= minY && rect.maxY <= maxY
    }

    public func intersects(_ rect: CGRect) -> Bool {
        !intersection(rect).isNull
    }

    public func intersection(_ rect: CGRect) -> CGRect {
        guard !isNull, !rect.isNull else { return .null }
        let x1 = Swift.max(minX, rect.minX)
        let y1 = Swift.max(minY, rect.minY)
        let x2 = Swift.min(maxX, rect.maxX)
        let y2 = Swift.min(maxY, rect.maxY)
        guard x2 > x1, y2 > y1 else { return .null }
        return CGRect(x: x1, y: y1, width: x2 - x1, height: y2 - y1)
    }

    public func union(_ rect: CGRect) -> CGRect {
        if isNull { return rect }
        if rect.isNull { return self }
        let x1 = Swift.min(minX, rect.minX)
        let y1 = Swift.min(minY, rect.minY)
        let x2 = Swift.max(maxX, rect.maxX)
        let y2 = Swift.max(maxY, rect.maxY)
        return CGRect(x: x1, y: y1, width: x2 - x1, height: y2 - y1)
    }

    public func offsetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        guard !isNull else { return .null }
        return CGRect(x: origin.x + dx, y: origin.y + dy, width: size.width, height: size.height)
    }

    public func insetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        guard !isNull else { return .null }
        return CGRect(
            x: origin.x + dx,
            y: origin.y + dy,
            width: size.width - 2 * dx,
            height: size.height - 2 * dy
        )
    }

    public func divided(
        atDistance distance: CGFloat,
        from edge: CGRectEdge
    ) -> (slice: CGRect, remainder: CGRect) {
        let rect = standardized
        switch edge {
        case .minXEdge:
            let amount = Swift.max(0, Swift.min(distance, rect.width))
            return (
                CGRect(x: rect.minX, y: rect.minY, width: amount, height: rect.height),
                CGRect(x: rect.minX + amount, y: rect.minY, width: rect.width - amount, height: rect.height)
            )
        case .minYEdge:
            let amount = Swift.max(0, Swift.min(distance, rect.height))
            return (
                CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: amount),
                CGRect(x: rect.minX, y: rect.minY + amount, width: rect.width, height: rect.height - amount)
            )
        case .maxXEdge:
            let amount = Swift.max(0, Swift.min(distance, rect.width))
            return (
                CGRect(x: rect.maxX - amount, y: rect.minY, width: amount, height: rect.height),
                CGRect(x: rect.minX, y: rect.minY, width: rect.width - amount, height: rect.height)
            )
        case .maxYEdge:
            let amount = Swift.max(0, Swift.min(distance, rect.height))
            return (
                CGRect(x: rect.minX, y: rect.maxY - amount, width: rect.width, height: amount),
                CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - amount)
            )
        }
    }

    public var debugDescription: String {
        "(\(origin.x), \(origin.y), \(size.width), \(size.height))"
    }
}
#endif
