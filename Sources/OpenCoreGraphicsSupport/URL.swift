#if hasFeature(Embedded)
public struct URL: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let path: String
    private let serialized: String
    private let fileURL: Bool

    public init(fileURLWithPath path: String) {
        self.path = path
        self.serialized = "file://\(path)"
        self.fileURL = true
    }

    public init?(string: String) {
        guard !string.isEmpty else { return nil }
        if string.hasPrefix("file://") {
            self.path = String(string.dropFirst(7))
            self.serialized = string
            self.fileURL = true
        } else {
            guard let schemeEnd = string.firstIndex(of: ":"),
                  schemeEnd != string.startIndex,
                  string[string.startIndex].isASCII,
                  string[string.startIndex].isLetter,
                  string[..<schemeEnd].allSatisfy({
                      $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == ".")
                  }) else {
                return nil
            }
            let authorityStart = string.index(after: schemeEnd)
            let remainder = string[authorityStart...]
            if remainder.hasPrefix("//") {
                let authorityAndPath = remainder.dropFirst(2)
                if let delimiter = authorityAndPath.firstIndex(where: {
                    $0 == "/" || $0 == "?" || $0 == "#"
                }), authorityAndPath[delimiter] == "/" {
                    self.path = String(authorityAndPath[delimiter...].prefix {
                        $0 != "?" && $0 != "#"
                    })
                } else {
                    self.path = ""
                }
            } else {
                self.path = String(remainder.prefix { $0 != "?" && $0 != "#" })
            }
            self.serialized = string
            self.fileURL = false
        }
    }

    public var isFileURL: Bool { fileURL }
    public var absoluteString: String { serialized }
    public var description: String { absoluteString }
}
#endif
