//
//  ManuscriptFileExporter.swift · Wenshu
//
//  The `.fileExporter` modifier for a SUBMISSION MANUSCRIPT.
//
//  WHY IT IS A SEPARATE MODIFIER AND NOT A MODE OF
//  `ChapterFileExporter`
//
//  The two chapter exports write DIFFERENT products through
//  DIFFERENT document types: = the Markdown export writes the
//  author's own bytes (= the editor's round trip), = the manuscript
//  writes plain text shaped by the target's measured rules. = The
//  `.fileExporter` modifier binds ONE document type per file, = so
//  a manuscript needs its own modifier.
//
//  The modifier's own binding is SEPARATE from the sheet's shared
//  `isExporting`: = the sheet's button flips this one only when a
//  manuscript is being written, = so the manuscript's save panel is
//  the only one that opens (= the other kinds' panels do not fire
//  for a manuscript export).
//

import SwiftUI
import UniformTypeIdentifiers

/// `ViewModifier` that wires the manuscript `.fileExporter`.
///
/// The onCompletion handler dispatches to the chapter engine
/// (`chapterEngine.exportManuscript(id:to:target:)`). The
/// destination URL the user picks via the system save dialog is the
/// engine's `to:` argument (= the engine writes the manuscript to
/// that path).
struct ManuscriptFileExporter: ViewModifier {
    let chapterEngine: ChapterExportEngine
    /// The FILE the resolver handed over (= = an imported chapter is
    /// named after its title, = = so an id lookup found nothing for it).
    let chapterFileURL: URL?
    let target: ManuscriptTarget
    @Binding var lastChapterURLString: String
    @Binding var isExporting: Bool
    let onComplete: (URL) -> Void

    func body(content: Content) -> some View {
        content
            // Chapter → one plain-text submission manuscript.
            .fileExporter(
                isPresented: $isExporting,
                document: ManuscriptDocument(text: ""),
                contentType: .plainText,
                onCompletion: { result in
                    handle(result: result)
                }
            )
    }

    /// Dispatch the user's chosen destination URL to the chapter
    /// engine. The picker tap is what flipped isExporting.
    private func handle(result: Result<URL, Error>) {
        defer { isExporting = false }
        guard case let .success(url) = result else { return }

        // Persist the destination path (= next time the user opens
        // the sheet for this kind, the system save dialog starts
        // there).
        lastChapterURLString = url.path

        guard let fileURL = chapterFileURL else { return }
        let manuscriptTarget = target
        Task {
            _ = try? await chapterEngine.exportManuscript(
                fileURL: fileURL,
                to: url,
                target: manuscriptTarget
            )
        }
        onComplete(url)
    }
}
