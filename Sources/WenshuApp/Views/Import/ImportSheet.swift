//
//  ImportSheet.swift · Wenshu
//
//  T3 of the v2.7 markdown import feature. A single-page
//  sheet (= Apple HIG canonical macOS 14+ pattern) for
//  the user to pick:
//
//  1. The source directory on disk (= the directory
//     containing their existing markdown files; = e.g.
//     an Obsidian vault).
//  2. The target book (= a Book in the active library
//     = the book they want the .md files to land
//     inside; = the orchestrator writes book-folder
//     content into `<book>/world`, `<book>/characters`,
//     etc.; = the reference library content goes into
//     the library's `reference-library/`).
//
//  Reachable from File → 导入… (= ⇧⌘I) via the
//  `wenshuImportRequested` notification; the host
//  (= AppleSidebarView) listens and flips
//  `showImportSheet`.
//
//  The sheet body is the same VStack + Form pattern the
//  ExportSheet uses (= 1 file = 1 sheet = no per-section
//  view files; = the import flow is structurally simple
//  enough to not need that split).
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// `ImportSheet` body. Hosts the two pickers + a
/// progress strip (= a per-file state machine; = the
/// orchestrator's `ImportTask` is the model) + the
/// unified `开始导入` / `取消` button row.
struct ImportSheet: View {

    /// Bumped when the `wenshuImportRequested`
    /// notification fires (= the File menu's 导入…
    /// shortcut). The parent flips this to dismiss.
    @Binding var isPresented: Bool

    @Environment(BookStore.self) private var bookStore

    /// Picked source directory on disk (= the user's
    /// existing markdown library; = the orchestrator
    /// walks this directory recursively for .md files).
    @State private var sourceDirectory: URL?

    /// Selected target book id (= the user picks
    /// which book the .md files should land in).
    @State private var selectedBookID: UUID?

    /// Per-file task state (= the orchestrator's
    /// `ImportTask` model; = the progress strip
    /// shows one row per file).
    @State private var tasks: [ImportTask] = []

    /// Flipped while a batch is importing. Disables
    /// the pickers + the action button.
    @State private var isImporting: Bool = false

    /// Last-used source directory (= Apple HIG
    /// canonical "remember the last folder"; =
    /// the system open panel starts here).
    @AppStorage("wenshu.import.source.lastURL") private var lastSourceURLString: String = ""

    /// The orchestrator. Created once per sheet
    /// presentation (= the actor is stateless; = the
    /// T4 production router lives in
    /// `WenshuConductor`; = the sheet uses the
    /// production binding once T4 lands).
    private let importService = ImportService()

    /// The production router. T4 wires the LLM-backed
    /// `WenshuConductorImportRouter` (= the same
    /// EntityClassifier the rest of wenshu uses; = the
    /// sheet classifies each .md file via the project's
    /// standard 2-pass keyword + LLM classifier; = no
    /// new inference path; = "用文枢正常机制来推出" per
    /// boss 2026-10-09 OOB).
    private let router: any ImportRouter = WenshuConductorImportRouter()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            Text("导入 Markdown 文件")
                .font(.title2.weight(.semibold))

            Form {
                Section {
                    HStack {
                        if let url = sourceDirectory {
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("选择一个包含 .md 文件的目录")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("选择…") { pickSourceDirectory() }
                            .disabled(isImporting)
                    }

                    Picker("目标书籍", selection: $selectedBookID) {
                        Text("请选择书籍").tag(UUID?.none)
                        ForEach(bookStore.books) { book in
                            Text(book.title).tag(Optional(book.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isImporting)
                }

                if !tasks.isEmpty {
                    Section("进度") {
                        ImportProgressStrip(tasks: tasks)
                            .frame(maxHeight: DesignTokens.kanbanBoardMaxHeight)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                Button("开始导入") {
                    startImport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canStart)
            }
        }
        .padding(DesignTokens.spacingSection)
        .frame(minWidth: 480, minHeight: 360)
    }

    private var canStart: Bool {
        guard !isImporting,
              sourceDirectory != nil,
              let bookID = selectedBookID,
              bookStore.books.contains(where: { $0.id == bookID }) else {
            return false
        }
        return true
    }

    /// Present the system open panel (= Apple HIG
    /// canonical directory picker). Starts at the
    /// last-used URL if any.
    private func pickSourceDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        if !lastSourceURLString.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: lastSourceURLString)
        }
        if panel.runModal() == .OK, let url = panel.url {
            sourceDirectory = url
            lastSourceURLString = url.path
        }
    }

    /// Kick off the import. Builds the ImportTarget
    /// from the picked source + book, then asks the
    /// orchestrator to walk + dedup + route + write.
    private func startImport() {
        guard let source = sourceDirectory,
              let bookID = selectedBookID,
              let book = bookStore.books.first(where: { $0.id == bookID }) else {
            return
        }
        isImporting = true
        let target = ImportTarget(
            wsRoot: libraryRoot(),
            bookId: bookID,
            shelfId: shelfIdForBook(bookID),
            referenceStore: FileSystemReferenceStore(
                referenceLibraryRoot: libraryRoot().appendingPathComponent("reference-library")
            )
        )
        Task {
            let result = await importService.importFiles(
                in: source, into: target, router: router
            )
            await MainActor.run {
                tasks = result
                isImporting = false
            }
        }
    }

    /// Resolve the active library's on-disk root.
    private func libraryRoot() -> URL {
        if let path = ActiveLibrary.path {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    /// Walk the shelves to find the shelf that owns
    /// this book (= the orchestrator's ImportTarget
    /// carries both shelfId and bookId).
    private func shelfIdForBook(_ bookID: UUID) -> UUID {
        let shelvesURL = libraryRoot().appendingPathComponent("shelves", isDirectory: true)
        let fm = FileManager.default
        guard let shelves = try? fm.contentsOfDirectory(at: shelvesURL, includingPropertiesForKeys: nil) else {
            return UUID()
        }
        for shelf in shelves {
            let candidate = shelf
                .appendingPathComponent("books", isDirectory: true)
                .appendingPathComponent(bookID.uuidString, isDirectory: true)
            if fm.fileExists(atPath: candidate.path) {
                // shelf URL = <shelves>/<shelfId>/
                return UUID(uuidString: shelf.lastPathComponent) ?? UUID()
            }
        }
        return UUID()
    }
}

/// Per-file progress strip (= one row per `ImportTask`).
/// Apple HIG canonical list pattern (= vertical stack of
/// short rows; = the row shows the file name + the state
/// badge + an inline error caption if the task failed).
private struct ImportProgressStrip: View {
    let tasks: [ImportTask]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                ForEach(tasks) { task in
                    ImportTaskRow(task: task)
                }
            }
        }
    }
}

/// One row in the progress strip. Shows the source
/// file's basename + the state pill + the error
/// caption if the task failed.
private struct ImportTaskRow: View {
    let task: ImportTask

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingStandard) {
            Text((task.sourcePath as NSString).lastPathComponent)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            statePill
        }
        .padding(.vertical, DesignTokens.spacingCaption)
        if let err = task.errorMessage {
            Text(err)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var statePill: some View {
        switch task.state {
        case .pending:
            Text("待处理").font(.caption).foregroundStyle(.secondary)
        case .routing:
            Text("分析中").font(.caption).foregroundStyle(.secondary)
        case .writing:
            Text("写入中").font(.caption).foregroundStyle(.secondary)
        case .done:
            Text("完成").font(.caption).foregroundStyle(.green)
        case .skipped:
            Text("已跳过").font(.caption).foregroundStyle(.secondary)
        case .failed:
            Text("失败").font(.caption).foregroundStyle(.red)
        }
    }
}

/// Placeholder router for the sheet (= kept as a
/// fallback for unit tests + the dev hot-reload
/// path; = the production sheet wires
/// `WenshuConductorImportRouter` instead).
private struct StubImportRouterForSheet: ImportRouter {
    func route(_ input: ImportFileInput) async throws -> ImportRoutingResult {
        return ImportRoutingResult(
            destination: .referenceLibrary,
            title: (input.filePath as NSString).deletingPathExtension,
            summary: "stub classification",
            tags: ["imported"],
            entityType: "other",
            category: nil,
            confidence: 1.0
        )
    }
}
