#if hasFeature(Embedded)
public struct CGSize: Equatable, Hashable, Sendable, CustomDebugStringConvertible {
    public var width: CGFloat
    public var height: CGFloat

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    public static let zero = CGSize(width: 0, height: 0)

    public func equalTo(_ size: CGSize) -> Bool {
        self == size
    }

    public var debugDescription: String {
        "(\(width), \(height))"
    }
}
#endif
