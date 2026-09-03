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
    private func manualCompress() async {
        guard !isCompressing else { return }
        isCompressing = true
        defer { isCompressing = false }

        let llmMessages = vm.messages.map { msg -> LLMMessage in
            LLMMessage(
                role: msg.role == .user ? .user : .assistant,
                blocks: [.text(msg.content)]
            )
        }
        let systemPrompt = "you are 文枢 writing assistant"
        let cc = ConversationCompression()
        let result = await cc.manualTrigger(messages: llmMessages, systemMessage: systemPrompt)

        let before = vm.messages.count
        let after = result.messages.count
        if after < before {
            let ratio = Double(after) / Double(before)
            let percent = Int((1.0 - ratio) * 100)
            compressionSummary = String(
                format: "📦 compressed %d%% (%d → %d messages)",
                percent, before, after
            )
        } else {
            compressionSummary = "No compression needed"
        }
        vm.recomputeContextUsed()
    }
}