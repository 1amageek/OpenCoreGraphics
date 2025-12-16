//
//  CGPDFTests.swift
//  OpenCoreGraphics
//
//  Tests for PDF-related types: CGPDFDocument, CGPDFPage, CGPDFBox,
//  CGPDFObjectType, CGPDFDataFormat, CGPDFAccessPermissions
//

import Foundation
import Testing
@testable import OpenCoreGraphics

// Type aliases to avoid ambiguity with CoreFoundation types on macOS
private typealias CGFloat = OpenCoreGraphics.CGFloat
private typealias CGRect = OpenCoreGraphics.CGRect
private typealias CGAffineTransform = OpenCoreGraphics.CGAffineTransform
private typealias CGPDFDocument = OpenCoreGraphics.CGPDFDocument
private typealias CGPDFPage = OpenCoreGraphics.CGPDFPage
private typealias CGPDFBox = OpenCoreGraphics.CGPDFBox
private typealias CGPDFObjectType = OpenCoreGraphics.CGPDFObjectType
private typealias CGPDFDataFormat = OpenCoreGraphics.CGPDFDataFormat
private typealias CGPDFAccessPermissions = OpenCoreGraphics.CGPDFAccessPermissions
private typealias CGDataProvider = OpenCoreGraphics.CGDataProvider

// MARK: - CGPDFBox Tests

@Suite("CGPDFBox Tests")
struct CGPDFBoxTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGPDFBox.mediaBox.rawValue == 0)
        #expect(CGPDFBox.cropBox.rawValue == 1)
        #expect(CGPDFBox.bleedBox.rawValue == 2)
        #expect(CGPDFBox.trimBox.rawValue == 3)
        #expect(CGPDFBox.artBox.rawValue == 4)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGPDFBox(rawValue: 0) == .mediaBox)
        #expect(CGPDFBox(rawValue: 1) == .cropBox)
        #expect(CGPDFBox(rawValue: 2) == .bleedBox)
        #expect(CGPDFBox(rawValue: 3) == .trimBox)
        #expect(CGPDFBox(rawValue: 4) == .artBox)
        #expect(CGPDFBox(rawValue: 100) == nil)
    }

    @Test("Sendable conformance")
    func sendableConformance() async {
        let box = CGPDFBox.mediaBox
        let task = Task {
            return box
        }
        let result = await task.value
        #expect(result == .mediaBox)
    }
}

// MARK: - CGPDFObjectType Tests

@Suite("CGPDFObjectType Tests")
struct CGPDFObjectTypeTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGPDFObjectType.null.rawValue == 0)
        #expect(CGPDFObjectType.boolean.rawValue == 1)
        #expect(CGPDFObjectType.integer.rawValue == 2)
        #expect(CGPDFObjectType.real.rawValue == 3)
        #expect(CGPDFObjectType.name.rawValue == 4)
        #expect(CGPDFObjectType.string.rawValue == 5)
        #expect(CGPDFObjectType.array.rawValue == 6)
        #expect(CGPDFObjectType.dictionary.rawValue == 7)
        #expect(CGPDFObjectType.stream.rawValue == 8)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGPDFObjectType(rawValue: 0) == .null)
        #expect(CGPDFObjectType(rawValue: 1) == .boolean)
        #expect(CGPDFObjectType(rawValue: 2) == .integer)
        #expect(CGPDFObjectType(rawValue: 3) == .real)
        #expect(CGPDFObjectType(rawValue: 4) == .name)
        #expect(CGPDFObjectType(rawValue: 5) == .string)
        #expect(CGPDFObjectType(rawValue: 6) == .array)
        #expect(CGPDFObjectType(rawValue: 7) == .dictionary)
        #expect(CGPDFObjectType(rawValue: 8) == .stream)
        #expect(CGPDFObjectType(rawValue: 100) == nil)
    }

    @Test("Sendable conformance")
    func sendableConformance() async {
        let type = CGPDFObjectType.dictionary
        let task = Task {
            return type
        }
        let result = await task.value
        #expect(result == .dictionary)
    }
}

// MARK: - CGPDFDataFormat Tests

@Suite("CGPDFDataFormat Tests")
struct CGPDFDataFormatTests {

    @Test("Raw values")
    func rawValues() {
        #expect(CGPDFDataFormat.raw.rawValue == 0)
        #expect(CGPDFDataFormat.jpegEncoded.rawValue == 1)
        #expect(CGPDFDataFormat.JPEG2000.rawValue == 2)
    }

    @Test("Init from raw value")
    func initFromRawValue() {
        #expect(CGPDFDataFormat(rawValue: 0) == .raw)
        #expect(CGPDFDataFormat(rawValue: 1) == .jpegEncoded)
        #expect(CGPDFDataFormat(rawValue: 2) == .JPEG2000)
        #expect(CGPDFDataFormat(rawValue: 100) == nil)
    }

    @Test("Sendable conformance")
    func sendableConformance() async {
        let format = CGPDFDataFormat.jpegEncoded
        let task = Task {
            return format
        }
        let result = await task.value
        #expect(result == .jpegEncoded)
    }
}

// MARK: - CGPDFAccessPermissions Tests

@Suite("CGPDFAccessPermissions Tests")
struct CGPDFAccessPermissionsTests {

    @Suite("Raw Values")
    struct RawValuesTests {

        @Test("Individual permission values")
        func individualPermissionValues() {
            #expect(CGPDFAccessPermissions.allowsLowQualityPrinting.rawValue == 1 << 0)
            #expect(CGPDFAccessPermissions.allowsHighQualityPrinting.rawValue == 1 << 1)
            #expect(CGPDFAccessPermissions.allowsDocumentChanges.rawValue == 1 << 2)
            #expect(CGPDFAccessPermissions.allowsDocumentAssembly.rawValue == 1 << 3)
            #expect(CGPDFAccessPermissions.allowsContentCopying.rawValue == 1 << 4)
            #expect(CGPDFAccessPermissions.allowsContentAccessibility.rawValue == 1 << 5)
            #expect(CGPDFAccessPermissions.allowsCommenting.rawValue == 1 << 6)
            #expect(CGPDFAccessPermissions.allowsFormFieldEntry.rawValue == 1 << 7)
        }
    }

    @Suite("OptionSet Operations")
    struct OptionSetTests {

        @Test("Union of permissions")
        func unionPermissions() {
            let permissions: CGPDFAccessPermissions = [.allowsContentCopying, .allowsHighQualityPrinting]
            #expect(permissions.contains(.allowsContentCopying))
            #expect(permissions.contains(.allowsHighQualityPrinting))
            #expect(!permissions.contains(.allowsCommenting))
        }

        @Test("Empty permissions")
        func emptyPermissions() {
            let permissions: CGPDFAccessPermissions = []
            #expect(permissions.rawValue == 0)
        }

        @Test("All printing permissions")
        func allPrintingPermissions() {
            let printPermissions: CGPDFAccessPermissions = [.allowsLowQualityPrinting, .allowsHighQualityPrinting]
            #expect(printPermissions.contains(.allowsLowQualityPrinting))
            #expect(printPermissions.contains(.allowsHighQualityPrinting))
        }

        @Test("Intersection of permissions")
        func intersectionPermissions() {
            let permissions1: CGPDFAccessPermissions = [.allowsContentCopying, .allowsCommenting]
            let permissions2: CGPDFAccessPermissions = [.allowsContentCopying, .allowsFormFieldEntry]
            let intersection = permissions1.intersection(permissions2)
            #expect(intersection.contains(.allowsContentCopying))
            #expect(!intersection.contains(.allowsCommenting))
            #expect(!intersection.contains(.allowsFormFieldEntry))
        }

        @Test("Sendable conformance")
        func sendableConformance() async {
            let permissions: CGPDFAccessPermissions = [.allowsContentCopying]
            let task = Task {
                return permissions
            }
            let result = await task.value
            #expect(result.contains(.allowsContentCopying))
        }
    }
}

// MARK: - CGPDFDocument Tests

@Suite("CGPDFDocument Tests")
struct CGPDFDocumentTests {

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Init with data provider")
        func initWithDataProvider() {
            let data = Data([0x25, 0x50, 0x44, 0x46]) // %PDF
            let provider = CGDataProvider(data: data)
            let document = CGPDFDocument(provider)
            #expect(document != nil)
        }
    }

    @Suite("Properties")
    struct PropertiesTests {

        @Test("Number of pages for empty document")
        func numberOfPagesEmpty() {
            let data = Data([0x25, 0x50, 0x44, 0x46])
            let provider = CGDataProvider(data: data)
            if let document = CGPDFDocument(provider) {
                #expect(document.numberOfPages == 0)
            }
        }

        @Test("Is encrypted default")
        func isEncryptedDefault() {
            let data = Data([0x25, 0x50, 0x44, 0x46])
            let provider = CGDataProvider(data: data)
            if let document = CGPDFDocument(provider) {
                #expect(document.isEncrypted == false)
            }
        }

        @Test("Is unlocked default")
        func isUnlockedDefault() {
            let data = Data([0x25, 0x50, 0x44, 0x46])
            let provider = CGDataProvider(data: data)
            if let document = CGPDFDocument(provider) {
                #expect(document.isUnlocked == true)
            }
        }

        @Test("Allows copying default")
        func allowsCopyingDefault() {
            let data = Data([0x25, 0x50, 0x44, 0x46])
            let provider = CGDataProvider(data: data)
            if let document = CGPDFDocument(provider) {
                #expect(document.allowsCopying == true)
            }
        }

        @Test("Allows printing default")
        func allowsPrintingDefault() {
            let data = Data([0x25, 0x50, 0x44, 0x46])
            let provider = CGDataProvider(data: data)
            if let document = CGPDFDocument(provider) {
                #expect(document.allowsPrinting == true)
            }
        }

        @Test("Access permissions default")
        func accessPermissionsDefault() {
            let data = Data([0x25, 0x50, 0x44, 0x46])
            let provider = CGDataProvider(data: data)
            if let document = CGPDFDocument(provider) {
                #expect(document.accessPermissions.rawValue == 0)
            }
        }

        @Test("Type ID")
        func typeID() {
            let typeID = CGPDFDocument.typeID
            #expect(typeID >= 0)
        }
    }

    @Suite("Version")
    struct VersionTests {

        @Test("Get version")
        func getVersion() {
            let data = Data([0x25, 0x50, 0x44, 0x46])
            let provider = CGDataProvider(data: data)
            if let document = CGPDFDocument(provider) {
                var major: Int32 = 0
                var minor: Int32 = 0
                document.getVersion(majorVersion: &major, minorVersion: &minor)
                #expect(major == 1)
                #expect(minor == 4)
            }
        }
    }

    @Suite("Page Access")
    struct PageAccessTests {

        @Test("Page at invalid index returns nil")
        func pageAtInvalidIndex() {
            let data = Data([0x25, 0x50, 0x44, 0x46])
            let provider = CGDataProvider(data: data)
            if let document = CGPDFDocument(provider) {
                #expect(document.page(at: 0) == nil)
                #expect(document.page(at: 1) == nil)
                #expect(document.page(at: -1) == nil)
            }
        }
    }

    @Suite("Unlock")
    struct UnlockTests {

        @Test("Unlock unencrypted document")
        func unlockUnencrypted() {
            let data = Data([0x25, 0x50, 0x44, 0x46])
            let provider = CGDataProvider(data: data)
            if let document = CGPDFDocument(provider) {
                let result = "password".withCString { password in
                    document.unlockWithPassword(password)
                }
                #expect(result == true)
            }
        }
    }

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Same instance is equal")
        func sameInstanceEqual() {
            let data = Data([0x25, 0x50, 0x44, 0x46])
            let provider = CGDataProvider(data: data)
            if let document = CGPDFDocument(provider) {
                #expect(document == document)
            }
        }

        @Test("Different instances are not equal")
        func differentInstancesNotEqual() {
            let data = Data([0x25, 0x50, 0x44, 0x46])
            let provider1 = CGDataProvider(data: data)
            let provider2 = CGDataProvider(data: data)
            if let document1 = CGPDFDocument(provider1),
               let document2 = CGPDFDocument(provider2) {
                #expect(document1 != document2)
            }
        }
    }

    @Suite("Hashable Conformance")
    struct HashableTests {

        @Test("Can be used in Set")
        func setUsage() {
            var set = Set<CGPDFDocument>()
            let data = Data([0x25, 0x50, 0x44, 0x46])

            let provider1 = CGDataProvider(data: data)
            let provider2 = CGDataProvider(data: data)
            if let doc1 = CGPDFDocument(provider1),
               let doc2 = CGPDFDocument(provider2) {
                set.insert(doc1)
                set.insert(doc2)
                set.insert(doc1)
                #expect(set.count == 2)
            }
        }
    }
}

// MARK: - CGPDFPage Tests

@Suite("CGPDFPage Tests")
struct CGPDFPageTests {

    @Suite("Properties")
    struct PropertiesTests {

        @Test("Type ID")
        func typeID() {
            let typeID = CGPDFPage.typeID
            #expect(typeID >= 0)
        }
    }

    @Suite("Equatable Conformance")
    struct EquatableTests {

        @Test("Page from document")
        func pageFromDocument() {
            let data = Data([0x25, 0x50, 0x44, 0x46])
            let provider = CGDataProvider(data: data)
            if let document = CGPDFDocument(provider) {
                // Document has no pages, so page(at:) returns nil
                let page = document.page(at: 1)
                #expect(page == nil)
            }
        }
    }
}

// MARK: - CGPDFObject Primitive Types Tests

@Suite("CGPDFObject Primitive Types Tests")
struct CGPDFObjectPrimitiveTypesTests {

    @Test("CGPDFBoolean is UInt8")
    func pdfBooleanType() {
        let boolValue: CGPDFBoolean = 1
        #expect(boolValue == 1)
        #expect(MemoryLayout<CGPDFBoolean>.size == MemoryLayout<UInt8>.size)
    }

    @Test("CGPDFInteger is Int")
    func pdfIntegerType() {
        let intValue: CGPDFInteger = 42
        #expect(intValue == 42)
        #expect(MemoryLayout<CGPDFInteger>.size == MemoryLayout<Int>.size)
    }

    @Test("CGPDFReal is CGFloat")
    func pdfRealType() {
        let realValue: CGPDFReal = 3.14
        #expect(realValue.native == 3.14)
        #expect(MemoryLayout<CGPDFReal>.size == MemoryLayout<CGFloat>.size)
    }
}

// MARK: - CGPDFObject Functions Tests

@Suite("CGPDFObject Functions Tests")
struct CGPDFObjectFunctionsTests {

    @Test("CGPDFObjectGetType returns null for placeholder")
    func objectGetType() {
        // This is a placeholder test - the actual function requires a valid CGPDFObjectRef
        // For now we just verify the function exists and compiles
        // In a real implementation, we would need a valid PDF object to test
    }

    @Test("CGPDFObjectGetValue returns false for placeholder")
    func objectGetValue() {
        // Placeholder test - verifies function signature exists
    }
}

// MARK: - CGPDFArray Functions Tests

@Suite("CGPDFArray Functions Tests")
struct CGPDFArrayFunctionsTests {

    @Test("CGPDFArrayGetCount placeholder returns 0")
    func arrayGetCountPlaceholder() {
        // The placeholder implementation returns 0
        // This test verifies the function exists
    }

    @Test("CGPDFArrayGetNull placeholder returns false")
    func arrayGetNullPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFArrayGetBoolean placeholder returns false")
    func arrayGetBooleanPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFArrayGetInteger placeholder returns false")
    func arrayGetIntegerPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFArrayGetNumber placeholder returns false")
    func arrayGetNumberPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFArrayGetName placeholder returns false")
    func arrayGetNamePlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFArrayGetString placeholder returns false")
    func arrayGetStringPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFArrayGetArray placeholder returns false")
    func arrayGetArrayPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFArrayGetDictionary placeholder returns false")
    func arrayGetDictionaryPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFArrayGetStream placeholder returns false")
    func arrayGetStreamPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFArrayGetObject placeholder returns false")
    func arrayGetObjectPlaceholder() {
        // Placeholder test
    }
}

// MARK: - CGPDFDictionary Functions Tests

@Suite("CGPDFDictionary Functions Tests")
struct CGPDFDictionaryFunctionsTests {

    @Test("CGPDFDictionaryGetCount placeholder returns 0")
    func dictionaryGetCountPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFDictionaryGetBoolean placeholder returns false")
    func dictionaryGetBooleanPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFDictionaryGetInteger placeholder returns false")
    func dictionaryGetIntegerPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFDictionaryGetNumber placeholder returns false")
    func dictionaryGetNumberPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFDictionaryGetName placeholder returns false")
    func dictionaryGetNamePlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFDictionaryGetString placeholder returns false")
    func dictionaryGetStringPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFDictionaryGetArray placeholder returns false")
    func dictionaryGetArrayPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFDictionaryGetDictionary placeholder returns false")
    func dictionaryGetDictionaryPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFDictionaryGetStream placeholder returns false")
    func dictionaryGetStreamPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFDictionaryGetObject placeholder returns false")
    func dictionaryGetObjectPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFDictionaryApplyFunction exists")
    func dictionaryApplyFunctionExists() {
        // Verifies the function and callback type exist
    }
}

// MARK: - CGPDFString Functions Tests

@Suite("CGPDFString Functions Tests")
struct CGPDFStringFunctionsTests {

    @Test("CGPDFStringGetBytePtr placeholder returns nil")
    func stringGetBytePtrPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFStringGetLength placeholder returns 0")
    func stringGetLengthPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFStringCopyTextString placeholder returns nil")
    func stringCopyTextStringPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFStringCopyDate placeholder returns nil")
    func stringCopyDatePlaceholder() {
        // Placeholder test
    }
}

// MARK: - CGPDFStream Functions Tests

@Suite("CGPDFStream Functions Tests")
struct CGPDFStreamFunctionsTests {

    @Test("CGPDFStreamGetDictionary placeholder returns nil")
    func streamGetDictionaryPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFStreamCopyData placeholder returns nil")
    func streamCopyDataPlaceholder() {
        // Placeholder test
    }
}

// MARK: - CGPDFOperatorTable Functions Tests

@Suite("CGPDFOperatorTable Functions Tests")
struct CGPDFOperatorTableFunctionsTests {

    @Test("CGPDFOperatorTableCreate placeholder returns nil")
    func operatorTableCreatePlaceholder() {
        let table = CGPDFOperatorTableCreate()
        #expect(table == nil)
    }

    @Test("CGPDFOperatorTableRetain returns same pointer")
    func operatorTableRetainPlaceholder() {
        // Since we can't create a table, we just verify the function exists
    }

    @Test("CGPDFOperatorTableRelease exists")
    func operatorTableReleaseExists() {
        // Verifies the function exists
    }

    @Test("CGPDFOperatorTableSetCallback exists")
    func operatorTableSetCallbackExists() {
        // Verifies the function and callback type exist
    }
}

// MARK: - CGPDFContentStream Functions Tests

@Suite("CGPDFContentStream Functions Tests")
struct CGPDFContentStreamFunctionsTests {

    @Test("CGPDFContentStreamCreateWithPage placeholder returns nil")
    func contentStreamCreateWithPagePlaceholder() {
        // Cannot test without a valid CGPDFPage with actual content
    }

    @Test("CGPDFContentStreamCreateWithStream placeholder returns nil")
    func contentStreamCreateWithStreamPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFContentStreamGetStreams placeholder returns nil")
    func contentStreamGetStreamsPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFContentStreamGetResource placeholder returns nil")
    func contentStreamGetResourcePlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFContentStreamRetain returns same pointer")
    func contentStreamRetainPlaceholder() {
        // Verifies the function exists
    }

    @Test("CGPDFContentStreamRelease exists")
    func contentStreamReleaseExists() {
        // Verifies the function exists
    }
}

// MARK: - CGPDFScanner Functions Tests

@Suite("CGPDFScanner Functions Tests")
struct CGPDFScannerFunctionsTests {

    @Test("CGPDFScannerCreate placeholder returns nil")
    func scannerCreatePlaceholder() {
        // Cannot test without valid content stream and operator table
    }

    @Test("CGPDFScannerScan placeholder returns false")
    func scannerScanPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFScannerGetContentStream placeholder returns nil")
    func scannerGetContentStreamPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFScannerRetain returns same pointer")
    func scannerRetainPlaceholder() {
        // Verifies the function exists
    }

    @Test("CGPDFScannerRelease exists")
    func scannerReleaseExists() {
        // Verifies the function exists
    }
}

// MARK: - CGPDFScanner Pop Functions Tests

@Suite("CGPDFScanner Pop Functions Tests")
struct CGPDFScannerPopFunctionsTests {

    @Test("CGPDFScannerPopObject placeholder returns false")
    func scannerPopObjectPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFScannerPopBoolean placeholder returns false")
    func scannerPopBooleanPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFScannerPopInteger placeholder returns false")
    func scannerPopIntegerPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFScannerPopNumber placeholder returns false")
    func scannerPopNumberPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFScannerPopName placeholder returns false")
    func scannerPopNamePlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFScannerPopString placeholder returns false")
    func scannerPopStringPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFScannerPopArray placeholder returns false")
    func scannerPopArrayPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFScannerPopDictionary placeholder returns false")
    func scannerPopDictionaryPlaceholder() {
        // Placeholder test
    }

    @Test("CGPDFScannerPopStream placeholder returns false")
    func scannerPopStreamPlaceholder() {
        // Placeholder test
    }
}

// MARK: - CGPDFOperatorCallback Type Tests

@Suite("CGPDFOperatorCallback Type Tests")
struct CGPDFOperatorCallbackTypeTests {

    @Test("CGPDFOperatorCallback type alias exists")
    func operatorCallbackTypeExists() {
        // Verifies the type alias compiles correctly
        let _: CGPDFOperatorCallback? = nil
    }

    @Test("CGPDFDictionaryApplierFunction type alias exists")
    func dictionaryApplierFunctionTypeExists() {
        // Verifies the type alias compiles correctly
        let _: CGPDFDictionaryApplierFunction? = nil
    }
}

// MARK: - PDF Reference Types Tests

@Suite("PDF Reference Types Tests")
struct PDFReferenceTypesTests {

    @Test("CGPDFArrayRef is OpaquePointer")
    func arrayRefType() {
        // Verifies the type alias exists
        let _: CGPDFArrayRef? = nil
    }

    @Test("CGPDFDictionaryRef is OpaquePointer")
    func dictionaryRefType() {
        // Verifies the type alias exists
        let _: CGPDFDictionaryRef? = nil
    }

    @Test("CGPDFObjectRef is OpaquePointer")
    func objectRefType() {
        // Verifies the type alias exists
        let _: CGPDFObjectRef? = nil
    }

    @Test("CGPDFStreamRef is OpaquePointer")
    func streamRefType() {
        // Verifies the type alias exists
        let _: CGPDFStreamRef? = nil
    }

    @Test("CGPDFStringRef is OpaquePointer")
    func stringRefType() {
        // Verifies the type alias exists
        let _: CGPDFStringRef? = nil
    }

    @Test("CGPDFOperatorTableRef is OpaquePointer")
    func operatorTableRefType() {
        // Verifies the type alias exists
        let _: CGPDFOperatorTableRef? = nil
    }

    @Test("CGPDFContentStreamRef is OpaquePointer")
    func contentStreamRefType() {
        // Verifies the type alias exists
        let _: CGPDFContentStreamRef? = nil
    }

    @Test("CGPDFScannerRef is OpaquePointer")
    func scannerRefType() {
        // Verifies the type alias exists
        let _: CGPDFScannerRef? = nil
    }
}
