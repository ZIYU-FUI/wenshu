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
//  The body is drawn inside a bounded rectangle (= ReasoningScrollBox):
//  the trace scrolls inside the rectangle instead of pushing the
//  transcript down, so the transcript's height does not follow the
//  length of the thinking. While the turn runs the rectangle follows
//  the new words, and it stops as soon as the reader scrolls up.
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
            ReasoningScrollBox {
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
            }
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

/// The distance from the bottom within which the reader is still following
/// the stream inside the reasoning rectangle.
///
/// The slack keeps the gate from flapping on a sub-pixel difference at the
/// bottom.
private let reasoningFollowThreshold: CGFloat = 24

/// The anchor the reasoning rectangle's follow scrolls to (= the end of the
/// body).
private let reasoningBottomAnchor = "reasoning-bottom"

/// The reasoning rectangle's own scroll geometry (= what the gate is read
/// from).
private struct ReasoningScrollGeometry: Equatable {
    /// How far the rectangle is scrolled.
    let offset: CGFloat
    /// The height of the words inside it.
    let contentHeight: CGFloat
    /// The height of the rectangle itself.
    let containerHeight: CGFloat

    /// How far the reader is from the bottom.
    var gap: CGFloat {
        contentHeight - offset - containerHeight
    }
}

/// The rectangle a reasoning body is read in.
///
/// The body scrolls inside the rectangle, so a long trace does not push
/// the transcript down: the transcript's height then does not follow the
/// length of the thinking. While the turn runs the rectangle follows the
/// new words (= it scrolls to its own bottom), and it stops the moment
/// the reader scrolls up (= the reader's position wins, and the new
/// words pile up below it).
///
/// The gate is the reader's distance from the bottom: within the
/// threshold the reader is still following the stream, and past it the
/// reader has taken over. The threshold carries a little slack, so a
/// sub-pixel difference at the bottom cannot make the gate flap.
private struct ReasoningScrollBox<Content: View>: View {
    /// The body the rectangle holds.
    @ViewBuilder let content: Content
    /// Whether the reader is still at the bottom of the rectangle.
    @State private var following = true
    /// The height the body had the last time it was measured.
    ///
    /// It starts EMPTY (= no measurement yet), = = not at -1: a -1 is
    /// smaller than every real height, = = so the first measurement
    /// would look like growth, = = and a FINISHED trace (= one that is
    /// not growing any more) would scroll to its tail before the reader
    /// had done anything (= = the reader's place inside the rectangle
    /// was lost, = = and the `LazyVStack` builds the row again when it
    /// scrolls out of the viewport, = = so every re-realization landed
    /// back at the tail).
    @State private var lastContentHeight: CGFloat?
    /// The offset the rectangle was at the last time it was measured.
    @State private var lastOffset: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
                    .id(reasoningBottomAnchor)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _, new in
                        // The body grew (= the stream added words), so the
                        // rectangle follows it while the reader is at the
                        // bottom. A width change also lands here, so the
                        // growth is what opens the gate.
                        //
                        // The FIRST measurement is not a growth: there is
                        // nothing to compare it with yet, = = so it only
                        // records the height. A body that is not growing
                        // (= a finished trace) therefore never scrolls on
                        // its own, = = and the reader finds the top of
                        // the trace where they left it.
                        guard let previous = lastContentHeight else {
                            lastContentHeight = new
                            return
                        }
                        let grew = new > previous
                        lastContentHeight = new
                        guard grew, following else { return }
                        proxy.scrollTo(reasoningBottomAnchor, anchor: .bottom)
                    }
            }
            // The cap is a maximum, not a height: a short trace holds a
            // short rectangle, and a long one scrolls inside the cap.
            //
            // The rectangle is ALWAYS bounded: a block the reader took
            // over is drawn whole was a shape that never shipped (= the
            // parameter had no caller), = = so the shape the app draws
            // is the one the record describes.
            .frame(maxHeight: DesignTokens.reasoningBoxMaxHeight)
            // The system's own scroll indicator (= the reader is told the
            // rectangle scrolls; = it is never hidden).
            .scrollIndicators(.automatic)
            // The rectangle says where it ends.
            //
            // A scroller that draws nothing at its edges (= the overlay
            // indicator only paints while the reader scrolls, = and a
            // body of plain text has no background of its own) looks
            // like a cut-off line of words: the reader cannot tell that
            // there is more below. The edge is a hairline in the
            // divider colour the app already uses for separators.
            .overlay(alignment: .bottom) {
                Rectangle()
                    // The system's own separator colour (= = the app's
                    // precedent: `InspectorStyleRule` draws its rule
                    // with `Color(nsColor: .separatorColor)`).
                    //
                    // NOT a hand-mixed alpha (= = the app's own rule:
                    // "hand-rolled alphas do not follow Dark Mode or
                    // Increase Contrast"), = = and not `.secondary`
                    // (= = that is a text tier, = = not a line).
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: DesignTokens.dividerHeight)
            }
            .onScrollGeometryChange(for: ReasoningScrollGeometry.self) { geometry in
                ReasoningScrollGeometry(
                    offset: geometry.contentOffset.y,
                    contentHeight: geometry.contentSize.height,
                    containerHeight: geometry.containerSize.height
                )
            } action: { _, geometry in
                // The gate is read when the RECTANGLE MOVED (= the reader
                // scrolled), and not when the words grew: a body that
                // grows under a reader who is at the bottom must not be
                // mistaken for a reader who scrolled away.
                let moved = geometry.offset != lastOffset
                lastOffset = geometry.offset
                guard moved else { return }
                following = geometry.gap < reasoningFollowThreshold
            }
        }
    }
}

/// One labelled step of the assistant's reasoning.
private struct ReasoningSegmentView: View {
    let segment: ReasoningSegment

    var body: some View {
        switch segment {
        case let .prose(text):
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
