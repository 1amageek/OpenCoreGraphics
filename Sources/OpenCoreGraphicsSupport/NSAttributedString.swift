#if hasFeature(Embedded)
// FIXME(INCOMPLETE_IMPLEMENTATION): Embedded filter metadata currently uses only the immutable plain-string portion of NSAttributedString.
// Public OpenCoreImage metadata paths can construct this type, but attributes are not yet representable and must not be reported as preserved.
// Remove this marker after attribute runs, equality, and failure behavior have portable implementations and target-specific tests.
public final class NSAttributedString: Hashable, Sendable {
    public let string: String

    public init(string: String) {
        self.string = string
    }

    public static func == (lhs: NSAttributedString, rhs: NSAttributedString) -> Bool {
        lhs.string == rhs.string
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(string)
    }
}
#endif
