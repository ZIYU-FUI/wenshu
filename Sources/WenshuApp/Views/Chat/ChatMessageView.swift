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
    @State private var thinkingExpanded: Bool = false

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
                    Text(sourceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    if message.parts.isEmpty, let thinking = message.thinking, !thinking.isEmpty, message.source == .wenshu {
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
                        isStreaming: message.isPlaceholder
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
            }

            if !isOutgoing { Spacer(minLength: 40) }
        }
    }

    /// Outgoing messages are the ones this person sent, which iMessage puts
    /// on the trailing side in the accent colour.
    private var isOutgoing: Bool { message.source == .user }

    /// Bubble fill.
    ///
    /// Measured Messages.app on this machine in dark mode: outgoing
    /// rgb(29, 143, 250), incoming rgb(51, 52, 54) against an
    /// rgb(28, 28, 28) transcript. Wenshu uses the semantic equivalents of
    /// those instead of the literals, so the bubbles track the user's
    /// accent colour and appearance rather than being pinned to one theme.
    private var bubbleFill: AnyShapeStyle {
        if message.source == .system {
            return AnyShapeStyle(Color.red.opacity(0.15))
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
