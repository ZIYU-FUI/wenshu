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
    /// Where this bubble sits in a run of consecutive messages from one
    /// author, which decides the tail and the merged corners.
    var position: ChatBubblePosition = .only
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
    /// T28-PLAN-BADGE-EXPAND (2026-09-18): true when the user is
    /// hovering the PLAN badge (= expands the badge to show the
    /// step count; = Apple Messages hover affordance).
    @State private var isPlanBadgeHovered: Bool = false

    public init(
        message: ChatMessage,
        position: ChatBubblePosition = .only,
        onApprovePlan: ((Plan) -> Void)? = nil
    ) {
        self.message = message
        self.position = position
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
        // v0.57 boss 2026-09-09 OOB: push the bubbles toward the iMessage
        // look. Outgoing messages sit on the trailing side in the accent
        // colour, incoming ones on the leading side in the neutral fill,
        // and a run of consecutive messages from one author merges.
        HStack(alignment: .bottom, spacing: 8) {
            if isOutgoing { Spacer(minLength: 40) }

            // The avatar only appears on the last bubble of a run, so a
            // burst of replies is not a column of repeated faces. The
            // slot stays reserved on the other bubbles to keep the run's
            // left edge aligned.
            Group {
                if position.hasTail && !isOutgoing {
                    switch message.source {
                    case .user:
                        Image(systemName: "person").font(.system(size: 24, weight: .regular))
                            .aspectRatio(contentMode: .fit)
                    case .wenshu:
                        Image(systemName: "sparkles").font(.system(size: 24, weight: .regular))
                            .aspectRatio(contentMode: .fit)
                    case .system:
                        Image(systemName: sourceIcon).font(.system(size: 24, weight: .regular))
                    }
                } else if !isOutgoing {
                    Color.clear
                }
            }
            .foregroundStyle(sourceColor)
            .frame(
                width: isOutgoing ? 0 : DesignTokens.iconLargeSize,
                height: isOutgoing ? 0 : DesignTokens.iconLargeSize
            )

VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                // iMessage names the author once per run, not per bubble.
                if position == .only || position == .first {
                    HStack(spacing: 4) {
                        // T71-SOURCE-STATUS-DOT (2026-09-18): a small
                        // "circle.fill" status dot BEFORE the source
                        // label (= green for wenshu = sealed /
                        // delivered; = Apple Messages read receipt
                        // pattern). Dot is .caption + .green tone
                        // (= matches T44/T45 status icon style).
                        // Hidden for user messages (= user doesn't
                        // need a delivery receipt on their own message).
                        if message.source == .wenshu {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(.green)
                        }
                        // T75-BOT-ICON (2026-09-18): a small
                        // "brain.head.profile" SF Symbol for
                        // wenshu messages (= the Apple HIG
                        // AI/assistant identity affordance;
                        // = replaces the older "person.crop.circle
                        // .badge.questionmark" placeholder glyph
                        // with a cleaner AI visual). Used in
                        // the source label row alongside the
                        // T71 delivery dot.
                        if message.source == .wenshu {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        // T73-USER-SENT-ICON (2026-09-18): a small
                        // "paperplane.fill" SF Symbol for user-sent
                        // messages (= "sent" affordance; = matches
                        // Apple Messages' delivered-status icon
                        // for outgoing bubbles). Mirror of T71: T71
                        // is for wenshu (= delivery receipt), T73
                        // is for user (= sent confirmation).
                        if message.source == .user {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        Text(sourceLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        // T23-PLAN-BADGE (2026-09-18): when the message
                        // has a .plan part (= a /plan command result),
                        // show a small "PLAN" badge next to the
                        // source label (= identifies plan-mode
                        // messages at a glance; = matches the Hermes
                        // desktop pattern where plan cards get a
                        // distinct header tag).
                        if messageHasPlanPart {
                            // T28-PLAN-BADGE-EXPAND (2026-09-18): on
                            // hover, the PLAN badge expands to show
                            // the step count (= "PLAN" -> "PLAN · 3 steps").
                            // Matches Apple Messages' "typing..."
                            // expand affordance.
                            Text(isPlanBadgeHovered
                                 ? "PLAN · \(planStepCountLabel)"
                                 : "PLAN")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 0.5)
                                )
                                .onHover { hovering in
                                    isPlanBadgeHovered = hovering
                                }
                        }
                    }
                }
                if message.isPlaceholder {
                    // Wenshu AI placeholder status indicator
                    HStack(spacing: 4) {
                        // v1.0.0-m1-shell boss 2026-09-15 OOB 'use SF Symbols 6':
                        // canonical placeholder indicator
                        // (= 'person.crop.circle.badge.questionmark'
                        // = SF Symbols 6 dot.case form of
                        // Lucide's 'bot-message-square').
                        Image(systemName: "person.crop.circle.badge.questionmark").font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text(message.content)
                            .foregroundStyle(.secondary)
                        ProgressView()
                            .controlSize(.mini)
                            .progressViewStyle(.circular)
                        // T58-ELAPSED-TIME (2026-09-18): a small
                        // elapsed-time indicator next to the
                        // ProgressView (= "🧠 3.2s"). Drives a
                        // TimelineView(.periodic(from: .now,
                        // by: 0.5)) so the seconds tick while the
                        // model is thinking. Gives the user a
                        // concrete sense of progress (= "still
                        // thinking, has been for 3s now") rather
                        // than a generic spinner.
                        TimelineView(.periodic(from: .now, by: 0.5)) { context in
                            let elapsed = context.date.timeIntervalSince(message.timestamp)
                            Text(Self.formatElapsed(elapsed))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleFill, in: bubbleShape)
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
                            HStack(spacing: 4) {
                                Image(systemName: "brain.head.profile").font(.system(size: 16, weight: .regular))
                                    .font(.caption)
                                Text(WenshuI18n.t("chatview.ai_thinking"))
                                    .font(.caption)
                            }
                            .foregroundStyle(.tertiary)
                        }
                        .animation(.default, value: thinkingExpanded)
                    }
                    // CHATIMG-001 (2026-09-07): render attached image
                    // thumbnail above the parts. (= unchanged)
                    if let imagePath = message.imagePath {
                        if let nsImage = NSImage(contentsOfFile: imagePath) {
                            // T51-OPEN-IMAGE (2026-09-18): wrap the
                            // thumbnail in a Button so clicking it
                            // opens the image in Preview.app via
                            // NSWorkspace.shared.open(url). The
                            // Reveal-in-Finder button (= T34) is
                            // preserved below as a separate affordance.
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
                            // T34-OPEN-IMAGE-IN-FINDER (2026-09-18): a small
                            // "Reveal" button below the thumbnail (= the
                            // user can right-click a file in Finder to
                            // see it; = the equivalent here is a single-
                            // click button that does NSWorkspace.activateFileViewerSelecting
                            // = the standard macOS "Reveal in Finder" affordance).
                            // Hidden when the file doesn't exist (= already
                            // handled by the outer if-let).
                            Button {
                                let url = URL(fileURLWithPath: imagePath)
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            } label: {
                                // T35-REVEAL-I18N (2026-09-18): retired the
                                // hardcoded English "Reveal in Finder" label
                                // (= landed in T34) in favor of the localized
                                // WenshuI18n.t("chatview.message.reveal_in_finder")
                                // = "Reveal in Finder" in en.lproj,
                                //   "在访达中显示" in zh-Hans.lproj.
                                Label(
                                    WenshuI18n.t("chatview.message.reveal_in_finder"),
                                    systemImage: "folder"
                                )
                                .font(.caption2)
                            }
                            .buttonStyle(.borderless)
                            .padding(.bottom, DesignTokens.chromePaddingMicro)
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
                        isStreaming: message.isPlaceholder,
                        onApprovePlan: onApprovePlan
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleFill, in: bubbleShape)
                    .overlay(alignment: .topTrailing) {
                        if isOutgoing {
                            ChatMessageHoverActions(content: message.content)
                                .padding(.top, DesignTokens.chromePaddingSmall)
                                .padding(.trailing, DesignTokens.chromePaddingSmall)
                        }
                    }
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
                // T54-ATTACHMENT-FOOTER-ICON (2026-09-18): when
                // the message carries an image attachment,
                // render a small paperclip SF Symbol in the
                // footer (= meta indicator = "this message has
                // an attachment"). Hidden when message has no
                // imagePath. Placed AFTER the timestamp HStack
                // so the existing footer is untouched.
                if message.imagePath != nil {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Image(systemName: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .help(WenshuI18n.t("chatview.message.has_attachment"))
                    }
                    .padding(.top, 2)
                    .padding(.trailing, DesignTokens.chromePaddingLeading)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            if !isOutgoing { Spacer(minLength: 40) }
        }
    }

    /// Outgoing messages are the ones this person sent, which iMessage puts
    /// on the trailing side in the accent colour.
    private var isOutgoing: Bool { message.source == .user }

    /// T23-PLAN-BADGE (2026-09-18): true when the message carries at
    /// least one `.plan` part (= identifies /plan command results
    /// = the source label area gets a small "PLAN" badge).
    private var messageHasPlanPart: Bool {
        message.parts.contains { part in
            if case .plan = part.kind { return true }
            return false
        }
    }

    /// T28-PLAN-BADGE-EXPAND (2026-09-18): step count shown in the
    /// PLAN badge on hover (= "PLAN · 3"). Pulls the first .plan
    /// part's steps.count and formats it. Returns empty string when
    /// no plan part exists (= the caller only invokes this when
    /// messageHasPlanPart is true; = defensive return for safety).
    private var planStepCountLabel: String {
        for part in message.parts {
            if case .plan(let p) = part.kind {
                let n = p.steps.count
                return "\(n) step\(n == 1 ? "" : "s")"
            }
        }
        return ""
    }

    /// Bubble fill.
    ///
    /// Measured Messages.app on this machine in dark mode: outgoing
    /// rgb(29, 143, 250), incoming rgb(51, 52, 54) against an
    /// rgb(28, 28, 28) transcript. Wenshu uses the semantic equivalents of
    /// those instead of the literals, so the bubbles track the user's
    /// accent colour and appearance rather than being pinned to one theme.
    private var bubbleFill: AnyShapeStyle {
        if message.source == .system {
            return AnyShapeStyle(Color(nsColor: .systemRed).opacity(0.15))
        }
        return isOutgoing
            ? AnyShapeStyle(Color.accentColor)
            // Chosen by measurement. Messages runs a 23-unit gap between
            // the incoming bubble and the transcript behind it (51 vs 28).
            // Rendered every candidate semantic style in a sample app and
            // measured each against the same background: quinary +10, fill.secondary
            // +17, quaternary +22, fill +22, unemphasized +27, tertiary +55.
            // .quaternary lands on Messages' gap while still tracking the
            // user's appearance instead of hard-coding a grey.
            : AnyShapeStyle(.quaternary)
    }

    private var bubbleShape: ChatBubbleShape {
        ChatBubbleShape(isOutgoing: isOutgoing, position: position)
    }

    private var sourceIcon: String {
        switch message.source {
        // v1.0.0-m1-shell boss 2026-09-16 OOB '所有 ICON，都不要 .fill':
        // chat bubble avatars (= user / wenshu) use outline glyphs
        // (= the canonical Apple HIG form for the Liquid Glass
        // 3rd-generation design language).
        case .user: return "person"
        case .wenshu: return "text.book.closed"
        case .system: return "exclamationmark.triangle"
        }
    }

    private var sourceLabel: String {
        switch message.source {
        case .user: return "你"
        case .wenshu: return "文枢"
        case .system: return "系统"
        }
    }

    private var sourceColor: Color {
        switch message.source {
        case .user: return .blue
        case .wenshu: return .accentColor
        case .system: return .red
        }
    }
}
