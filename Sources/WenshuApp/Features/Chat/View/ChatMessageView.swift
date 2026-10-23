//
//  ChatMessageView.swift
//
//  Split out of ChatView.swift (originally line 1702-1954; = 252 LOC
//  = the per-message sub-view body). The split removes the
//  per-message bubble rendering from ChatView (= 1954 LOC → 1702
//  LOC = -13% LOC; = the first god-view split step).
//
//  Per work-tree spec: extract ChatMessageView (which is
//  already a self-contained struct with 4 SwiftUI dependencies =
//  ChatBubble / ChatBubblePosition / ChatBubbleShape / ChatMessage /
//  DesignTokens / String(localized:); = the only cross-file references are
//  these types which are all in wenshu-app internal scope; = safe
//  to extract).
//
//  No behavior change: ChatMessageView stays `internal` (= same module
//  visibility as before the split; = ChatView.swift and ChatMessageView.swift
//  live in the same wenshu-app Swift module).
//
//  Callers (= 1 site, ChatView.swift:1103): unchanged.
//
import AppKit
import SwiftUI

/// One chat-message view (Apple HIG ground truth)
struct ChatMessageView: View {
    let message: ChatMessage
    /// True when this row is the most recent
    /// user (= .user source) message in the transcript. Hermes
    /// (`user-message.tsx:30-55` `StickyHumanMessageContainer`)
    /// pins the latest user bubble to the top of the scroll
    /// viewport via `position: sticky; top: 0` (= the bubble
    /// scrolls with the rest until it reaches the viewport top,
    /// then it pins there). The SwiftUI equivalent is the
    /// `.sticky(top:)` modifier; we apply it ONLY to the latest
    /// user message (= the historical user messages scroll
    /// normally, no overlap stack at the top).
    ///
    /// The `top: 80` offset (= the chat input row height) lets the
    /// sticky bubble park ABOVE the floating input row instead of
    /// underneath (= the same `sticky-human- top` reservation
    /// hermes uses in list.tsx for the secondary window titlebar case;
    /// wenshu uses 80 PT for the floating input instead). z-index
    /// places the sticky bubble above the transcript content but below
    /// the titlebar.
    /// (see OOB.md #2026-09-21) — sticky behavior reverted; = the
    /// parameter is accepted by the init (= API compatibility) but
    /// no stored property is kept.
    /// T24-PLAN-APPROVE: callback invoked when the user clicks
    /// Approve & Run on a plan card. The closure is provided by the
    /// parent ChatView (= the closure submits the plan's original
    /// query back into the chat zone as a user message; = the LLM
    /// sees both the plan (= via chat history) and the question; =
    /// produces an answer). Nil = the Approve button is hidden (= the
    /// user can still read the plan, they just can't re-invoke).
    let onApprovePlan: ((Plan) -> Void)?
    @State private var thinkingExpanded: Bool = false
    /// T26-HOVER-TIMESTAMP: true when the user is hovering the
    /// timestamp footer (= expands the time to a full date; = Apple
    /// Messages hover affordance).
    @State private var isTimestampHovered: Bool = false

    init(
        message: ChatMessage,
        isLatestUser: Bool = false,
        onApprovePlan: ((Plan) -> Void)? = nil
    ) {
        self.message = message
        // (see OOB.md #2026-09-21) — isLatestUser is accepted for API
        // compatibility (= the sticky-top attempt was
        // reverted; = external callers still pass it; = accepting the
        // value here keeps the public surface stable for the next
        // ticket that may reintroduce sticky in a different form).
        _ = isLatestUser
        self.onApprovePlan = onApprovePlan
    }

    /// Parses a message body as markdown for display.
    ///
    /// `.inlineOnlyPreservingWhitespace`, not `.full`. Verified by parsing
    /// a multi-paragraph sample three ways: `.full` applies block intents
    /// and drops every newline, so a model reply arrives as one run-on
    /// block; the inline-preserving option keeps all 5 newlines and still
    /// resolves bold, code spans and links. Chat bubbles want inline
    /// formatting with the author's line breaks intact, which is exactly
    /// that option.
    ///
    /// Invalid markdown falls back to the plain string rather than
    /// throwing, so a stray bracket never blanks a message.
    static func markdown(_ raw: String) -> AttributedString {
        (try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(raw)
    }

    var body: some View {
        // :
        // drop the iMessage-style bubble + avatar-run-merge path (= the
        // (see OOB.md)) and render per Hermes:
        //   - user row: `apps/desktop/src/components/assistant-ui/
        //     thread/user-message.tsx:67-69` rounded-xl glass card with
        //     bg fill + border (= MC2).
        //   - assistant row: `assistant-message.tsx:275-282`
        //     `self-start` flat text, no background / no rounded / no tail
        //     (= MC1).
        // The source label row + body row + footer + attachments stay
        // identical to the MC1 layout; the only structural change in
        // MC2 is the OUTER wrapper that hosts the glass card for
        // outgoing (= user) messages.
        //
        // STICKY NOTE: hermes user-message.tsx:46 renders the latest user
        // bubble sticky at the top of the scroll viewport. wenshu already
        // has the floating chat input row claiming that scroll-viewport
        // top zone (= floating-chat-input), so a sticky user bubble
        // would overlap the input. MC2 deliberately drops the sticky
        // behaviour. If a future ticket wants to re-introduce it, the
        // right hook is a `.sticky()` modifier on the userCard wrapper
        // below plus a `z-index` above the floating input but below the
        // titlebar.
        messageContents
                    .modifier(UserGlassCardModifier(isOutgoing: isOutgoing))
                    // The row fills the chat column; the outgoing card
                    // takes the trailing corner (= the side the user's
                    // own words come from), the assistant row keeps its
                    // flat leading text.
                    .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
                    // AI rows get a 10 PT horizontal padding (= total
                    // 20 PT from chat column edge to AI text after the
                    // inner card padding of 10 PT; = matches the
                    // requested AI-row left/right gutter). User rows
                    // pass through (= their glass-card L2 inner padding
                    // in UserGlassCardModifier is the SOLE source of
                    // user horizontal padding; = unchanged).
                    .padding(.horizontal, isOutgoing ? 0 : 10)
                    // 
                    //
                    // Apple SwiftUI on macOS 27 does NOT expose CSS `position:
                    // sticky` (= no `.sticky()` modifier). The closest
                    // 1:1 implementation uses 3 SwiftUI public primitives:
                    //
                    //   1. `.padding(.top, 80)` on the latest user row
                    //      (= reserves the floating-chat-input zone;
                    //      = the row sits ABOVE the input instead of
                    //      underneath).
                    //   2. `.zIndex(40)` on the latest user row (= mirrors
                    //      hermes `z-40`; = the row floats above
                    //      assistant content that scrolls beneath it).
                    //   3. ChatView's `ScrollViewReader` runs
                    //      `proxy.scrollTo(latestUserID, anchor: .top)`
                    //      whenever latestUserID changes (= a new user
                    //      message arrives; = the scroll viewport pins the
                    //      latest user row to the top edge; = CSS-like
                    //      `position: sticky; top: 0` in effect).
                    //
                    // The remaining gap from hermes (= Apple API
                    // limitation, documented per the directive 'Apple API 
                    // '):
                    //   -  hermes: `position: sticky; top: 0` is a
                    //     continuous scroll-tracking behavior (= the row
                    //     scrolls with the transcript and pins when it
                    //     reaches the viewport top; = the user can scroll
                    //     up and back without the sticky row "yanking"
                    //     them).
                    //   - wenshu 1:1 here: `scrollTo(anchor: .top)` is a
                    //     DISCRETE scroll event. When the user scrolls up to
                    //     read history and then a new message arrives, the
                    //     scrollTo pins the new latest row at the top (= the
                    //     user is yanked back). This is jarring but it's the
                    //     closest the Apple public API gets without an
                    //     NSScrollView bridge (= 1-2 week ticket; = future).
                    //
                    // historical user rows (= non-latest) get neither the
                                        // 80 PT padding nor the zIndex (= they scroll normally
                                        // without overlap with the floating input; = matches
                                        // the MC1 flat-text self-start behavior).
                                        //
                                        // -cleanup E3: the latest user message card was padded 80 PT down
                                        // inside the LazyVStack but did NOT actually stick
                                        // to the top of the chat viewport (= the row
                                        // scrolled out of view when the user scrolled back
                                        // to read history; = the 80 PT padding was an empty
                                        // visual gap below the floating chat input panel;
                                        // = wrong). The real sticky-top behavior now lives
                                        // in ChatView's `.safeAreaInset(edge: .top)` overlay
                                        // (= the latest user row is mounted as a SwiftUI
                                        // safeAreaInset overlay that floats above the scroll
                                        // content; = does not scroll with the user; =
                                        // matches hermes user-message.tsx:46 `sticky z-40`
                                        // 1:1). The in-LazyVStack row for the latest user
                                        // message id is now a 0-height placeholder
                                        // (= scroll anchor target; = no visual contribution
                                        // since the overlay renders the same id). The
                                        // padding + zIndex modifiers below are no-ops for
                                        // the latest-user case; = kept for backward
                                        // compatibility with older wenshu chat views that
                                        // don't have the safeAreaInset overlay (= if some
                                        // other chat zone still uses ChatMessageView
                                        // directly without the overlay, the 80 PT padding
                                        // and zIndex 40 still rescue that older layout
                                        // from floating-input overlap).
                                        // legacy: used to apply `.padding(.top, 80) +
                                        // .zIndex(40)` for the latest user row (= E3
                                        // sticky-top attempt; = reverted). All user rows
                                        // render normally inside the LazyVStack now (= no
                                        // padding-top or zIndex override).
            }

    /// The row's content (= source label row + body row + footer +
    /// attachments). Identical structure for user + assistant rows;
    /// the glass card wraps this when the row is outgoing.
    @ViewBuilder
    private var messageContents: some View {
        // -cleanup E3: the user text inside the glass card was
        // right-aligned (= expected: left-aligned text reading like
        // iMessage / Slack / hermes). Root cause: the inner VStack
        // (= messageContents) was using .trailing alignment for outgoing
        // rows; = all child elements (= ChatMessageBodyView text +
        // timestamp footer + image thumbnail) anchored to the right
        // edge of the card. Override: outgoing rows now use .leading
        // for the inner VStack (= text reads left-to-right from the
        // leading edge of the card); the OUTER frame in the body still
        // uses .trailing alignment to push the entire card to the
        // trailing edge of the chat column. Net visual: card is on
        // the right (= outer alignment), but text inside reads from
        // the left (= inner alignment); = matches iMessage +
        // Slack + hermes user-message.tsx).
        VStack(alignment: .leading, spacing: 4) {
                // wenshu-side source label + icon chrome (= not in hermes):
                //   - user-message.tsx:240-585 (= full UserMessage scan) renders
                //     the user text with NO source label, NO avatar/icon, NO
                //     role text — only `UserMessageText` (= pure markdown) +
                //     the `bg-(--dt-user-bubble)` glass card wrapper.
                //   - assistant-message.tsx:106-340 (= full AssistantMessage
                //     scan) renders only `MESSAGE_PARTS` (= pure markdown) with
                //     `text-foreground` — NO source label, NO avatar/icon, NO
                //     role text.
                //   - The 1:1 hermes distinguishes user vs assistant by
                //     foreground color + container presence alone (= user has
                //     `bg-(--dt-user-bubble)`, assistant has none; user has
                //     `text-foreground/95`, assistant has `text-foreground`).
                //   - All wenshu-side chrome (= source label row + 9 icon +
                //     status dot + paperplane + checkmarks + PLAN badge) is
                //     REMOVED in this commit (= C1 of the cleanup arc).
                if message.isPlaceholder {
                    // C-8c (refactor chat-mvvm-3layer): placeholder
                    // row extracted to its own leaf view
                    // (Views/Chat/ChatMessagePlaceholderRow.swift).
                    // Contains the StatusPulse + hint text + elapsed
                    // timer (= hermes 1:1 ResponseLoadingIndicator).
                    // The pulse slot is generic so StatusPulse can
                    // stay private to ChatMessageView.swift (=
                    // hermes 1:1 leaf boundary).
                    ChatMessagePlaceholderRow(
                        hintText: message.content,
                        timestamp: message.timestamp
                    ) {
                        StatusPulse()
                    }
                } else {
                    // 
                    // zone isn't implemented... port the whole thing from hermes... The editor uses SM,
                    // a third-party Markdown editor we brought in'): the canonical
                    // 1:1 Hermes streaming UI. Renders message.parts[]
                    // (= the Hermes canonical state) via ChatMessageBodyView
                    // (= text / reasoning / tool_use / tool_result each
                    // have their own inline render).
                    //
                    // ChatMessageBodyView wraps each part in the bubble
                    // background (= Apple HIG iMessage-style) and applies
                    // the streaming contentTransition to the text parts
                    // only (= the canonical SwiftUI "no flicker" pattern
                    //
                    // When parts is empty (= back-compat with previous
                    // messages that didn't carry parts), ChatMessageBodyView
                    // falls back to rendering message.content as a single
                    // text part (= the same Text(Self.markdown(...)) path
                    // we had before).
                    //
                    // The thinking DisclosureGroup + image thumbnail stay
                    // outside ChatMessageBodyView (= they're rendered
                    // above the parts array, = the conventional Apple
                    // HIG pattern of "supplementary content above the main
                    // content").
                    //
                    // Thinking collapsed: rendered as a DisclosureGroup
                    // (= Apple HIG footnote; = collapses by default;
                    // = expands on click). When parts[] is non-empty,
                    // the reasoning parts render via ChatReasoningPartView
                    // (= each part is its own collapsible block) — so we
                    // hide the legacy DisclosureGroup to avoid duplication.
                    // T1-THINKING-VISIBLE (2026-09-18): also hide when ANY .reasoning
                    // part is present in message.parts (= the new
                    // ChatReasoningPartView renders the reasoning as
                    // its own collapsible block; = legacy
                    // DisclosureGroup would render the same content
                    // a 2nd time as a duplicate).
                    let hasReasoningPart = message.parts.contains { part in
                        if case .reasoning = part.kind { return true }
                        return false
                    }
                    if message.parts.isEmpty && !hasReasoningPart, let thinking = message.thinking, !thinking.isEmpty, message.source == .wenshu {
                        // C-8b (refactor chat-mvvm-3layer): thinking
                        // DisclosureGroup extracted to its own leaf view
                        // (Views/Chat/ChatMessageThinkingDisclosure.swift).
                        // The collapse state stays on ChatMessageView's
                        // @State (= each message owns its own collapse).
                        // The collapsed-label slot is generic (any View)
                        // because StatusPulse is a private nested type
                        // in ChatMessageView.swift and stays there (=
                        // hermes 1:1 thinking identity).
                        ChatMessageThinkingDisclosure(
                            thinking: thinking,
                            isExpanded: $thinkingExpanded
                        ) {
                            // hermes = NO icon, NO 'chatview.ai_thinking'
                            // label, just the 3×3 PT StatusPulse square.
                            StatusPulse()
                        }
                    }
                    // CHATIMG-001: render attached image thumbnail above the parts.
                    // (= unchanged structure; = C2 dropped
                    // the wenshu-side Reveal-in-Finder button (= T34 +
                    // T35 i18n) — a macOS-specific add-on; = hermes
                    // has attachment directive chips inline with the
                    // bubble surface (= per user-message.tsx:415
                    // attachmentRefs.map). The thumbnail click now opens
                    // Preview directly without a separate reveal
                    // affordance; = the macro-free Mac-side reveal
                    // affordance is dropped, matching hermes.)
                    // C-8a (refactor chat-mvvm-3layer): image
                    // attachment preview extracted to its own leaf
                    // view (Views/Chat/ChatMessageAttachmentPreview.swift).
                    if let imagePath = message.imagePath {
                        ChatMessageAttachmentPreview(imagePath: imagePath)
                    }
                    // ChatMessageBodyView (= the
                    // Hermes-style per-part renderer) wraps each part
                    // in the bubble background. Falls back to the
                    // single-text rendering for legacy messages with no
                    // parts.
                    //
                    // 
                    // for OUTGOING messages (= user-sent), overlay
                    // ChatMessageHoverActions (= copy + delete buttons
                    // that fade in on hover = the Hermes MessageActions
                    // pattern). Agent messages don't get hover actions
                    // (= matches Hermes = the agent-side is read-only
                    // in the chat transcript = actions live on the
                    // user's own messages only).
                    ChatMessageBodyView(
                        message: message,
                        // MC2.1 streaming fix: `isStreaming` stays true
                        // for the full streaming lifecycle (= .streaming
                        // state) AND the initial placeholder. The
                        // previous `message.isPlaceholder` only was
                        // true during the placeholder row (= flipped
                        // off the instant the first streamCallback
                        // replaced the placeholder with the real
                        // message). After that flip ChatTextPartView's
                        // `.contentTransition` degraded from
                        // `.interpolate` to `.identity` AND the
                        // streaming cursor wasn't drawn. Combined: the
                        // user saw the text appear in one render
                        // (= the user's '' report).
                        //
                        // Hermes: assistant-message.tsx:346
                        // checks `s.message.status?.type === 'running'`
                        // = the same gate (= true for the entire
                        // active turn, not just the initial
                        // placeholder).
                        isStreaming: message.streamState == .streaming || message.isPlaceholder,
                        onApprovePlan: onApprovePlan
                    )
                    // -cleanup E6: dropped the inline `.padding(.horizontal, 12)`
                    // (= L1 in ChatView.swift is now the single source
                    // of truth for chat-column horizontal padding; =
                    // maintenance = one place to change). Kept the
                    // vertical chromePaddingVertical (= 8 PT; = row
                    // vertical breathing room; = matches Apple HIG
                    // py-2 vertical row gap convention).
                    .padding(.vertical, DesignTokens.spacingStandard)
                    .wenshuChatHover()
                }
                // T19-MESSAGE-TIMESTAMP (2026-09-18): render a small
                // timestamp footer below sealed assistant messages
                // (= same Apple HIG footer pattern as Apple Messages
                // = small monospaced text below the bubble showing
                // the time). Hidden for:
                //   - user messages (= iMessage doesn't show timestamps
                //     on user-sent bubbles; = the pattern lives below
                //     the bubble row in the conversation, not per-message)
                //   - streaming messages (= the cursor + shimmer
                //     communicate activity; = adding a stale timestamp
                //     here would be misleading)
                //   - system messages (= too noisy; = the bubble
                //     already includes the error icon)
                // C-8e (refactor chat-mvvm-3layer): sealed-message footer
                // extracted to its own leaf view
                // (Views/Chat/ChatMessageFooter.swift). Owns the
                // timestamp + token count + cost + NEW chip + divider
                // rendering, plus the 5 formatting helpers
                // (formatTokenCount / formatTokenCost /
                // fullTokenCountTooltip / fullTimestampTooltip /
                // comboFooterTooltip). Hover-state binding stays on
                // ChatMessageView's @State (= each message tracks
                // its own footer hover independently).
                if message.source == .wenshu && message.streamState == .sealed {
                    ChatMessageFooter(
                        timestamp: message.timestamp,
                        tokens: message.tokens,
                        isSealed: message.streamState == .sealed,
                        isTimestampHovered: $isTimestampHovered
                    )
                }
            }
            // Right-side spacer removed: with the left-gutter glyph
            // column above, every row is full-width from the avatar to
            // the right edge (= the Hermes `ROLE` glyph + flat body
            // pattern; = no right-edge trailing space).
            // L818: extra } removed (= previous HStack wrapper gone).
            // The assistant row fills the chat column (= its text
            // wraps at the column's trailing edge). The outgoing row
            // stays at its content's intrinsic width (= the bubble
            // takes its width from the words it carries).
            .frame(maxWidth: isOutgoing ? nil : .infinity, alignment: .leading)
    }

    /// Outgoing messages are the ones this person sent, which iMessage puts
    /// on the trailing side in the accent colour.
    private var isOutgoing: Bool { message.source == .user }

    /// T23-PLAN-BADGE: true when the message carries at
    /// least one Plan card.
}

/// Hermes user bubble surface per `apps/desktop/src/components/
/// assistant-ui/thread/user-message.tsx:67-69` `USER_BUBBLE_BASE_CLASS`.
///
/// In Tailwind the source is `rounded-xl border bg-(--dt-user-bubble)
/// px-3 py-2`. In SwiftUI on macOS 27 the bg is an Apple semantic
/// solid fill that tracks the user's appearance automatically (= the
/// `.bg-(--dt-user-bubble)` token's job). The bubble draws NO stroke:
/// on macOS a filled surface's own colour IS its edge (= the
/// composer field's Liquid Glass capsule is fill-only, so the two
/// surfaces agree by construction).
///
/// Activates only on outgoing (= user) messages; on assistant rows the
/// modifier is a pass-through (= no visual change from MC1's flat
/// self-start text).
/// Drop the wenshu-side chrome: the user bubble surface now uses an
/// Apple semantic solid fill
/// (`Color(nsColor: .unemphasizedSelectedTextBackgroundColor)`)
/// instead of the previous Liquid Glass `.regularMaterial` (= too
/// heavy vs hermes's subtle bg token). The bubble wears NO border:
/// its own solid fill is its edge (= the fill is a real step away
/// from the chat panel behind it, so a hairline on top of it would
/// read as a rim drawn over the shape rather than as the shape's
/// own boundary).
///
/// Card internal padding = 12 PT horizontal (= was 16 in MC6; = tighter,
/// matches hermes `px-3 py-2` from USER_BUBBLE_BASE_CLASS). Vertical
/// padding = 0 (= the card floors at the 36 PT resting chat-surface
/// height instead of padding itself taller; = the band matches the
/// composer field and grows with its own text).
///
/// 
/// remove the broken `.frame(maxWidth: 0.95, alignment: .trailing)` line.
/// Root cause: `maxWidth: 0.95` was treated as 0.95 PT (= less than 1 PT,
/// = essentially zero usable width); = the user card collapsed to a
/// single 1-2 PT vertical line in the center of the chat column while
/// the AI card passed through normally. The correct SwiftUI expression
/// is `.frame(maxWidth: .infinity, alignment: ...)` (= fills the parent's
/// horizontal extent; = the inner VStack trailing-aligns its children;
/// = the background draws at content intrinsic size and floats to the
/// trailing edge). This restores the v1.65 MC6 visual (= user bubble
/// wraps text, sits at trailing edge, full chat-column width available
/// for very long messages).
///
/// Activates only on outgoing (= user) messages; on assistant rows the
/// modifier is a pass-through (= no visual change from C1's flat
/// self-start text).
private struct UserGlassCardModifier: ViewModifier {
    let isOutgoing: Bool

    func body(content: Content) -> some View {
        if isOutgoing {
            // -cleanup E3.5: the user text inside the glass card is at
            // 12 PT horizontal padding (= the user card L2 inner padding
            // below is the SOLE source of horizontal padding for user
            // cards; = L1 in ChatView.swift is 0 PT = transcript content
            // sits flush against the chat column edge).
            // The card carries NO vertical padding of its own (= the
            // resting height comes from the frame floor below; = a grown
            // message keeps its own text height instead of being padded
            // twice; = the band matches the composer field height).
            //
            // The surface is the Apple semantic inactive-selection fill
            // (= an appearance-aware colour that resolves to a different
            // value in the light and the dark appearance). The previous
            // Liquid Glass fill collapsed to the chat panel's own colour
            // in the dark appearance, so the user's own words rendered as
            // text on a field of the same tone and became the least
            // readable text in the window.
            //
            // Shape = ChatSurfaceShape (= the shared chat-surface
            // outline; = the composer field wears the same shape, so the
            // two surfaces agree by construction).
            //
            // WIDTH: the bubble takes its width from the words it
            // carries and never grows past the canonical chat-bubble
            // width (= DesignTokens.chatBubbleMaxWidth). The fill is
            // painted BEFORE that cap on purpose: a fill painted after
            // a greedy frame spans the whole frame (= a slab across the
            // chat column), while a fill painted before it hugs the
            // words and the frame then only bounds the result.
            content
                .padding(.horizontal, DesignTokens.spacingModerate)
                .frame(minHeight: DesignTokens.controlHeightLarge, alignment: .leading)
                .background(
                    ChatSurfaceShape()
                        .fill(Color(nsColor: ChatUserBubblePalette.surface))
                )
                .frame(maxWidth: DesignTokens.chatBubbleMaxWidth, alignment: .trailing)
                .foregroundStyle(ChatUserBubblePalette.text)
        } else {
            content
        }
    }
}

// MARK: - Hermes user bubble surface per `apps/desktop/src/components/


// StatusPulse (= hermes `.tsx status-pulse.tsx` PULSE_DURATION_MS=400 +
// PULSE_PERIOD_MS=5000).
//
// 1:1 visual (= a small 3×3 PT rounded-2PT square that opacity-
// pulses 1 → 0.5 → 1 over 400 ms, then sleeps 5 seconds before
// the next pulse; = NOT a continuous breathing animation). The
// wenshu-side implementation uses SwiftUI's `TimelineView` for
// the 5 second tick (= scheduled against `PULSE_PERIOD_MS`) +
// `withAnimation(.easeInOut(duration: 0.4))` for the 400 ms
// opacity transition (= same visual rhythm as hermes's WAAPI
// `element.animate(...)`).
private struct StatusPulse: View {
    /// 5 second sleep between pulses (= matches hermes PULSE_PERIOD_MS).
    private static let pulsePeriod: TimeInterval = 5.0
    /// 400 ms opacity transition (= matches hermes PULSE_DURATION_MS).
    private static let pulseDuration: Double = 0.4

    @State private var isPulsing: Bool = false
    @State private var nextPulseAt: Date = .now.addingTimeInterval(pulsePeriod)

    var body: some View {
        // The 3×3 PT rounded-2PT square (= hermes `size-3
        // rounded-[2px] text-midground/80`). SwiftUI's tint is
        // mapped to Color.secondary (= Apple semantic for muted
        // foreground on the assistant transcript).
        RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip, style: .continuous)
            .fill(Color.secondary)
            .frame(width: DesignTokens.bulletDotSize, height: DesignTokens.bulletDotSize)
            .opacity(isPulsing ? 0.5 : 1.0)
            // 400 ms ease-in-out opacity transition (1 → 0.5 → 1).
            // The single keyframe `from→to` matches hermes's
            // `[{opacity:1}, {opacity:0.5}, {opacity:1}]` visual
            // rhythm (= the .easeInOut curve makes the fade out
            // + fade back in feel like a soft "breath" inside the
            // 400 ms window).
            .animation(
                .easeInOut(duration: Self.pulseDuration),
                value: isPulsing
            )
            // TimelineView ticks once every 5 seconds (= matches
            // hermes PULSE_PERIOD_MS); on each tick, if the
            // scheduled time has been reached, flip isPulsing (= one
            // pulse: 1 → 0.5 → 1 over the 400 ms animation).
            .onAppear { nextPulseAt = .now.addingTimeInterval(Self.pulsePeriod) }
            .background(
                TimelineView(.periodic(from: .now, by: Self.pulsePeriod)) { context in
                    Color.clear
                        .onChange(of: context.date) { _, now in
                            if now >= nextPulseAt {
                                nextPulseAt = now.addingTimeInterval(Self.pulsePeriod)
                                isPulsing.toggle()
                            }
                        }
                }
            )
    }
}
