//
//  ChatReasoningPartView.swift
//
//  Apple MVVM canonical part view: renders one reasoning block
//  (= the "thinking…" trace that shows what the assistant considered
//  before replying). Lifted out of ChatPartView.swift so:
//
//  - The chat part surface follows 1-view-1-file (= product
//    canonical file-per-view).
//  - Reasoning rendering can evolve independently of text/tool/result
//    part rendering (= hermes 1:1 = reasoning gets its own card;
//    = wenshu mirrors the same separation).
//
// :
//  UI-only (= no business logic; = the reasoning string comes
//  straight from ChatMessagePart.ReasoningPart.text).
//
//  hermes 1:1 (= assistant-message.tsx + message-parts.tsx):
//  - Collapsed by default (= product footnote convention).
//  - On expand: shows the reasoning content in a slightly-quieter
//    foreground + monospaced font (= the "internal log" affordance).
//  - isRunning pulse (= the wenshu StatusPulse private struct) is
//    rendered inline as the row identity when still streaming.
//
//  The reasoning is split into labelled steps when it carries markers
//  (= the model's own action and result notes) and shown as one block
//  when it does not. The tool-derived activity is a separate list under
//  the same disclosure, because the tool calls are facts and the model's
//  prose is its own account of them.
//

import SwiftUI

struct ChatReasoningPartView: View {
    let text: String
    let isRunning: Bool
    /// The steps the assistant performed, when the reply performed any.
    let activity: [ToolActivity]
    /// Whether the block's own text is showing.
    ///
    /// The state arrives as a binding into the part this block belongs to
    /// and is written straight back. It is not `@State`: the row that draws
    /// a thinking block is built again when the reply grows and is not
    /// built at all while the transcript scrolls it out of the viewport, so
    /// state kept here would be the reader's choice losing to a token.
    ///
    /// -cleanup E2 (see OOB.md #2026-09-21) OOB 'AI ' (= the
    /// thinking content was collapsed by default; = the user could see
    /// only the brain-head-profile icon and the "AI thought for Xs"
    /// label, = effectively no visible thinking content). The value the
    /// model hands over opens the block (= ChatMessagePart keeps it open
    /// until the reader closes it), so the reasoning text is visible
    /// without a click and the reader's own collapse is what changes it.
    @Binding var isRevealed: Bool

    init(
        text: String,
        isRunning: Bool = false,
        activity: [ToolActivity] = [],
        isRevealed: Binding<Bool>
    ) {
        self.text = text
        self.isRunning = isRunning
        self.activity = activity
        _isRevealed = isRevealed
    }

    var body: some View {
        // product footnote pattern (= the DisclosureGroup is the
        // canonical SwiftUI collapse/expand control = identical to
        // Mail / Notes "Show Details" toggles). Renders a label +
        // chevron that the user clicks to expand.
        DisclosureGroup(isExpanded: $isRevealed) {
            VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    ReasoningSegmentView(segment: segment)
                }
                if !activity.isEmpty {
                    ToolActivityList(activity: activity)
                }
            }
            .padding(.top, DesignTokens.spacingIconic)
            .transition(.opacity)
        } label: {
            // -cleanup E2 (see OOB.md #2026-09-21) OOB 'AI '
            // (= the brain-head-profile icon was C2-era wenshu-side chrome
            // that hermes does NOT use; = status.tsx ResponseLoadingIndicator
            // is a 3×3 PT StatusPulse square, no icon). Drop the icon; =
            // a small grayer caption label is enough to identify the
            // thinking section. The label flips between running + finished
            // (= the Hermes `thoughtFor` / `thoughtBriefly` / `thought`
            // state machine = simplified to a 2-state label here).
            Text(isRunning
                ? String(localized: "chatview.ai_thinking")
                : String(localized: "chatview.ai_thought"))
                .font(.caption)
        }
        .animation(.default, value: isRevealed)
    }

    // T17: opacity value driven by a TimelineView so the pulse
    // animates without needing external state mutation. Starts at
    // 1.0 (= visible) and animates to 0.4 and back (= subtler than
    // going fully invisible). `private` so the view body can read
    // it directly without exposing the TimelineView as part of the
    // public surface.
    // -cleanup E2 (see OOB.md #2026-09-21) OOB 'AI ': removed
    // the brain-head-profile icon + the runningOpacity pulse animation
    // (= was driving the icon's 0.4 -> 1.0 -> 0.4 oscillation). The
    // thinking section is now a small caption label (= "AI " /
    // "AI ") with no icon, no pulse

    /// Reasoning text also uses inline markdown (= reasoning often
    /// contains structure like `**KEY POINT**: ...`).
    private static func renderMarkdown(_ raw: String) -> AttributedString {
        ChatTextPartView.parseMarkdown(raw)
    }

    /// The reasoning split into steps.
    ///
    /// A message whose reasoning carries no markers is one prose block, so
    /// the rendering matches what the reader would see anyway.
    private var segments: [ReasoningSegment] {
        let parsed = ReasoningMarkupParser.parse(text)
        return parsed.isEmpty ? [.prose(text)] : parsed
    }
}

/// One labelled step of the assistant's reasoning.
private struct ReasoningSegmentView: View {
    let segment: ReasoningSegment

    var body: some View {
        switch segment {
        case .prose(let text):
            // The thinking is the model's private scratchpad (= its own
            // markdown-ish notes, = indented the way it indents its
            // notes), = so it is read as plain text: = the markers and
            // the indentation go, = the words stay. (= hermes renders
            // the same block as a scratchpad, = never as app chrome.)
            // .caption (= smaller than the main text) + .secondary tone
            // (= the standard product "supplementary content" tone).
            MarkdownBlocksView(text: text, baseFont: .caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        case let .action(text), let .result(text):
            // A step the assistant took, labelled so the reader can tell
            // an attempt from an outcome. The label is what makes the
            // difference: without it, "reading the outline" and "the
            // outline has three parts" look like the same kind of line.
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingTight) {
                Text(label)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                MarkdownBlocksView(text: text, baseFont: .caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var label: String {
        switch segment {
        case .action: return String(localized: "chatview.reasoning.action")
        case .result: return String(localized: "chatview.reasoning.result")
        case .prose: return ""
        }
    }
}

/// The steps the assistant performed, as a running log.
private struct ToolActivityList: View {
    let activity: [ToolActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            ForEach(activity) { step in
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingTight) {
                    Text(step.kind == .action
                        ? String(localized: "chatview.reasoning.action")
                        : String(localized: "chatview.reasoning.result"))
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                    Text(step.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// T40-THINKING-FADEIN (2026-09-18): a static helper that produces
/// the standard fade-in transition for a reasoning part. Used by
/// the ChatPartRow container when it inserts / removes a
/// ChatReasoningPartView in response to streaming events.
extension AnyTransition {
    /// T40 standard transition (= fade-in + settle from above).
    ///   - duration: this transition sets NO duration — the call sites
    ///     run under `.animation(.default, value:)` from
    ///     `ChatPartView.swift:146` (= wenshu-tuned; the HIG publishes no
    ///     duration figures. The craft audit's corpus quotes NN/g's
    ///     100–500 ms animation range as third-party research, not Apple
    ///     policy — quoted, never measured here).
    ///   - opacity: 0 -> 1
    ///   - movement: `.move(edge: .top)` translates the view DOWN into
    ///     position by its own height (= there is no fixed 4pt literal in
    ///     this code; reads as "drop into place")
    ///
    /// T40 implementation note: implemented as a STATIC FUNCTION
    /// (not a stored property) to satisfy Swift 6 strict concurrency
    /// (= AnyTransition is not Sendable, so a static let at file
    /// scope triggers MutableGlobalVariable). The function is
    /// @MainActor-isolated (= it is only ever called from SwiftUI
    /// view bodies which run on the main actor).
    @MainActor
    static func wenshuThinkingAppear() -> AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        )
    }
}

// MARK: - Tool-use part (= hermes ToolCallMessagePart)

// Render a `.toolUse(ToolUsePart)` part (= the model invokes a tool
// = Hermes ToolCallMessagePart = wenshu's internal `toolUse` from
// `LLMBlock.toolUse`).
//
// Rendered as an inline card (= Apple Mail / Notes "block quote"
// style = a thin left border + lighter background + small status
// dot + tool name + collapsed args). Click to expand the JSON args.
// Mirrors the Hermes `ToolFallback` component (= wenshu's
// generalized fallback for any tool call, whatever the model names).
