//
//  ChatViewCompressionRow.swift · Wenshu · v0.35 ticket 003 sub-step 4 + 5
//
//  Compression status pill + manual compress button (= 🟨 + 🟥 UI).
//  Inserted into ChatView body via `ChatViewCompressionRow(vm: vm)`.
//
//  Iron rules enforced (= wenshu-pocock-workflow §11.1):
//    - Rule 6: layout/spacing uses DesignTokens (= no magic numbers)
//    - Rule 7: Button + system buttonStyle (= no custom-drawn icons)
//    - Apple HIG canonical control colors (= NSColor.systemXxx)
//

import SwiftUI

// Token scope: DesignTokens (§ Sources/WenshuApp/DesignTokens.swift) covers
// chrome dimensions, paddings, font, dividers. Token budget for compression
// (= 30,000 tokens) is a DATA constant (= chat context budget, not chrome),
// so it lives as a file-scope private constant (= per iron rule 'no magic
// numbers in view code').

private let contextCompressionThreshold: Int = 30_000

public struct ChatViewCompressionRow: View {
    public let vm: ChatViewModel
    @State private var isCompressing: Bool = false
    @State private var compressionSummary: String? = nil

    public init(vm: ChatViewModel) {
        self.vm = vm
    }

    public var body: some View {
        // Show row when context exceeds threshold OR when a compression
        // summary is set (= either threshold warning or post-compress pill).
        let showRow = vm.contextUsed >= contextCompressionThreshold || compressionSummary != nil
        if showRow {
            HStack(spacing: DesignTokens.chromePaddingMicro) {
                if let summary = compressionSummary {
                    // Compression status pill (🟨)
                    Text(summary)
                        .font(DesignTokens.statusFont)
                        .foregroundStyle(DesignTokens.statusForeground)
                        .padding(.horizontal, DesignTokens.chromePaddingChipHorizontal)
                        .padding(.vertical, DesignTokens.chromePaddingMicro)
                        .background(
                            Color(nsColor: .controlBackgroundColor),
                            in: Capsule()
                        )
                } else {
                    // Threshold warning
                    Text(String(
                        format: "💡 %d tokens used (compress recommended)",
                        vm.contextUsed
                    ))
                    .font(DesignTokens.statusFont)
                    .foregroundStyle(.orange)
                }
                Spacer()
                Button {
                    Task { await manualCompress() }
                } label: {
                    Label("Compress", systemImage: "arrow.down.circle")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .disabled(isCompressing)
            }
            .padding(.horizontal, DesignTokens.chromePaddingMedium)
            .padding(.vertical, DesignTokens.chromePaddingSmall)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    /// Trigger manual compression (lives here, not in extension; reads
    /// vm.messages directly + writes compressionSummary to @State).
    ///
    /// 真实修改 path (= ticket 003 sub-step 5 acceptance criteria):
    /// 1. map vm.messages -> [LLMMessage]
    /// 2. cc.manualTrigger returns compressed [LLMMessage]
    /// 3. map [LLMMessage] -> [ChatMessage] preserving id + timestamp
    /// 4. vm.messages = compressed (= observability triggers ChatView re-render)
    /// 5. vm.recomputeContextUsed() (= updates compression pill token count)
    private func manualCompress() async {
        guard !isCompressing else { return }
        isCompressing = true
        defer { isCompressing = false }

        let originals = vm.messages
        guard originals.count >= 2 else {
            compressionSummary = "Need at least 2 messages to compress"
            return
        }

        let llmMessages = originals.map { msg -> LLMMessage in
            LLMMessage(
                role: msg.role.toLLMRole,
                blocks: [.text(msg.content)]
            )
        }
        let systemPrompt = "you are 文枢 writing assistant"
        let cc = ConversationCompression()
        let result = await cc.manualTrigger(messages: llmMessages, systemMessage: systemPrompt)

        let before = originals.count
        let after = result.messages.count
        guard after < before else {
            compressionSummary = "No compression needed"
            return
        }

        // Pair compressed LLMMessage results back to ChatMessage by index,
        // preserving id + timestamp + tokens (from the original). This
        // ensures the rest of ChatView (messages list, kanban, etc.)
        // sees the same message identity after compression.
        let compressedChat = result.messages.enumerated().map { idx, llm in
            let original = originals[idx]
            return ChatMessage(
                id: original.id,
                role: llm.role.fromLLMRole,
                content: llm.firstTextContent,
                timestamp: original.timestamp,
                isPlaceholder: false,
                tokens: original.tokens,
                thinking: original.thinking
            )
        }

        vm.messages = compressedChat
        vm.recomputeContextUsed()

        let ratio = Double(after) / Double(before)
        let percent = Int((1.0 - ratio) * 100)
        compressionSummary = String(
            format: "📦 compressed %d%% (%d → %d messages)",
            percent, before, after
        )
    }
}

// MARK: - Role bridge (ChatRole ↔ LLMMessage.Role)
// Ticket 003 sub-step 5 acceptance: compression round-trip preserves
// message identity. Role bridge lives in this file (= single source of
// truth for ChatView ↔ LLMMessage role mapping). Per §11.3 wenshu-side
// wins, this bridge is a thin adapter over the existing ChatRole enum.

extension ChatRole {
    internal var toLLMRole: LLMMessage.Role {
        switch self {
        case .user: return .user
        case .agent: return .assistant
        case .system: return .user  // system messages travel as user in
                                    // LLMMessage (= system prompt is
                                    // always a top-level parameter, not
                                    // an in-band message, per LLMConnector
                                    // Anthropic-native semantics)
        }
    }
}

extension LLMMessage.Role {
    internal var fromLLMRole: ChatRole {
        switch self {
        case .user: return .user
        case .assistant: return .agent
        case .tool: return .user  // tool result travels as user-visible
                                   // status in ChatView (= tool execution
                                   // is rendered inline above the agent
                                   // response, see ChatMessageView line 941)
        }
    }
}

extension LLMMessage {
    /// First text content from the blocks (= recovery for compressed
    /// messages that may collapse multiple blocks into one). Ticket 003
    /// sub-step 5 acceptance: ChatMessage.content is a String, so we
    /// concatenate text blocks (= empty string if none).
    internal var firstTextContent: String {
        blocks.compactMap { block in
            if case let .text(text) = block { return text }
            return nil
        }.joined(separator: "\n")
    }
}