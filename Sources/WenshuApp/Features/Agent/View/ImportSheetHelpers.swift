//
//  ImportSheetHelpers.swift
//
//  Cross-file `extension ImportSheet { ... }` extracted from
//  ImportSheet.swift (= §6.6 god-class split: 619 LOC of the
//  4-step wizard helpers moved out of the main file).
//
//  Why extracted (= §6.6 god-class split): the main `struct
//  ImportSheet: View` is 957 LOC and the cross-file `extension
//  ImportSheet { ... }` (= the 4-step wizard helpers) is 619
//  LOC; = the file was 2.7x the 600-LOC cap. The extension
//  holds 10 methods:
//    - canReachStep / canGoPrev / canGoNext / primaryActionLabel
//      / goPrev / goNext (= 6 control methods for the wizard
//      navigation; = ~150 LOC).
//    - step1ConfigureView / step2RunningView / step3ResultsView
//      / step4DoneView (= 4 step views for the wizard surfaces;
//      = ~470 LOC).
//
//  Access-level changes (= required for cross-file extension):
//    - 13 `@State private var` → `@State var`
//    - 3 `@Environment(...) private var` → `@Environment(...) var`
//    - 1 `@AppStorage(...) private var` → `@AppStorage(...) var`
//    - 10 `fileprivate var/func` → `var/func`
//    - 17 `    private let/var/func/enum` → internal
//

import SwiftUI

// MARK: - 4-step wizard helpers

extension ImportSheet {
    /// (= boss 2026-10-10 (see OOB.md #2026-10-10) 步骤" directive). The
    /// reachability predicate for the dot indicator. The user can only click a
    /// dot for a step they have already reached (= a fresh sheet on ① 选目 标 only
    /// has ① clickable; = ②③④ are dimmed AND disabled). The reachability
    /// contract: - `.configure` always reachable (= the initial step). -
    /// `.running` reachable when the user has pressed 开始 (= `hasRunOnce`). -
    /// `.results` reachable when the import has finished (= the orchestrator's
    /// `isRunComplete` flag is true) OR the user has already navigated past it
    /// (= currentStep ≥ .results). - `.done` reachable only after the user has
    /// tapped 完成 on the .results step (= currentStep == .done OR currentStep
    /// has been past it).
    func canReachStep(_ step: WizardStep) -> Bool {
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

    /// True if the user can go back one step (= not on the first step; = never
    /// go back from .running because the import is mid-flight; = the boss's
    /// "上一步" button is enabled on every step EXCEPT the first (.configure); =
    /// on the first step the button is HIDDEN entirely per the boss's [archived-round]
    /// "第一步的页面, 不应该有 上一步" directive).
    var canGoPrev: Bool {
        currentStep != .configure
    }

    /// True if the user can advance to the next step. The rules (= the boss's
    /// "不点 '开始导入' 不能 进步骤 2" answer): - .configure → .running iff `canStart` (=
    /// the user has filled the required fields). - .running → .results iff
    /// `isRunComplete` (= the orchestrator has finished; = the user can review
    /// the results). - .results → .done always (= just a "next" tap to dismiss
    /// the per-file list). - .done: ALWAYS reachable (= the boss's [archived-round]
    /// "完成不用判 断任何, 就直接能点就可以" directive; = even if there are failures (= 21
    /// failed + 14 skipped = the user has acknowledged the failures and wants
    /// to close the sheet; = the button is a "dismiss" not a "validate
    /// success"; = gating the dismiss button on `hasFailures == false` forces
    /// the user to do an extra step to dismiss the sheet even though the import
    /// is done and the user has accepted the outcome; = the gate is unnecessary
    /// friction).
    var canGoNext: Bool {
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

    /// The primary action button's label (= the right side of the nav bar).
    /// Apple HIG canonical: a single label that reflects what tapping it WILL
    /// do (= "开始" → start the import; = "下一步" → advance; = "完成" → dismiss the
    /// sheet).
    var primaryActionLabel: String {
        switch currentStep {
        case .configure: return "开始"
        case .running:   return "下一步"
        case .results:   return "完成"
        case .done:      return "完成"
        }
    }

    /// The previous-step action (= Apple HIG canonical: a simple "上一步" label; =
    /// the button is disabled when `canGoPrev` is false; = never go back from
    /// .running).
    func goPrev() {
        guard canGoPrev else { return }
        switch currentStep {
        case .configure: break
        case .running:   currentStep = .configure
        case .results:   currentStep = .running
        case .done:      currentStep = .results
        }
    }

    /// The next-step action. Apple HIG canonical: tapping the primary action
    /// advances the wizard. Side effects per step: - .configure → .running:
    /// starts the import (= `startImport()` kicks off the orchestrator; = the
    /// user lands on .running + the progress view animates). - .running →
    /// .results: no-op (the auto- advance via .onChange of isRunComplete
    /// already fired; = this path is the user manually tapping "下一步" while
    /// still on .running; = advancing is idempotent). - .results → .done: no-op
    /// (the .done view presents a summary). - .done: dismiss the sheet (= the
    /// boss's terminal state).
    func goNext() {
        guard canGoNext else { return }
        switch currentStep {
        case .configure:
            // "开始" button. Triggers the import + advances the wizard. The orchestrator's
            // `importFiles` runs asynchronously (= the user lands on
            // .running; = the progress view animates as the orchestrator
            // emits `onProgress` ticks).
            startImport()
            currentStep = .running
        case .running:
            // "下一步" while on .running. The user can manually advance once `isRunComplete`
            // flips (= the orchestrator has finished; = the user might be
            // reviewing the progress while waiting for the next onProgress
            // tick).
            currentStep = .results
        case .results:
            // "完成" button. Advance to .done (= the summary view).
            currentStep = .done
        case .done:
            // Terminal state. The "完成" button dismisses the sheet.
            isPresented = false
        }
    }

    // MARK: - Per-step views

    /// Step 1: 选目标. The macOS 27 list row pattern (= 32 PT row height; = no
    /// card background fill; = the boss's [archived-round] "每一行的背景矩形不需要" directive; =
    /// the row is just text + control; = sections separated by a hairline
    /// Divider).
    @ViewBuilder
    var step1ConfigureView: some View {
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
                            // (= boss 2026-10-10 "提示文 案显示不全" directive). The previous
                            // implementation truncated the
                            // placeholder with the default
                            // truncation mode (= tail)
                            // which cut off the meaningful
                            // portion of the hint (=
                            // "选择一个包 含 .md 文" = the user
                            // couldn't see the file
                            // extension at the end; = the
                            // most important part of the
                            // hint was missing). Fix:
                            // middle truncation (= the
                            // same pattern the path uses
                            // above; = the middle of the
                            // hint is omitted and the file
                            // extension stays visible at
                            // the end; = "选择...含 .md 文件
                            // 的目录" = the user reads the
                            // hint as "choose a directory
                            // containing .md files").
                            .truncationMode(.middle)
                            // the Text needs to fill the available horizontal space (=
                            // the HStack contains a fixed-
                            // size button on the right; =
                            // the Text gets the rest; =
                            // without maxWidth the Text
                            // would shrink-to- fit and the
                            // truncation would kick in
                            // even when the full hint
                            // could fit = the shrink- fit
                            // is iOS-only; = on macOS the
                            // Text expands until the
                            // HStack overflows; = adding
                            // maxWidth makes the Text take
                            // the remaining space
                            // explicitly).
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .help(fileType.placeholderHint)
                    }
                    Button("选择…") { pickSourceDirectory() }
                        .disabled(isImporting)
                        .buttonStyle(.borderedProminent)
                        // (= boss 2026-10-10 "选择按钮 的文字大小，和按 钮高度，与其它 按钮不同，需要 拉成同意大小"
                        // directive). REMOVED
                        // `.controlSize(.small)` (= the "选择…"
                        // button is now the default
                        // .controlSize(.regular) = 28 PT tall
                        // + the canonical Apple HIG macOS body
                        // text size; = the button height
                        // matches the segmented Picker (= "导入到
                        // 资料库" / "导入到 书") + the menu Pickers
                        // (= Markdown / 请选择书籍 / 基于 现有内容整理 /
                        // 3); = the visual rhythm across the
                        // trailing column is now uniform; =
                        // the user reads the row as "all
                        // controls are the same height"). The
                        // previous `.small` (= 22 PT tall +
                        // smaller text) made "选择…" stand out
                        // as visually inconsistent with its
                        // row neighbors.
                }
            }

            // Divider between the file / source section and the destination section (=
            // the boss's "用一条 分割线分割" directive; = the previous
            // `PickerSectionLabel ` + 24 PT gap is replaced with a single
            // hairline Divider; = the small vertical padding around the
            // Divider is 8 PT (= `spacing Standard`) = enough for the user
            // to see the Divider as a deliberate separator; = matches the
            // wenshu v3.0 design system Divider padding convention).
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
                // (= boss 2026-10-10 "用 户在 导入 书的 时候， 要选 择二 级目 录 ... 资料 库不用" 反馈). The 2nd-
                // level folder Picker (= the "目标目录" row). Only shown
                // when `importDestination == .book` AND a book is
                // selected (= the Picker needs a bookId context to
                // resolve the folder's path; = the user can't pick a
                // folder before picking a book). Uses the same
                // `Picker` + `PickerRow` pattern as the 目标书籍 row above
                // (= consistent visual treatment; = the segmented
                // style is NOT used here because the 6 options are too
                // long to fit; = the menu style shows a compact
                // dropdown). (= boss 2026-10-10 "这 个选择 目录 的， 不用 选书 后 再
                // 显 示， 就 长 显 就 可 以 了" feedback). The 2nd-level folder
                // Picker is now ALWAYS shown when `importDestination
                // == .book` (= no conditional on `selectedBookID !=
                // nil`; = the user sees the folder picker immediately
                // when they pick "导入到书"; = the Picker is disabled
                // (greyed out) until a book is selected for the Picker
                // to make sense visually; = but the row itself is
                // always there so the user doesn't see the layout jump
                // when they pick a book). The same row format as 目标书籍
                // (= PickerRow + .menu picker; = visually consistent).
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

            // Divider between the destination section and the AI section.
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

    /// Step 2: 进度. The progress bar + the per-file strip; = the two surfaces
    /// are separated by a hairline Divider (= matches the step 1 / step 3
    /// pattern; = the boss's [archived-round] "演示要每一步骤的页面 都一样, 不只改第一步" directive; =
    /// every step has the same dot-indicator / Divider / bottom-nav-bar
    /// chrome).
    @ViewBuilder
    var step2RunningView: some View {
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
            // Divider between the progress section and the per-file list (= the boss's
            // "演示要每一步 骤的页面都一 样" directive; = every step uses the same
            // "section content + Divider + list" pattern).
            Divider()
                .padding(.vertical, DesignTokens.spacingStandard)
            ImportProgressStrip(tasks: tasks)
                .frame(maxHeight: DesignTokens.kanbanBoardMaxHeight)
        }
    }

    /// Step 3: 结果. The per-file list (= the same strip as Step 2) + per-row
    /// "重试" buttons. No pickers, no progress bar (= the import already
    /// finished; = the user is now in review/retry mode).
    /// (= boss 2026-10-10 (see OOB.md #2026-10-10) directive). The "重新调研所有失败"
    /// total button moves from the top of the view (= the [archived-round] position; =
    /// the user complained "挨着完成放" = the button should be next to the 完成
    /// button, not at the top of the list) to the BOTTOM of the view, right-
    /// aligned, with a hairline Divider above it (= the "操作上面需要也 加一条分割线"
    /// requirement; = the Divider separates the file list from the action
    /// surface; = the action sits in its own row, visually analogous to the
    /// "完成" button in the nav bar).
    @ViewBuilder
    var step3ResultsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The per-file list (= the same strip as Step 2; = per-row "重试" buttons are
            // inside the ImportProgressStrip / ImportTaskRow).
            ImportProgressStrip(tasks: tasks)
                .frame(maxHeight: DesignTokens.kanbanBoardMaxHeight)
            // the "重新调研所有失败" button at the BOTTOM of the results view (= the boss's "挨着完成
            // 放" directive; = the button is now visually adjacent to the
            // nav bar's "完成" button; = the user reads the two buttons as
            // "secondary action + primary action" = a standard dialog
            // pattern). The button is only visible when at least one task
            // failed because the file was unreadable on disk (= same
            // condition as before; = the
            if canRetryFailedTitleOnly {
                // hairline Divider above the action row (= the "操作 上面需要也加 一条分割线"
                // requirement).
                Divider()
                HStack {
                    Spacer()
                    Button {
                        Task { retryFailedTitleOnly() }
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

    /// Step 4: 完成. The summary (= "完成 N, 跳过 M, 失败 K") + a "完成" button to
    /// dismiss the sheet. No pickers, no progress bar, no per-file list (= the
    /// user is already done with the import).
    /// (= boss 2026-10-10 (see OOB.md #2026-10-10) 左对齐" directive). The
    /// previous implementation had `.padding(DesignTokens .spacingStandard)` (=
    /// 12 PT internal padding) on the VStack (= the summary text was inset 12
    /// PT from the sheet's left edge; = the user perceived the text as
    /// "floating in the middle of the sheet" with a visible gap from the
    /// sheet's left edge). The fix: REMOVE the internal padding (= the text now
    /// starts at x = 0 inside the VStack; = the VStack itself uses `alignment:
    /// .leading` + the `frame(maxWidth: .infinity, alignment: .leading)` to
    /// make the text flush with the sheet's left edge; = the summary text is
    /// now aligned with the dot indicator + the nav bar buttons on the other
    /// steps; = the visual alignment is consistent across all 4 steps).
    @ViewBuilder
    var step4DoneView: some View {
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
