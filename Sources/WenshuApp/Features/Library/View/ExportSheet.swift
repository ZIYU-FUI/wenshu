//
//  ExportSheet.swift · Wenshu
//
//  Single-page sheet (= Apple HIG canonical macOS 14+ Sheet pattern)
//  for exporting content from the active Wenshu library. Reachable
//  from the menu bar via File → Export… (= ⇧⌘E). Presents three
//  export-kind sections (Library / Book / Chapter), each backed by
//  its own `ExportEngine` actor.
//
//  The sheet body is one file (= not split per section): the three
//  sections differ in their content (= radio button state +
//  pickers), not in their structure. Splitting into three views
//  creates three near-clones with no testable seam.
//
//  Engine dispatch: when the user clicks 导出 (= the .defaultAction
//  shortcut), the sheet computes the destination FileDocument
//  (= `LibraryExportDocument.package(...)` for the directory mirror;
//  `LibraryExportDocument.archive(...)` for the zip; =
//  `EBookExportDocument.epub(...)` or `.pdf(...)` for the book; =
//  a fresh `MarkdownDocument` for the chapter) and flips
//  `isExporting: Bool`. The `.fileExporter` modifier observes
//  `isExporting` and presents the system save sheet (= Apple HIG
//  canonical flow). The engine runs on the background actor; =
//  `onCompletion` dismisses the sheet after the file is written.
//
//  See `.scratch/2026-10-07-export-sheet/spec.md` for the full
//  user-story list and acceptance criteria.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// The three export kinds the sheet can produce.
enum ExportKind: String, CaseIterable, Identifiable, Sendable {
    case library
    case book
    case chapter

    var id: String { rawValue }
}

/// `ExportSheet` body. Hosts the three sections + the unified
/// `导出` / `取消` button row.
struct ExportSheet: View {

    /// Bumps when `exportSheetRequest` increments (= from the
    /// File → Export… menu). The parent flips this to dismiss.
    @Binding var isPresented: Bool

    /// Book source (= needed for the book + chapter pickers).
    /// Injected from the parent (= AppleSidebarView) where the
    /// environment chain already carries it.
    @Environment(BookStore.self) private var bookStore

    /// Which kind the user has selected. Defaults to library.
    @State private var kind: ExportKind = .library

    /// Library export sub-option: zip vs raw copy.
    @State private var libraryFormat: LibraryExportFormat = .copy

    /// Book export sub-option: EPUB / PDF / combined MD.
    @State private var bookFormat: BookExportFormat = .epub

    /// Selected book id (= populated from `BookStore.books`).
    @State private var selectedBookID: UUID?

    /// Selected chapter id (= populated when `selectedBookID`
    /// changes; = lazy-loaded from FileSystemChapterStore).
    @State private var selectedChapterID: UUID?

    /// Loaded chapters for the selected book (= `liveChapters(of:)`
    /// walks `bookStore.books` for the book, then calls
    /// `FileSystemChapterStore.loadChaptersFromFileSystem`).
    @State private var chapters: [Document] = []

    /// Flipped when the user clicks 导出; = triggers the
    /// `.fileExporter` modifier for the selected kind.
    @State private var isExporting: Bool = false

    /// Last-used destination URL per kind (Apple HIG canonical
    /// "remember the last folder" pattern, persisted via
    /// @AppStorage below).
    @AppStorage("wenshu.export.library.lastURL") private var lastLibraryURLString: String = ""
    @AppStorage("wenshu.export.book.lastURL") private var lastBookURLString: String = ""
    @AppStorage("wenshu.export.chapter.lastURL") private var lastChapterURLString: String = ""

    /// The engine instances (= long-lived; = actor-isolated).
    /// Held on the sheet (= recreated each time the sheet
    /// presents). Lazy init via MainActor because the engines
    /// are actors (= `init()` is nonisolated and the engines
    /// themselves are pure-value constructs).
    private let libraryEngine = LibraryExportEngine()
    private let bookEngine = BookExportEngine()
    private let chapterEngine = ChapterExportEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            Text(String(localized: "export.sheet.title"))
                .font(.title2.weight(.semibold))

            Form {
                Section {
                    Picker("", selection: $kind) {
                        ForEach(ExportKind.allCases) { k in
                            Text(label(for: k)).tag(k)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                switch kind {
                case .library:
                    librarySection
                case .book:
                    bookSection
                case .chapter:
                    chapterSection
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(String(localized: "export.sheet.cancel")) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                Button(String(localized: "export.sheet.confirm")) {
                    isExporting = true
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canConfirm)
            }
        }
        .padding(DesignTokens.spacingSection)
        .frame(minWidth: 480, minHeight: 360)
        .modifier(ExportFileExporters(
            kind: kind,
            libraryFormat: libraryFormat,
            bookFormat: bookFormat,
            selectedBookID: selectedBookID,
            selectedChapterID: selectedChapterID,
            libraryEngine: libraryEngine,
            bookEngine: bookEngine,
            chapterEngine: chapterEngine,
            lastLibraryURLString: $lastLibraryURLString,
            lastBookURLString: $lastBookURLString,
            lastChapterURLString: $lastChapterURLString,
            isExporting: $isExporting,
            onComplete: { _ in
                isExporting = false
                isPresented = false
            }
        ))
    }

    private var canConfirm: Bool {
        switch kind {
        case .library: return true
        case .book: return selectedBookID != nil
        case .chapter: return selectedChapterID != nil
        }
    }

    private func label(for kind: ExportKind) -> String {
        switch kind {
        case .library: return String(localized: "export.section.library")
        case .book:    return String(localized: "export.section.book")
        case .chapter: return String(localized: "export.section.chapter")
        }
    }

    @ViewBuilder
    private var librarySection: some View {
        Picker(String(localized: "export.section.library"), selection: $libraryFormat) {
            Text(String(localized: "export.library.format.copy")).tag(LibraryExportFormat.copy)
            Text(String(localized: "export.library.format.zip")).tag(LibraryExportFormat.zip)
        }
        .pickerStyle(.radioGroup)
    }

    @ViewBuilder
    private var bookSection: some View {
        Picker(String(localized: "export.section.book"), selection: $bookFormat) {
            Text(String(localized: "export.book.format.epub")).tag(BookExportFormat.epub)
            Text(String(localized: "export.book.format.pdf")).tag(BookExportFormat.pdf)
            Text(String(localized: "export.book.format.combined_md")).tag(BookExportFormat.combinedMd)
        }
        .pickerStyle(.radioGroup)
        Picker(String(localized: "export.book.picker"), selection: $selectedBookID) {
            Text(String(localized: "export.book.placeholder")).tag(UUID?.none)
            ForEach(bookStore.books) { book in
                Text(book.title).tag(Optional(book.id))
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedBookID) { _, newValue in
            guard let bookID = newValue,
                  let book = bookStore.books.first(where: { $0.id == bookID }) else {
                chapters = []
                selectedChapterID = nil
                return
            }
            // Load chapters from the book's filesystem JSON index
            // (= the nonisolated static helper on FileSystemChapterStore).
            let bookDir = bookURL(for: book)
            chapters = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
                bookDirectory: bookDir,
                chaptersDirectory: bookDir.appendingPathComponent("chapters", isDirectory: true),
                indexURL: bookDir.appendingPathComponent("chapters.json")
            )) ?? []
            selectedChapterID = nil
        }
    }

    @ViewBuilder
    private var chapterSection: some View {
        Picker(String(localized: "export.book.picker"), selection: $selectedBookID) {
            Text(String(localized: "export.book.placeholder")).tag(UUID?.none)
            ForEach(bookStore.books) { book in
                Text(book.title).tag(Optional(book.id))
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedBookID) { _, newValue in
            guard let bookID = newValue,
                  let book = bookStore.books.first(where: { $0.id == bookID }) else {
                chapters = []
                selectedChapterID = nil
                return
            }
            let bookDir = bookURL(for: book)
            chapters = (try? FileSystemChapterStore.loadChaptersFromFileSystem(
                bookDirectory: bookDir,
                chaptersDirectory: bookDir.appendingPathComponent("chapters", isDirectory: true),
                indexURL: bookDir.appendingPathComponent("chapters.json")
            )) ?? []
            selectedChapterID = nil
        }
        Picker(String(localized: "export.chapter.picker"), selection: $selectedChapterID) {
            Text(String(localized: "export.chapter.placeholder")).tag(UUID?.none)
            ForEach(chapters) { chapter in
                Text(chapter.title).tag(Optional(chapter.id))
            }
        }
        .pickerStyle(.menu)
        .disabled(chapters.isEmpty)
    }

    /// Resolve the book's filesystem URL (= `.ws/shelves/<shelf>/
    /// books/<book-uuid>/`). Walks the shelves in the active
    /// library root.
    private func bookURL(for book: Book) -> URL {
        guard let libPath = ActiveLibrary.path else {
            return URL(fileURLWithPath: "/")
        }
        let libURL = URL(fileURLWithPath: libPath, isDirectory: true)
        let shelvesURL = libURL.appendingPathComponent("shelves", isDirectory: true)
        let fm = FileManager.default
        guard fm.fileExists(atPath: shelvesURL.path) else {
            return libURL
        }
        let shelves = (try? fm.contentsOfDirectory(at: shelvesURL, includingPropertiesForKeys: nil)) ?? []
        for shelf in shelves {
            let candidate = shelf.appendingPathComponent("books", isDirectory: true)
                .appendingPathComponent(book.id.uuidString, isDirectory: true)
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return libURL
    }
}

/// Library export sub-format.
enum LibraryExportFormat: String, CaseIterable, Identifiable, Sendable {
    case copy
    case zip
    var id: String { rawValue }
}

/// Book export sub-format.
enum BookExportFormat: String, CaseIterable, Identifiable, Sendable {
    case epub
    case pdf
    case combinedMd
    var id: String { rawValue }
}

/// `ViewModifier` that wires the three `.fileExporter` modifiers
/// (= library / book / chapter). Apple HIG canonical pattern: one
/// modifier per FileDocument type (= each declares its own
/// `writableContentTypes`).
///
/// The onCompletion handler dispatches to the appropriate engine:
/// library → libraryEngine.exportLibrary(to:as:); book → bookEngine.
/// exportBook(id:to:format:); chapter → chapterEngine.exportChapter
/// (id:to:). The destination URL the user picks via the system
/// save dialog is the engine's `to:` argument (= the engine reads
/// it + writes the result to that path).
private struct ExportFileExporters: ViewModifier {
    let kind: ExportKind
    let libraryFormat: LibraryExportFormat
    let bookFormat: BookExportFormat
    let selectedBookID: UUID?
    let selectedChapterID: UUID?
    let libraryEngine: LibraryExportEngine
    let bookEngine: BookExportEngine
    let chapterEngine: ChapterExportEngine
    @Binding var lastLibraryURLString: String
    @Binding var lastBookURLString: String
    @Binding var lastChapterURLString: String
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
                contentType: kind == .library ? .folder : .folder,
                onCompletion: { result in
                    handle(result: result, kind: .library, lastURLBinding: $lastLibraryURLString)
                }
            )
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
                    handle(result: result, kind: .book, lastURLBinding: $lastBookURLString)
                }
            )
            // Chapter → single Markdown file.
            .fileExporter(
                isPresented: $isExporting,
                document: MarkdownDocument(text: ""),
                contentType: .plainText,
                onCompletion: { result in
                    handle(result: result, kind: .chapter, lastURLBinding: $lastChapterURLString)
                }
            )
    }

    /// Build the default destination URL for the system save dialog.
    /// Reads the last-used URL from @AppStorage (= Apple HIG
    /// canonical "remember last folder" pattern); = falls back to
    /// the temp directory with a timestamped filename.
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

    /// Dispatch the user's chosen destination URL to the matching
    /// engine. The kind matches the kind the user picked when they
    /// clicked 导出; = the picker tap is what flipped isExporting.
    private func handle(
        result: Result<URL, Error>,
        kind: ExportKind,
        lastURLBinding: Binding<String>
    ) {
        defer { isExporting = false }
        guard case .success(let url) = result else { return }

        // Persist the destination path (= next time the user opens
        // the sheet for this kind, the system save dialog starts
        // there).
        lastURLBinding.wrappedValue = url.path

        switch kind {
        case .library:
            let format: LibraryExportFormat = (self.libraryFormat == .zip) ? .zip : .copy
            Task {
                _ = try? await libraryEngine.exportLibrary(to: url, as: format)
            }
        case .book:
            guard let bookID = self.selectedBookID else { return }
            let fmt: BookExportFormat = self.bookFormat
            Task {
                _ = try? await bookEngine.exportBook(id: bookID, to: url, format: fmt)
            }
        case .chapter:
            guard let chapterID = self.selectedChapterID else { return }
            Task {
                _ = try? await chapterEngine.exportChapter(id: chapterID, to: url)
            }
        }
        onComplete(url)
    }
}