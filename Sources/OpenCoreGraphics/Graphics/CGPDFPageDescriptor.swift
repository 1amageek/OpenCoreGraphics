import OpenCoreGraphicsSupport

internal struct CGPDFPageDescriptor: Sendable {
    let pageNumber: Int
    let rotationAngle: Int32
    let mediaBox: CGRect
}
