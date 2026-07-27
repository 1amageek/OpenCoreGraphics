#if hasFeature(Embedded)
public struct CGPoint: Equatable, Hashable, Sendable, CustomDebugStringConvertible {
    public var x: CGFloat
    public var y: CGFloat

    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    public static let zero = CGPoint(x: 0, y: 0)

    public func equalTo(_ point: CGPoint) -> Bool {
        self == point
    }

    public var debugDescription: String {
        "(\(x), \(y))"
    }
}
#endif
