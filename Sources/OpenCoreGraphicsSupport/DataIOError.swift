#if hasFeature(Embedded)
public enum DataIOError: Error, Equatable, Sendable, CustomStringConvertible {
    case readFailed(path: String, code: Int32)
    case writeFailed(path: String, code: Int32)

    public var description: String {
        switch self {
        case .readFailed(let path, let code):
            return "Failed to read \(path) (error \(code))"
        case .writeFailed(let path, let code):
            return "Failed to write \(path) (error \(code))"
        }
    }
}
#endif
