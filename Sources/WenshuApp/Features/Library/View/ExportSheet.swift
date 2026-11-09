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

/// The three export kinds the sheet can produce.
enum ExportKind: String, CaseIterable, Identifiable, Sendable {
    case library
    case book
    case chapter

    var id: String {
        rawValue
    }
}

/// `ExportSheet` body. Hosts the three sections + the unified
/// `Export` / `Cancel` button row.
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

    /// Chapter export sub-option: the author's Markdown (= the
    /// editor's round trip) or a SUBMISSION MANUSCRIPT (= plain
    /// text for a platform's editor).
    @State private var chapterFormat: ChapterExportFormat = .markdown

    /// Which platform the submission manuscript is shaped for
    /// (= only asked for when the format is a manuscript).
    @State private var manuscriptTarget: ManuscriptTarget = .qidian

    /// The selected chapter's word count (= the count the target's own
    /// rule measures), = nil when it has not been measured yet.
    @State private var manuscriptWordCount: Int?

    /// Selected book id (= populated from `BookStore.books`).
    @State private var selectedBookID: UUID?

    /// Selected chapter id (= populated when `selectedBookID`
    /// changes; = lazy-loaded from FileSystemChapterStore).
    @State private var selectedChapterID: UUID?

    /// Loaded chapters for the selected book (= resolved from the
    /// book's `chapters/` folder by `ChapterResolver`).
    @State private var chapters: [ResolvedChapter] = []

    /// Flipped when the user clicks 导出; = triggers the
    /// `.fileExporter` modifier for the selected kind.
    @State private var isExporting: Bool = false

    /// Flipped when the user clicks Export on a MANUSCRIPT; = triggers
    /// the manuscript `.fileExporter` modifier.
    ///
    /// It is SEPARATE from `isExporting` (= the other kinds'
    /// modifiers watch that one) = so a manuscript export opens only
    /// the manuscript's save panel.
    @State private var isExportingManuscript: Bool = false

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
                    if kind == .chapter && chapterFormat == .manuscript {
                        // A manuscript opens its OWN save panel
                        // (= its document type is a plain text
                        // manuscript, = not the chapter's Markdown).
                        isExportingManuscript = true
                    } else {
                        isExporting = true
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canConfirm)
            }
        }
        .padding(DesignTokens.spacingSection)
        .frame(minWidth: 480, minHeight: 360)
        .modifier(LibraryFileExporter(
            libraryFormat: libraryFormat,
            libraryEngine: libraryEngine,
            lastLibraryURLString: $lastLibraryURLString,
            isExporting: $isExporting,
            onComplete: { _ in
                isExporting = false
                isPresented = false
            }
        ))
        .modifier(BookFileExporter(
            bookFormat: bookFormat,
            bookEngine: bookEngine,
            selectedBookID: selectedBookID,
            lastBookURLString: $lastBookURLString,
            isExporting: $isExporting,
            onComplete: { _ in
                isExporting = false
                isPresented = false
            }
        ))
        .modifier(ChapterFileExporter(
            chapterEngine: chapterEngine,
            selectedChapterID: selectedChapterID,
            chapters: chapters,
            lastChapterURLString: $lastChapterURLString,
            isExporting: $isExporting,
            onComplete: { _ in
                isExporting = false
                isPresented = false
            }
        ))
        .modifier(ManuscriptFileExporter(
            chapterEngine: chapterEngine,
            chapterFileURL: selectedChapterFileURL,
            target: manuscriptTarget,
            lastChapterURLString: $lastChapterURLString,
            isExporting: $isExportingManuscript,
            onComplete: { _ in
                isExportingManuscript = false
                isPresented = false
            }
        ))
        .task(id: manuscriptCountKey) {
            manuscriptWordCount = await chapterEngine.manuscriptWordCount(
                fileURL: selectedChapterFileURL,
                target: manuscriptTarget
            )
        }
    }

    /// The warning the count earns, = when it falls outside the
    /// target's published range.
    ///
    /// = The DECISION is the model's (= `chapterWordCountWarning`), =
    /// so a test can reach it; = this view only RENDERS what the model
    /// decided. = A target that publishes no per-chapter word rule earns
    /// no warning, = because the app has no number to check against.
    private var manuscriptWordCountWarning: String? {
        guard let count = manuscriptWordCount else { return nil }
        return manuscriptTarget.chapterWordCountWarning(for: count)
    }

    /// What the count is measured against (= the chapter and the target
    /// together), = so a change to either re-measures it.
    private var manuscriptCountKey: String {
        "\(selectedChapterFileURL?.path ?? "-")-\(manuscriptTarget.rawValue)"
    }

    /// The chapter the manuscript export writes: = the FILE the
    /// resolver handed over, = because an imported chapter is named
    /// after its title and = the id lookup found nothing for it.
    private var selectedChapterFileURL: URL? {
        ResolvedChapter.fileURL(for: selectedChapterID, in: chapters)
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
        case .book: return String(localized: "export.section.book")
        case .chapter: return String(localized: "export.section.chapter")
        }
    }

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
                  let book = bookStore.books.first(where: { $0.id == bookID })
            else {
                chapters = []
                selectedChapterID = nil
                return
            }
            // Load chapters from the book's filesystem folder
            // (= the same reader the export engine uses; = the
            // folder on disk is the truth and the index enriches it).
            let bookDir = bookURL(for: book)
            chapters = ChapterResolver.resolveChapters(
                bookId: bookID,
                chaptersDirectory: bookDir.appendingPathComponent("chapters", isDirectory: true),
                indexURL: bookDir.appendingPathComponent("chapters.json")
            )
            selectedChapterID = nil
        }
    }

    @ViewBuilder
    private var chapterSection: some View {
        Picker(String(localized: "export.chapter.format"), selection: $chapterFormat) {
            Text(String(localized: "export.chapter.format.markdown")).tag(ChapterExportFormat.markdown)
            Text(String(localized: "export.chapter.format.manuscript")).tag(ChapterExportFormat.manuscript)
        }
        .pickerStyle(.radioGroup)
        if chapterFormat == .manuscript {
            // The target picker asks only when a manuscript is
            // being written (= the Markdown export has no target).
            Picker(String(localized: "export.chapter.target"), selection: $manuscriptTarget) {
                ForEach(ManuscriptTarget.allCases) { target in
                    Text(target.displayName).tag(target)
                }
            }
            .pickerStyle(.radioGroup)
            // What the target's shape IS, = in two lines: = the indent
            // lives in the content or the platform renders it, = and
            // the segments are separated by a blank line or not. = The
            // writer is about to hand the platform's editor a file, =
            // so the rules that shaped it are worth saying.
            Text(manuscriptTarget.indentDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(manuscriptTarget.spacingDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            // What the platform COUNTS, = and this chapter's count of
            // it: = the writer is about to hand the platform's editor a
            // file, = so the number the platform will count is worth
            // saying before the file is written.
            if let count = manuscriptWordCount {
                Text("正文 \(count) 字（\(manuscriptTarget.wordCountRule)）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let warning = manuscriptWordCountWarning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            }
        }
        Picker(String(localized: "export.book.picker"), selection: $selectedBookID) {
            Text(String(localized: "export.book.placeholder")).tag(UUID?.none)
            ForEach(bookStore.books) { book in
                Text(book.title).tag(Optional(book.id))
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedBookID) { _, newValue in
            guard let bookID = newValue,
                  let book = bookStore.books.first(where: { $0.id == bookID })
            else {
                chapters = []
                selectedChapterID = nil
                return
            }
            let bookDir = bookURL(for: book)
            chapters = ChapterResolver.resolveChapters(
                bookId: bookID,
                chaptersDirectory: bookDir.appendingPathComponent("chapters", isDirectory: true),
                indexURL: bookDir.appendingPathComponent("chapters.json")
            )
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
    var id: String {
        rawValue
    }
}

/// Book export sub-format.
enum BookExportFormat: String, CaseIterable, Identifiable, Sendable {
    case epub
    case pdf
    case combinedMd
    var id: String {
        rawValue
    }
}

/// Chapter export sub-format: the author's own Markdown (= the
/// editor's round trip, = the body bytes preserved verbatim) or a
/// SUBMISSION MANUSCRIPT (= plain text for a platform's editor, =
/// shaped by the target's measured rules).
enum ChapterExportFormat: String, CaseIterable, Identifiable, Sendable {
    case markdown
    case manuscript
    var id: String {
        rawValue
    }
}
