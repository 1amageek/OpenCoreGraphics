#if hasFeature(Embedded)
public enum CGRectEdge: UInt32, Sendable {
    case minXEdge = 0
    case minYEdge = 1
    case maxXEdge = 2
    case maxYEdge = 3
}
#endif
