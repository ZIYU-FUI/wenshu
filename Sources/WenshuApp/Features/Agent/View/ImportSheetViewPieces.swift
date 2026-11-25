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
/// the product list pattern (= vertical stack of
/// short rows; = the row shows the file name + the state
/// badge + an inline error caption if the task failed).
struct ImportProgressStrip: View {
    let tasks: [ImportTask]

    var body: some View {
        // The reply grows while the agent writes, = so the strip follows
        // the newest line (= the same shape as the chat zone's
        // transcript: = the scroll view's anchor is the bottom, = and
        // the last row is scrolled into view when the reply grows).
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                    ForEach(tasks) { task in
                        ImportTaskRow(task: task)
                            .id(task.id)
                    }
                }
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: replySize) { _, _ in
                guard let last = tasks.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    /// How much reply the rows hold (= the signal that the content grew).
    ///
    /// The count of the parts is not enough: = the trailing text part
    /// grows character by character, = so the size is measured in
    /// characters.
    private var replySize: Int {
        tasks.reduce(0) { total, task in
            total + task.agentParts.reduce(0) { sum, part in
                switch part.kind {
                case let .text(text): return sum + text.count
                case let .reasoning(text): return sum + text.count
                default: return sum
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
        // (= product rule from the 2026-10-10 librarian round: a re-analysis must
        // skip chapters whose content is unchanged). The skip reason (= a short
        // explanation for the user; = "内容相同 (LLM confidence 0.95): 两段完全相同" or
        // "同 title retry skip" from the title-only path). Shown as a secondary
        // caption below the state pill.
        if let reason = task.skippedReason {
            Text(reason)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        // ticket 04 (= product rule from the 2026-10-10 librarian round: content
        // that does not fit the template is auto-split into its own file). When the LLM suggested N extra
        // files (= the split-out content), show a caption below the state pill
        // counting how many were written. Examples: - " + 3 拆出" (= all done) -
        // " + 1/3 拆出" (= mid-flight) - " + 2 拆出, 1 失败" (= some failed) Hidden
        // when extraFilesTotal = 0 (= the canonical case where the LLM had
        // nothing to split out).
        if task.extraFilesTotal > 0 {
            extraFilesCaption
        }
        // (see OOB.md #2026-10-10). When the LLM could not extract
        // the 6 必填 (= phase 2 empty), show a small ⚠️ needs-attention badge
        // next to the row so the user knows there are empty placeholder files
        // (= the 2026-10-10 needs-attention badge decision; = SF Symbol exclamationmark.triangle.fill +
        // orange + caption font). (see OOB.md #2026-10-10)
        // = the user sees what the agent is doing RIGHT NOW; = the reply
        // grows as the agent writes it).
        // Hidden when the row has no parts yet (= before the agent says
        // anything).
        if !task.agentParts.isEmpty {
            ImportAgentReplyView(
                parts: task.agentParts,
                isStreaming: task.state == .writing || task.state == .routing
            )
        }
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
            // (= product rule from the 2026-10-10 librarian round: the
            // in-progress label needs a looping animated glyph or the panel
            // reads as frozen). The `ellipsis` SF Symbol (= three dots, no
            // background) + the `.variableColor` effect (= the dots
            // animate through colors in a loop) = the "wait / in progress"
            // visual affordance; = the user sees continuous motion (= the
            // `SFIcon` factory exposes the symbol via the canonical
            // wenshu-icon-policy pipeline; = the `.symbolEffect` is
            // attached to the underlying Image; = SF Symbols 6
            // variableColor dots loop forever at ~1 Hz; = the user
            // immediately sees "this is still running"); = without this,
            // the previous static in-progress text felt frozen (see OOB.md #2026-10-10).
            HStack(spacing: DesignTokens.spacingCaption) {
                // (= product rule from the 2026-10-10 librarian round: the glyph keeps no
                // circular background, only the icon). Switched from
                // `ellipsis.circle.fill` (= three dots inside a filled
                // circle; = the "gray circle" the rule rejected) to
                // `ellipsis` (= three dots, no background; = matches
                // the product macOS 14+ 'system progress indicator'
                // pattern; = the `variableColor` rendering still
                // animates the dots as the canonical "thinking" cue).
                SFIcon(
                    "ellipsis",
                    style: .toolbar,
                    color: IconColor.secondary,
                    rendering: .variableColor,
                    matchingText: .caption
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
                    rendering: .variableColor,
                    matchingText: .caption
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

// MARK: - Wizard chrome (= step indicator + nav bar)

/// (see OOB.md #2026-10-10) = the guided multi-step interaction.
/// The 4-step dot indicator at the
/// top of the sheet. product
/// canonical: a horizontal row of 4
/// dots + labels (= one per step; =
/// the current step is highlighted;
/// = completed steps show a
/// checkmark; = future steps are
/// dim). The dots are also
/// clickable to jump to that
/// step (= the product's hybrid wizard
/// shape: progress dots at the top
/// + a 'next step' button at the bottom
/// answer to the Q3 clarify).
struct WizardStepIndicator: View {
    @Binding var currentStep: ImportSheet.WizardStep
    let canReach: (ImportSheet.WizardStep) -> Bool

    var body: some View {
        HStack(spacing: DesignTokens.spacingModerate) {
            ForEach(ImportSheet.WizardStep.allCases) { step in
                let reachable = canReach(step)
                Button {
                    // (= product rule from the 2026-10-10 librarian round: a progress dot may
                    // only advance to a step actually reached). Only jump if the step is
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
        if step == currentStep {
            return step.iconName
        }
        if step.rawValue < currentStep.rawValue {
            return "checkmark.circle.fill"
        }
        return "\(step.rawValue + 1).circle"
    }

    private func dotColor(for step: ImportSheet.WizardStep, reachable: Bool) -> Color {
        // a step that is NOT reachable (= the user hasn't reached it yet) is dimmed more
        // than a step that is just "future from the current". System label
        // ink, not a hand-rolled alpha: tertiaryLabel resolves to α 0.26 and
        // adapts to appearance and increase contrast (craft audit C2).
        if !reachable {
            return Color(nsColor: .tertiaryLabelColor)
        }
        if step == currentStep {
            return .accentColor
        }
        if step.rawValue < currentStep.rawValue {
            return .green
        }
        return .secondary
    }

    private func connectorColor(for step: ImportSheet.WizardStep) -> Color {
        if step.rawValue < currentStep.rawValue {
            return .green
        }
        return Color(nsColor: .tertiaryLabelColor)
    }
}

// MARK: - Picker card (product wizard layout)

/// (see OOB.md #2026-10-10). The macOS 27
/// inspector row shape the
/// product settled on (= the canonical macOS
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
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .frame(height: DesignTokens.pickerCardHeight)
    }
}

/// the wizard chrome (= step indicator + nav bar)
///
/// (see OOB.md #2026-10-10). The nav bar
/// is updated to match the
/// wizard inspector panel
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
/// (see OOB.md #2026-10-10). The previous-step button is
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
/// = the rule wants
/// the button gone
/// from the chrome
/// entirely on the
/// first step).
struct WizardStepNavBar: View {
    let canGoPrev: Bool
    let canGoNext: Bool
    let primaryActionLabel: String
    let onPrev: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            // hide the back button on step 1 entirely. An `if` (not `.disabled`) because
            // the rule was explicit ("should not exist"; a
            // disabled button is visible; = the rule wants it removed from
            // the chrome).
            if canGoPrev {
                Button("上一步") { onPrev() }
                    // the back button uses the .borderless style (= the wizard never
                    // wants a prominent back button; = a plain text
                    // button is the canonical "I'm secondary"
                    // style).
                    .buttonStyle(.borderless)
            }
            Spacer()
            Button(primaryActionLabel) { onNext() }
                .keyboardShortcut(.defaultAction)
                .disabled(!canGoNext)
                // the primary action uses the .borderedProminent style with
                // .controlSize(.regular) (= the wizard's primary
                // action = a 28 PT pill button; = the
                // .borderedProminent is the canonical "do the thing"
                // visual).
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
        .padding(.top, DesignTokens.spacingStandard)
    }
}

/// (see OOB.md #2026-10-10). The hairline Divider between the step's
/// per-step content (= the settings area = the pickers / progress bar /
/// file list / summary) and the bottom action row (= the action area = the
/// nav bar with the previous, next, start and done buttons) separates
/// "what the user does next" from the content area (= the product dialog
/// pattern; =
/// the wizard uses the same hairline Divider between the inspector body and
/// the toolbar at the bottom of the panel). The Divider is applied to the sheet body (=
/// ABOVE the WizardStepNavBar; = below the per-step view's content; = on every step) so
/// the action area is always visually separated from the content area. The Divider has
/// no vertical padding (= the Divider is a single hairline; = the padding above the
/// Divider is supplied by the per-step view's bottom padding; = the padding below the
/// Divider is supplied by the WizardStepNavBar's `padding(.top, ... spacingStandard)`).
struct WizardActionDivider: View {
    var body: some View {
        Divider()
    }
}
