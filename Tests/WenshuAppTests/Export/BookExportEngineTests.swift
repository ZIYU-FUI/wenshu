//
//  BookExportEngineTests.swift · Wenshu
//
//  Source-level structural tests for `BookExportEngine` and
//  `EBookExportDocument`. Mirrors `LibraryExportEngineTests`.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("BookExportEngine")
struct BookExportEngineTests {

    @Test("engine declares the public export surface")
    func publicSurface() throws {
        let typeStr = String(describing: BookExportEngine.self)
        #expect(typeStr.contains("BookExportEngine"))

        // BookExportFormat enum must expose epub + pdf + combinedMd.
        let epubStr = "\(BookExportFormat.epub)"
        let pdfStr = "\(BookExportFormat.pdf)"
        let combinedStr = "\(BookExportFormat.combinedMd)"
        #expect(epubStr.contains("epub"))
        #expect(pdfStr.contains("pdf"))
        #expect(combinedStr.contains("combinedMd"))
    }

    @Test("engine errors expose localized descriptions")
    func errorDescriptions() {
        let e1 = BookExportError.noActiveLibrary
        #expect(e1.errorDescription != nil)
        let e2 = BookExportError.bookNotFound(UUID())
        #expect(e2.errorDescription != nil)
        let e3 = BookExportError.noChapters(UUID())
        #expect(e3.errorDescription != nil)
        let e4 = BookExportError.destinationReadOnly(URL(fileURLWithPath: "/tmp/x"))
        #expect(e4.errorDescription != nil)
        let e5 = BookExportError.ioFailure(URL(fileURLWithPath: "/tmp/x"), "boom")
        #expect(e5.errorDescription != nil)
        let e6 = BookExportError.zipProcessFailed(status: 1, stderr: "fail")
        #expect(e6.errorDescription != nil)
    }

    @Test("EBookExportDocument declares EPUB + PDF content types")
    func fileDocumentVariants() {
        let epubStr = "\(EBookExportDocument.epub(URL(fileURLWithPath: "/tmp/x.epub")))"
        let pdfStr = "\(EBookExportDocument.pdf(URL(fileURLWithPath: "/tmp/x.pdf")))"
        #expect(epubStr.contains("epub"))
        #expect(pdfStr.contains("pdf"))

        let contentTypes = EBookExportDocument.writableContentTypes
        #expect(contentTypes.contains(.epub))
        #expect(contentTypes.contains(.pdf))
    }
}