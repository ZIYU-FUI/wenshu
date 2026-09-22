//
//  ChatReasoningPartView.swift · Wenshu · refactor chat-mvvm-3layer C-9b
//
//  Apple MVVM canonical part view: renders one reasoning block
//  (= the "thinking…" trace that shows what the assistant considered
//  before replying). Lifted out of ChatPartView.swift so:
//
//  - The chat part surface follows 1-view-1-file (= Apple HIG
//    canonical file-per-view).
//  - Reasoning rendering can evolve independently of text/tool/result
//    part rendering (= hermes 1:1 = reasoning gets its own card;
//    = wenshu mirrors the same separation).
//
//  Boss 2026-09-22 '目标 UI，业务，数据，三分离':
//  UI-only (= no business logic; = the reasoning string comes
//  straight from ChatMessagePart.ReasoningPart.text).
//
//  hermes 1:1 (= assistant-message.tsx + message-parts.tsx):
//  - Collapsed by default (= Apple HIG footnote convention).
//  - On expand: shows the reasoning content in a slightly-quieter
//    foreground + monospaced font (= the "internal log" affordance).
//  - isRunning pulse (= the wenshu StatusPulse private struct) is
//    rendered inline as the row identity when still streaming.
//

import SwiftUI

public struct ChatReasoningPartView: View {
    public let text: String
    public let isRunning: Bool
    // v1.65-cleanup E2 boss 2026-09-21 OOB 'AI 思考过程不显示' (= the
    // thinking content was collapsed by default; = the user could see
    // only the brain-head-profile icon and the "AI thought for Xs"
    // label, = effectively no visible thinking content). Default to
    // expanded so the reasoning text is always visible (= matches
    // hermes assistant-message.tsx: where the reasoning block sits
    // inline with the message body, = visible by default). The user
    // can collapse it manually via the disclosure chevron.
    @State private var isExpanded: Bool = true

    public init(text: String, isRunning: Bool = false) {
        self.text = text
        self.isRunning = isRunning
    }

    public var body: some View {
        // Apple HIG footnote pattern (= the DisclosureGroup is the
        // canonical SwiftUI collapse/expand control = identical to
        // Mail / Notes "Show Details" toggles). Renders a label +
        // chevron that the user clicks to expand.
        DisclosureGroup(isExpanded: $isExpanded) {
            // Reasoning content (= same markdown treatment as the
            // text part = inline bold/italic/code works). Use .caption
            // (= smaller than the main text) + .secondary tone (= the
            // standard Apple HIG "supplementary content" tone).
            Text(Self.renderMarkdown(text))
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, DesignTokens.chromePaddingMicro)
                .transition(.opacity)
        } label: {
            // v1.65-cleanup E2 boss 2026-09-21 OOB 'AI 思考过程不显示'
            // (= the brain-head-profile icon was C2-era wenshu-side chrome
            // that hermes真值 does NOT use; = status.tsx ResponseLoadingIndicator
            // is a 3×3 PT StatusPulse square, no icon). Drop the icon; =
            // a small grayer caption label is enough to identify the
            // thinking section. The label flips between running + finished
            // (= the Hermes `thoughtFor` / `thoughtBriefly` / `thought`
            // state machine = simplified to a 2-state label here).
            Text(isRunning
                 ? WenshuI18n.t("chatview.ai_thinking")
                 : WenshuI18n.t("chatview.ai_thought"))
                .font(.caption)
        }
        .animation(.default, value: isExpanded)
    }

    /// T17: opacity value driven by a TimelineView so the pulse
    /// animates without needing external state mutation. Starts at
    /// 1.0 (= visible) and animates to 0.4 and back (= subtler than
    /// going fully invisible). `private` so the view body can read
    /// it directly without exposing the TimelineView as part of the
    /// public surface.
    // v1.65-cleanup E2 boss 2026-09-21 OOB 'AI 思考过程不显示': removed
    // the brain-head-profile icon + the runningOpacity pulse animation
    // (= was driving the icon's 0.4 -> 1.0 -> 0.4 oscillation). The
    // thinking section is now a small caption label (= "AI 已思考" /
    // "AI 思考中") with no icon, no pulse

    /// Reasoning text also uses inline markdown (= reasoning often
    /// contains structure like `**KEY POINT**: ...`).
    private static func renderMarkdown(_ raw: String) -> AttributedString {
        ChatTextPartView.parseMarkdown(raw)
    }
}

// T40-THINKING-FADEIN (2026-09-18): a static helper that produces
// the standard fade-in transition for a reasoning part. Used by
// the ChatPartRow container when it inserts / removes a
// ChatReasoningPartView in response to streaming events.
extension AnyTransition {
    /// T40 standard transition (= fade-in + small upward slide,
    /// = Apple HIG "appear from above" affordance).
    ///   - duration: 0.3s (= matches Apple HIG 0.2-0.4s range for
    ///     content insertion)
    ///   - opacity: 0 -> 1
    ///   - movement: 4pt upward (edge: .top, so the view slides
    ///     DOWN into position; = reads as "drop into place")
    ///
    /// T40 implementation note: implemented as a STATIC FUNCTION
    /// (not a stored property) to satisfy Swift 6 strict concurrency
    /// (= AnyTransition is not Sendable, so a static let at file
    /// scope triggers MutableGlobalVariable). The function is
    /// @MainActor-isolated (= it is only ever called from SwiftUI
    /// view bodies which run on the main actor).
    @MainActor
    public static func wenshuThinkingAppear() -> AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        )
    }
}

// MARK: - Tool-use part (= hermes ToolCallMessagePart)

/// Render a `.toolUse(ToolUsePart)` part (= the model invokes a tool
/// = Hermes ToolCallMessagePart = wenshu's internal `toolUse` from
/// `LLMBlock.toolUse`).
///
/// Rendered as an inline card (= Apple Mail / Notes "block quote"
/// style = a thin left border + lighter background + small status
/// dot + tool name + collapsed args). Click to expand the JSON args.
/// Mirrors the Hermes `ToolFallback` component (= wenshu's
/// generalized fallback for any tool call = since v0.71 P1 batch 2
