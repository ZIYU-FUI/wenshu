// ImportSheet.swift · Wenshu T3 of the v2.7 markdown import feature. A single-page sheet
// (= Apple HIG canonical macOS 14+ pattern) for the user to pick: 1. The source
// directory on disk (= the directory containing their existing markdown files; = e.g.
// an Obsidian vault). 2. The target book (= a Book in the active library = the book
// they want the .md files to land inside; = the orchestrator writes book-folder
// content into `<book>/world`, `<book>/characters`, etc.; = the reference library
// content goes into the library's `reference-library/`). Reachable from File → 导入… (=
// ⇧⌘I) via the `wenshuImportRequested` notification; the host (= AppleSidebarView)
// listens and flips `showImportSheet`. The sheet body is the same VStack + Form
// pattern the ExportSheet uses (= 1 file = 1 sheet = no per-section view files; = the
// import flow is structurally simple enough to not need that split).

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// `ImportSheet` body. Hosts the two pickers + a
/// progress strip (= a per-file state machine; = the
/// orchestrator's `ImportTask` is the model) + the
/// unified `开始导入` / `取消` button row.
struct ImportSheet: View {

    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// 骤交互" directive).
    /// The 4-step wizard state (= the
    /// canonical Apple HIG macOS
    /// 14+ multi-step sheet pattern;
    /// = same as Pages / Mail
    /// composer / Final Draft
    /// importer; = one step at a
    /// time; = the dot indicator at
    /// the top + the nav bar at the
    /// bottom are the only chrome;
    /// = each step is a focused
    /// Form / List with no
    /// conditional button rows
    /// hidden inside; = the state
    /// machine is linear; = the
    /// user can go back to fix a
    /// setting, or forward when
    /// ready).
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
        /// Apple HIG canonical: a SF Symbol
        /// per step (= the dot indicator
        /// uses the symbol for the
        /// completed state; = the
        /// unfulfilled state is just a
        /// dot; = the current step uses
        /// the symbol + tint).
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

    /// Bumped when the `wenshuImportRequested`
    /// notification fires (= the File menu's 导入…
    /// shortcut). The parent flips this to dismiss.
    @Binding var isPresented: Bool

    /// parameters (= the boss's
    /// 2026-10-09 round-18 "右键点资料库，点
    /// 导入，进到弹窗后，目标自动选好资料库。
    /// 右键点书的时候目标自动选好对应的书"
    /// directive). Both are nil when the sheet
    /// is opened via the File menu (= no
    /// pre-selection; = the user picks the
    /// destination themselves).
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
        // per sheet instance; = re-opening via contextMenu after a File-menu
        // first-open left the prefill stale; = the fix is to initialize the
        // @State values in the init (= SwiftUI's `_State(wrappedValue:)`
        // initializer accepts an `initialValue`; = the value is set when the
        // sheet is constructed; = every contextMenu click that calls
        // `showImportSheet = true` rebuilds the sheet (= the @State is
        // initialized fresh on each construction); = the prefill is honored on
        // EVERY presentation)).
        if let d = prefillDestination {
            self._importDestination = State(initialValue: d)
        }
        if let id = prefillBookID {
            self._selectedBookID = State(initialValue: id)
        }
    }

    @Environment(BookStore.self) var bookStore

    /// Picked source directory on disk (= the user's
    /// existing markdown library; = the orchestrator
    /// walks this directory recursively for .md files).
    @State var sourceDirectory: URL?

    /// Selected target book id (= the user picks
    /// which book the .md files should land in). Nil
    /// when `importDestination == .referenceLibrary`
    /// (= the user pinned the reference library as
    /// the target; = no book is involved).
    @State var selectedBookID: UUID?

    /// (= boss
    /// 2026-10-10 "用
    /// 户在
    /// 导入
    /// 书的
    /// 时候，
    /// 要选
    /// 择二
    /// 级目
    /// 录"
    /// 反馈).
    /// The user-picked
    /// 2nd-level folder
    /// for the book
    /// destination (= the
    /// 6 import folders
    /// = world /
    /// characters /
    /// outlines /
    /// chapters / drafts
    /// / ideas). Nil
    /// when
    /// `importDestination
    /// == .referenceLibrary`
    /// (= the reference
    /// library has no
    /// folder hierarchy;
    /// = this state is
    /// ignored). When
    /// the user picks
    /// a book, the
    /// `canStart` gate
    /// requires a
    /// non-nil value
    /// (= no default
    /// = the user
    /// must explicitly
    /// decide which
    /// folder the
    /// batch lands in;
    /// = the boss's
    /// "让用户
    /// 决定"
    /// directive).
    @State var selectedBookFolder: BookFolder?

    /// (= boss
    /// 2026-10-09 round-18 "导入目标加一个资料库，
    /// 用户指定了资料库的，就自动全进到资料库。
    /// 用户指定到书的，就自动全进入到书的五目
    /// 录。这样可以简化一些提示词。强制让用户分
    /// 开导入"; = the user picks ONCE at sheet open
    /// time; = the LLM no longer picks the
    /// destination; = the LLM is reduced to a
    /// metadata-only role = title + summary + tags).
    enum ImportDestination: String, CaseIterable, Identifiable, Sendable {
        /// Every file in the batch lands in the
        /// reference library (= the user is
        /// importing research / 调研 / 民俗
        /// 文献 / 古籍原文; = no LLM
        /// destination classification; = the LLM
        /// just produces title / summary / tags).
        case referenceLibrary
        /// Every file in the batch lands in the
        /// selected book's 5 folders (= the user
        /// is importing book-specific setting; =
        /// the LLM picks world/characters/outline
        /// s/chapters/drafts).
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

    /// (= boss 2026-10-09 (see OOB.md #2026-10-09)
    /// 重写程度"). The user picks ONCE at sheet
    /// open; = the LLM's tool set + the
    /// orchestrator's write path both
    /// respect this; = default = `reorganize`
    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// `extraFiles`).
    @State var rewriteMode: ImportFileInput.RewriteMode = .reorganize

    /// Per-file task state (= the orchestrator's
    /// `ImportTask` model; = the progress strip
    /// shows one row per file).
    @State var tasks: [ImportTask] = []

    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// directive). The user-picked
    /// parallelism for the 5-way
    /// concurrent LLM dispatch
    /// loop. Range: 1..5 (= the
    /// boss's five options). Default
    /// 3 (= the middle option; = a
    /// safe rate for most LLM
    /// providers; = the tradeoff
    /// between throughput and
    /// rate-limit risk; = the
    /// user can adjust to 1 if
    /// they hit 429 from their
    /// provider; = adjust to 5
    /// for fast quota). The
    /// Picker below exposes
    /// 1..5 (= the user's UI
    /// surface); = the
    /// `ImportTarget` init clamps
    /// to 1..5 defensively.
    @State var maxParallel: Int = 3

    /// Flipped while a batch is importing. Disables
    /// the pickers + the action button.
    @State var isImporting: Bool = false

    /// The file-type filter the user wants to import
    /// (= the user's 2026-10-09 ask: "加一个导入文件类
    /// 型选择，其它的可以慢慢做，现在默认 MD 可导
    /// 入，以后要加电子书格式什么的"; = today only
    /// Markdown is wired; = the enum is open to .epub /
    /// .pdf / .txt / etc. as future tickets ship; = the
    /// `ImportService.walkSourceDir(_:_:)` accepts the
    /// filter via the `extensions` parameter so the
    /// orchestrator only walks files whose extension
    /// matches the user's pick). Apple canonical pattern:
    /// closed enum (= "make illegal states unrepresentable";
    /// = a new file type forces a decision at the
    /// walker's match site).
    @State var fileType: ImportFileType = .markdown

    /// Counters surfaced to the sheet's ProgressView
    /// (= the orchestrator emits per-file state
    /// transitions through `onProgress`; = the
    /// sheet's view derives a single `progress`
    /// fraction from the completed-state count).
    @State var completedCount: Int = 0
    @State var totalCount: Int = 0

    /// Counter of files currently in `routing` or
    /// `writing` (= the LLM is mid-flight or the
    /// file is mid-write). Drives the "进行中"
    /// label next to "完成 / 跳过 / 失败" so the
    /// user sees live activity (= the user's
    /// 2026-10-09 feedback: "进度条还是不会跟着
    /// 走，还在憋大招，最后给一个 100%"; = the
    /// 4-way parallel LLM dispatch means at most
    /// 4 files are in flight at any time, but the
    /// per-second "in flight" count combined with
    /// the moving `done` count is what makes the
    /// bar feel alive).
    @State var inFlightCount: Int = 0

    /// True after the orchestrator finishes at least
    /// one batch (= the action button changes from
    /// "开始导入" to "重试" / "再次导入" so the user
    /// can re-run on the same directory; = the user
    /// explicitly picked this UX in the 2026-10-09
    /// round of feedback where they said "部分导入
    /// 成功后，按钮还是开始导入，不是重试").
    @State var hasRunOnce: Bool = false

    /// Flag for the cancel-confirmation dialog (= the
    /// boss's 2026-10-09 follow-up "那你要在取消的
    /// 时候弹一个拦截弹窗，用户确认才取消，不然 ESC
    /// 容易误触"). The `取消` button + every dismiss
    /// path (= ESC / Cmd+W / toolbar X / clicking
    /// outside) flips this to `true`; = the
    /// `confirmationDialog` modifier presents
    /// immediately (= the user can't dismiss the
    /// sheet without picking "确认取消" or
    /// "返回"; = the `interactiveDismissDisabled`
    /// modifier on the sheet body holds the dismiss
    /// hostage while the import is mid-flight).
    @State var confirmCancelPresented: Bool = false

    /// Last-used source directory (= Apple HIG
    /// canonical "remember the last folder"; =
    /// the system open panel starts here).
    @AppStorage("wenshu.import.source.lastURL") var lastSourceURLString: String = ""

    /// The orchestrator. Created once per sheet
    /// presentation (= the actor is stateless; = the
    /// T4 production router lives in
    /// `WenshuConductor`; = the sheet uses the
    /// production binding once T4 lands).
    let importService = ImportService()

    /// The production router. T4 wires the LLM-backed
    /// `WenshuConductorImportRouter` (= the same
    /// EntityClassifier the rest of wenshu uses; = the
    /// sheet classifies each .md file via the project's
    /// standard 2-pass keyword + LLM classifier; = no
    /// new inference path; = "用文枢正常机制来推出" per
    /// boss 2026-10-09 (see OOB.md #2026-10-09)
    let router: any ImportRouter = WenshuConductorImportRouter()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
            // (= boss 2026-10-10 (see OOB.md #2026-10-10) directive). The "导入 Markdown
            // 文件" title is REMOVED (= redundant; = the user just clicked
            // 导入 from the File menu OR the sidebar contextMenu; = the
            // wizard's top-of-sheet title is dead weight; = the Pages
            // inspector has no such title either; = removing it gives the
            // dot indicator + the first picker card more vertical
            // breathing room).

            // (= boss 2026-10-10 (see OOB.md #2026-10-10) directive). The 4-step dot
            // indicator at the top of the sheet (= canonical Apple HIG
            // macOS 14+ multi-step pattern; = the user can see which step
            // they're on + how many remain; = the dots are also clickable
            // to jump back; = this replaces the old single-page Form). (=
            // boss 2026-10-10 "dot 如果没 有进到下一步，dot 就不能跳到下一 步骤" directive).
            // The dot jumps are GATED on `canReachStep(step)`; = the user
            // can only click a dot for a step they have already reached; =
            // a fresh sheet on ① 选目标 only has ① clickable; = ②③④ are
            // dimmed and disabled; = the user MUST walk through the wizard
            // linearly.
            WizardStepIndicator(
                currentStep: $currentStep,
                canReach: canReachStep
            )
                .padding(.bottom, DesignTokens.spacingTight)

            // The per-step content. Each step is a focused view (= no conditional button
            // rows hidden inside; = the state machine is linear; = the
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
            // "上 一步" on the left + primary action on the right; = the
            // primary action's label varies with the current step; = "开始"
            // / "下一步" / "完成"). (= boss 2026-10-10 "我画的 红线处, 缺一条 分割先. 让操作
            // 区和设定区分 开" directive). A hairline Divider between the per-
            // step content (= 设定 区) and the nav bar (= 操作 区). The Divider
            // is on every step (= the boss's "演示 要每一步骤 的页面都 一样" directive
            // from round-50).
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
        // doesn't have to tap "下一步" to see the results; = the orchestrator's
        // `isImporting` flag flips to false when the import completes; = the
        // `isRunComplete` derived state becomes true; = the `.onChange`
        // modifier below advances the wizard to .results automatically). The
        // transition is guarded on `currentStep == .running` so the user can
        // still manually re-navigate to .running (e.g. to re-watch the per-
        // file strip) without being yanked back to .results on every state
        // flip.
        .onChange(of: isRunComplete) { newValue in
            if newValue && currentStep == .running {
                currentStep = .results
            }
        }
        // for the cancel-and-rollback path.
        .interactiveDismissDisabled(isImporting)
        .padding(DesignTokens.spacingSection)
        // on first appear (= the boss's 2026-10-09 round-18 "右键点 资料库，点导入，进到弹窗后，目标
        // 自动选好资料库。右键点书的时候 目标自动选好对应的书" directive; = when the user right-clicks
        // the reference library, the sheet opens with `prefillDestination =
        // .referenceLibrary`; = when the user right-clicks a book, the sheet
        // opens with `prefillDestination = .book` + `prefillBookID =
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
        // minimum so the sheet is always wide enough to be readable) + no
        // `minHeight` (= the sheet hugs the content; = the empty / fresh sheet
        // is a small 2-picker card; = the post-import sheet grows to fit the
        // per-file progress strip; = the boss's 2026-10-09 feedback
        // "这个弹窗留白太多了" referred to the fixed 360 PT minHeight on the fresh
        // sheet; = dropping the minHeight lets SwiftUI pick the right
        // intrinsic height). The sheet does not bound `maxHeight` either (= no
        // upper cap; = the progress strip's own `maxHeight` constrains its
        // scroll surface; = the sheet body itself can grow as needed for the
        // 1-N error captions in the failure list).
        .frame(minWidth: 480)
        // The boss's 2026-10-09 follow-up: "那你要 在取消的时候弹一个拦截弹窗，用户确认才 取消，不然 ESC 容易误触". The
        // dismiss path (ESC + Cmd+W + the toolbar X button + clicking outside
        // the sheet) fires SwiftUI's `.onDisappear`; = we DO NOT auto-rollback
        // here (= that was the previous version; = the user was right that ESC
        // can be a reflexive muscle-memory press; = the auto-rollback would
        // nuke the partial batch without confirmation). Instead, every dismiss
        // path (ESC / Cmd+W / toolbar close / clicking outside) routes through
        // the `confirmCancelPresented` confirmation dialog (= the user
        // explicitly confirms "yes, throw away the partial batch"; = the
        // dialog is an Apple HIG canonical macOS 14+ `confirmationDialog`
        // pattern; = a "返回" option lets the user dismiss the dialog and keep
        // importing). If the user clicks "返回" (= cancel the cancel), the sheet
        // stays open + the import keeps running. If the user clicks "确认取消",
        // the orchestrator's cancel + rollback fire (= the partial batch is
        // gone, = the sheet dismisses to the "no trace" state the boss asked
        // for).
        .onDisappear {
            // Intentionally no-op. The `confirmCancelPresented` flow owns the dismiss
            // path (= the sheet's parent binding flips to false ONLY after
            // the user confirms; = this hook is the no-op tail of the
            // dismiss path so we don't double-rollback).
        }
        // The confirmation dialog (= the canonical Apple HIG macOS 14+
        // `confirmationDialog` pattern; = a popup the user can't miss; = the
        // dismiss is blocked until the user explicitly picks an outcome).
        // Apple canonical: the dialog presents ONLY when
        // `confirmCancelPresented = true`; = the `isPresented` binding reads
        // the user-pick (= a Bool return = "true" means "yes, throw it all
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
                // import keeps running; = the `isPresented` binding
                // already flipped back to false by SwiftUI's
                // `confirmationDialog` machinery.
            }
        } message: {
            Text("目前已经导入的 \(completedCount) 个文件会全部回退清掉，关闭弹窗后不会保留任何内容。")
        }
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
    var actionButtonLabel: String {
        if isImporting { return "导入中…" }
        if isRunComplete && hasFailures { return "重试" }
        if isRunComplete { return "完成" }
        return "开始导入"
    }

    /// The cancel button's label varies with the sheet's
    /// state machine too (= the user's 2026-10-09
    /// feedback: "取消改叫跳过失败" + the 2026-10-09
    /// follow-up "跳过失败按钮，不是遇到失败就亮起，
    /// 而是在进度跑到 100% 后亮起" = the button is
    /// "跳过失败" only AFTER the batch has run to
    /// completion; = mid-flight, the button is still
    /// "取消" because the user is mid-import and the
    /// label is "cancel the running batch"; = a
    /// done-state with zero failures stays "取消" (= the
    /// user can dismiss the sheet as normal; = the
    /// "跳过失败" label is meaningless when there were
    /// no failures to skip).
    var cancelButtonLabel: String {
        if isRunComplete && hasFailures { return "跳过失败" }
        return "取消"
    }

    /// True when the import batch has run to completion
    /// (= no tasks are in `.pending` or `.routing` or
    /// `.writing` state; = every task reached a terminal
    /// state). Apple canonical pattern: a derived
    /// state-machine flag (= composed from `tasks` and
    /// `isImporting`; = avoids storing a separate
    /// boolean that could desync from the source of
    /// truth). Drives the "跳过失败" / "重试" /
    /// "再次导入" label switch.
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

    /// True when at least one task ended in `.failed` (= the
    /// sheet's per-file state machine). Drives the
    /// "重试" / "跳过失败" button-label switch (in
    /// combination with `isRunComplete`; = mid-flight
    /// failures are not surfaced as "重试" yet).
    var hasFailures: Bool {
        tasks.contains { $0.state == .failed }
    }

    // (= boss 2026-10-09 (see OOB.md #2026-10-09) 于标题重新调研" directive). The "重新调研所有失败"
    // button is only visible when at least one task failed because the file was
    // unreadable on disk (= `errorMessage` starts with "读取文件失败"). LLM-routing
    // failures and write failures are NOT retried by this button (= those are bugs
    // in the pipeline config, not file problems; = the user re-imports the whole
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
    /// (= boss 2026-10-09 (see OOB.md #2026-10-09)
    /// 红字后面" directive). True while
    /// `retryFailedTasksTitleOnly` is
    /// mid-flight (= the button flips to
    /// "重新调研中…" and disables the
    /// progress strip's bottom buttons).
    @State var isRetryingFailed: Bool = false

    /// The cancel-button action (= Apple HIG canonical:
    /// closing the sheet means the user is done with the
    /// UI surface; = the per-file state machine goes
    /// with the sheet; = boss's 2026-10-09 directive
    /// "取消退出时，所有已经导入的内容回退清掉" =
    /// if a batch is mid-flight when the user clicks
    /// The cancel button's action (= the boss's
    /// 2026-10-09 follow-up "那你要在取消的时候弹一个
    /// 拦截弹窗，用户确认才取消，不然 ESC 容易误触";
    /// = the cancel button (= and ESC / Cmd+W / toolbar
    /// X / click-outside) all flip
    /// `confirmCancelPresented`; = the
    /// `confirmationDialog` modifier presents the
    /// 拦截弹窗 immediately; = the user picks
    /// "确认取消" (= the rollback runs) or "返回" (=
    /// the sheet stays open + the import keeps
    /// running). The "确认取消" branch in the
    /// `confirmationDialog` body is the single source
    /// of truth for the cancel-and-rollback path.
    func showCancelConfirmation() {
        // The cancel-confirmation dialog is only meaningful while an import is mid-flight
        // (= the boss's 2026-10-09 follow-up "那你要 在取消的时候弹一个拦截弹窗"; = an empty
        // sheet's "取消" click = no partial batch to confirm = the dialog would
        // feel like a roadblock for a no-op dismiss). Two paths: -
        // `isImporting == true` (= the click arrives after 开始导入; = the partial
        // batch is on disk; = the dialog is the boss's "确认取消 / 返回" UX). -
        // `isImporting == false` (= the click arrives before the user ever
        // clicked 开始导入; = no batch to confirm; = the dismiss is
        // unconditional).
        if isImporting {
            confirmCancelPresented = true
        } else {
            // Pre-run state: just close the sheet. The dialog would be a roadblock with
            // nothing to roll back (= the `ImportService.rollback` path is
            // a no-op when `writtenURLs` is empty + `entitiesJSONSnapshot`
            // is the empty sentinel; = the dialog adds friction with no
            // upside).
            isPresented = false
        }
    }

    /// The ProgressView's caption row (= derived from
    /// the live per-task state counts; = updates
    /// automatically as `tasks` mutates). Shows the
    /// in-flight count (= the boss's 2026-10-09
    /// "进度条还是不会跟着走" feedback; = the
    /// `inFlightCount` ("进行中 N") is what makes
    /// the row feel alive while the 5-way parallel
    /// LLM dispatch is mid-flight).
    ///
    /// The "跳过 N" segment is CONDITIONAL (= the
    /// boss's 2026-10-09 round-15 feedback "跳过是
    /// 最后一个动作，这个过程中永远都会显示零，
    /// 没有意义"; = `skipped` is the terminal
    /// state for a cache-hit dedup (= the file was
    /// already imported in a previous batch); = the
    /// skip only happens in Phase 2 dedup; = the
    /// 5-way parallel Phase 3 dispatch never
    /// produces skips; = the running caption row
    /// always shows "跳过 0" which is noise; = the
    /// segment only renders when at least one skip
    /// has happened; = the row stays 3-segment
    /// during the import run + 4-segment on a
    /// re-import).
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
            // 完成 · 跳过 · 失败 · 进行中 = the canonical Apple HIG progress
            // annotation pattern; = no surprise when the user re-imports
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
            // level folder (= no default; = the boss's "让用户 决定哪 些是 世界观 ，哪
            // 些是 角色" requirement; = the user explicitly chooses
            // world/characters /etc.; = the LLM is reduced to metadata
            // extraction only).
            return selectedBookFolder != nil
        }
    }

    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// directive). The
    /// NSOpenPanel now
    /// allows BOTH file
    /// and directory
    /// selection (= the
    /// user can pick a
    /// single .md file
    /// OR a directory
    /// of .md files;
    /// = `canChooseFiles
    /// = true` +
    /// `canChooseDirectories
    /// = true`); the
    /// open panel's UI
    /// shows a toggle
    /// between "files"
    /// and "folders"
    /// (= the standard
    /// macOS file
    /// picker; = the
    /// user picks
    /// whichever the
    /// workflow
    /// requires).
    /// The `allowsMultiple
    /// Selection` flag
    /// stays false (= a
    /// single pick; = if
    /// the user wants
    /// multiple files,
    /// they pick a
    /// directory).
    func pickSourceDirectory() {
        let panel = NSOpenPanel()
        // both files and directories are selectable. `canChooseFiles` +
        // `canChooseDirectories` both = true makes the system open panel show
        // a toggle between "files" and "folders" mode.
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        // filter to the selected file type's extension (= the open panel shows .md files
        // when the user picks Markdown; = the user can't accidentally pick a
        // .pdf when they meant to import .md). UTType is Apple canonical (= a
        // `UTType` array = the `allowedContentTypes` parameter on NSOpenPanel;
        // = the system
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
    func startImport() {
        guard let source = sourceDirectory else { return }
        // (= boss 2026-10-09 round-18 "强制让用户分开导 入" directive). The `canStart` gate
        // already validated the picker state (= book is selected when
        // destination = .book; = no book is required when destination =
        // .referenceLibrary).
        let target: ImportTarget
        switch importDestination {
        case .referenceLibrary:
            target = ImportTarget(
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
                return
            }
            // the user-picked 2nd-level folder is passed through to `ImportTarget`; = the
            // orchestrator forces the destination to that folder
            // (overriding the LLM's pick).
            target = ImportTarget(
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
        isImporting = true
        completedCount = 0
        Task {
            // The closure is `@Sendable` (= ImportService's signature) and runs on the
            // orchestrator's actor; = hop to @MainActor before mutating
            // @State so SwiftUI sees the updates on the right isolation
            // domain.
            let onProgress: @Sendable ([ImportTask]) async -> Void = { snapshot in
                await MainActor.run {
                    tasks = snapshot
                    totalCount = snapshot.count
                    // The ProgressView's bar value counts terminal states (= the done
                    // counter); = the `currentValueLabel` row
                    // shows the per-state breakdown so the user
                    // sees live activity from the in-flight count
                    // too (= the user's 2026-10-09 feedback
                    // "进度条还是不会跟着走，还在憋 大招，最后给一个 100%"; = the done
                    // counter ticks one row at a time as the 5-way
                    // parallel LLM dispatch finishes, = the bar
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
                // canonical sidebar host) re-reads the on-disk library
                // state (= the existing SidebarService.reload() path;
                // = same pattern the create / rename / delete sheets
                // use today). The user's 2026-10-09 feedback:
                // "点取消返回后，目录 树没有刷新".
                NotificationCenter.default.post(name: .wenshuLibraryDidChange, object: nil)
            }
        }
    }

    // (= boss 2026-10-09 (see OOB.md #2026-10-09) 研" directive). The "重新调研所有失败" button
    // handler. Reuses the same `ImportTarget` and `router` as the original
    // `startImport`; the difference is the orchestrator's
    // `retryFailedTasksTitleOnly` method bypasses the disk read (= the source
    // files failed `String(contentsOfFile:)`; = the orchestrator synthesizes a
    // body from the filename + sibling .md names in the same folder).
    func retryFailedTitleOnly() {
        guard !isRetryingFailed else { return }
        // The retry path doesn't need the source directory URL (= each task already
        // carries its absolute `sourcePath`; = the orchestrator synthesizes
        // the body from the filename + sibling .md names walked from the same
        // parent dir). Reuse the same `ImportTarget` shape as `startImport` (=
        // the user pinned destination in the sheet is the same for retry).
        let target: ImportTarget
        switch importDestination {
        case .referenceLibrary:
            target = ImportTarget(
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
                return
            }
            target = ImportTarget(
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
                    // counter is suppressed for the duration of
                    // the retry (= the retry's in-flight .routing
                    // tasks are not visible to the user as "进行中";
                    // = the user just sees the completedCount
                    // ticking up; = the progress bar moves by
                    // completedCount alone; = the boss's intent is
                    // "retry is a different mode from the import;
                    // = don't conflate the two activity
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

    /// Walk the shelves to find the shelf that owns
    /// this book (= the orchestrator's ImportTarget
    /// carries both shelfId and bookId).
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
// (= the cross-file `extension ImportSheet { ... }` with the
// 4-step wizard helpers = 4 step views + 6 control methods
// moved out of the main file. The `fileprivate` qualifier was
// relaxed to `var`/`func` = internal; = the 13 `@State private var`
// + 3 `@Environment(...) private var` + 1 `@AppStorage(...) private var`
// + 17 `    private ` were relaxed to internal; = required for
// the cross-file extension access.)
