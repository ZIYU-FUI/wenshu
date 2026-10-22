// ImportSheet.swift · Wenshu T3 of the v2.7 markdown import feature. A single-page sheet
// … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
// import flow is structurally simple enough to not need that split).
import SwiftUI
import UniformTypeIdentifiers
import AppKit

// / `ImportSheet` body. Hosts the two pickers + a progress strip (= a per-file
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / `开始导入` / `取消` button row.
struct ImportSheet: View {

    // / (= boss 2026-10-10 (see OOB.md #2026-10-10) 骤交互" directive). The 4-step
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / the user can go back to fix a setting, or forward when ready).
    enum WizardStep: Int, CaseIterable, Identifiable {
        case configure = 0  // 步骤 1: 选目标 (= source dir + file type + destination + book + AI 程度 + 并发数)
        case running = 1    // 步骤 2: 进度 (= ProgressView + progressLabel + per-file strip)
        case results = 2    // 步骤 3: 结果 (= per-file list + per-row 重试 + 总重新调研所有失败)
        case done = 3       // 步骤 4: 完成 (= 摘要 + 完成 button)

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .configure: return "选目标"
            case .running:   return "导入中"
            case .results:   return "处理结果"
            case .done:      return "完成"
            }
        }
        // / Apple HIG canonical: a SF Symbol per step (= the dot indicator uses
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / a dot; = the current step uses the symbol + tint).
        var iconName: String {
            switch self {
            case .configure: return "1.circle.fill"
            case .running:   return "2.circle.fill"
            case .results:   return "3.circle.fill"
            case .done:      return "4.circle.fill"
            }
        }
    }
    @State var currentStep: WizardStep = .configure

    /// Bumped when the `wenshuImportRequested` notification fires (= the File
    /// menu's 导入… shortcut). The parent flips this to dismiss.
    @Binding var isPresented: Bool

    // / parameters (= the boss's 2026-10-09 [archived-round] "右键点资料库，点
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / the destination themselves).
    var prefillDestination: ImportDestination?
    var prefillBookID: UUID?

    init(
        isPresented: Binding<Bool>,
        prefillDestination: ImportDestination? = nil,
        prefillBookID: UUID? = nil
    ) {
        self._isPresented = isPresented
        self.prefillDestination = prefillDestination
        self.prefillBookID = prefillBookID
        // boss 2026-10-09 (see OOB.md #2026-10-09) 定十二地仙" (= `.onAppear` only fires once
        // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // EVERY presentation)).
        if let d = prefillDestination {
            self._importDestination = State(initialValue: d)
        }
        if let id = prefillBookID {
            self._selectedBookID = State(initialValue: id)
        }
    }

    @Environment(BookStore.self) var bookStore

    /// Picked source directory on disk (= the user's existing markdown library;
    /// = the orchestrator walks this directory recursively for .md files).
    @State var sourceDirectory: URL?

    // / Selected target book id (= the user picks which book the .md files
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / involved).
    @State var selectedBookID: UUID?

    // / (= boss 2026-10-10 "用 户在 导入 书的 时候， 要选 择二 级目 录" 反馈). The user-picked
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / "让用户 决定" directive).
    @State var selectedBookFolder: BookFolder?

    // / (= boss 2026-10-09 [archived-round] "导入目标加一个资料库， 用户指定了资料库的，就自动全进到资料库。
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / reduced to a metadata-only role = title + summary + tags).
    enum ImportDestination: String, CaseIterable, Identifiable, Sendable {
        // / Every file in the batch lands in the reference library (= the user
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / classification; = the LLM just produces title / summary / tags).
        case referenceLibrary
        // / Every file in the batch lands in the selected book's 5 folders (=
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / world/characters/outline s/chapters/drafts).
        case book

        var id: String { rawValue }
        var label: String {
            switch self {
            case .referenceLibrary: return "导入到资料库"
            case .book: return "导入到书"
            }
        }
    }
    @State var importDestination: ImportDestination = .book

    // / (= boss 2026-10-09 (see OOB.md #2026-10-09) 重写程度"). The user picks ONCE
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / #2026-10-10) `extraFiles`).
    @State var rewriteMode: ImportFileInput.RewriteMode = .reorganize

    /// Per-file task state (= the orchestrator's `ImportTask` model; = the
    /// progress strip shows one row per file).
    @State var tasks: [ImportTask] = []

    // / (= boss 2026-10-10 (see OOB.md #2026-10-10) directive). The user-picked
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / UI surface); = the `ImportTarget` init clamps to 1..5 defensively.
    @State var maxParallel: Int = 3

    /// Flipped while a batch is importing. Disables the pickers + the action
    /// button.
    @State var isImporting: Bool = false

    // / The file-type filter the user wants to import (= the user's 2026-10-09
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / forces a decision at the walker's match site).
    @State var fileType: ImportFileType = .markdown

    // / Counters surfaced to the sheet's ProgressView (= the orchestrator emits
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / derives a single `progress` fraction from the completed-state count).
    @State var completedCount: Int = 0
    @State var totalCount: Int = 0

    // / Counter of files currently in `routing` or `writing` (= the LLM is
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / what makes the bar feel alive).
    @State var inFlightCount: Int = 0

    // / True after the orchestrator finishes at least one batch (= the action
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / 2026-10-09 round of feedback where they said "部分导入 成功后，按钮还是开始导入，不是重试").
    @State var hasRunOnce: Bool = false

    // / Flag for the cancel-confirmation dialog (= the boss's 2026-10-09
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / dismiss hostage while the import is mid-flight).
    @State var confirmCancelPresented: Bool = false

    /// Last-used source directory (= Apple HIG canonical "remember the last
    /// folder"; = the system open panel starts here).
    @AppStorage("wenshu.import.source.lastURL") var lastSourceURLString: String = ""

    // / The orchestrator. Created once per sheet presentation (= the actor is
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / sheet uses the production binding once T4 lands).
    let importService = ImportService()

    // / The production router. T4 wires the LLM-backed
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / "用文枢正常机制来推出" per boss 2026-10-09 (see OOB.md #2026-10-09)
    let router: any ImportRouter = WenshuConductorImportRouter(
        shelvesRootProvider: { WenshuAppDelegate.activeShelvesRoot() }
    )

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            // (= boss 2026-10-10 (see OOB.md #2026-10-10) directive). The "导入 Markdown
            // … (= 16 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // linearly.
            WizardStepIndicator(
                currentStep: $currentStep,
                canReach: canReachStep
            )
                .padding(.bottom, DesignTokens.spacingTight)

            // The per-step content. Each step is a focused view (= no conditional button
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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

            // the bottom nav bar (= the canonical Apple HIG macOS 14+ wizard pattern; =
            // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // from [archived-round]).
            WizardActionDivider()
            WizardStepNavBar(
                currentStep: $currentStep,
                canGoPrev: canGoPrev,
                canGoNext: canGoNext,
                primaryActionLabel: primaryActionLabel,
                onPrev: goPrev,
                onNext: goNext
            )
        }
        // auto-advance from .running to .results once the import finishes (= the user
        // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // flip.
        .onChange(of: isRunComplete) { _, newValue in
            if newValue && currentStep == .running {
                currentStep = .results
            }
        }
        // for the cancel-and-rollback path.
        .interactiveDismissDisabled(isImporting)
        .padding(DesignTokens.spacingSection)
        // on first appear (= the boss's 2026-10-09 [archived-round] "右键点 资料库，点导入，进到弹窗后，目标
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // book.id`).
        .onAppear {
            if let d = prefillDestination {
                importDestination = d
            }
            if let id = prefillBookID {
                selectedBookID = id
            }
        }
        // Sheet sizing: the canonical Apple HIG macOS 14+ pattern is `minWidth: N` (= a
        // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // 1-N error captions in the failure list).
        .frame(minWidth: 480)
        // The boss's 2026-10-09 follow-up: "那你要 在取消的时候弹一个拦截弹窗，用户确认才 取消，不然 ESC 容易误触". The
        // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // for).
        .onDisappear {
            // Intentionally no-op. The `confirmCancelPresented` flow owns the dismiss
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // dismiss path so we don't double-rollback).
        }
        // The confirmation dialog (= the canonical Apple HIG macOS 14+
        // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // away").
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
                // No-op; = the user changed their mind; = the sheet stays open + the
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // `confirmationDialog` machinery.
            }
        } message: {
            Text("目前已经导入的 \(completedCount) 个文件会全部回退清掉，关闭弹窗后不会保留任何内容。")
        }
    }

    // / The action button's label varies with the sheet's state machine (= the
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / "import again").
    var actionButtonLabel: String {
        if isImporting { return "导入中…" }
        if isRunComplete && hasFailures { return "重试" }
        if isRunComplete { return "完成" }
        return "开始导入"
    }

    // / The cancel button's label varies with the sheet's state machine too (=
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / there were no failures to skip).
    var cancelButtonLabel: String {
        if isRunComplete && hasFailures { return "跳过失败" }
        return "取消"
    }

    // / True when the import batch has run to completion (= no tasks are in
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / "重试" / "再次导入" label switch.
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

    // / True when at least one task ended in `.failed` (= the sheet's per-file
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / as "重试" yet).
    var hasFailures: Bool {
        tasks.contains { $0.state == .failed }
    }

    // (= boss 2026-10-09 (see OOB.md #2026-10-09) 于标题重新调研" directive). The "重新调研所有失败"
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // batch if the LLM is misconfigured).
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
    // / (= boss 2026-10-09 (see OOB.md #2026-10-09) 红字后面" directive). True while
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / "重新调研中…" and disables the progress strip's bottom buttons).
    @State var isRetryingFailed: Bool = false

    // / The cancel-button action (= Apple HIG canonical: closing the sheet means
    // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / truth for the cancel-and-rollback path.
    func showCancelConfirmation() {
        // The cancel-confirmation dialog is only meaningful while an import is mid-flight
        // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // unconditional).
        if isImporting {
            confirmCancelPresented = true
        } else {
            // Pre-run state: just close the sheet. The dialog would be a roadblock with
            // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // upside).
            isPresented = false
        }
    }

    // / The ProgressView's caption row (= derived from the live per-task state
    // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / import run + 4-segment on a re-import).
    var progressLabel: String {
        guard totalCount > 0 else { return "" }
        let done = tasks.filter { $0.state == .done }.count
        let skipped = tasks.filter { $0.state == .skipped }.count
        let failed = tasks.filter { $0.state == .failed }.count
        var parts: [String] = [
            "完成 \(done)",
            "失败 \(failed)",
            "进行中 \(inFlightCount)"
        ]
        if skipped > 0 {
            // Insert "跳过 N" between 完成 and 失败 (= matches the pre-fix segment order; = =
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // and sees the skip count appear).
            parts.insert("跳过 \(skipped)", at: 1)
        }
        return parts.joined(separator: " · ")
    }

    var canStart: Bool {
        guard !isImporting,
              sourceDirectory != nil else {
            return false
        }
        switch importDestination {
        case .referenceLibrary:
            return true
        case .book:
            guard let bookID = selectedBookID,
                  bookStore.books.contains(where: { $0.id == bookID }) else {
                return false
            }
            // (= boss 2026-10-10 "用 户来 决定" directive). The user must also pick a 2nd-
            // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // extraction only).
            return selectedBookFolder != nil
        }
    }

    // / (= boss 2026-10-10 (see OOB.md #2026-10-10) directive). The NSOpenPanel
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / multiple files, they pick a directory).
    func pickSourceDirectory() {
        let panel = NSOpenPanel()
        // both files and directories are selectable. `canChooseFiles` +
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // a toggle between "files" and "folders" mode.
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        // filter to the selected file type's extension (= the open panel shows .md files
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // file picker uses it to filter the list of selectable files).
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

    // / Kick off the import. Builds the ImportTarget from the picked source +
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / the tree without manually re-launching.
    /// Build the `ImportTarget` for the current import destination (= the
    /// target the orchestrator uses to wire up file routing). Centralized
    /// helper (= extracted in A118 from the 2 inline duplicates in
    /// startImport + retryFailedTitleOnly) so the routing config stays
    /// in 1 place.
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
                  bookStore.books.contains(where: { $0.id == bookID }) else {
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
        // (= boss 2026-10-09 [archived-round] "强制让用户分开导 入" directive). The `canStart` gate
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // .referenceLibrary).
        guard let target = buildImportTarget() else { return }
        isImporting = true
        completedCount = 0
        Task {
            // The closure is `@Sendable` (= ImportService's signature) and runs on the
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // domain.
            let onProgress: @Sendable ([ImportTask]) async -> Void = { snapshot in
                await MainActor.run {
                    tasks = snapshot
                    totalCount = snapshot.count
                    // The ProgressView's bar value counts terminal states (= the done
                    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // visibly moves).
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
                // Post the library-change notification so AppleSidebarView (= the
                // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // "点取消返回后，目录 树没有刷新".
                NotificationCenter.default.post(name: .wenshuLibraryDidChange, object: nil)
            }
        }
    }

    // (= boss 2026-10-09 (see OOB.md #2026-10-09) 研" directive). The "重新调研所有失败" button
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // body from the filename + sibling .md names in the same folder).
    func retryFailedTitleOnly() {
        guard !isRetryingFailed else { return }
        // The retry path doesn't need the source directory URL (= each task already
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // the user pinned destination in the sheet is the same for retry).
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
                    // (= boss 2026-10-10 "补充， 重新调研时，进行 中，不统计" directive). The "进行中 N"
                    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // counters").
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

// (extracted to ImportSheetHelpers.swift in A34; = see that file)
// … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
// the cross-file extension access.)