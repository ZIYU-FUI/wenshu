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

    /// Counters surfaced to the sheet's ProgressView
    /// (= the orchestrator emits per-file state
    /// transitions through `onProgress`; = the
    /// sheet's view derives a single `progress`
    /// fraction from the completed-state count).
    @State private var completedCount: Int = 0
    @State private var totalCount: Int = 0

    /// True after the orchestrator finishes at least
    /// one batch (= the action button changes from
    /// "开始导入" to "重试" / "再次导入" so the user
    /// can re-run on the same directory; = the user
    /// explicitly picked this UX in the 2026-10-09
    /// round of feedback where they said "部分导入
    /// 成功后，按钮还是开始导入，不是重试").
    @State private var hasRunOnce: Bool = false

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
                            // Show the FULL path (= the
                            // user's 2026-10-09 feedback:
                            // "选择文件夹只显示最后一个
                            // 文件夹的名字不合适，需要放
                            // 文件路径"). Middle-elided so
                            // long paths still fit on one
                            // line in the 480 PT sheet
                            // (= the trailing parent dir
                            // is what the user usually
                            // needs to verify they're
                            // importing the right tree).
                            Text(url.path)
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(url.path)
                                .textSelection(.enabled)
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
                        // The ProgressView shows the
                        // canonical "已完成 X / Y" form
                        // (= Apple HIG canonical
                        // indeterminate determinate
                        // progress pattern). The
                        // fraction is the count of
                        // terminal-state tasks (.done /
                        // .skipped / .failed) divided by
                        // the total (= the orchestrator's
                        // live state machine; = updated
                        // on each `onProgress` emit).
                        if totalCount > 0 {
                            ProgressView(
                                value: Double(completedCount),
                                total: Double(max(totalCount, 1))
                            ) {
                                Text("已完成 \(completedCount) / \(totalCount)")
                                    .font(.callout.monospacedDigit())
                            } currentValueLabel: {
                                Text(progressLabel)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .progressViewStyle(.linear)
                        }
                        ImportProgressStrip(tasks: tasks)
                            .frame(maxHeight: DesignTokens.kanbanBoardMaxHeight)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(cancelButtonLabel) {
                    skipFailedAndClose()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isImporting)
                Button(actionButtonLabel) {
                    startImport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canStart)
            }
        }
        .padding(DesignTokens.spacingSection)
        // Sheet sizing: the canonical Apple HIG macOS 14+
        // pattern is `minWidth: N` (= a minimum so the
        // sheet is always wide enough to be readable) +
        // no `minHeight` (= the sheet hugs the content; =
        // the empty / fresh sheet is a small 2-picker
        // card; = the post-import sheet grows to fit
        // the per-file progress strip; = the boss's
        // 2026-10-09 feedback "这个弹窗留白太多了"
        // referred to the fixed 360 PT minHeight on
        // the fresh sheet; = dropping the minHeight
        // lets SwiftUI pick the right intrinsic
        // height). The sheet does not bound
        // `maxHeight` either (= no upper cap; = the
        // progress strip's own `maxHeight` constrains
        // its scroll surface; = the sheet body itself
        // can grow as needed for the 1-N error
        // captions in the failure list).
        .frame(minWidth: 480)
    }

    /// The action button's label varies with the sheet's
    /// state machine (= the user's 2026-10-09 round of
    /// feedback: "失败的时候，再次导入改叫重试"). Apple HIG
    /// canonical sheet button convention = the label
    /// reflects what tapping it WILL do; = the
    /// running-state disables the button; = a
    /// done-state with at least one failure shows
    /// "重试" (= taps re-run the import; = the user
    /// reads this as "再试一次" = fix + retry); = a
    /// done-state with zero failures shows "再次导入"
    /// (= taps re-run the import on a clean state; =
    /// idiomatic for "import again").
    private var actionButtonLabel: String {
        if isImporting { return "导入中…" }
        if hasFailures { return "重试" }
        if hasRunOnce { return "再次导入" }
        return "开始导入"
    }

    /// The cancel button's label varies with the sheet's
    /// state machine too (= the user's 2026-10-09
    /// feedback: "取消改叫跳过失败"). Apple HIG canonical:
    /// the button's label always reflects what tapping it
    /// will do; = a fresh sheet shows "取消" (= dismiss
    /// without doing anything); = a done sheet with at
    /// least one failure shows "跳过失败" (= dismiss,
    /// leaving the failed rows out of the final
    /// ImportSheet state machine; = the file-system
    /// write either succeeded or failed, = the user
    /// can't "skip" a half-written file; = the label
    /// reads as "close the sheet and stop looking at
    /// the failure list").
    private var cancelButtonLabel: String {
        if hasFailures { return "跳过失败" }
        return "取消"
    }

    /// True when at least one task ended in `.failed` (= the
    /// sheet's per-file state machine). Drives the
    /// "重试" / "跳过失败" button-label switch.
    private var hasFailures: Bool {
        tasks.contains { $0.state == .failed }
    }

    /// The cancel-button action (= Apple HIG canonical:
    /// closing the sheet means the user is done with the
    /// UI surface; = the per-file state machine goes
    /// with the sheet).
    private func skipFailedAndClose() {
        isPresented = false
    }

    /// The ProgressView's caption row (= derived from
    /// the live per-task state counts; = updates
    /// automatically as `tasks` mutates).
    private var progressLabel: String {
        guard totalCount > 0 else { return "" }
        let done = tasks.filter { $0.state == .done }.count
        let skipped = tasks.filter { $0.state == .skipped }.count
        let failed = tasks.filter { $0.state == .failed }.count
        return "完成 \(done) · 跳过 \(skipped) · 失败 \(failed)"
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
    ///
    /// Progress: the orchestrator's `onProgress`
    /// callback hops to `@MainActor` and updates the
    /// sheet's `tasks` + `completedCount` + `totalCount`
    /// (= the ProgressView re-renders on each tick;
    /// = the per-file state strip re-renders on
    /// each tick).
    ///
    /// On completion (= success or partial failure):
    /// the sheet posts `.wenshuLibraryDidChange` so
    /// `AppleSidebarView` (= the canonical sidebar
    /// host) calls `SidebarService.reload()` and
    /// the user sees the new files in the tree
    /// without manually re-launching.
    private func startImport() {
        guard let source = sourceDirectory,
              let bookID = selectedBookID,
              let book = bookStore.books.first(where: { $0.id == bookID }) else {
            return
        }
        isImporting = true
        completedCount = 0
        let target = ImportTarget(
            wsRoot: libraryRoot(),
            bookId: bookID,
            shelfId: shelfIdForBook(bookID),
            referenceStore: FileSystemReferenceStore(
                referenceLibraryRoot: libraryRoot().appendingPathComponent("reference-library")
            )
        )
        Task {
            // The closure is `@Sendable` (=
            // ImportService's signature) and runs on the
            // orchestrator's actor; = hop to @MainActor
            // before mutating @State so SwiftUI sees the
            // updates on the right isolation domain.
            let onProgress: @Sendable ([ImportTask]) async -> Void = { snapshot in
                await MainActor.run {
                    tasks = snapshot
                    totalCount = snapshot.count
                    completedCount = snapshot.filter {
                        switch $0.state {
                        case .done, .skipped, .failed: return true
                        default: return false
                        }
                    }.count
                }
            }
            let result = await importService.importFiles(
                in: source, into: target, router: router, onProgress: onProgress
            )
            await MainActor.run {
                tasks = result
                completedCount = result.filter {
                    switch $0.state {
                    case .done, .skipped, .failed: return true
                    default: return false
                    }
                }.count
                isImporting = false
                hasRunOnce = true
                // Post the library-change notification so
                // AppleSidebarView (= the canonical sidebar
                // host) re-reads the on-disk library state
                // (= the existing SidebarService.reload()
                // path; = same pattern the create / rename
                // / delete sheets use today). The user's
                // 2026-10-09 feedback: "点取消返回后，目录
                // 树没有刷新".
                NotificationCenter.default.post(name: .wenshuLibraryDidChange, object: nil)
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
