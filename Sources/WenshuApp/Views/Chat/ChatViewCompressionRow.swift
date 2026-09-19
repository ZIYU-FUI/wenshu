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

/// T31-CONTEXT-PERCENTAGE (2026-09-18): namespace for the
/// context-usage formatting helpers. Separate enum (= top-level
/// type) so the static functions compile correctly (= file-scope
/// nonisolated static funcs are not allowed on plain file-scope
/// declarations in Swift).
enum ChatViewCompressionRowFormatter {
    /// Format a context-used value as a percentage of the compression
    /// threshold (= e.g. "1.5k / 30k tokens (5%)"). `nonisolated` so
    /// the ChatViewModel (= MainActor) can call it without an actor
    /// hop. Uses the same compact-token convention as
    /// ChatMessageView.formatTokenCount.
    nonisolated static func formatContextUsage(_ count: Int, threshold: Int) -> String {
        let countStr = formatCompactTokenCount(count)
        let thresholdStr = formatCompactTokenCount(threshold)
        let percent = Int((Double(count) / Double(max(threshold, 1))) * 100)
        return "\(countStr) / \(thresholdStr) tokens (\(percent)%)"
    }

    /// T31 helper: compact token count (= "1.5k", "234", "12.3k").
    nonisolated private static func formatCompactTokenCount(_ count: Int) -> String {
        if count < 1_000 { return "\(count)" }
        if count < 10_000 {
            return String(format: "%.1fk", Double(count) / 1_000.0)
        }
        if count < 1_000_000 {
            return "\(count / 1_000)k"
        }
        return String(format: "%.1fM", Double(count) / 1_000_000.0)
    }
}

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
                            .regularMaterial,
                            in: Capsule()
                        )
                } else {
                    // Threshold warning
                    // T31-CONTEXT-PERCENTAGE (2026-09-18): the text now
                    // includes a live percentage of the compression
                    // budget (= e.g. "💡 1.5k / 30k tokens (5%)"). The
                    // pre-T31 format was just "💡 N tokens used"; = the
                    // user can see at a glance how close they are to the
                    // 30k compression threshold.
                    Text(ChatViewCompressionRowFormatter.formatContextUsage(vm.contextUsed, threshold: contextCompressionThreshold))
                    .font(DesignTokens.statusFont)
                    .foregroundStyle(.orange)
                }
                Spacer()
                Button {
                    Task { await manualCompress() }
                } label: {
                    Label { Text(WenshuI18n.t("b5.chatviewcompressionrow.l62.h10389252")) } icon: { Image(systemName: "arrow.down.circle").font(.system(size: 16, weight: .regular)) }
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
                .disabled(isCompressing)
            }
            .padding(.horizontal, DesignTokens.chromePaddingMedium)
            .padding(.vertical, DesignTokens.chromePaddingSmall)
            // v0.40 boss 2026-09-08 OOB 'sweep for remaining background colors: removed the
            // chrome tier background tint (= .windowBackgroundColor
            // = boss wants gone per the 'go up another layer and remove the background' cleanup).
        }
    }

    /// Trigger manual compression (lives here, not in extension; reads
    /// vm.messages directly + writes compressionSummary to @State).
    ///
    /// modify path (= ticket 003 sub-step 5 acceptance criteria):
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
                content: llm.textContent,
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

// Role bridge + content bridge moved to ChatMessageBridge.swift per
// Standards-axis S2 Feature Envy smell (= view was reaching into
// ChatMessage + LLMMessage internals; bridge belongs on dedicated type).
// Call sites in this file now use the same internal extensions (= they
// resolve to the canonical declarations in ChatMessageBridge.swift).