// ExportSheet+FileExporters.swift · The three `.fileExporter` modifiers
// the export sheet hangs on its sections, = = and the helper that names
// their destination.
//
// They live together because they are ONE concern: = = each is the system
// save panel for one export kind, = = and each dispatches to its own
// engine. = = The sheet itself keeps the kind enum, = = the three format
// enums, = = and the sections that offer them.
//
// AND `lastURL` IS HERE BECAUSE TWO OF THEM CALL IT: = = the library and
// the book panels remember where they last wrote, = = and they name their
// next file from that. = = The chapter panel does NOT call it (= = its
// document carries no URL default = = = = `MarkdownDocument(text: "")`
// has nothing to name), = = = = so it is two callers, not three.
import SwiftUI
import UniformTypeIdentifiers

/// Build the default destination URL for the system save dialog.
/// Reads the last-used URL from @AppStorage (= Apple HIG canonical
/// "remember last folder" pattern); = falls back to the temp
/// directory with a timestamped filename.
private func lastURL(_ stored: String, suffix: String, ext: String = "") -> URL {
    if !stored.isEmpty {
        let url = URL(fileURLWithPath: stored)
        let base = url.deletingLastPathComponent()
        let baseName = url.lastPathComponent
        let stripped = baseName.hasSuffix(ext)
            ? String(baseName.dropLast(ext.count))
            : baseName
        return base.appendingPathComponent("\(stripped)-\(Int(Date.now.timeIntervalSince1970))\(ext)")
    }
    return FileManager.default.temporaryDirectory
        .appendingPathComponent("\(suffix)-\(Int(Date.now.timeIntervalSince1970))\(ext)")
}

/// `ViewModifier` that wires the library `.fileExporter` modifier.
/// Apple HIG canonical pattern: one modifier per FileDocument type
/// (= each declares its own `writableContentTypes`).
///
/// The onCompletion handler dispatches to the library engine
/// (libraryEngine.exportLibrary(to:as:)). The destination URL the
/// user picks via the system save dialog is the engine's `to:`
/// argument (= the engine reads it + writes the result to that path).
struct LibraryFileExporter: ViewModifier {
    let libraryFormat: LibraryExportFormat
    let libraryEngine: LibraryExportEngine
    @Binding var lastLibraryURLString: String
    @Binding var isExporting: Bool
    let onComplete: (URL) -> Void

    func body(content: Content) -> some View {
        content
            // Library → .package directory OR .zip archive.
            // The destination URL is the user-picked path (= the
            // system save dialog returns it; = the engine writes
            // the library mirror or zip to that exact path).
            .fileExporter(
                isPresented: $isExporting,
                document: LibraryExportDocument.package(
                    lastURL(lastLibraryURLString, suffix: "wenshu-export")
                ),
                contentType: .folder,
                onCompletion: { result in
                    handle(result: result)
                }
            )
    }

    /// Dispatch the user's chosen destination URL to the library
    /// engine. The picker tap is what flipped isExporting.
    private func handle(result: Result<URL, Error>) {
        defer { isExporting = false }
        guard case let .success(url) = result else { return }

        // Persist the destination path (= next time the user opens
        // the sheet for this kind, the system save dialog starts
        // there).
        lastLibraryURLString = url.path

        let format: LibraryExportFormat = (libraryFormat == .zip) ? .zip : .copy
        Task {
            _ = try? await libraryEngine.exportLibrary(to: url, as: format)
        }
        onComplete(url)
    }
}

/// `ViewModifier` that wires the book `.fileExporter` modifier.
/// Apple HIG canonical pattern: one modifier per FileDocument type
/// (= each declares its own `writableContentTypes`).
///
/// The onCompletion handler dispatches to the book engine
/// (bookEngine.exportBook(id:to:format:)). The destination URL the
/// user picks via the system save dialog is the engine's `to:`
/// argument (= the engine reads it + writes the result to that path).
struct BookFileExporter: ViewModifier {
    let bookFormat: BookExportFormat
    let bookEngine: BookExportEngine
    let selectedBookID: UUID?
    @Binding var lastBookURLString: String
    @Binding var isExporting: Bool
    let onComplete: (URL) -> Void

    func body(content: Content) -> some View {
        content
            // Book → EPUB / PDF / combined MD (= one modifier per
            // FileDocument type because each declares its own
            // writableContentTypes; = Apple's canonical pattern for
            // type-driven file pickers).
            .fileExporter(
                isPresented: $isExporting,
                document: EBookExportDocument.epub(
                    lastURL(lastBookURLString, suffix: "wenshu-book", ext: ".epub")
                ),
                contentType: .epub,
                onCompletion: { result in
                    handle(result: result)
                }
            )
    }

    /// Dispatch the user's chosen destination URL to the book
    /// engine. The picker tap is what flipped isExporting.
    private func handle(result: Result<URL, Error>) {
        defer { isExporting = false }
        guard case let .success(url) = result else { return }

        // Persist the destination path (= next time the user opens
        // the sheet for this kind, the system save dialog starts
        // there).
        lastBookURLString = url.path

        guard let bookID = selectedBookID else { return }
        let fmt: BookExportFormat = bookFormat
        Task {
            _ = try? await bookEngine.exportBook(id: bookID, to: url, format: fmt)
        }
        onComplete(url)
    }
}

/// `ViewModifier` that wires the chapter `.fileExporter` modifier.
/// Apple HIG canonical pattern: one modifier per FileDocument type
/// (= each declares its own `writableContentTypes`).
///
/// The onCompletion handler dispatches to the chapter engine
/// (chapterEngine.exportChapter(id:to:)). The destination URL the
/// user picks via the system save dialog is the engine's `to:`
/// argument (= the engine reads it + writes the result to that path).
struct ChapterFileExporter: ViewModifier {
    let chapterEngine: ChapterExportEngine
    let selectedChapterID: UUID?
    /// The resolved chapters (= so the exporter can find the FILE that
    /// holds the selected chapter; = an imported chapter is named
    /// after its title, = not `<uuid>.md`).
    let chapters: [ResolvedChapter]
    @Binding var lastChapterURLString: String
    @Binding var isExporting: Bool
    let onComplete: (URL) -> Void

    func body(content: Content) -> some View {
        content
            // Chapter → single Markdown file.
            .fileExporter(
                isPresented: $isExporting,
                document: MarkdownDocument(text: ""),
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

        guard let chapterID = selectedChapterID else { return }
        // The chapter is exported from the FILE that holds it (= the
        // resolver's answer), = not from an id lookup. An imported
        // chapter is named after its title, = the `<uuid>.md` lookup
        // found nothing for it, = and the chapter could not be
        // exported at all.
        guard let chapter = chapters.first(where: { $0.id == chapterID }) else { return }
        Task {
            _ = try? await chapterEngine.exportChapter(fileURL: chapter.fileURL, to: url)
        }
        onComplete(url)
    }
}
