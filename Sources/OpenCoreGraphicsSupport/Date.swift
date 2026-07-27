#if hasFeature(Embedded)
public typealias TimeInterval = Double

public struct Date: Equatable, Hashable, Comparable, Sendable {
    public let timeIntervalSince1970: Double

    public init(timeIntervalSince1970: Double) {
        self.timeIntervalSince1970 = timeIntervalSince1970
    }

    public static func < (lhs: Date, rhs: Date) -> Bool {
        lhs.timeIntervalSince1970 < rhs.timeIntervalSince1970
    }
}
#endif
