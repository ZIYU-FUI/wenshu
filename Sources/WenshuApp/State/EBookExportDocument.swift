//
//  EBookExportDocument.swift · Wenshu
//
//  FileDocument wrapper for the .fileExporter modifier in the
//  book-export path. Two flavors:
//
//  - `.epub`: a single EPUB file (= Apple Books / generic reader).
//  - `.pdf`: a single PDF file (= generic print format).
//
//  Combined Markdown is NOT a FileDocument export (= it is a
//  directory of files; = the engine writes the directory and
//  returns a folder URL; the sheet hands it to NSSavePanel-style
//  directory picker via the existing LibraryExportDocument pattern).
//
//  Why a concrete FileDocument per flavor (= vs. one union): the
//  `.fileExporter` modifier requires a `FileDocument`-conforming
//  type that declares its writableContentTypes (= Apple HIG canonical
//  pattern for type-driven file pickers).
//

import SwiftUI
import UniformTypeIdentifiers

/// Book export = the result of writing a single book as either an
/// EPUB or a PDF. The engine produces one of these two FileDocument
/// variants and hands it to `.fileExporter`.
enum EBookExportDocument {

    /// Writes an EPUB file to the destination URL.
    case epub(URL)

    /// Writes a PDF file to the destination URL.
    case pdf(URL)
}

extension EBookExportDocument: FileDocument {

    static var readableContentTypes: [UTType] {
        [.epub, .pdf]
    }
    static var writableContentTypes: [UTType] {
        [.epub, .pdf]
    }

    init(configuration: ReadConfiguration) throws {
        // EBookExportDocument is write-only. Reading a book back
        // (= for an import path) is not in scope today.
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        switch self {
        case .epub(let url):
            return try FileWrapper(url: url, options: [])
        case .pdf(let url):
            return try FileWrapper(url: url, options: [])
        }
    }
}