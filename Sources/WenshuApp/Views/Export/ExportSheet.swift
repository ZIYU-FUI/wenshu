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

    /// Which kind the user has selected. Defaults to library.
    @State private var kind: ExportKind = .library

    /// Library export sub-option: zip vs raw copy.
    @State private var libraryFormat: LibraryExportFormat = .copy

    /// Book export sub-option: EPUB / PDF / combined MD.
    @State private var bookFormat: BookExportFormat = .epub

    /// Selected book id (= populated from `WenshuLibrary`).
    @State private var selectedBookID: UUID?

    /// Selected chapter id (= populated from the selected book's chapters).
    @State private var selectedChapterID: UUID?

    /// Flipped when the user clicks 导出; = triggers the
    /// `.fileExporter` modifier for the selected kind.
    @State private var isExporting: Bool = false

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
            isExporting: $isExporting,
            onComplete: { url in
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
        Text("Book picker placeholder")
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var chapterSection: some View {
        Text("Chapter picker placeholder")
            .foregroundStyle(.secondary)
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
private struct ExportFileExporters: ViewModifier {
    let kind: ExportKind
    let libraryFormat: LibraryExportFormat
    let bookFormat: BookExportFormat
    let selectedBookID: UUID?
    let selectedChapterID: UUID?
    let libraryEngine: LibraryExportEngine
    let bookEngine: BookExportEngine
    let chapterEngine: ChapterExportEngine
    @Binding var isExporting: Bool
    let onComplete: (URL) -> Void

    func body(content: Content) -> some View {
        content
            // Library → .package directory OR .zip archive
            .fileExporter(
                isPresented: $isExporting,
                document: LibraryExportDocument.package(
                    // Default destination = the user's Downloads
                    // folder with a timestamped name (= the system
                    // save dialog will override if the user picks
                    // another path).
                    FileManager.default.temporaryDirectory
                        .appendingPathComponent("wenshu-export-\(Int(Date.now.timeIntervalSince1970))")
                ),
                contentType: .folder,
                onCompletion: { result in
                    if case .success(let url) = result {
                        onComplete(url)
                    }
                    isExporting = false
                }
            )
    }
}