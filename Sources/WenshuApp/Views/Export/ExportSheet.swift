//
//  ExportSheet.swift · Wenshu
//
//  Single-page sheet (= Apple HIG canonical macOS 14+ Sheet pattern)
//  for exporting content from the active Wenshu library. Reachable
//  from the menu bar via File → Export… (= ⇧⌘E). Presents three
//  export-kind sections (Library / Book / Chapter), each backed by
//  its own `ExportEngine` actor. The user picks one kind, configures
//  the section-specific options, then clicks `导出` to trigger the
//  engine. The engine produces a URL; the sheet then hands the URL
//  to `.fileExporter` (= single-file kinds) or to NSSavePanel-style
//  destination picker (= whole-library kinds).
//
//  Why a single sheet (= not a multi-step wizard): per Apple HIG,
//  the export dialog in Pages / Numbers / Xcode collapses all
//  options onto one page with section headers. A wizard implies
//  dependent state between pages (= the user has to remember what
//  they picked on page 1 while reading page 2). The FCP export
//  dialog the user named as reference follows the same single-page
//  shape.
//
//  Why the sheet body is one file (= not split per section): the
//  three sections differ in their content (= radio button state +
//  pickers), not in their structure. Splitting into three views
//  creates three near-clones with no testable seam. A single file
//  keeps the section state co-located with the section content
//  (= easier to read).
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
                    // Engine dispatch lands in ticket 08.
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DesignTokens.spacingSection)
        .frame(minWidth: 480, minHeight: 360)
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
        // Book + chapter picker populated when the engine wiring
        // lands (= ticket 08); sheet renders the section
        // structure now so the menu wiring can be tested.
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