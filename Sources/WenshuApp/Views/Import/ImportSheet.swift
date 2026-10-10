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

    /// v2.7 round-44 (= boss 2026-10-10
    /// "我觉的这个流程需要
    /// 重构一下 我感觉
    /// 现在在这同一个弹窗
    /// 里跑所有步骤，按钮
    /// 等 判断会变复杂
    /// 我想改成引导式多步
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
    @State private var currentStep: WizardStep = .configure

    /// Bumped when the `wenshuImportRequested`
    /// notification fires (= the File menu's 导入…
    /// shortcut). The parent flips this to dismiss.
    @Binding var isPresented: Bool

    /// v2.7 pre-fill parameters (= the boss's
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
        // v2.7 boss 2026-10-09 round-22 "右键
        // 十二地仙... 目标书籍没有自动选
        // 定十二地仙" (= `.onAppear` only
        // fires once per sheet instance; =
        // re-opening via contextMenu after a
        // File-menu first-open left the
        // prefill stale; = the fix is to
        // initialize the @State values in
        // the init (= SwiftUI's
        // `_State(wrappedValue:)` initializer
        // accepts an `initialValue`; = the
        // value is set when the sheet is
        // constructed; = every contextMenu
        // click that calls `showImportSheet =
        // true` rebuilds the sheet (= the
        // @State is initialized fresh on
        // each construction); = the
        // prefill is honored on EVERY
        // presentation)).
        if let d = prefillDestination {
            self._importDestination = State(initialValue: d)
        }
        if let id = prefillBookID {
            self._selectedBookID = State(initialValue: id)
        }
    }

    @Environment(BookStore.self) private var bookStore

    /// Picked source directory on disk (= the user's
    /// existing markdown library; = the orchestrator
    /// walks this directory recursively for .md files).
    @State private var sourceDirectory: URL?

    /// Selected target book id (= the user picks
    /// which book the .md files should land in). Nil
    /// when `importDestination == .referenceLibrary`
    /// (= the user pinned the reference library as
    /// the target; = no book is involved).
    @State private var selectedBookID: UUID?

    /// v2.7 round-66 commit C (= boss
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
    @State private var selectedBookFolder: BookFolder?

    /// v2.7 user-pinned import destination (= boss
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
    @State private var importDestination: ImportDestination = .book

    /// v2.7 (= boss 2026-10-09 round-18 "AI
    /// 重写程度"). The user picks ONCE at sheet
    /// open; = the LLM's tool set + the
    /// orchestrator's write path both
    /// respect this; = default = `consolidate`
    /// (= Token 节约; = original body
    /// verbatim).
    @State private var rewriteMode: ImportFileInput.RewriteMode = .consolidate

    /// Per-file task state (= the orchestrator's
    /// `ImportTask` model; = the progress strip
    /// shows one row per file).
    @State private var tasks: [ImportTask] = []

    /// v2.7 round-42 (= boss 2026-10-10
    /// "多数用户的 LLM 并发不能
    /// 太高，所以同时处理 5
    /// 个文件有可能会撞限流
    /// ，要不慢一点就慢一点，
    /// 加一个同时处理文件数
    /// 量。1 2 3 4 5，给五
    /// 个选择。默认选3"
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
    @State private var maxParallel: Int = 3

    /// Flipped while a batch is importing. Disables
    /// the pickers + the action button.
    @State private var isImporting: Bool = false

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
    @State private var fileType: ImportFileType = .markdown

    /// Counters surfaced to the sheet's ProgressView
    /// (= the orchestrator emits per-file state
    /// transitions through `onProgress`; = the
    /// sheet's view derives a single `progress`
    /// fraction from the completed-state count).
    @State private var completedCount: Int = 0
    @State private var totalCount: Int = 0

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
    @State private var inFlightCount: Int = 0

    /// True after the orchestrator finishes at least
    /// one batch (= the action button changes from
    /// "开始导入" to "重试" / "再次导入" so the user
    /// can re-run on the same directory; = the user
    /// explicitly picked this UX in the 2026-10-09
    /// round of feedback where they said "部分导入
    /// 成功后，按钮还是开始导入，不是重试").
    @State private var hasRunOnce: Bool = false

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
    @State private var confirmCancelPresented: Bool = false

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
            // v2.7 round-46 (= boss 2026-10-10
            // "截图红框的大标题
            // 不需要. 用户点
            // 导入进来的，知道
            // 这个弹窗就是导入
            // ，不需要标题"
            // directive). The
            // "导入 Markdown 文件"
            // title is REMOVED
            // (= redundant; = the
            // user just clicked
            // 导入 from the File
            // menu OR the
            // sidebar contextMenu;
            // = the wizard's
            // top-of-sheet title
            // is dead weight; =
            // the Pages inspector
            // has no such title
            // either; = removing
            // it gives the dot
            // indicator + the
            // first picker card
            // more vertical
            // breathing room).

            // v2.7 round-44 (= boss 2026-10-10
            // "引导式多步骤交互"
            // directive). The 4-step
            // dot indicator at the top of
            // the sheet (= canonical
            // Apple HIG macOS 14+
            // multi-step pattern; = the
            // user can see which step
            // they're on + how many
            // remain; = the dots are
            // also clickable to jump
            // back; = this replaces the
            // old single-page Form).
            //
            // v2.7 round-47 (= boss
            // 2026-10-10 "dot 如果没
            // 有进到下一步，dot
            // 就不能跳到下一
            // 步骤" directive).
            // The dot jumps are
            // GATED on
            // `canReachStep(step)`;
            // = the user can
            // only click a dot
            // for a step they
            // have already
            // reached; = a
            // fresh sheet on
            // ① 选目标 only
            // has ① clickable;
            // = ②③④ are
            // dimmed and
            // disabled; = the
            // user MUST walk
            // through the
            // wizard linearly.
            WizardStepIndicator(
                currentStep: $currentStep,
                canReach: canReachStep
            )
                .padding(.bottom, DesignTokens.spacingTight)

            // The per-step content. Each step
            // is a focused view (= no
            // conditional button rows hidden
            // inside; = the state machine is
            // linear; = the per-step view
            // contains exactly the widgets
            // for that step).
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

            // v2.7 round-44: the bottom
            // nav bar (= the canonical
            // Apple HIG macOS 14+
            // wizard pattern; = "上
            // 一步" on the left +
            // primary action on the
            // right; = the primary
            // action's label varies
            // with the current step;
            // = "开始" / "下一步" /
            // "完成").
            // v2.7 round-52 (= boss
            // 2026-10-10 "我画的
            // 红线处, 缺一条
            // 分割先. 让操作
            // 区和设定区分
            // 开" directive).
            // A hairline
            // Divider between
            // the per-step
            // content (= 设定
            // 区) and the nav
            // bar (= 操作
            // 区). The Divider
            // is on every
            // step (= the
            // boss's "演示
            // 要每一步骤
            // 的页面都
            // 一样"
            // directive from
            // round-50).
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
        // v2.7 round-44: auto-advance from
        // .running to .results once the
        // import finishes (= the user
        // doesn't have to tap "下一步"
        // to see the results; = the
        // orchestrator's `isImporting`
        // flag flips to false when the
        // import completes; = the
        // `isRunComplete` derived state
        // becomes true; = the
        // `.onChange` modifier below
        // advances the wizard to
        // .results automatically). The
        // transition is guarded on
        // `currentStep == .running` so
        // the user can still manually
        // re-navigate to .running (e.g.
        // to re-watch the per-file
        // strip) without being yanked
        // back to .results on every
        // state flip.
        .onChange(of: isRunComplete) { newValue in
            if newValue && currentStep == .running {
                currentStep = .results
            }
        }
        // for the cancel-and-rollback path.
        .interactiveDismissDisabled(isImporting)
        .padding(DesignTokens.spacingSection)
        // v2.7 prefill on first appear (= the
        // boss's 2026-10-09 round-18 "右键点
        // 资料库，点导入，进到弹窗后，目标
        // 自动选好资料库。右键点书的时候
        // 目标自动选好对应的书" directive; =
        // when the user right-clicks the
        // reference library, the sheet opens
        // with `prefillDestination = .referenceLibrary`;
        // = when the user right-clicks a book,
        // the sheet opens with
        // `prefillDestination = .book` +
        // `prefillBookID = book.id`).
        .onAppear {
            if let d = prefillDestination {
                importDestination = d
            }
            if let id = prefillBookID {
                selectedBookID = id
            }
        }
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
        // The boss's 2026-10-09 follow-up: "那你要
        // 在取消的时候弹一个拦截弹窗，用户确认才
        // 取消，不然 ESC 容易误触". The dismiss
        // path (ESC + Cmd+W + the toolbar X button +
        // clicking outside the sheet) fires SwiftUI's
        // `.onDisappear`; = we DO NOT auto-rollback
        // here (= that was the previous version; =
        // the user was right that ESC can be a
        // reflexive muscle-memory press; = the
        // auto-rollback would nuke the partial batch
        // without confirmation). Instead, every
        // dismiss path (ESC / Cmd+W / toolbar close
        // / clicking outside) routes through the
        // `confirmCancelPresented` confirmation
        // dialog (= the user explicitly confirms
        // "yes, throw away the partial batch"; = the
        // dialog is an Apple HIG canonical
        // macOS 14+ `confirmationDialog` pattern; =
        // a "返回" option lets the user dismiss the
        // dialog and keep importing). If the user
        // clicks "返回" (= cancel the cancel), the
        // sheet stays open + the import keeps
        // running. If the user clicks "确认取消",
        // the orchestrator's cancel + rollback
        // fire (= the partial batch is gone, = the
        // sheet dismisses to the "no trace" state
        // the boss asked for).
        .onDisappear {
            // Intentionally no-op. The
            // `confirmCancelPresented` flow owns
            // the dismiss path (= the sheet's
            // parent binding flips to false ONLY
            // after the user confirms; = this hook
            // is the no-op tail of the dismiss
            // path so we don't double-rollback).
        }
        // The confirmation dialog (= the canonical
        // Apple HIG macOS 14+ `confirmationDialog`
        // pattern; = a popup the user can't miss; =
        // the dismiss is blocked until the user
        // explicitly picks an outcome). Apple
        // canonical: the dialog presents ONLY when
        // `confirmCancelPresented = true`; = the
        // `isPresented` binding reads the
        // user-pick (= a Bool return = "true" means
        // "yes, throw it all away").
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
                // No-op; = the user changed their
                // mind; = the sheet stays open + the
                // import keeps running; = the
                // `isPresented` binding already flipped
                // back to false by SwiftUI's
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
    private var actionButtonLabel: String {
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
    private var cancelButtonLabel: String {
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
    private var isRunComplete: Bool {
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
    private var hasFailures: Bool {
        tasks.contains { $0.state == .failed }
    }

    // v2.7 round-36 (= boss 2026-10-09 "在红字
    // 后面，加一个小操作文字，就是基
    // 于标题重新调研" directive). The
    // "重新调研所有失败" button is only
    // visible when at least one task failed
    // because the file was unreadable on
    // disk (= `errorMessage` starts with
    // "读取文件失败"). LLM-routing failures
    // and write failures are NOT retried by
    // this button (= those are bugs in the
    // pipeline config, not file problems;
    // = the user re-imports the whole batch
    // if the LLM is misconfigured).
    private var failedReadFileCount: Int {
        tasks.filter {
            $0.state == .failed
                && ($0.errorMessage?.hasPrefix("读取文件失败") ?? false)
        }.count
    }
    private var canRetryFailedTitleOnly: Bool {
        failedReadFileCount > 0 && !isImporting && !isRetryingFailed
            && isRunComplete
    }
    /// v2.7 round-36 (= boss 2026-10-09 "在
    /// 红字后面" directive). True while
    /// `retryFailedTasksTitleOnly` is
    /// mid-flight (= the button flips to
    /// "重新调研中…" and disables the
    /// progress strip's bottom buttons).
    @State private var isRetryingFailed: Bool = false

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
    private func showCancelConfirmation() {
        // The cancel-confirmation dialog is only
        // meaningful while an import is mid-flight
        // (= the boss's 2026-10-09 follow-up "那你要
        // 在取消的时候弹一个拦截弹窗"; = an empty
        // sheet's "取消" click = no partial batch to
        // confirm = the dialog would feel like a
        // roadblock for a no-op dismiss). Two paths:
        // - `isImporting == true` (= the click
        //   arrives after 开始导入; = the partial
        //   batch is on disk; = the dialog is the
        //   boss's "确认取消 / 返回" UX).
        // - `isImporting == false` (= the click
        //   arrives before the user ever clicked
        //   开始导入; = no batch to confirm; = the
        //   dismiss is unconditional).
        if isImporting {
            confirmCancelPresented = true
        } else {
            // Pre-run state: just close the sheet.
            // The dialog would be a roadblock with
            // nothing to roll back (= the
            // `ImportService.rollback` path is a
            // no-op when `writtenURLs` is empty +
            // `entitiesJSONSnapshot` is the empty
            // sentinel; = the dialog adds friction
            // with no upside).
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
    private var progressLabel: String {
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
            // Insert "跳过 N" between 完成 and 失败
            // (= matches the pre-fix segment order; =
            // = 完成 · 跳过 · 失败 · 进行中 = the
            // canonical Apple HIG progress
            // annotation pattern; = no surprise
            // when the user re-imports and sees
            // the skip count appear).
            parts.insert("跳过 \(skipped)", at: 1)
        }
        return parts.joined(separator: " · ")
    }

    private var canStart: Bool {
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
            // v2.7 round-66 commit C (= boss
            // 2026-10-10 "用
            // 户来
            // 决定"
            // directive).
            // The user must
            // also pick a
            // 2nd-level
            // folder (= no
            // default; =
            // the boss's
            // "让用户
            // 决定哪
            // 些是
            // 世界观
            // ，哪
            // 些是
            // 角色"
            // requirement;
            // = the user
            // explicitly
            // chooses
            // world/characters
            // /etc.; = the
            // LLM is
            // reduced to
            // metadata
            // extraction
            // only).
            return selectedBookFolder != nil
        }
    }

    /// v2.7 round-57 (= boss 2026-10-10
    /// "现在有个问题, 我
    /// 们只能选目录, 而
    /// 不能选择单文件"
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
    private func pickSourceDirectory() {
        let panel = NSOpenPanel()
        // v2.7 round-57: both
        // files and
        // directories
        // are selectable.
        // `canChooseFiles`
        // + `canChooseDirectories`
        // both = true
        // makes the
        // system open
        // panel show a
        // toggle between
        // "files" and
        // "folders" mode.
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        // v2.7 round-57: filter
        // to the selected
        // file type's
        // extension (= the
        // open panel
        // shows .md files
        // when the user
        // picks Markdown;
        // = the user
        // can't accidentally
        // pick a .pdf
        // when they meant
        // to import .md).
        // UTType is
        // Apple canonical
        // (= a
        // `UTType` array
        // = the
        // `allowedContentTypes`
        // parameter on
        // NSOpenPanel;
        // = the system
                // file picker
                // uses it to
                // filter the
                // list of
                // selectable
                // files).
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
    private func startImport() {
        guard let source = sourceDirectory else { return }
        // v2.7 user-pinned destination (= boss
        // 2026-10-09 round-18 "强制让用户分开导
        // 入" directive). The `canStart` gate
        // already validated the picker state
        // (= book is selected when destination =
        // .book; = no book is required when
        // destination = .referenceLibrary).
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
            // v2.7 round-66 commit C: the
            // user-picked
            // 2nd-level
            // folder is
            // passed
            // through to
            // `ImportTarget`;
            // = the
            // orchestrator
            // forces the
            // destination
            // to that
            // folder
            // (overriding
            // the LLM's
            // pick).
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
            // The closure is `@Sendable` (=
            // ImportService's signature) and runs on the
            // orchestrator's actor; = hop to @MainActor
            // before mutating @State so SwiftUI sees the
            // updates on the right isolation domain.
            let onProgress: @Sendable ([ImportTask]) async -> Void = { snapshot in
                await MainActor.run {
                    tasks = snapshot
                    totalCount = snapshot.count
                    // The ProgressView's bar value
                    // counts terminal states (= the
                    // done counter); = the
                    // `currentValueLabel` row shows
                    // the per-state breakdown so the
                    // user sees live activity from
                    // the in-flight count too (= the
                    // user's 2026-10-09 feedback
                    // "进度条还是不会跟着走，还在憋
                    // 大招，最后给一个 100%"; = the
                    // done counter ticks one row at
                    // a time as the 5-way parallel
                    // LLM dispatch finishes, = the
                    // bar visibly moves).
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

    // v2.7 round-36 (= boss 2026-10-09 "在
    // 红字后面，加一个小操作文
    // 字，就是基于标题重新调
    // 研" directive). The
    // "重新调研所有失败" button
    // handler. Reuses the same
    // `ImportTarget` and `router` as
    // the original `startImport`; the
    // difference is the orchestrator's
    // `retryFailedTasksTitleOnly`
    // method bypasses the disk read
    // (= the source files failed
    // `String(contentsOfFile:)`; = the
    // orchestrator synthesizes a body
    // from the filename + sibling
    // .md names in the same folder).
    private func retryFailedTitleOnly() {
        guard !isRetryingFailed else { return }
        // The retry path doesn't need the
        // source directory URL (= each
        // task already carries its absolute
        // `sourcePath`; = the orchestrator
        // synthesizes the body from the
        // filename + sibling .md names
        // walked from the same parent dir).
        // Reuse the same `ImportTarget` shape
        // as `startImport` (= the user
        // pinned destination in the sheet
        // is the same for retry).
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
                    // v2.7 round-43 (= boss
                    // 2026-10-10 "补充，
                    // 重新调研时，进行
                    // 中，不统计"
                    // directive). The
                    // "进行中 N" counter
                    // is suppressed for
                    // the duration of the
                    // retry (= the retry's
                    // in-flight .routing
                    // tasks are not
                    // visible to the user
                    // as "进行中"; = the
                    // user just sees the
                    // completedCount
                    // ticking up; = the
                    // progress bar moves
                    // by completedCount
                    // alone; = the boss's
                    // intent is "retry is
                    // a different mode
                    // from the import;
                    // = don't conflate
                    // the two activity
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

// MARK: - 4-step wizard helpers

extension ImportSheet {
    /// v2.7 round-47 (= boss 2026-10-10
    /// "dot 如果没有进
    /// 到下一步，dot
    /// 就不能跳到下一
    /// 步骤" directive).
    /// The reachability
    /// predicate for the
    /// dot indicator. The
    /// user can only click
    /// a dot for a step
    /// they have already
    /// reached (= a fresh
    /// sheet on ① 选目
    /// 标 only has ①
    /// clickable; = ②③④
    /// are dimmed AND
    /// disabled). The
    /// reachability
    /// contract:
    /// - `.configure`
    ///   always reachable
    ///   (= the initial
    ///   step).
    /// - `.running`
    ///   reachable when
    ///   the user has
    ///   pressed 开始 (=
    ///   `hasRunOnce`).
    /// - `.results`
    ///   reachable when
    ///   the import has
    ///   finished (= the
    ///   orchestrator's
    ///   `isRunComplete`
    ///   flag is true) OR
    ///   the user has
    ///   already
    ///   navigated past
    ///   it (= currentStep
    ///   ≥ .results).
    /// - `.done`
    ///   reachable only
    ///   after the user
    ///   has tapped 完成
    ///   on the .results
    ///   step (= currentStep
    ///   == .done OR
    ///   currentStep has
    ///   been past it).
    fileprivate func canReachStep(_ step: WizardStep) -> Bool {
        switch step {
        case .configure:
            return true
        case .running:
            return hasRunOnce || currentStep.rawValue >= WizardStep.running.rawValue
        case .results:
            return isRunComplete || currentStep.rawValue >= WizardStep.results.rawValue
        case .done:
            return currentStep.rawValue >= WizardStep.done.rawValue
        }
    }

    /// True if the user can go back one step (= not on
    /// the first step; = never go back from .running
    /// because the import is mid-flight; = the boss's
    /// "上一步" button is enabled on every step EXCEPT
    /// the first (.configure); = on the first step
    /// the button is HIDDEN entirely per the
    /// boss's round-48 "第一步的页面, 不应该有
    /// 上一步" directive).
    fileprivate var canGoPrev: Bool {
        currentStep != .configure
    }

    /// True if the user can advance to the next step.
    /// The rules (= the boss's "不点 '开始导入' 不能
    /// 进步骤 2" answer):
    /// - .configure → .running iff `canStart` (= the
    ///   user has filled the required fields).
    /// - .running → .results iff `isRunComplete` (=
    ///   the orchestrator has finished; = the user
    ///   can review the results).
    /// - .results → .done always (= just a "next" tap
    ///   to dismiss the per-file list).
    /// - .done: ALWAYS reachable (= the
    ///   boss's round-51 "完成不用判
    ///   断任何, 就直接能点就可以"
    ///   directive; = even if there
    ///   are failures (= 21 failed
    ///   + 14 skipped = the user has
    ///   acknowledged the failures
    ///   and wants to close the
    ///   sheet; = the button is a
    ///   "dismiss" not a "validate
    ///   success"; = gating the
    ///   dismiss button on
    ///   `hasFailures == false`
    ///   forces the user to do an
    ///   extra step to dismiss the
    ///   sheet even though the
    ///   import is done and the
    ///   user has accepted the
    ///   outcome; = the gate is
    ///   unnecessary friction).
    fileprivate var canGoNext: Bool {
        switch currentStep {
        case .configure:
            return canStart && !isImporting
        case .running:
            return isRunComplete
        case .results:
            return true
        case .done:
            return true
        }
    }

    /// The primary action button's label (= the
    /// right side of the nav bar). Apple HIG
    /// canonical: a single label that reflects what
    /// tapping it WILL do (= "开始" → start the
    /// import; = "下一步" → advance; = "完成" →
    /// dismiss the sheet).
    fileprivate var primaryActionLabel: String {
        switch currentStep {
        case .configure: return "开始"
        case .running:   return "下一步"
        case .results:   return "完成"
        case .done:      return "完成"
        }
    }

    /// The previous-step action (= Apple HIG
    /// canonical: a simple "上一步" label; = the
    /// button is disabled when `canGoPrev` is
    /// false; = never go back from .running).
    fileprivate func goPrev() {
        guard canGoPrev else { return }
        switch currentStep {
        case .configure: break
        case .running:   currentStep = .configure
        case .results:   currentStep = .running
        case .done:      currentStep = .results
        }
    }

    /// The next-step action. Apple HIG canonical:
    /// tapping the primary action advances the
    /// wizard. Side effects per step:
    /// - .configure → .running: starts the import
    ///   (= `startImport()` kicks off the
    ///   orchestrator; = the user lands on
    ///   .running + the progress view animates).
    /// - .running → .results: no-op (the auto-
    ///   advance via .onChange of isRunComplete
    ///   already fired; = this path is the user
    ///   manually tapping "下一步" while still
    ///   on .running; = advancing is idempotent).
    /// - .results → .done: no-op (the .done view
    ///   presents a summary).
    /// - .done: dismiss the sheet (= the boss's
    ///   terminal state).
    fileprivate func goNext() {
        guard canGoNext else { return }
        switch currentStep {
        case .configure:
            // "开始" button. Triggers the import
            // + advances the wizard. The
            // orchestrator's `importFiles` runs
            // asynchronously (= the user lands
            // on .running; = the progress view
            // animates as the orchestrator emits
            // `onProgress` ticks).
            startImport()
            currentStep = .running
        case .running:
            // "下一步" while on .running. The
            // user can manually advance once
            // `isRunComplete` flips (= the
            // orchestrator has finished; = the
            // user might be reviewing the
            // progress while waiting for the
            // next onProgress tick).
            currentStep = .results
        case .results:
            // "完成" button. Advance to .done
            // (= the summary view).
            currentStep = .done
        case .done:
            // Terminal state. The "完成"
            // button dismisses the sheet.
            isPresented = false
        }
    }

    // MARK: - Per-step views

    /// Step 1: 选目标. The macOS 27 list
    /// row pattern (= 32 PT row
    /// height; = no card background
    /// fill; = the boss's round-49
    /// "每一行的背景矩形不需要"
    /// directive; = the row is
    /// just text + control; =
    /// sections separated by a
    /// hairline Divider).
    @ViewBuilder
    fileprivate var step1ConfigureView: some View {
        VStack(alignment: .leading, spacing: 0) {
            PickerRow {
                Text("文件类型")
                    .foregroundStyle(.primary)
            } trailing: {
                Picker("", selection: $fileType) {
                    ForEach(ImportFileType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(isImporting)
            }

            PickerRow {
                Text("源目录")
                    .foregroundStyle(.primary)
            } trailing: {
                HStack(spacing: DesignTokens.spacingStandard) {
                    if let url = sourceDirectory {
                        Text(url.path)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(url.path)
                            .textSelection(.enabled)
                    } else {
                        Text(fileType.placeholderHint)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            // v2.7 round-55 (= boss
                            // 2026-10-10 "提示文
                            // 案显示不全"
                            // directive). The
                            // previous
                            // implementation
                            // truncated the
                            // placeholder
                            // with the
                            // default
                            // truncation
                            // mode (= tail)
                            // which cut
                            // off the
                            // meaningful
                            // portion of
                            // the hint (=
                            // "选择一个包
                            // 含 .md 文"
                            // = the user
                            // couldn't see
                            // the file
                            // extension at
                            // the end; =
                            // the most
                            // important
                            // part of the
                            // hint was
                            // missing).
                            // Fix: middle
                            // truncation
                            // (= the same
                            // pattern the
                            // path uses
                            // above; = the
                            // middle of
                            // the hint is
                            // omitted and
                            // the file
                            // extension
                            // stays
                            // visible at
                            // the end; =
                            // "选择...含
                            // .md 文件
                            // 的目录" =
                            // the user
                            // reads the
                            // hint as
                            // "choose a
                            // directory
                            // containing
                            // .md files").
                            .truncationMode(.middle)
                            // v2.7 round-55:
                            // the Text
                            // needs to
                            // fill the
                            // available
                            // horizontal
                            // space (= the
                            // HStack
                            // contains a
                            // fixed-size
                            // button on
                            // the right;
                            // = the Text
                            // gets the
                            // rest; =
                            // without
                            // maxWidth the
                            // Text would
                            // shrink-to-
                            // fit and the
                            // truncation
                            // would kick
                            // in even
                            // when the
                            // full hint
                            // could fit
                            // = the
                            // shrink-
                            // fit is
                            // iOS-only;
                            // = on
                            // macOS the
                            // Text
                            // expands
                            // until the
                            // HStack
                            // overflows;
                            // = adding
                            // maxWidth
                            // makes the
                            // Text
                            // take the
                            // remaining
                            // space
                            // explicitly).
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .help(fileType.placeholderHint)
                    }
                    Button("选择…") { pickSourceDirectory() }
                        .disabled(isImporting)
                        .buttonStyle(.borderedProminent)
                        // v2.7 round-53 (= boss
                        // 2026-10-10 "选择按钮
                        // 的文字大小，和按
                        // 钮高度，与其它
                        // 按钮不同，需要
                        // 拉成同意大小"
                        // directive). REMOVED
                        // `.controlSize(.small)`
                        // (= the "选择…" button
                        // is now the default
                        // .controlSize(.regular)
                        // = 28 PT tall + the
                        // canonical Apple HIG
                        // macOS body text size;
                        // = the button height
                        // matches the segmented
                        // Picker (= "导入到
                        // 资料库" / "导入到
                        // 书") + the menu
                        // Pickers (= Markdown /
                        // 请选择书籍 / 基于
                        // 现有内容整理 / 3);
                        // = the visual rhythm
                        // across the trailing
                        // column is now
                        // uniform; = the user
                        // reads the row as
                        // "all controls are
                        // the same height").
                        // The previous
                        // `.small` (= 22 PT
                        // tall + smaller text)
                        // made "选择…" stand
                        // out as visually
                        // inconsistent with
                        // its row neighbors.
                }
            }

            // v2.7 round-49: Divider
            // between the file /
            // source section and
            // the destination
            // section (= the
            // boss's "用一条
            // 分割线分割"
            // directive; = the
            // previous
            // `PickerSectionLabel
            // ` + 24 PT gap is
            // replaced with a
            // single hairline
            // Divider; = the
            // small vertical
            // padding around
            // the Divider is
            // 8 PT (= `spacing
            // Standard`) =
            // enough for the
            // user to see the
            // Divider as a
            // deliberate
            // separator; =
            // matches the
            // wenshu v3.0
            // design system
            // Divider padding
            // convention).
            Divider()
                .padding(.vertical, DesignTokens.spacingStandard)

            PickerRow {
                Text("目标")
                    .foregroundStyle(.primary)
            } trailing: {
                Picker("目标", selection: $importDestination) {
                    ForEach(ImportDestination.allCases) { d in
                        Text(d.label).tag(d)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(isImporting)
                .fixedSize()
            }

            if importDestination == .book {
                PickerRow {
                    Text("目标书籍")
                        .foregroundStyle(.primary)
                } trailing: {
                    Picker("目标书籍", selection: $selectedBookID) {
                        Text("请选择书籍").tag(UUID?.none)
                        ForEach(bookStore.books) { book in
                            Text(book.title).tag(Optional(book.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .disabled(isImporting)
                }
                // v2.7 round-66 commit C (= boss
                // 2026-10-10 "用
                // 户在
                // 导入
                // 书的
                // 时候，
                // 要选
                // 择二
                // 级目
                // 录
                // ... 资料
                // 库不用"
                // 反馈).
                // The 2nd-level
                // folder Picker
                // (= the
                // "目标目录"
                // row). Only
                // shown when
                // `importDestination
                // == .book` AND
                // a book is
                // selected (=
                // the Picker
                // needs a
                // bookId
                // context to
                // resolve the
                // folder's
                // path; = the
                // user can't
                // pick a
                // folder before
                // picking a
                // book). Uses
                // the same
                // `Picker`
                // + `PickerRow`
                // pattern as
                // the 目标书籍
                // row above (=
                // consistent
                // visual
                // treatment;
                // = the
                // segmented
                // style is NOT
                // used here
                // because the
                // 6 options are
                // too long to
                // fit; = the
                // menu style
                // shows a
                // compact
                // dropdown).
                // v2.7 round-66 commit C+1 (= boss
                // 2026-10-10 "这
                // 个选择
                // 目录
                // 的，
                // 不用
                // 选书
                // 后
                // 再
                // 显
                // 示，
                // 就
                // 长
                // 显
                // 就
                // 可
                // 以
                // 了"
                // feedback).
                // The 2nd-level
                // folder
                // Picker is
                // now ALWAYS
                // shown when
                // `importDestination
                // == .book` (=
                // no
                // conditional
                // on
                // `selectedBookID
                // != nil`;
                // = the user
                // sees the
                // folder
                // picker
                // immediately
                // when they
                // pick
                // "导入到书";
                // = the Picker
                // is disabled
                // (greyed out)
                // until a
                // book is
                // selected
                // for the
                // Picker to
                // make sense
                // visually;
                // = but the
                // row itself is
                // always
                // there so
                // the user
                // doesn't
                // see the
                // layout
                // jump when
                // they pick
                // a book).
                // The same row
                // format as
                // 目标书籍 (=
                // PickerRow +
                // .menu
                // picker;
                // = visually
                // consistent).
                PickerRow {
                    Text("目标目录")
                        .foregroundStyle(.primary)
                } trailing: {
                    Picker("目标目录", selection: $selectedBookFolder) {
                        Text("请选择目录").tag(BookFolder?.none)
                        ForEach(BookFolder.allCases, id: \.self) { folder in
                            if folder.importTemplate != nil {
                                Text(folder.displayName).tag(Optional(folder))
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .disabled(isImporting || selectedBookID == nil)
                }
            }

            // v2.7 round-49: Divider
            // between the
            // destination
            // section and the AI
            // section.
            Divider()
                .padding(.vertical, DesignTokens.spacingStandard)

            PickerRow {
                Text("AI 重写程度")
                    .foregroundStyle(.primary)
            } trailing: {
                Picker("AI 重写程度", selection: $rewriteMode) {
                    ForEach(ImportFileInput.RewriteMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(isImporting)
            }

            PickerRow {
                Text("同时处理文件数")
                    .foregroundStyle(.primary)
            } trailing: {
                Picker("同时处理文件数", selection: $maxParallel) {
                    ForEach(1...5, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(isImporting)
            }
        }
    }

    /// Step 2: 进度. The progress
    /// bar + the per-file strip;
    /// = the two surfaces are
    /// separated by a hairline
    /// Divider (= matches the
    /// step 1 / step 3 pattern;
    /// = the boss's round-50
    /// "演示要每一步骤的页面
    /// 都一样, 不只改第一步"
    /// directive; = every step
    /// has the same
    /// dot-indicator / Divider /
    /// bottom-nav-bar chrome).
    @ViewBuilder
    fileprivate var step2RunningView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if totalCount > 0 {
                ProgressView(
                    value: Double(completedCount) + Double(inFlightCount) * 0.5,
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
            // v2.7 round-50:
            // Divider between
            // the progress
            // section and the
            // per-file list
            // (= the boss's
            // "演示要每一步
            // 骤的页面都一
            // 样" directive;
            // = every step
            // uses the same
            // "section
            // content +
            // Divider +
            // list"
            // pattern).
            Divider()
                .padding(.vertical, DesignTokens.spacingStandard)
            ImportProgressStrip(tasks: tasks)
                .frame(maxHeight: DesignTokens.kanbanBoardMaxHeight)
        }
    }

    /// Step 3: 结果. The per-file list
    /// (= the same strip as Step 2) +
    /// per-row "重试" buttons. No
    /// pickers, no progress bar (= the
    /// import already finished; = the
    /// user is now in review/retry
    /// mode).
    ///
    /// v2.7 round-50 (= boss 2026-10-10
    /// "步骤二的按钮换个
    /// 位置，挨着完成放
    /// 然后操作上面需要
    /// 也加一条分割线"
    /// directive). The
    /// "重新调研所有失败"
    /// total button
    /// moves from the
    /// top of the view
    /// (= the round-36
    /// position; = the
    /// user complained
    /// "挨着完成放" =
    /// the button
    /// should be next
    /// to the 完成
    /// button, not at
    /// the top of the
    /// list) to the
    /// BOTTOM of the
    /// view, right-
    /// aligned, with a
    /// hairline Divider
    /// above it (= the
    /// "操作上面需要也
    /// 加一条分割线"
    /// requirement; =
    /// the Divider
    /// separates the
    /// file list from
    /// the action
    /// surface; = the
    /// action sits in
    /// its own row,
    /// visually
    /// analogous to the
    /// "完成" button in
    /// the nav bar).
    @ViewBuilder
    fileprivate var step3ResultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The per-file list (= the
            // same strip as Step 2;
            // = per-row "重试" buttons
            // are inside the
            // ImportProgressStrip /
            // ImportTaskRow).
            ImportProgressStrip(tasks: tasks)
                .frame(maxHeight: DesignTokens.kanbanBoardMaxHeight)
            // v2.7 round-50: the
            // "重新调研所有失败"
            // button at the
            // BOTTOM of the
            // results view (= the
            // boss's "挨着完成
            // 放" directive;
            // = the button is
            // now visually
            // adjacent to the
            // nav bar's "完成"
            // button; = the
            // user reads the
            // two buttons as
            // "secondary action
            // + primary action"
            // = a standard
            // dialog pattern).
            // The button is only
            // visible when at
            // least one task
            // failed because
            // the file was
            // unreadable on
            // disk (= same
            // condition as
            // before; = the
            // boss's "不变"
            // answer to the
            // Q1 clarify).
            if canRetryFailedTitleOnly {
                // v2.7 round-50: hairline
                // Divider above
                // the action row
                // (= the "操作
                // 上面需要也加
                // 一条分割线"
                // requirement).
                Divider()
                HStack {
                    Spacer()
                    Button {
                        Task { await retryFailedTitleOnly() }
                    } label: {
                        if isRetryingFailed {
                            HStack(spacing: DesignTokens.spacingIconic) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("重新调研中…")
                            }
                        } else {
                            Text("重新调研所有失败 (\(failedReadFileCount) 个)")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(isRetryingFailed)
                }
                .padding(.top, DesignTokens.spacingStandard)
            }
        }
    }

    /// Step 4: 完成. The summary
    /// (= "完成 N, 跳过 M, 失败 K")
    /// + a "完成" button to dismiss
    /// the sheet. No pickers, no
    /// progress bar, no per-file
    /// list (= the user is
    /// already done with the
    /// import).
    ///
    /// v2.7 round-58 (= boss 2026-10-10
    /// "这个区域的文字没有
    /// 左对齐" directive).
    /// The previous
    /// implementation
    /// had
    /// `.padding(DesignTokens
    /// .spacingStandard)`
    /// (= 12 PT
    /// internal
    /// padding) on
    /// the VStack (= the
    /// summary text
    /// was inset 12 PT
    /// from the sheet's
    /// left edge; = the
    /// user perceived
    /// the text as
    /// "floating in the
    /// middle of the
    /// sheet" with a
    /// visible gap from
    /// the sheet's left
    /// edge). The fix:
    /// REMOVE the
    /// internal padding
    /// (= the text now
    /// starts at x = 0
    /// inside the
    /// VStack; = the
    /// VStack itself
    /// uses
    /// `alignment:
    /// .leading` + the
    /// `frame(maxWidth:
    /// .infinity,
    /// alignment:
    /// .leading)` to
    /// make the text
    /// flush with the
    /// sheet's left
    /// edge; = the
    /// summary text is
    /// now aligned with
    /// the dot indicator
    /// + the nav bar
    /// buttons on the
    /// other steps;
    /// = the visual
    /// alignment is
    /// consistent across
    /// all 4 steps).
    @ViewBuilder
    fileprivate var step4DoneView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
            let doneCount = tasks.filter { $0.state == .done }.count
            let skippedCount = tasks.filter { $0.state == .skipped }.count
            let failedCount = tasks.filter { $0.state == .failed }.count

            Text("导入完成")
                .font(.headline)
            HStack(spacing: DesignTokens.spacingLoose) {
                Label("\(doneCount) 完成", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if skippedCount > 0 {
                    Label("\(skippedCount) 跳过", systemImage: "arrow.uturn.forward.circle")
                        .foregroundStyle(.secondary)
                }
                if failedCount > 0 {
                    Label("\(failedCount) 失败", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.callout)
            Text("文件已写入资料库 / 目标书。点 '完成' 关闭弹窗。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        // v2.7 round-66 commit F (= boss
        // 2026-10-10 "故事宪法，没有
        // 重新分析是不是
        // 内容相同" 反馈).
        // The skip reason (= a
        // short explanation
        // for the user; =
        // "内容相同 (LLM
        // confidence 0.95):
        // 两段完全相同" or
        // "同 title retry skip"
        // from the title-only
        // path). Shown as a
        // secondary caption
        // below the state pill.
        if let reason = task.skippedReason {
            Text(reason)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var statePill: some View {
        switch task.state {
        case .pending:
            Text("待处理").font(.caption).foregroundStyle(.secondary)
        case .routing:
            // v2.7 round-66 commit G (= boss
            // 2026-10-10 "这
            // 个分析
            // 中三
            // 个字
            // 前面
            // ，需
            // 要加
            // 一个
            // 小小
            // 的动
            // 态
            // SF，
            // 循环
            // 播放
            // ，
            // 要
            // 不
            // 然
            // 这
            // 个
            // 界
            // 面
            // 像
            // 静
            // 止
            // 了" 反馈).
            // The
            // `ellipsis.circle.fill`
            // SF Symbol
            // (= three
            // dots in a
            // circle) +
            // the
            // `.variableColor`
            // effect (= the
            // dots
            // animate
            // through
            // colors
            // in a
            // loop) =
            // the
            // "wait / in
            // progress"
            // visual
            // affordance;
            // = the
            // user
            // sees
            // continuous
            // motion (= the
            // `SFIcon`
            // factory
            // exposes the
            // symbol via
            // the canonical
            // wenshu-icon-policy
            // pipeline; = the
            // `.symbolEffect`
            // is
            // attached
            // to the
            // underlying
            // Image; = SF
            // Symbols 6
            // variableColor
            // dots loop
            // forever at
            // ~1 Hz; = the
            // user
            // immediately
            // sees
            // "this is
            // still
            // running");
            // = without
            // this, the
            // previous
            // static
            // "分析中"
            // text felt
            // frozen (=
            // the boss's
            // "像
            // 静
            // 止
            // 了"
            // feedback).
            HStack(spacing: DesignTokens.spacingCaption) {
                SFIcon(
                    "ellipsis.circle.fill",
                    style: .toolbar,
                    color: Color.secondary,
                    rendering: .variableColor
                )
                Text("分析中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .writing:
            // v2.7 round-66 commit G:
            // same idea as
            // `routing` —
            // show a
            // spinning
            // icon to
            // signal
            // activity
            // (= the
            // user might
            // be confused
            // if the
            // state went
            // from
            // "分析中"
            // to
            // "写入中"
            // with no
            // visible
            // change).
            HStack(spacing: DesignTokens.spacingCaption) {
                SFIcon(
                    "arrow.down.circle.fill",
                    style: .toolbar,
                    color: Color.secondary,
                    rendering: .variableColor
                )
                Text("写入中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
            confidence: 1.0,
            rewrittenBody: nil
        )
    }
    // v2.7 round-66 commit F:
    // the stub's
    // isContentSame
    // is a
    // conservative
    // "always different"
    // default (= the
    // user always
    // sees a fresh
    // import in
    // stub mode;
    // = no false
    // skips in
    // the stub
    // path).
    func isContentSame(
        sourceBody: String,
        existingBody: String,
        sourceTitle: String
    ) async throws -> ContentSameResult {
        return ContentSameResult(
            isContentSame: false,
            confidence: 0.0,
            reasoning: "Stub router; 始终按不同内容处理。"
        )
    }
}

// MARK: - Wizard chrome (= step indicator + nav bar)

/// v2.7 round-44 (= boss 2026-10-10
/// "引导式多步骤交互" directive).
/// The 4-step dot indicator at the
/// top of the sheet. Apple HIG
/// canonical: a horizontal row of 4
/// dots + labels (= one per step; =
/// the current step is highlighted;
/// = completed steps show a
/// checkmark; = future steps are
/// dim). The dots are also
/// clickable to jump to that
/// step (= same UX as the Mail
/// composer / Pages onboarding;
/// = the boss's "混合: 顶部 dot
/// + 底部 '下一步' 按钮"
/// answer to the Q3 clarify).
private struct WizardStepIndicator: View {
    @Binding var currentStep: ImportSheet.WizardStep
    let canReach: (ImportSheet.WizardStep) -> Bool

    var body: some View {
        HStack(spacing: DesignTokens.spacingModerate) {
            ForEach(ImportSheet.WizardStep.allCases) { step in
                let reachable = canReach(step)
                Button {
                    // v2.7 round-47 (= boss
                    // 2026-10-10 "dot
                    // 如果没有进到下一
                    // 步，dot 就不能
                    // 跳到下一步骤
                    // 不能一进来什么
                    // 都没有，就可以
                    // 跳到完成去"
                    // directive). Only
                    // jump if the step
                    // is reachable
                    // (= the button is
                    // also .disabled
                    // below; = the
                    // guard is a
                    // defense-in-depth
                    // check). The
                    // round-44
                    // "可以跳到任意
                    // 步骤" behavior
                    // is the bug this
                    // commit fixes.
                    guard reachable else { return }
                    currentStep = step
                } label: {
                    VStack(spacing: DesignTokens.spacingCaption) {
                        Image(systemName: dotIcon(for: step))
                            .font(.title3)
                            .foregroundStyle(dotColor(for: step, reachable: reachable))
                        Text(step.label)
                            .font(.caption)
                            .foregroundStyle(dotColor(for: step, reachable: reachable))
                    }
                }
                .buttonStyle(.plain)
                .disabled(!reachable)
                if step.rawValue < ImportSheet.WizardStep.done.rawValue {
                    Rectangle()
                        .fill(connectorColor(for: step))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func dotIcon(for step: ImportSheet.WizardStep) -> String {
        if step == currentStep { return step.iconName }
        if step.rawValue < currentStep.rawValue { return "checkmark.circle.fill" }
        return "\(step.rawValue + 1).circle"
    }

    private func dotColor(for step: ImportSheet.WizardStep, reachable: Bool) -> Color {
        // v2.7 round-47: a step
        // that is NOT reachable
        // (= the user hasn't
        // reached it yet) is
        // dimmed more than a
        // step that is just
        // "future from the
        // current" (= .secondary
        // .opacity(0.4) = the
        // visual reads as
        // "disabled"; = the
        // user understands
        // "I can't click this
        // yet").
        if !reachable { return .secondary.opacity(0.4) }
        if step == currentStep { return .accentColor }
        if step.rawValue < currentStep.rawValue { return .green }
        return .secondary
    }

    private func connectorColor(for step: ImportSheet.WizardStep) -> Color {
        if step.rawValue < currentStep.rawValue { return .green }
        return .secondary.opacity(0.3)
    }
}

// MARK: - Pages-style picker card

/// v2.7 round-49 (= boss 2026-10-10
/// "每一行的背景矩形
/// 不需要, 每一类
/// 的小标题不需要
/// ，用一条分割线
/// 分割" directive).
/// The Pages macOS 27
/// inspector row pattern
/// (= the canonical macOS
/// 27 list row = 32 PT
/// tall, no card
/// background fill; =
/// the row is just text
/// on the panel surface;
/// = the previous
/// round-45 "filled
/// card with 12% white
/// overlay" was wrong
/// for a wizard step
/// surface; = the
/// wenshu v3.0 design
/// system now uses the
/// macOS 14+ list row
/// pattern). The row
/// is split into 2
/// columns:
/// 1. Leading: the
///    row's title (=
///    left aligned,
///    primary
///    foreground).
/// 2. Trailing: the
///    row's control (=
///    right aligned;
///    = a Picker /
///    Button / HStack).
///
/// v2.7 round-48 also
/// removed ALL icons.
/// v2.7 round-49 also
/// removed the
/// per-card background
/// fill (= the
/// `RoundedRectangle`
/// with the 12% white
/// overlay is GONE).
/// v2.7 round-49 also
/// removed the
/// per-section labels
/// (= "目标" / "AI 处
/// 理" are gone; = the
/// sections are
/// separated by a
/// single hairline
/// `Divider`; = the
/// 24 PT section gap
/// collapses to the
/// Divider's natural
/// 1 PT line + small
/// padding).
private struct PickerRow<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .frame(height: DesignTokens.pickerCardHeight)
    }
}

/// v2.7 round-49: renamed
/// from `PickerSectionLabel`
/// (= the boss rejected
/// per-section labels; =
/// sections are now
/// separated by a single
/// `Divider`; = no label
/// needed). Kept here as
/// an unused stub for
/// the moment (= a future
/// ticket might need it
/// for a different
/// surface; = deleting it
/// would be a dead-code
/// sweep that violates
/// Q112's "don't mix
/// dead-code cleanup with
/// feature commits"; =
/// leave it for the next
/// dead-code sweep).

/// v2.7 round-45: a Pages-style
/// section label (= the bold
/// text-only label that introduces
/// a new section in the inspector;
/// = e.g. "字体", "字符样式",
/// "文本颜色"; = the label is
/// NOT in a card; = it sits
/// directly on the panel surface
/// with 24 PT gap above (= the
/// section gap; = the Pages
/// inspector uses a larger gap
/// between major sections than
/// within a section).
private struct PickerSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// v2.7 round-45: the wizard chrome (= step indicator + nav bar)
///
/// v2.7 round-45 (= boss 2026-10-10
/// "UI 参考, pages 的
/// mac os 27 的样式"
/// directive). The nav bar
/// is updated to match the
/// Pages inspector panel
/// bottom = 16 PT panel
/// padding (= `spacingLoose`;
/// = the same horizontal
/// padding the picker cards
/// use internally; = the
/// visual alignment is
/// flush with the cards
/// above; = the user
/// reads this as "the
/// nav bar is part of
/// the panel, not a
/// separate footer").
/// v2.7 round-48 (= boss 2026-10-10
/// "第一步的页面，
/// 不应该有上一步"
/// directive). The "上
/// 一步" button is
/// HIDDEN on step 1
/// (NOT just disabled;
/// = the user said
/// "不应该有" = the
/// button should not
/// be present at
/// all; = a disabled
/// button takes up
/// the same space and
/// is visually noisy;
/// = the boss wants
/// the button gone
/// from the chrome
/// entirely on the
/// first step).
private struct WizardStepNavBar: View {
    @Binding var currentStep: ImportSheet.WizardStep
    let canGoPrev: Bool
    let canGoNext: Bool
    let primaryActionLabel: String
    let onPrev: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            // v2.7 round-48: hide the
            // back button on
            // step 1 entirely.
            // An `if` (not
            // `.disabled`)
            // because the
            // boss explicitly
            // said "不应该有"
            // (= "should not
            // exist"; = a
            // disabled
            // button is
            // visible; = the
            // boss wants it
            // removed from
            // the chrome).
            if canGoPrev {
                Button("上一步") { onPrev() }
                    // v2.7 round-45:
                    // the back
                    // button uses
                    // the
                    // .borderless
                    // style (=
                    // Pages
                    // inspector
                    // never uses
                    // a prominent
                    // back button;
                    // = a plain
                    // text button
                    // is the
                    // canonical
                    // "I'm
                    // secondary"
                    // style).
                    .buttonStyle(.borderless)
            }
            Spacer()
            Button(primaryActionLabel) { onNext() }
                .keyboardShortcut(.defaultAction)
                .disabled(!canGoNext)
                // v2.7 round-45: the
                // primary action
                // uses the
                // .borderedProminent
                // style with
                // .controlSize(.regular)
                // (= Pages inspector
                // primary action
                // = a 28 PT pill
                // button; = the
                // .borderedProminent
                // is the canonical
                // "do the thing"
                // visual).
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
        .padding(.top, DesignTokens.spacingStandard)
    }
}

// v2.7 round-52 (= boss 2026-10-10
// "我画的红线处, 缺一
// 条分割先. 让操作区
// 和设定区分开"
// directive). The hairline
// Divider between the
// step's per-step content
// (= the 设定区 = the
// pickers / progress bar
// / file list / summary)
// and the bottom action
// row (= the 操作区 = the
// nav bar with "上一步"
// + "下一步/开始/
// 完成"). The Divider is
// the visual seam that
// separates "what the user
// is configuring /
// observing" from "what
// the user does next" (=
// Apple HIG canonical
// dialog pattern; = the
// Pages inspector uses
// the same hairline
// Divider between the
// inspector body and the
// toolbar at the bottom
// of the panel).
//
// The Divider is applied
// to the sheet body
// (= ABOVE the
// WizardStepNavBar; =
// below the per-step
// view's content; = on
// every step) so the
// action area is always
// visually separated
// from the content area.
// The Divider has no
// vertical padding (= the
// Divider is a single
// hairline; = the
// padding above the
// Divider is supplied by
// the per-step view's
// bottom padding; = the
// padding below the
// Divider is supplied by
// the WizardStepNavBar's
// `padding(.top, ...
// spacingStandard)`).
private struct WizardActionDivider: View {
    var body: some View {
        Divider()
    }
}
