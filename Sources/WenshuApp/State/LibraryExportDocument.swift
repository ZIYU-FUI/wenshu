//
//  LibraryExportDocument.swift · Wenshu
//
//  FileDocument wrapper for the .fileExporter modifier
//  (= developer.apple.com/documentation/swiftui/fileexporter).
//  Two flavors:
//
//  - `.copy` mode: a package directory (= the destination URL points
//    at a new .ws bundle the user just emptied; = the fileWrapper
//    carries a directory package with the original contents mirrored
//    inside).
//  - `.zip` mode: a single archive (= the destination URL points at a
//    .zip file; = the fileWrapper carries a regular file with the
//    zipped bytes).
//
//  Why a concrete FileDocument per flavor (= vs. one union type): the
//  `.fileExporter` modifier requires a `FileDocument`-conforming type
//  that declares its writableContentTypes (= Apple HIG canonical
//  pattern for type-driven file pickers). The two flavors declare
//  different UTType sets, so one type per flavor is the right shape.
//

import SwiftUI
import UniformTypeIdentifiers

/// Library export = the result of writing the user's library as a
/// `.ws` package (= directory) or as a `.zip` archive (= file).
/// The engine produces one of these two FileDocument variants and
/// hands it to `.fileExporter`.
enum LibraryExportDocument {

    /// Mirrors the library as a new `.ws` package directory at the
    /// destination URL (= the user picks the parent folder + the
    /// new `.ws` name via the standard save dialog).
    case package(URL)

    /// Writes a zipped archive of the library to a `.zip` file at
    /// the destination URL (= the user picks the destination file
    /// path via the standard save dialog).
    case archive(URL)
}

extension LibraryExportDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.folder, .zip] }
    static var writableContentTypes: [UTType] { [.folder, .zip] }

    init(configuration: ReadConfiguration) throws {
        // LibraryExportDocument is write-only. Reading a library
        // export back (= for an import path) is not in scope today;
        // = the existing .ws importer goes through FileSystemLibraryStore.
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        switch self {
        case .package(let dirURL):
            // The engine is responsible for writing the directory
            // contents before this returns (= the engine builds the
            // directory mirror synchronously and passes the resulting
            // URL in). The FileDocument here only carries the
            // directory reference to .fileExporter.
            return try FileWrapper(url: dirURL, options: [])
        case .archive(let zipURL):
            // The engine is responsible for writing the zipped
            // archive bytes before this returns. The FileDocument
            // here only carries the file reference to .fileExporter.
            return try FileWrapper(url: zipURL, options: [])
        }
    }
}