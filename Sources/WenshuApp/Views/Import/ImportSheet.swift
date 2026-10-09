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

    /// Per-file task state (= the orchestrator's
    /// `ImportTask` model; = the progress strip
    /// shows one row per file).
    @State private var tasks: [ImportTask] = []

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
            Text("导入 Markdown 文件")
                .font(.title2.weight(.semibold))

            Form {
                Section {
                    // File-type filter (= the user's
                    // 2026-10-09 ask: "在目录树上一行，
                    // 加一行文件类型图标，单选"; = a
                    // one-line row that sits at the top
                    // of the form, with an SF Symbol on
                    // the left, the type name in the
                    // middle, and a chevron on the right
                    // (= the same pattern as the
                    // `目标书籍` picker below). Apple
                    // canonical: `Picker` with
                    // `.menu` style (= the user picks
                    // from a dropdown, = the row itself
                    // shows the current value as a
                    // label). The .pdf / .epub cases are
                    // visible in the menu but disabled
                    // (= the v2.7 orchestrator only
                    // knows how to walk + write .md
                    // files; = the disabled rows
                    // communicate "coming soon" without
                    // a separate label).
                    Picker(selection: $fileType) {
                        ForEach(ImportFileType.allCases) { type in
                            HStack {
                                SFIcon(type.iconName, style: .toolbarButton, color: .tint)
                                Text(type.displayName)
                                if !type.isSupported {
                                    Text("（即将支持）")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .tag(type)
                        }
                    } label: {
                        HStack(spacing: DesignTokens.spacingStandard) {
                            SFIcon(fileType.iconName, style: .toolbarButton, color: .tint)
                            Text("文件类型")
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isImporting)

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

                    Picker("目标", selection: $importDestination) {
                        ForEach(ImportDestination.allCases) { d in
                            Text(d.label).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isImporting)

                    if importDestination == .book {
                        Picker("目标书籍", selection: $selectedBookID) {
                            Text("请选择书籍").tag(UUID?.none)
                            ForEach(bookStore.books) { book in
                                Text(book.title).tag(Optional(book.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(isImporting)
                    }
                }

                if !tasks.isEmpty {
                    Section("进度") {
                        // The ProgressView shows the
                        // canonical "已完成 X / Y" form
                        // (= Apple HIG canonical
                        // indeterminate determinate
                        // progress pattern). The
                        // fraction counts the
                        // terminal-state tasks
                        // (.done / .skipped / .failed)
                        // PLUS the in-flight tasks
                        // (.routing / .writing); = the
                        // bar moves continuously while
                        // the 5-way parallel LLM
                        // dispatch is mid-flight
                        // (= the user's 2026-10-09
                        // follow-up "进度一直在反复跳，
                        // 逐个文件处理没有生效" = the
                        // bar stuck at 0% because
                        // in-flight tasks were
                        // excluded from the fraction;
                        // = the new model shows the
                        // full pipeline moving
                        // (= completed + inFlight
                        // ticks as each LLM call
                        // returns and each file
                        // write lands)). The "已完成"
                        // label still counts only
                        // terminal states (= the
                        // canonical "X / Y" feel the
                        // user expects).
                        if totalCount > 0 {
                            ProgressView(
                                value: Double(completedCount + inFlightCount),
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
                    // The cancel button + every
                    // dismiss path (ESC / Cmd+W /
                    // toolbar X / clicking outside)
                    // all flip the same flag (= the
                    // `confirmationDialog` modifier
                    // presents immediately; = the
                    // user can't dismiss the sheet
                    // without picking "确认取消" or
                    // "返回"; = the dialog is the
                    // single source of truth for the
                    // cancel-and-rollback path).
                    showCancelConfirmation()
                }
                .keyboardShortcut(.cancelAction)
                // Do NOT disable the cancel button
                // while the import is mid-flight:
                // the user NEEDS this button (= and
                // its bound ESC key) as the only way
                // to surface the confirmation dialog
                // when `interactiveDismissDisabled`
                // is blocking the OS dismiss verbs.
                // The button's label still changes
                // (= "取消" → "跳过失败") so the
                // visual state is informative.
                .disabled(false)
                Button(actionButtonLabel) {
                    // The action button's behavior
                    // varies with the state machine:
                    // - "开始导入" / "重试" /
                    //   "导入中…" → start the import
                    //   (or wait for the running
                    //   import; = `canStart` is
                    //   gated on `!isImporting`).
                    // - "完成" (= 100% + zero
                    //   failures) → dismiss the
                    //   sheet (= the user's 2026-10-09
                    //   round-17 feedback "3 个全完成
                    //   了，但按钮还是再次导入，应该
                    //   是完成"; = "完成" is a
                    //   terminal state; = the user
                    //   expects to close the sheet,
                    //   not re-run an already-finished
                    //   batch; = the previous
                    //   "再次导入" label
                    //   mis-represents the state).
                    if isRunComplete && !hasFailures {
                        isPresented = false
                    } else {
                        startImport()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canStart)
            }
        }
        // Boss's 2026-10-09 directive: "ESC，cmd+w
        // 应该还是可以关掉了，不要让用户可关闭。
        // 只能通过取消退出". The intended UX is:
        // ESC + Cmd+W + the toolbar X button +
        // clicking outside DO close the sheet
        // (= the user is in control of the
        // window-chrome dismiss verbs); = but the
        // sheet re-opens with the confirmation
        // dialog immediately (= the
        // `onDisappear` hook flips
        // `confirmCancelPresented = true`; = the
        // parent binding is restored via
        // `isPresented = true` in the same hook;
        // = the dialog is the only way out). The
        // `interactiveDismissDisabled` modifier is
        // NOT used (= the user wanted ESC to
        // "still work"; = blocking it would be the
        // wrong UX). The behavior: any dismiss path
        // = user sees the confirmation dialog =
        // "返回" keeps the sheet open + the import
        // running; = "确认取消" runs the rollback +
        // dismisses the sheet for real (= the
        // `isPresented = false` flag flips AFTER
        // the rollback Task completes).
        // (previous onChange-of-isPresented
        // interceptor was removed = the
        // SwiftUI lifecycle fires it after the
        // sheet has already torn down; = the
        // new interception model is
        // `interactiveDismissDisabled(isImporting)`
        // below = blocks the OS dismiss paths
        // while an import is mid-flight; = the
        // 取消 button + ESC + Cmd+W all flip
        // `confirmCancelPresented` to show the
        // boss's 确认 / 返回 dialog = the
        // dialog is the single source of truth
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
            return true
        }
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
                )
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
                )
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
