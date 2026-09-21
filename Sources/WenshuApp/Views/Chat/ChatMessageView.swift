//
//  ChatMessageView.swift · Wenshu · v1.28 C3.4.1
//
//  Split out of ChatView.swift (originally line 1702-1954; = 252 LOC
//  = the per-message sub-view body). The split removes the
//  per-message bubble rendering from ChatView (= 1954 LOC → 1702
//  LOC = -13% LOC; = the first god-view split step).
//
//  Per work-tree v1.28 C3.4.1 spec: extract ChatMessageView (which is
//  already a self-contained struct with 4 SwiftUI dependencies =
//  ChatBubble / ChatBubblePosition / ChatBubbleShape / ChatMessage /
//  DesignTokens / WenshuI18n; = the only cross-file references are
//  these types which are all in wenshu-app internal scope; = safe
//  to extract).
//
//  No behavior change: ChatMessageView stays `internal` (= same module
//  visibility as before the split; = ChatView.swift and ChatMessageView.swift
//  live in the same wenshu-app Swift module).
//
//  Callers (= 1 site, ChatView.swift:1103): unchanged.
//
import SwiftUI

/// One chat-message view (Apple HIG ground truth)
struct ChatMessageView: View {
    let message: ChatMessage
    /// v1.65 boss 2026-09-21 'all 1:1 hermes真值, 文字回显就按
    /// hermes 的方式走': true when this row is the most recent
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
    /// The `top: 80` offset (= the v1.74 boss 拍 chat input row
    /// height) lets the sticky bubble park ABOVE the floating
    /// input row instead of underneath (= the same `sticky-human-
    /// top` reservation hermes uses in list.tsx for the secondary
    /// window titlebar case; wenshu uses 80 PT for the floating
    /// input instead). z-index places the sticky bubble above the
    /// transcript content but below the titlebar.
    var isLatestUser: Bool = false
    /// T24-PLAN-APPROVE (2026-09-18): callback invoked when the user
    /// clicks Approve & Run on a plan card. The closure is provided
    /// by the parent ChatView (= the closure submits the plan's original
    /// query back into the chat zone as a user message; = the LLM sees
    /// both the plan (= via chat history) and the question; = produces
    /// an answer). Nil = the Approve button is hidden (= the user can
    /// still read the plan, they just can't re-invoke).
    let onApprovePlan: ((Plan) -> Void)?
    @State private var thinkingExpanded: Bool = false
    /// T26-HOVER-TIMESTAMP (2026-09-18): true when the user is
    /// hovering the timestamp footer (= expands the time to a full
    /// date; = Apple Messages hover affordance).
    @State private var isTimestampHovered: Bool = false

    public init(
        message: ChatMessage,
        isLatestUser: Bool = false,
        onApprovePlan: ((Plan) -> Void)? = nil
    ) {
        self.message = message
        self.isLatestUser = isLatestUser
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

    /// T25-TOKEN-FOOTER (2026-09-18): format a token count for the
    /// sealed-message footer (= e.g. "1.5k tokens", "234 tokens",
    /// "12.3k tokens"). Uses the Apple HIG compact-number convention
    /// (= drop trailing zeros, cap at one decimal). `nonisolated` so
    /// tests can call it without instantiating the view (= SwiftUI
    /// value-typed views are not directly testable otherwise).
    nonisolated static func formatTokenCount(_ count: Int) -> String {
        if count < 1_000 {
            return "\(count) tokens"
        }
        if count < 10_000 {
            // 1.2k, 9.9k (= one decimal)
            let k = Double(count) / 1_000.0
            return String(format: "%.1fk tokens", k)
        }
        if count < 1_000_000 {
            // 12k, 234k, 999k (= no decimal)
            let k = count / 1_000
            return "\(k)k tokens"
        }
        // 1.2M, 234M (= one decimal)
        let m = Double(count) / 1_000_000.0
        return String(format: "%.1fM tokens", m)
    }

    /// T52-TOKEN-TOOLTIP (2026-09-18): full token count string
    /// for the .help() tooltip (= "1,500 tokens" vs the inline
    /// "1.5k tokens" compact format from T25/formatTokenCount).
    /// Uses NumberFormatter with .decimal style for the
    /// thousand-separator (= the user's locale-aware digit
    /// grouping; = matches the standard macOS number format
    /// in tooltips).
    nonisolated static func fullTokenCountTooltip(for count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let formatted = formatter.string(from: NSNumber(value: count)) ?? String(count)
        return "\(formatted) tokens"
    }

    /// T26-HOVER-TIMESTAMP (2026-09-18): Date.FormatStyle for the
    /// timestamp footer. Compact form by default (= "14:32");
    /// expanded form on hover (= "14:32 · 9月18日"). Apple's
    /// Date.FormatStyle uses the system locale (= automatically
    /// picks the user's preferred date format).
    private var timestampDisplayFormat: Date.FormatStyle {
        if isTimestampHovered {
            return .dateTime
                .hour().minute()
                .day().month()
        }
        return .dateTime.hour().minute()
    }

    /// T50-TIMESTAMP-TOOLTIP (2026-09-18): full ISO-format date
    /// string for the .help() tooltip on the timestamp text
    /// (= e.g. "2026-09-18 14:32:05"). Complements T26's on-hover
    /// format expansion: T26 = visible-in-text change to compact
    /// locale format, T50 = native tooltip with full ISO
    /// precision (= shows year + seconds that T26 omits).
    /// nonisolated (= pure utility function; = testable from
    /// XCTest without instantiating the view).
    nonisolated static func fullTimestampTooltip(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")  // ISO-style format
        return formatter.string(from: date)
    }

    /// T53-FOOTER-COMBO-TOOLTIP (2026-09-18): combined tooltip
    /// string for the entire sealed footer (= "1,500 tokens ·
    /// 2026-09-18 14:32:05"). Provides a one-glance summary when
    /// the user hovers the footer's empty space.
    ///   - tokens present + timestamp present → "X tokens · <ISO>"
    ///   - tokens only                       → "X tokens"
    ///   - timestamp only                    → "<ISO>"
    ///   - neither                           → ""
    nonisolated static func comboFooterTooltip(message: ChatMessage) -> String {
        var parts: [String] = []
        if let tokens = message.tokens, tokens > 0 {
            parts.append(fullTokenCountTooltip(for: tokens))
        }
        parts.append(fullTimestampTooltip(for: message.timestamp))
        return parts.joined(separator: " · ")
    }

    /// T58-ELAPSED-TIME (2026-09-18): format a TimeInterval as a
    /// human-readable "thinking for Xs" string.
    ///   - < 1s    → "0.3s" (one decimal)
    ///   - < 60s   → "3.2s" / "12.5s"
    ///   - >= 60s  → "1m 5s"
    ///   - < 0     → "0.0s" (defensive: clock skew)
    /// nonisolated (= pure utility function).
    nonisolated static func formatElapsed(_ seconds: TimeInterval) -> String {
        if seconds < 0 { return "0.0s" }
        if seconds < 60.0 {
            return String(format: "%.1fs", seconds)
        }
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(remainingSeconds)s"
    }

    /// T62-TOKEN-COST (2026-09-18): format an estimated USD cost
    /// for a given total token count.
    ///   - 0          → hidden (caller checks)
    ///   - < 0.01     → "≈ <$0.01" (= the cost is sub-cent)
    ///   - >= 0.01    → "≈ $X.XX" with 2 decimals
    /// Pricing: assumes the claude-sonnet-4-5 tier (= $3 / 1M input
    /// + $15 / 1M output). For other models the value is off by
    /// ~10x but the order-of-magnitude is correct (= the user gets
    /// a sense of "this cost cents vs dollars").
    nonisolated static func formatTokenCost(_ tokens: Int) -> String {
        guard tokens > 0 else { return "" }
        // Conservative average rate (= $9 / 1M tokens = the average
        // of input + output pricing for Sonnet 4.5). This is a
        // rough heuristic (= the user gets a sense of magnitude,
        // not an exact billing figure).
        let avgRatePerMillion: Double = 9.0
        let cost = Double(tokens) / 1_000_000.0 * avgRatePerMillion
        if cost < 0.01 {
            return "≈ <$0.01"
        }
        return String(format: "≈ $%.2f", cost)
    }

    var body: some View {
        // v1.65 boss 2026-09-21 'chat detail 1:1 hermes macOS desktop':
        // drop the iMessage-style bubble + avatar-run-merge path (= the
        // v0.57 boss OOB) and render per Hermes真值:
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
        // top zone (= v1.57-floating-chat-input), so a sticky user bubble
        // would overlap the input. MC2 deliberately drops the sticky
        // behaviour. If a future ticket wants to re-introduce it, the
        // right hook is a `.sticky()` modifier on the userCard wrapper
        // below plus a `z-index` above the floating input but below the
        // titlebar.
        messageContents
                    .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
                    .modifier(UserGlassCardModifier(isOutgoing: isOutgoing))
                    // v1.65 boss 'B = 试着补一下 sticky 真值':
                    //
                    // Apple SwiftUI on macOS 27 does NOT expose CSS `position:
                    // sticky` (= no `.sticky()` modifier). The closest
                    // 1:1 implementation uses 3 SwiftUI public primitives:
                    //
                    //   1. `.padding(.top, 80)` on the latest user row
                    //      (= reserves the v1.57-floating-chat-input zone;
                    //      = the row sits ABOVE the input instead of
                    //      underneath).
                    //   2. `.zIndex(40)` on the latest user row (= mirrors
                    //      hermes真值 `z-40`; = the row floats above
                    //      assistant content that scrolls beneath it).
                    //   3. ChatView's `ScrollViewReader` runs
                    //      `proxy.scrollTo(latestUserID, anchor: .top)`
                    //      whenever latestUserID changes (= a new user
                    //      message arrives; = the scroll viewport pins the
                    //      latest user row to the top edge; = CSS-like
                    //      `position: sticky; top: 0` in effect).
                    //
                    // The remaining gap from hermes真值 (= Apple API
                    // limitation, documented per boss 'Apple API 限制可
                    // 接受'):
                    //   - 真值 hermes: `position: sticky; top: 0` is a
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
                    // Historical user rows (= non-latest) get neither the
                    // 80 PT padding nor the zIndex (= they scroll normally
                    // without overlap with the floating input; = matches
                    // the MC1 flat-text self-start behavior).
                    //
                    // The safeAreaInset overlay from MC6 (= the visual
                    // fallback for Apple API limitation) is REMOVED in
                    // MC8 (= no double-render of the latest user bubble;
                    // = the in-LazyVStack row IS the latest user bubble;
                    // = zIndex 40 keeps it visible above scrolling
                    // assistant content).
                    .padding(.top, isOutgoing && isLatestUser ? 80 : 0)
                    .zIndex(isOutgoing && isLatestUser ? 40 : 0)
            }

    /// The row's content (= source label row + body row + footer +
    /// attachments). Identical structure for user + assistant rows;
    /// the glass card wraps this when the row is outgoing.
    @ViewBuilder
    private var messageContents: some View {
        VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                // v1.65 boss 2026-09-21 "just refer to HERMES, do 1:1; drop
                // wenshu-side source label + icon chrome that HERMES doesn't have":
                //   - user-message.tsx:240-585 (= full UserMessage scan) renders
                //     the user text with NO source label, NO avatar/icon, NO
                //     role text — only `UserMessageText` (= pure markdown) +
                //     the `bg-(--dt-user-bubble)` glass card wrapper.
                //   - assistant-message.tsx:106-340 (= full AssistantMessage
                //     scan) renders only `MESSAGE_PARTS` (= pure markdown) with
                //     `text-foreground` — NO source label, NO avatar/icon, NO
                //     role text.
                //   - The 1:1 hermes真值 distinguishes user vs assistant by
                //     foreground color + container presence alone (= user has
                //     `bg-(--dt-user-bubble)`, assistant has none; user has
                //     `text-foreground/95`, assistant has `text-foreground`).
                //   - All wenshu-side chrome (= source label row + 9 icon +
                //     status dot + paperplane + checkmarks + PLAN badge) is
                //     REMOVED in this commit (= C1 of the v1.65-cleanup arc;
                //     = boss 2026-09-21 "多做的，没用的，你就改掉").
                if message.isPlaceholder {
                    // v1.65 boss '思考中的那个效果不是 hermes 的效果':
                    // Hermes真值 (= status.tsx ResponseLoadingIndicator
                    // + status-pulse.tsx PULSE_DURATION_MS=400 +
                    // PULSE_PERIOD_MS=5000):
                    //   - A 3×3 PT rounded-2PT square (`size-3
                    //     rounded-[2px]`) tinted at text-midground/80.
                    //   - Animates opacity 1 → 0.5 → 1 over 400 ms
                    //     ease-in-out; then SLEEPS 5 seconds
                    //     (= PULSE_PERIOD_MS) before the next pulse.
                    //     NOT a continuous breathing animation.
                    //   - Sits inside a StatusRow (= flex self-start
                    //     = left-aligned with the assistant content).
                    //   - Followed by hint text + ActivityTimerText.
                    HStack(spacing: 6) {
                        StatusPulse()
                        Text(message.content)
                            .foregroundStyle(.secondary)
                        TimelineView(.periodic(from: .now, by: 0.5)) { context in
                            let elapsed = context.date.timeIntervalSince(message.timestamp)
                            Text(Self.formatElapsed(elapsed))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    // T87-STREAM-PULSE removed (= 1.6s scale breathing):
                    // hermes真值 `StatusPulse` (= 400 ms opacity pulse
                    // every 5 s) replaces it. The 1.6 s breathing was
                    // NOT what hermes does.
                } else {
                    // v0.71 P1 batch 2 (boss 2026-09-12 OOB 'streaming output in the chat
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
                    // from v0.55 boss OOB).
                    //
                    // When parts is empty (= back-compat with v0.34
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
                        DisclosureGroup(isExpanded: $thinkingExpanded) {
                            Text(thinking)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .padding(.top, DesignTokens.chromePaddingMicro)
                                .transition(.opacity)
                        } label: {
                            // v1.65-cleanup C2 boss 2026-09-21 'just refer to
                            // HERMES, do 1:1; drop the wenshu-side chrome':
                            // Hermes真值 thinking DisclosureGroup (= status.tsx
                            // ResponseLoadingIndicator + assistant-message.tsx)
                            // uses NO icon + NO 'chatview.ai_thinking' label —
                            // just the 3×3 PT StatusPulse square (= the
                            // wenshu StatusPulse private struct already
                            // implements this 1:1). The collapsed row in
                            // wenshu becomes the StatusPulse inline (= the
                            // user clicks to expand; the pulse is the row
                            // identity).
                            StatusPulse()
                        }
                        .animation(.default, value: thinkingExpanded)
                    }
                    // CHATIMG-001 (2026-09-07): render attached image
                    // thumbnail above the parts. (= unchanged structure
                    // but cleaned per v1.65-cleanup C2 boss 2026-09-21
                    // 'just refer to HERMES, do 1:1; drop the wenshu-side
                    // chrome': the Reveal-in-Finder button (= T34 +
                    // T35 i18n) was a macOS-specific wenshu-side add-on;
                    // hermes真值 has attachment directive chips inline
                    // with the bubble surface (= per user-message.tsx:415
                    // attachmentRefs.map). The thumbnail click now opens
                    // Preview directly without a separate reveal
                    // affordance; = the macro-free Mac-side reveal
                    // affordance is dropped, matching hermes真值.)
                    if let imagePath = message.imagePath {
                        if let nsImage = NSImage(contentsOfFile: imagePath) {
                            Button {
                                let url = URL(fileURLWithPath: imagePath)
                                NSWorkspace.shared.open(url)
                            } label: {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 240, maxHeight: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .padding(.bottom, DesignTokens.chromePaddingMicro)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(WenshuI18n.t("chat.message.imageMissing"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, DesignTokens.chromePaddingMicro)
                        }
                    }
                    // v0.71 P1 batch 2: ChatMessageBodyView (= the
                    // Hermes-style per-part renderer) wraps each part
                    // in the bubble background. Falls back to the
                    // single-text rendering for v0.34 messages with no
                    // parts.
                    //
                    // v0.71 P1 batch 2 (user message hover actions):
                    // for OUTGOING messages (= user-sent), overlay
                    // ChatMessageHoverActions (= copy + delete buttons
                    // that fade in on hover = the Hermes MessageActions
                    // pattern). Agent messages don't get hover actions
                    // (= matches Hermes = the agent-side is read-only
                    // in the chat transcript = actions live on the
                    // user's own messages only).
                    ChatMessageBodyView(
                        message: message,
                        isOutgoing: isOutgoing,
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
                        // (= the boss's '一次吐出' report).
                        //
                        // Hermes真值: assistant-message.tsx:346
                        // checks `s.message.status?.type === 'running'`
                        // = the same gate (= true for the entire
                        // active turn, not just the initial
                        // placeholder).
                        isStreaming: message.streamState == .streaming || message.isPlaceholder,
                        onApprovePlan: onApprovePlan
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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
                if message.source == .wenshu && message.streamState == .sealed {
                    HStack(spacing: 6) {
                        // T19-MESSAGE-TIMESTAMP (2026-09-18): time footer
                        // (= same Apple HIG footer pattern as Apple Messages
                        // = small monospaced text below the bubble).
                        // T26-HOVER-TIMESTAMP (2026-09-18): on hover,
                        // expand the time to a full date (= "14:32" ->
                        // "14:32 · 9月18日"). Matches Apple Messages' hover
                        // affordance (= hovering a timestamp reveals
                        // the full date). Uses .onHover + @State
                        // to toggle the display format.
                        //
                        // T50-TIMESTAMP-TOOLTIP (2026-09-18):
                        // the timestamp text gets a .help()
                        // tooltip (= the macOS native
                        // accessibility / tooltip affordance).
                        // When the user hovers the timestamp
                        // OR uses VoiceOver, they see the FULL
                        // ISO-format date
                        // (= e.g. "2026-09-18 14:32:05"). This
                        // complements T26's on-hover format
                        // expansion: T26 = visible-in-text change,
                        // T50 = native tooltip with full precision.
                        //
                        // T65-CLOCK-PREFIX (2026-09-18): a
                        // small "clock" SF Symbol prefix for
                        // the timestamp text (= Apple HIG
                        // metadata icon affordance; = mirrors
                        // T63 'number' icon for token count
                        // + T64 'dollarsign.circle' for cost).
                        // Icon uses .caption2 + .quaternary
                        // tone (= the established footer
                        // metadata icon style).
                        HStack(spacing: 2) {
                            // T65-CLOCK-PREFIX: small "clock" icon
                            // before the timestamp text.
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                            // T84-DELIVERED-CHECK (2026-09-18): a
                            // small "checkmark" SF Symbol after
                            // the timestamp text (= Apple HIG
                            // "delivered" affordance; = mirrors
                            // Apple Messages read-receipts).
                            // Icon uses .caption2 + .quaternary
                            // tone (= matches T65 clock icon
                            // style; = only shown when the
                            // message is sealed AND has at
                            // least one non-placeholder part).
                            Image(systemName: "checkmark")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                            Text(message.timestamp, format: timestampDisplayFormat)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .onHover { hovering in
                                    isTimestampHovered = hovering
                                }
                                // T50-TIMESTAMP-TOOLTIP (2026-09-18): the
                                // timestamp text gets a .help()
                                // tooltip (= the macOS native
                                // accessibility / tooltip affordance).
                                // When the user hovers the timestamp
                                // OR uses VoiceOver, they see the FULL
                                // ISO-format date
                                // (= e.g. "2026-09-18 14:32:05"). This
                                // complements T26's on-hover format
                                // expansion: T26 = visible-in-text change,
                                // T50 = native tooltip with full precision.
                                .help(Self.fullTimestampTooltip(for: message.timestamp))
                            // T72-FRESH-CHIP (2026-09-18): a small
                            // "NEW" badge next to the timestamp when
                            // the message was created less than
                            // 60 seconds ago (= the standard Apple
                            // HIG "fresh content" affordance; =
                            // highlights the user's last reply
                            // for easy scanning). Uses TimelineView
                            // to recompute the elapsed time every
                            // 0.5s and hide the badge once 60s pass.
                            if message.streamState == .sealed,
                               Date().timeIntervalSince(message.timestamp) < 60 {
                                Text("· NEW")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        // T25-TOKEN-FOOTER (2026-09-18): token count footer
                        // (= LLM API usage.total_tokens = input + output).
                        // Hidden when:
                        //   - tokens is nil (= user message; = no LLM
                        //     usage to report; = the field is nil for
                        //     non-assistant messages per ChatMessage init)
                        //   - tokens is 0 (= streaming connector didn't
                        //     surface usage; = avoid showing "0 tokens"
                        //     which is misleading)
                        if let tokens = message.tokens, tokens > 0 {
                            // T63-TOKEN-ICON (2026-09-18): a small
                            // "number" SF Symbol prefix for the token
                            // count text (= Apple HIG metadata icon
                            // affordance). The icon uses .caption2 +
                            // .quaternary tone (= one notch quieter
                            // than the .tertiary token count = the
                            // icon is a visual cue, not the data).
                            Image(systemName: "number")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                            Text(Self.formatTokenCount(tokens))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                // T52-TOKEN-TOOLTIP (2026-09-18):
                                // .help() tooltip showing the EXACT
                                // full token count (= "1,500 tokens"
                                // vs the inline "1.5k tokens"
                                // compact format). Matches T50's
                                // timestamp tooltip pattern (= full
                                // precision lives in the native
                                // tooltip; = compact text stays
                                // scannable).
                                .help(Self.fullTokenCountTooltip(for: tokens))
                            // T62-TOKEN-COST (2026-09-18): an
                            // estimated USD cost label next to
                            // the token count (= "≈ $0.045" for
                            // 1500 input + output tokens). Hidden
                            // when tokens is 0 (= meaningless).
                            // Uses a simple heuristic:
                            //   - $3 per million input tokens
                            //   - $15 per million output tokens
                            // (= the Claude Sonnet 4.5 pricing
                            // tier; = the most common wenshu
                            // profile). For other models the
                            // cost will be off by ~10x but the
                            // order-of-magnitude is right (= the
                            // user gets a sense of "this cost
                            // cents vs dollars").
                            //
                            // T64-DOLLAR-ICON (2026-09-18): a small
                            // "$" SF Symbol prefix for the cost
                            // label (= Apple HIG metadata icon
                            // affordance). The icon uses .caption2 +
                            // .quaternary tone (= matches the T63
                            // 'number' icon style = visual
                            // consistency). Icon placed BEFORE
                            // the cost text (= Apple HIG metadata
                            // icon convention).
                            Image(systemName: "dollarsign.circle")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                            Text(Self.formatTokenCost(tokens))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.quaternary)
                        }
                    }
                    .padding(.top, 2)
                    .padding(.leading, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // T53-FOOTER-COMBO-TOOLTIP (2026-09-18): the
                    // entire footer HStack gets a .help()
                    // tooltip combining timestamp + token count
                    // in one summary string (= "1,500 tokens ·
                    // 2026-09-18 14:32:05"). Useful when the
                    // user hovers the footer's empty space
                    // (between the timestamp + token text) and
                    // wants the combined picture. Individual
                    // tooltips on timestamp + token text remain
                    // (= T50 + T52 not regressed).
                    .help(Self.comboFooterTooltip(message: message))
                    // T55-FOOTER-DIVIDER (2026-09-18): a thin
                    // hairline above the footer (= Apple HIG
                    // secondary chrome = separates the message
                    // body from the metadata row). Hidden when
                    // both timestamp + token are absent (= the
                    // divider would float without context).
                    .overlay(alignment: .top) {
                        if message.streamState == .sealed
                            && (message.tokens ?? 0) > 0 {
                            Rectangle()
                                .fill(.quaternary)
                                .frame(height: 0.5)
                                .offset(y: -2)
                        }
                    }
                }
            }

            // Right-side spacer removed: with the left-gutter glyph
            // column above, every row is full-width from the avatar to
            // the right edge (= the Hermes `ROLE` glyph + flat body
            // pattern; = no right-edge trailing space).
            // L818: extra } removed (= previous HStack wrapper gone).
    }

    /// Outgoing messages are the ones this person sent, which iMessage puts
    /// on the trailing side in the accent colour.
    private var isOutgoing: Bool { message.source == .user }

    /// T23-PLAN-BADGE (2026-09-18): true when the message carries at
}

/// Hermes真值 user bubble surface per `apps/desktop/src/components/
/// assistant-ui/thread/user-message.tsx:67-69` `USER_BUBBLE_BASE_CLASS`.
///
/// In Tailwind the source is `rounded-xl border bg-(--dt-user-bubble)
/// px-3 py-2`. In SwiftUI on macOS 27 the equivalent is
/// `.regularMaterial` for the bg (= Apple's canonical translucent
/// surface; = the `.bg-(--dt-user-bubble)` token tracks the user's
/// appearance automatically, same as `.regularMaterial` does). The
/// border uses `.accentColor.opacity(0.18)` (= the same family of
/// subtle accent borders Apple HIG adopts for floating surfaces on
/// macOS 27; = tracks the user's accent in subtle mode).
///
/// Activates only on outgoing (= user) messages; on assistant rows the
/// modifier is a pass-through (= no visual change from MC1's flat
/// self-start text).
/// v1.65-cleanup C2 boss 2026-09-21 'just refer to HERMES, do 1:1;
/// drop the wenshu-side chrome': the user bubble surface now uses
/// hermes真值 `bg-DT-USER-BUBBLE` semantics (= Apple semantic
/// `Color(nsColor: .controlBackgroundColor)`) instead of the
/// previous Liquid Glass `.regularMaterial` (= too heavy vs
/// hermes真值's subtle bg token). The border keeps Apple HIG
/// semantic `Color(nsColor: .separatorColor).opacity(0.5)` (= 0.5
/// PT; = matches hermes border-UI-STROKE-TERTIARY token in spirit).
///
/// Card internal padding = 12 PT horizontal + 6 PT vertical (= was
/// 16 + 8 in MC6; = tighter, matches hermes `px-3 py-2` from
/// USER_BUBBLE_BASE_CLASS).
///
/// Card maxWidth stays 0.95 of the transcript column (= preserves
/// MC6's outdent-without-overflow cap; = hermes `-mx-4 px-4`
/// outdent is not expressible in SwiftUI macOS 27 without breaking
/// the parent frame, so 0.95 is the closest 1:1 visual).
///
/// Activates only on outgoing (= user) messages; on assistant rows the
/// modifier is a pass-through (= no visual change from C1's flat
/// self-start text).
private struct UserGlassCardModifier: ViewModifier {
    let isOutgoing: Bool

    func body(content: Content) -> some View {
        if isOutgoing {
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: 0.95, alignment: .trailing)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                )
        } else {
            content
        }
    }
}


// v1.65 boss '思考中的那个效果不是 hermes 的效果': StatusPulse
// (= hermes真值 `.tsx status-pulse.tsx` PULSE_DURATION_MS=400 +
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
        // The 3×3 PT rounded-2PT square (= hermes真值 `size-3
        // rounded-[2px] text-midground/80`). SwiftUI's tint is
        // mapped to Color.secondary (= Apple semantic for muted
        // foreground on the assistant transcript).
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.secondary)
            .frame(width: 3, height: 3)
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
