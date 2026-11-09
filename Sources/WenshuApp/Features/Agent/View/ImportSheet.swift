// ImportSheet.swift · Wenshu's markdown import feature. A
// single-page sheet (= Apple HIG canonical macOS 14+ pattern) for the user to
// pick: 1. The source directory on disk (= the directory containing their
// existing markdown files; = e.g. an Obsidian vault). 2. The target book (= a
// Book in the active library = the book they want the.md files to land inside; =
// the orchestrator writes book-folder content into `<book>/world`,
// `<book>/characters`, etc.; = the reference library content goes into the
// library's `reference-library/`). Reachable from File → … (= ⇧⌘I) via the
// `wenshuImportRequested` notification; the host (= AppleSidebarView) listens and
// flips `showImportSheet`. The sheet body is the same VStack + Form pattern the
// ExportSheet uses (= 1 file = 1 sheet = no per-section view files; = the import
// flow is structurally simple enough to not need that split).
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The `ImportSheet` body. It hosts the two pickers and a progress strip (= a
/// per-file row) with the start and cancel buttons.
struct ImportSheet: View {
    /// The four-step wizard. Each step is a page the user can go back to in order
    /// to fix a setting, or forward from when they are ready.
    enum WizardStep: Int, CaseIterable, Identifiable {
        case configure = 0 // Step 1: pick the target (= source dir + file type + destination + book + AI level + concurrency)
        case running = 1 // Step 2: progress (= ProgressView + progressLabel + per-file strip)
        case results = 2 // Step 3: results (= per-file list + a retry per row + a way to re-research every failure)
        case done = 3 // Step 4: done (= a summary + a done button)

        var id: Int {
            rawValue
        }

        var label: String {
            switch self {
            case .configure: return "选目标"
            case .running: return "导入中"
            case .results: return "处理结果"
            case .done: return "完成"
            }
        }

        /// Apple HIG canonical: a SF Symbol per step (= the dot indicator uses a dot,
        /// and the current step uses the symbol with its tint).
        var iconName: String {
            switch self {
            case .configure: return "1.circle.fill"
            case .running: return "2.circle.fill"
            case .results: return "3.circle.fill"
            case .done: return "4.circle.fill"
            }
        }
    }

    @State var currentStep: WizardStep = .configure

    /// Bumped when the `wenshuImportRequested` notification fires (= the
    /// File menu's import shortcut). The parent flips this to dismiss.
    @Binding var isPresented: Bool

    /// The prefill for the target parameters (= the user picks the destination
    /// themselves).
    var prefillDestination: ImportDestination?
    var prefillBookID: UUID?

    init(
        isPresented: Binding<Bool>,
        prefillDestination: ImportDestination? = nil,
        prefillBookID: UUID? = nil
    ) {
        _isPresented = isPresented
        self.prefillDestination = prefillDestination
        self.prefillBookID = prefillBookID
        // The prefill is applied here rather than in `.onAppear` (= which
        // only fires once, so a second presentation would keep the old
        // destination).
        if let d = prefillDestination {
            _importDestination = State(initialValue: d)
        }
        if let id = prefillBookID {
            _selectedBookID = State(initialValue: id)
        }
    }

    @Environment(BookStore.self) var bookStore

    /// Picked source directory on disk (= the user's existing markdown library;
    /// = the orchestrator walks this directory recursively for .md files).
    @State var sourceDirectory: URL?

    /// The selected target book id (= the user picks which book the .md files are
    /// involved).
    @State var selectedBookID: UUID?

    /// The selected target book folder. The user picks the second-level folder
    /// themselves.
    @State var selectedBookFolder: BookFolder?

    /// The import destination. The reference library is one of them, and when the
    /// user names a library every file goes there.
    enum ImportDestination: String, CaseIterable, Identifiable, Sendable {
        /// Every file in the batch lands in the reference library (= the user picks
        /// the reference library, so there is no classification to do; the LLM just
        /// produces the title, the summary and the tags).
        case referenceLibrary
        /// Every file in the batch lands in the selected book's five folders (= the
        /// world, the characters, the outline, the chapters and the drafts).
        case book

        var id: String {
            rawValue
        }

        var label: String {
            switch self {
            case .referenceLibrary: return "导入到资料库"
            case .book: return "导入到书"
            }
        }
    }

    @State var importDestination: ImportDestination = .book

    /// The rewrite mode. The user picks it once, and it applies to the batch
    /// (= including the `extraFiles`).
    @State var rewriteMode: ImportFileInput.RewriteMode = .reorganize

    /// Per-file task state (= the orchestrator's `ImportTask` model; = the
    /// progress strip shows one row per file).
    @State var tasks: [ImportTask] = []

    /// The maximum number of files imported in parallel. It is the user-picked
    /// value, and the `ImportTarget` init clamps it to 1..5 defensively.
    @State var maxParallel: Int = 3

    /// Flipped while a batch is importing. Disables the pickers + the action
    /// button.
    @State var isImporting: Bool = false

    /// The file-type filter the user wants to import. The filter is what forces
    /// a decision at the walker's match site.
    @State var fileType: ImportFileType = .markdown

    /// The counters the sheet's ProgressView shows. The orchestrator emits them,
    /// and the view derives a single `progress` fraction from the completed count.
    @State var completedCount: Int = 0
    @State var totalCount: Int = 0

    /// The counter of the files currently in `routing` or `writing` (= the LLM is
    /// working on them). It is what makes the bar feel alive.
    @State var inFlightCount: Int = 0

    /// True after the orchestrator finishes at least one batch. The action button
    /// then offers a retry rather than starting a second import.
    @State var hasRunOnce: Bool = false

    /// The flag for the cancel-confirmation dialog. A cancel in the middle of an
    /// import must not dismiss the sheet while the work is in flight.
    @State var confirmCancelPresented: Bool = false

    /// Last-used source directory (= Apple HIG canonical "remember the last
    /// folder"; = the system open panel starts here).
    @AppStorage("wenshu.import.source.lastURL") var lastSourceURLString: String = ""

    /// The orchestrator. It is created once per sheet presentation, because it is
    /// an actor.
    let importService = ImportService()

    /// The production router. It wires the LLM-backed import path.
    let router: any ImportRouter = WenshuConductorImportRouter(
        shelvesRootProvider: { WenshuAppDelegate.activeShelvesRoot() }
    )

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            // The wizard steps run linearly, so the indicator shows the
            // import's progress as a row of steps.
            WizardStepIndicator(
                currentStep: $currentStep,
                canReach: canReachStep
            )
            .padding(.bottom, DesignTokens.spacingTight)

            // The per-step content. Each step is a focused view (= no conditional
            // button rows hidden inside; = the state machine is linear; = the
            // per-step view contains exactly the widgets for that step).
            Group {
                switch currentStep {
                case .configure:
                    step1ConfigureView
                case .running:
                    step2RunningView
                case .results:
                    step3ResultsView
                case .done:
                    step4DoneView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // The bottom nav bar.
            WizardActionDivider()
            WizardStepNavBar(
                canGoPrev: canGoPrev,
                canGoNext: canGoNext,
                primaryActionLabel: primaryActionLabel,
                onPrev: goPrev,
                onNext: goNext
            )
        }
        // Auto-advance from.running to.results once the import finishes (= the
        // user doesn't have to tap the next-step button to see the results; = the orchestrator's
        // `isImporting` flag flips to false when the import completes; = the
        // `isRunComplete` derived state becomes true; = the `.onChange` modifier
        // below advances the wizard to.results automatically). The transition is
        // guarded on `currentStep ==.running` so the user can still manually
        // re-navigate to.running (e.g. to re-watch the per- file strip) without
        // being yanked back to.results on every state flip.
        .onChange(of: isRunComplete) { _, newValue in
            if newValue && currentStep == .running {
                currentStep = .results
            }
        }
        // for the cancel-and-rollback path.
        .interactiveDismissDisabled(isImporting)
        .padding(DesignTokens.spacingSection)
        // on first appear (= the user right-clicks the library, picks
        // import, and the sheet opens with the destination already set to
        // that book).
        .onAppear {
            if let d = prefillDestination {
                importDestination = d
            }
            if let id = prefillBookID {
                selectedBookID = id
            }
        }
        // Sheet sizing: the canonical Apple HIG macOS 14+ pattern is `minWidth:
        // N` (= a minimum so the sheet is always wide enough to be readable) + no
        // `minHeight` (= the sheet hugs the content; = the empty / fresh sheet is
        // a small 2-picker card; = the post-import sheet grows to fit the
        // per-file progress strip;; = dropping the minHeight lets SwiftUI pick
        // the right intrinsic height). The sheet does not bound `maxHeight`
        // either (= no upper cap; = the progress strip's own `maxHeight`
        // constrains its scroll surface; = the sheet body itself can grow as
        // needed for the 1-N error captions in the failure list).
        .frame(minWidth: 480)
        // A cancel in the middle of an import asks for confirmation first:
        // the escape key is too easy to hit by accident, so the sheet
        // confirms before it rolls the import back.
        .onDisappear {
            // Intentionally no-op. The `confirmCancelPresented` flow owns the
            // dismiss path (= the sheet's parent binding flips to false ONLY
            // after the user confirms; = this hook is the no-op tail of the
            // dismiss path so we don't double-rollback).
        }
        // The confirmation dialog (= the canonical Apple HIG macOS 14+
        // `confirmationDialog` pattern; = a popup the user can't miss; = the
        // dismiss is blocked until the user explicitly picks an outcome). Apple
        // canonical: the dialog presents ONLY when `confirmCancelPresented =
        // true`; = the `isPresented` binding reads the user-pick (= a Bool return
        // = "true" means "yes, throw it all away").
        .confirmationDialog(
            "确认取消导入？",
            isPresented: $confirmCancelPresented,
            titleVisibility: .visible
        ) {
            Button("确认取消", role: .destructive) {
                Task {
                    await importService.cancel()
                    await importService.rollback()
                    await MainActor.run {
                        isPresented = false
                    }
                }
            }
            Button("返回", role: .cancel) {
                // No-op; = the user changed their mind; = the sheet stays open +
                // the import keeps running; = the `isPresented` binding already
                // flipped back to false by SwiftUI's `confirmationDialog`
                // machinery.
            }
        } message: {
            Text("目前已经导入的 \(completedCount) 个文件会全部回退清掉，关闭弹窗后不会保留任何内容。")
        }
    }

    /// The action button's label varies with the sheet's state machine (= the
    /// "import again" label after a finished run).
    var actionButtonLabel: String {
        if isImporting {
            return "导入中…"
        }
        if isRunComplete && hasFailures {
            return "重试"
        }
        if isRunComplete {
            return "完成"
        }
        return "开始导入"
    }

    /// The cancel button's label varies with the sheet's state machine too (= the
    /// "retry" label when there were failures to skip).
    var cancelButtonLabel: String {
        if isRunComplete && hasFailures {
            return "跳过失败"
        }
        return "取消"
    }

    /// True when the import batch has run to completion (= no task is in flight).
    /// It is what switches the action button between the "retry" and the "import
    /// again" labels.
    var isRunComplete: Bool {
        guard !isImporting else { return false }
        guard !tasks.isEmpty else { return false }
        return tasks.allSatisfy { task in
            switch task.state {
            case .pending, .routing, .writing: return false
            case .done, .skipped, .failed: return true
            }
        }
    }

    /// True when at least one task ended in `.failed`. It is what the sheet's
    /// per-file rows read, and what enables the "retry" action.
    var hasFailures: Bool {
        tasks.contains { $0.state == .failed }
    }

    /// The count of the files whose read failed. The retry-all-failed
    /// button uses it, and it reads 0 when the whole batch failed because
    /// the LLM is misconfigured.
    var failedReadFileCount: Int {
        tasks.filter {
            $0.state == .failed
                && ($0.errorMessage?.hasPrefix("读取文件失败") ?? false)
        }.count
    }

    var canRetryFailedTitleOnly: Bool {
        failedReadFileCount > 0 && !isImporting && !isRetryingFailed
            && isRunComplete
    }

    /// True while a failed batch is being retried. The label reads "retrying" and
    /// the progress strip's bottom buttons are disabled.
    @State var isRetryingFailed: Bool = false

    /// The cancel-button action. Closing the sheet means the truth for the
    /// cancel-and-rollback path.
    func showCancelConfirmation() {
        // The cancel-confirmation dialog is only meaningful while an import is
        // mid-flight (; = an empty sheet's cancel click = no partial batch to confirm
        // = the dialog would feel like a roadblock for a no-op dismiss). Two
        // paths: - `isImporting == true` (= the click arrives after; = the
        // partial batch is on disk; = the dialog is). - `isImporting == false` (=
        // the click arrives before the user ever clicked; = no batch to confirm;
        // = the dismiss is unconditional).
        if isImporting {
            confirmCancelPresented = true
        } else {
            // Pre-run state: just close the sheet. The dialog would be a
            // roadblock with nothing to roll back (= the `ImportService.rollback`
            // path is a no-op when `writtenURLs` is empty +
            // `entitiesJSONSnapshot` is the empty sentinel; = the dialog adds
            // friction with no upside).
            isPresented = false
        }
    }

    /// The ProgressView's caption row. It is derived from the live per-task state,
    /// so it reads the import run plus the four segments of a re-import.
    var progressLabel: String {
        guard totalCount > 0 else { return "" }
        let done = tasks.filter { $0.state == .done }.count
        let skipped = tasks.filter { $0.state == .skipped }.count
        let failed = tasks.filter { $0.state == .failed }.count
        var parts: [String] = [
            "完成 \(done)",
            "失败 \(failed)",
            "进行中 \(inFlightCount)",
        ]
        if skipped > 0 {
            // The skipped count goes between the done and the failed
            // segments (= it matches the pre-fix segment order, and the
            // reader sees the skip count appear).
            parts.insert("跳过 \(skipped)", at: 1)
        }
        return parts.joined(separator: " · ")
    }

    var canStart: Bool {
        guard !isImporting,
              sourceDirectory != nil
        else {
            return false
        }
        switch importDestination {
        case .referenceLibrary:
            return true
        case .book:
            guard let bookID = selectedBookID,
                  bookStore.books.contains(where: { $0.id == bookID })
            else {
                return false
            }
            // The user picks the second-level folder as well (= the
            // extraction needs it).
            return selectedBookFolder != nil
        }
    }

    /// Picks the source directory. The NSOpenPanel picks a directory, and never
    /// multiple files.
    func pickSourceDirectory() {
        let panel = NSOpenPanel()
        // Both files and directories are selectable. `canChooseFiles` +
        // `canChooseDirectories` both = true makes the system open panel show a
        // toggle between "files" and "folders" mode.
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        // Filter to the selected file type's extension (= the open panel shows.md
        // files when the user picks Markdown; = the user can't accidentally pick
        // a.pdf when they meant to import.md). UTType is Apple canonical (= a
        // `UTType` array = the `allowedContentTypes` parameter on NSOpenPanel; =
        // the system file picker uses it to filter the list of selectable files).
        panel.allowedContentTypes = fileType.allowedContentTypes
        panel.prompt = "选择"
        if !lastSourceURLString.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: lastSourceURLString)
        }
        if panel.runModal() == .OK, let url = panel.url {
            sourceDirectory = url
            lastSourceURLString = url.path
        }
    }

    /// Kicks off the import. It builds the ImportTarget from the picked source
    /// and the destination, so the user does not have to rebuild the tree by
    /// hand.
    func buildImportTarget() -> ImportTarget? {
        switch importDestination {
        case .referenceLibrary:
            return ImportTarget(
                destination: .referenceLibrary,
                wsRoot: libraryRoot(),
                bookId: nil,
                shelfId: nil,
                referenceStore: FileSystemReferenceStore(
                    referenceLibraryRoot: libraryRoot().appendingPathComponent("reference-library")
                ),
                rewriteMode: rewriteMode,
                maxParallel: maxParallel
            )
        case .book:
            guard let bookID = selectedBookID,
                  bookStore.books.contains(where: { $0.id == bookID })
            else {
                return nil
            }
            return ImportTarget(
                destination: .book,
                wsRoot: libraryRoot(),
                bookId: bookID,
                shelfId: shelfIdForBook(bookID),
                referenceStore: FileSystemReferenceStore(
                    referenceLibraryRoot: libraryRoot().appendingPathComponent("reference-library")
                ),
                rewriteMode: rewriteMode,
                maxParallel: maxParallel,
                bookFolder: selectedBookFolder
            )
        }
    }

    func startImport() {
        guard let source = sourceDirectory else { return }
        // The import is kept separate from the rest of the import flow.
        // The `canStart` gate has already checked the destination, so the
        // only thing left to reject is the case the user picked no
        // destination at all.
        guard let target = buildImportTarget() else { return }
        isImporting = true
        completedCount = 0
        Task {
            // The closure is `@Sendable` (= ImportService's signature) and runs
            // on the orchestrator's actor; = hop to @MainActor before mutating
            // @State so SwiftUI sees the updates on the right isolation domain.
            let onProgress: @Sendable ([ImportTask]) async -> Void = { snapshot in
                await MainActor.run {
                    tasks = snapshot
                    totalCount = snapshot.count
                    // The progress bar's value counts the terminal states (= the
                    // done counter); the `currentValueLabel` row shows the
                    // per-state breakdown, so the user sees live activity from
                    // the in-flight count too (= the bar visibly moves).
                    completedCount = snapshot.filter {
                        switch $0.state {
                        case .done, .skipped, .failed: return true
                        default: return false
                        }
                    }.count
                    inFlightCount = snapshot.filter {
                        switch $0.state {
                        case .routing, .writing: return true
                        default: return false
                        }
                    }.count
                }
            }
            let result = await importService.importFiles(
                in: source, into: target, router: router, onProgress: onProgress,
                extensions: fileType.extensions
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
                // Post the library-change notification, so the tree behind the
                // sheet refreshes when the sheet closes.
                NotificationCenter.default.post(name: .wenshuLibraryDidChange, object: nil)
            }
        }
    }

    /// Retries the failed files, title only. The "retry all the failed
    /// ones" button calls it, and it rebuilds each body from the filename
    /// and the sibling .md names in the same folder.
    func retryFailedTitleOnly() {
        guard !isRetryingFailed else { return }
        // The retry path doesn't need the source directory URL (= each task
        // already carries its absolute `sourcePath`; = the orchestrator
        // synthesizes the body from the filename + sibling.md names walked from
        // the same parent dir). Reuse the same `ImportTarget` shape as
        // `startImport` (= the user pinned destination in the sheet is the same
        // for retry).
        guard let target = buildImportTarget() else { return }
        isRetryingFailed = true
        Task {
            let onProgress: @Sendable ([ImportTask]) async -> Void = { snapshot in
                await MainActor.run {
                    tasks = snapshot
                    completedCount = snapshot.filter {
                        switch $0.state {
                        case .done, .skipped, .failed: return true
                        default: return false
                        }
                    }.count
                    // The in-flight files are not counted in this total:
                    // a file that is being retried is not done.
                    inFlightCount = 0
                }
            }
            let result = await importService.retryFailedTasksTitleOnly(
                tasks: tasks, into: target, router: router, onProgress: onProgress
            )
            await MainActor.run {
                tasks = result
                completedCount = result.filter {
                    switch $0.state {
                    case .done, .skipped, .failed: return true
                    default: return false
                    }
                }.count
                isRetryingFailed = false
                NotificationCenter.default.post(name: .wenshuLibraryDidChange, object: nil)
            }
        }
    }

    /// Resolve the active library's on-disk root.
    func libraryRoot() -> URL {
        if let path = ActiveLibrary.path {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    /// Walk the shelves to find the shelf that owns this book (= the
    /// orchestrator's ImportTarget carries both shelfId and bookId).
    func shelfIdForBook(_ bookID: UUID) -> UUID {
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

// (extracted to ImportSheetHelpers.swift; = see that file) (= the cross-file
// `extension ImportSheet {.. }` with the 4-step wizard helpers = 4 step views + 6
// control methods moved out of the main file. The `fileprivate` qualifier was
// relaxed to `var`/`func` = internal; = the 13 `@State private var` + 3
// `@Environment(..) private var` + 1 `@AppStorage(..) private var` + 17 ` private
// ` were relaxed to internal; = required for the cross-file extension access.)
