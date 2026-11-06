//
//  ManuscriptDocument.swift · Wenshu
//
//  Apple SwiftUI FileDocument for a SUBMISSION MANUSCRIPT (= the
//  plain text a Chinese web novel is submitted to).
//
//  WHY A SEPARATE DOCUMENT TYPE
//
//  The `.fileExporter` modifier takes ONE document type per file
//  (= the house's pattern: = one modifier per FileDocument type,
//  = each declaring its own `writableContentTypes`), = and the two
//  chapter exports are two products: = one is the author's own
//  Markdown (= the editor's round trip), = the other is plain text
//  for a platform's editor. = A manuscript is write-only (= a
//  submission artifact, = not a file the app reads back), = which
//  is the same shape as `EBookExportDocument`.
//
//  THE TEXT HERE IS A PLACEHOLDER
//
//  The engine writes the real manuscript at the destination the
//  user picked in the save panel (= the same shape as the chapter
//  export's, = where `ChapterExportEngine.exportChapter` writes the
//  body bytes at that URL). = So this document's own text is the
//  save panel's type carrier, = not the manuscript.
//

import SwiftUI
import UniformTypeIdentifiers

/// The submission manuscript (= plain text) offered by the save
/// panel.
struct ManuscriptDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.plainText]
    }

    static var writableContentTypes: [UTType] {
        [.plainText]
    }

    /// The manuscript's text (= a placeholder: = the engine writes
    /// the real bytes at the destination the user picked).
    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration _: ReadConfiguration) throws {
        // A manuscript is write-only (= a submission artifact, = not
        // a file the app reads back). = The same shape as
        // `EBookExportDocument`.
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
