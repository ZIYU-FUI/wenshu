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
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 240, maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(.bottom, DesignTokens.chromePaddingMicro)
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
                        Text(message.timestamp, format: timestampDisplayFormat)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .onHover { hovering in
                                isTimestampHovered = hovering
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
                            Text(Self.formatTokenCount(tokens))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.top, 2)
                    .padding(.leading, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
