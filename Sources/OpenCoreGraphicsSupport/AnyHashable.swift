#if hasFeature(Embedded)
public struct AnyHashable: Hashable, Sendable, ExpressibleByStringLiteral {
    private enum Storage: Hashable, Sendable {
        case string(String)
        case int(Int)
        case uint(UInt)
        case bool(Bool)
        case double(Double)
    }

    private let storage: Storage

    public init(_ value: String) { storage = .string(value) }
    public init(_ value: Int) { storage = .int(value) }
    public init(_ value: UInt) { storage = .uint(value) }
    public init(_ value: Bool) { storage = .bool(value) }
    public init(_ value: Double) { storage = .double(value) }
    public init(_ value: Float) { storage = .double(Double(value)) }

    public init(stringLiteral value: String) {
        storage = .string(value)
    }

    public var stringValue: String? {
        guard case .string(let value) = storage else { return nil }
        return value
    }
}
#endif
