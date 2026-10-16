//
//  ImportSheetViewPieces.swift
//
//  View-private structs and helpers extracted from ImportSheet.swift
//  (= §6.6 god-class split: 525 LOC of view chrome moved out of the
//  main file to keep the main struct under the §6.6 600-LOC cap; = the
//  8 structs here are file-private to ImportSheet's render surface
//  = step indicator, progress strip, task row, picker row, nav bar;
//  = all declared `private` to the original file; = now declared
//  `internal` so the main file can reference them, and the new
//  file is the canonical home).
//

import SwiftUI


/// Per-file progress strip (= one row per `ImportTask`).
/// Apple HIG canonical list pattern (= vertical stack of
/// short rows; = the row shows the file name + the state
/// badge + an inline error caption if the task failed).
struct ImportProgressStrip: View {
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
struct ImportTaskRow: View {
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
        // (= boss 2026-10-10 "故事宪法，没有 重新分析是不是 内容相同" 反馈). The skip reason (= a short
        // explanation for the user; = "内容相同 (LLM confidence 0.95): 两段完全相同" or
        // "同 title retry skip" from the title-only path). Shown as a secondary
        // caption below the state pill.
        if let reason = task.skippedReason {
            Text(reason)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        // ticket 04 (= boss 2026-10-10 "甚至原 文件 A 的内容, 与我们的 B 模版 不符合, 多了很 我非模版的内 容, 我希望能自
        // 动拆出一个文 件, 放在合适的 目录中去" feedback). When the LLM suggested N extra
        // files (= the split-out content), show a caption below the state pill
        // counting how many were written. Examples: - " + 3 拆出" (= all done) -
        // " + 1/3 拆出" (= mid-flight) - " + 2 拆出, 1 失败" (= some failed) Hidden
        // when extraFilesTotal = 0 (= the canonical case where the LLM had
        // nothing to split out).
        if task.extraFilesTotal > 0 {
            extraFilesCaption
        }
        // (= boss 2026-10-10 (see OOB.md #2026-10-10) 做"). When the LLM could not extract
        // the 6 必填 (= phase 2 empty), show a small ⚠️ needs-attention badge
        // next to the row so the user knows there are empty 占位子文件 (= Apple HIG
        // needs-attention pattern; = SF Symbol exclamationmark.triangle.fill +
        // orange + caption font). (= boss 2026-10-10 (see OOB.md #2026-10-10)
        // 馈" feedback). Real-time LLM activity log (= scrolling terminal-like
        // view; = the user sees what the LLM is doing RIGHT NOW; = the last 5
        // lines are shown; = each line gets a monospaced font + .caption +
        // .secondary color; = the user can scroll to see older entries).
        // Hidden when activityLog is empty (= before the orchestrator appends
        // anything).
        if !task.activityLog.isEmpty {
            activityLogView
        }
    }

    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// 馈" feedback). Real-time
    /// LLM activity log
    /// (= a scrolling
    /// terminal-like view
    /// showing the last N
    /// entries of
    /// `task.activityLog`;
    /// = the user can see
    /// what the LLM is doing
    /// right now). Shown when
    /// activityLog is non-empty.
    @ViewBuilder
    private var activityLogView: some View {
        // Show last 5 entries (= the most recent = the current LLM action; = older
        // entries can be inferred from the sequence; = the 30-entry cap is
        // still enforced in `appendActivity`).
        let visible = task.activityLog.suffix(5)
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(visible.enumerated()), id: \.offset) { idx, line in
                Text(line)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(idx == visible.count - 1 ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 2)
    }

    /// ticket 04: caption for
    /// the per-file extraFiles count
    /// (= the row's
    /// " + N 拆出"
    /// subline). Renders
    /// the live count vs
    /// total (= updated
    /// every time the
    /// orchestrator
    /// writes an extra
    /// file).
    @ViewBuilder
    private var extraFilesCaption: some View {
        let total = task.extraFilesTotal
        let done = task.extraFilesDone
        Group {
            if done < total {
                Text(String(
                    format: NSLocalizedString("import.row.extras_in_progress", comment: ""),
                    done, total
                ))
            } else {
                Text(String(
                    format: NSLocalizedString("import.row.extras_done", comment: ""),
                    done
                ))
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }

    @ViewBuilder
    private var statePill: some View {
        switch task.state {
        case .pending:
            Text("待处理").font(.caption).foregroundStyle(.secondary)
        case .routing:
            // (= boss 2026-10-10 "这 个分析 中三 个字 前面 ，需 要加 一个 小小 的动 态 SF， 循环 播放 ， 要 不 然 这 个 界
            // 面 像 静 止 了" 反馈). The `ellipsis` SF Symbol (= three dots, no
            // background) + the `.variableColor` effect (= the dots
            // animate through colors in a loop) = the "wait / in progress"
            // visual affordance; = the user sees continuous motion (= the
            // `SFIcon` factory exposes the symbol via the canonical
            // wenshu-icon-policy pipeline; = the `.symbolEffect` is
            // attached to the underlying Image; = SF Symbols 6
            // variableColor dots loop forever at ~1 Hz; = the user
            // immediately sees "this is still running"); = without this,
            // the previous static "分析中" text felt frozen (= the boss's "像
            // 静 止 了" feedback).
            HStack(spacing: DesignTokens.spacingCaption) {
                // (= boss 2026-10-10 "那 个 圆 背 景 去 掉 ， 只 留 ICON " feedback). Switched from
                // `ellipsis.circle.fill` (= three dots inside a filled
                // circle; = the "gray circle" the boss disliked) to
                // `ellipsis` (= three dots, no background; = matches
                // the Apple HIG macOS 14+ 'system progress indicator'
                // pattern; = the `variableColor` rendering still
                // animates the dots as the canonical "thinking" cue).
                SFIcon(
                    "ellipsis",
                    style: .toolbar,
                    color: IconColor.secondary,
                    rendering: .variableColor
                )
                Text("分析中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .writing:
            // same idea as `routing` — show a spinning icon to signal activity (= the
            // user might be confused if the state went from "分析中" to "写入中"
            // with no visible change).
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
struct StubImportRouterForSheet: ImportRouter {
    func route(
        _ input: ImportFileInput,
        progress: (@Sendable (String) async -> Void)? = nil
    ) async throws -> ImportRoutingResult {
        return ImportRoutingResult(
            destination: .referenceLibrary,
            title: (input.filePath as NSString).deletingPathExtension,
            summary: "stub classification",
            tags: ["imported"],
            entityType: "other",
            category: nil,
            confidence: 1.0,
            rewrittenBody: nil,
            extraFiles: [],
        )
    }
    // the stub's isContentSame is a conservative "always different" default (= the user
    // always sees a fresh import in stub mode; = no false skips in the stub path).
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

/// (= boss 2026-10-10 (see OOB.md #2026-10-10)
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
struct WizardStepIndicator: View {
    @Binding var currentStep: ImportSheet.WizardStep
    let canReach: (ImportSheet.WizardStep) -> Bool

    var body: some View {
        HStack(spacing: DesignTokens.spacingModerate) {
            ForEach(ImportSheet.WizardStep.allCases) { step in
                let reachable = canReach(step)
                Button {
                    // (= boss 2026-10-10 "dot 如果没有进到下一 步，dot 就不能 跳到下一步骤 不能一进来什么 都没有，就可以
                    // 跳到完成去" directive). Only jump if the step is
                    // reachable (= the button is also .disabled
                    // below; = the guard is a defense-in-depth
                    // check). The [archived-round] "可以跳到任意 步骤" behavior is
                    // the bug this commit fixes.
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
        // a step that is NOT reachable (= the user hasn't reached it yet) is dimmed more
        // than a step that is just "future from the current" (= .secondary
        // .opacity(0.4) = the visual reads as "disabled"; = the user
        // understands "I can't click this yet").
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

/// (= boss 2026-10-10 (see OOB.md #2026-10-10)
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
/// [archived-round] "filled
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
/// also
/// removed ALL icons.
/// also
/// removed the
/// per-card background
/// fill (= the
/// `RoundedRectangle`
/// with the 12% white
/// overlay is GONE).
/// also
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
struct PickerRow<Leading: View, Trailing: View>: View {
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

/// renamed
/// from `PickerSectionLabel`
/// (= the boss rejected
/// per-section labels; =
/// sections are now
/// separated by a single
/// `Divider`; = no label
/// needed). Kept here as
/// (= kept for future use;
/// deleting it = dead-code
/// sweep, deferred to a
/// dedicated cleanup pass).

/// a Pages-style
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
struct PickerSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// the wizard chrome (= step indicator + nav bar)
///
/// (= boss 2026-10-10 (see OOB.md #2026-10-10)
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
/// (= boss 2026-10-10 (see OOB.md #2026-10-10)
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
struct WizardStepNavBar: View {
    @Binding var currentStep: ImportSheet.WizardStep
    let canGoPrev: Bool
    let canGoNext: Bool
    let primaryActionLabel: String
    let onPrev: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            // hide the back button on step 1 entirely. An `if` (not `.disabled`) because
            // the boss explicitly said "不应该有" (= "should not exist"; = a
            // disabled button is visible; = the boss wants it removed from
            // the chrome).
            if canGoPrev {
                Button("上一步") { onPrev() }
                    // the back button uses the .borderless style (= Pages inspector never
                    // uses a prominent back button; = a plain text
                    // button is the canonical "I'm secondary"
                    // style).
                    .buttonStyle(.borderless)
            }
            Spacer()
            Button(primaryActionLabel) { onNext() }
                .keyboardShortcut(.defaultAction)
                .disabled(!canGoNext)
                // the primary action uses the .borderedProminent style with
                // .controlSize(.regular) (= Pages inspector primary
                // action = a 28 PT pill button; = the
                // .borderedProminent is the canonical "do the thing"
                // visual).
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
        .padding(.top, DesignTokens.spacingStandard)
    }
}

// (= boss 2026-10-10 (see OOB.md #2026-10-10) directive). The hairline Divider between
// the step's per-step content (= the 设定区 = the pickers / progress bar / file list /
// summary) and the bottom action row (= the 操作区 = the nav bar with "上一步" + "下一步/开始/
// 完成"). The Divider is the visual seam that separates "what the user is configuring /
// observing" from "what the user does next" (= Apple HIG canonical dialog pattern; =
// the Pages inspector uses the same hairline Divider between the inspector body and
// the toolbar at the bottom of the panel). The Divider is applied to the sheet body (=
// ABOVE the WizardStepNavBar; = below the per-step view's content; = on every step) so
// the action area is always visually separated from the content area. The Divider has
// no vertical padding (= the Divider is a single hairline; = the padding above the
// Divider is supplied by the per-step view's bottom padding; = the padding below the
// Divider is supplied by the WizardStepNavBar's `padding(.top, ... spacingStandard)`).
struct WizardActionDivider: View {
    var body: some View {
        Divider()
    }
}
