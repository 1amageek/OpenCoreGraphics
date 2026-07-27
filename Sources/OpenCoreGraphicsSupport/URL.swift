#if hasFeature(Embedded)
public struct URL: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let path: String

    public init(fileURLWithPath path: String) {
        self.path = path
    }

    public init?(string: String) {
        guard !string.isEmpty else { return nil }
        if string.hasPrefix("file://") {
            self.path = String(string.dropFirst(7))
        } else {
            self.path = string
        }
    }

    public var isFileURL: Bool { true }
    public var absoluteString: String { "file://\(path)" }
    public var description: String { absoluteString }
}
#endif
