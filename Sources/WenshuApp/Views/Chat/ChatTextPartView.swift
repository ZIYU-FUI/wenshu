//
//  ChatTextPartView.swift · Wenshu · refactor chat-mvvm-3layer C-9a
//
//  Apple MVVM canonical part view: renders one text block (= the
//  canonical "the assistant said this" cell). Lifted out of
//  ChatPartView.swift (= 929 lines = a multi-view file) so:
//
//  - The chat part surface follows 1-view-1-file (= Apple HIG
//    canonical file-per-view; = future changes are scoped to
//    one file).
//  - Each part view is independently testable + Xcode-previewable.
//  - The file no longer has 8 types crammed together (= easier to
//    navigate the type catalog).
//
//  Boss 2026-09-22 '目标 UI，业务，数据，三分离':
//  UI-only (= no business logic; = pure text rendering with optional
//  streaming cursor).
//
//  Streaming cursor (= the blinking caret at the end of an in-flight
//  reply): the cursor blinks at ~0.5 Hz while the part is the
//  latest streamed block (= isStreaming == true); = the per-block
//  CursorType enum drives the visual.
//
//  Outgoing color: user-side text gets the .primary tint + 95%
//  opacity (= hermes 1:1 user-message.tsx:386 'text-foreground/95').
//  Assistant-side text gets .secondary (= hermes 1:1 assistant-
//  message.tsx:292 'text-foreground'). Applied via the outer
//  ChatMessageBodyView's `.foregroundStyle(roleForeground)`, not here
//  (= this leaf stays presentational).
//

import SwiftUI

public struct ChatTextPartView: View {
    public let text: String
    public let isOutgoing: Bool
    public let isStreaming: Bool
    @State private var isCursorOn: Bool = true

    public init(text: String, isOutgoing: Bool, isStreaming: Bool = false) {
        self.text = text
        self.isOutgoing = isOutgoing
        self.isStreaming = isStreaming
    }

    public var body: some View {
        // v0.55 boss 2026-09-09 OOB 'use the ones we have not used yet':
        // AttributedString(markdown:) parses inline markdown natively
        // (= bold / italic / code / links show as formatting = not raw
        // asterisks). Falls back to plain string when not valid markdown.
        // `.inlineOnlyPreservingWhitespace` blocks are excluded (= those
        // would require a full markdown renderer = out of scope for this
        // batch).
        //
        // T42-STREAM-CURSOR (2026-09-18): when isStreaming, render the
        // text with a trailing blinking cursor (▎) at the end. The
        // cursor's on/off state oscillates via a TimelineView
        // (= .periodic(from: .now, by: 0.5)) so it blinks every 0.5s
        // (= matches the Apple Messages / Slack typing indicator
        // cadence). Hidden when isStreaming = false (= the message is
        // sealed; = no cursor).
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(Self.parseMarkdown(text))
                .textSelection(.enabled)
                // Streaming replies grow token by token. The default Text
                // transition re-renders the whole run; this one interpolates
                // so the bubble does not flicker on every chunk.
                .contentTransition(isStreaming ? .interpolate : .identity)
                // v1.65-cleanup E2 boss 2026-09-21 OOB 'no gray text like
                // hermes' (= the assistant reply was rendered as full
                // white because ChatTextPartView hardcoded
                // `.foregroundStyle(Color.primary)`; = overrode the parent
                // `.secondary` tint applied by ChatMessageBodyView per
                // hermes 1:1). Drop the local override and let the parent
                // tint win: assistant text = .secondary (= muted gray on
                // dark background; = matches hermes assistant-message.tsx
                // styling), user text = .primary (= full brightness; =
                // matches hermes user-message.tsx text-foreground/95).
            if isStreaming {
                // T42 blinking caret (= white-on-cursor / vertical bar)
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    // Toggle visibility every 0.5s (= matches Apple's
                    // text-cursor cadence in NSTextView).
                    let elapsed = context.date.timeIntervalSinceReferenceDate
                    let phase = Int(elapsed / 0.5) % 2 == 0
                    Text("▎")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.primary)
                        .opacity(phase ? 1.0 : 0.0)
                        // T61-CURSOR-HELP (2026-09-18): a .help()
                        // tooltip on the streaming cursor that
                        // explains the visual cue (= "Generating
                        // response..."). Helps screen-reader users
                        // + adds context for hover users (= a
                        // visible streaming cursor without
                        // surrounding text could be confusing;
                        // = the tooltip clarifies it).
                        .help(Self.streamingCursorTooltip)
                }
            }
        }
    }

    /// Parse the text as inline markdown (= canonical SwiftUI path).
    /// Falls back to plain string when the markdown parse fails.
    /// Marked `nonisolated` so it can be called from test contexts
    /// without `@MainActor` isolation (= the function is a pure
    /// utility that doesn't touch any view state).
    /// T42-HELPER (2026-09-18): the localized tooltip string
    /// for the streaming cursor. Helps screen-reader users
    /// understand the blinking ▎ affordance (= "Generating
    /// response...").
    /// nonisolated (= pure constant; = testable from XCTest).
    nonisolated static var streamingCursorTooltip: String {
        WenshuI18n.t("chatview.streaming_cursor.generating")
    }

    nonisolated static func parseMarkdown(_ raw: String) -> AttributedString {
        (try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(raw)
    }
}

// MARK: - Reasoning part (= hermes ReasoningMessagePart)

/// Render a `.reasoning(String)` part (= CoT / hidden thinking =
/// Hermes ReasoningTextPart = the model's internal monologue).
///
/// Hermes renders reasoning as a collapsible `<DisclosureGroup>` with
/// a `ScaffoldRow` header (= "Thinking…" label + elapsed timer + a
/// shimmer animation while running). wenshu's existing DisclosureGroup
/// is the canonical Apple HIG equivalent (= no custom scaffold row =
/// Apple default = boss's 'anything that uses Apple styles should default everything' OOB).
///
/// The `isRunning` parameter (= true when the model is still thinking)
/// controls:
///   • the label text ("Thinking…" vs "Thinking trace" = "finished")
///   • the icon (= Lucide `brain` + .shimmer-like Pulse animation
///     while running)
