//
//  ImportAgentReplyView.swift · wenshu
//
//  Renders one import row's agent reply.
//
//  The chat zone already renders an agent's reply properly: a message
//  with typed parts, where the text, the reasoning, the tool calls and
//  the tool results each have their own rendering. The import sheet
//  used a terminal-style log instead, which read as a debug log rather
//  than as the assistant's answer.
//
//  This view renders the import row's reply with the chat zone's own
//  message body view, so the sheet and the chat read the same.
//

import SwiftUI

/// The agent's reply for one import row.
struct ImportAgentReplyView: View {
    /// The parts the agent produced (= the row's reply).
    let parts: [ChatMessagePart]

    /// Whether the agent is still writing (= the reply grows as it
    /// arrives).
    let isStreaming: Bool

    /// The parts as drawn, which is the only place this sheet can keep the
    /// reader's collapse of a thinking block.
    ///
    /// The reply arrives here as a value, not as storage the sheet owns, so
    /// the answer cannot go back to the import row. It stays above the
    /// rows that draw it, which is what matters: a row is rebuilt on every
    /// streamed frame, and a choice kept in the row is lost with it.
    @State private var drawnParts: [ChatMessagePart]

    init(parts: [ChatMessagePart], isStreaming: Bool = false) {
        self.parts = parts
        self.isStreaming = isStreaming
        _drawnParts = State(initialValue: parts)
    }

    var body: some View {
        ChatMessageBodyView(
            message: ChatMessage(
                role: .agent,
                content: "",
                parts: drawnParts,
                streamState: isStreaming ? .streaming : .sealed
            ),
            isStreaming: isStreaming,
            onThinkingReveal: { _, partID, revealed in
                guard let partID,
                      let index = drawnParts.firstIndex(where: { $0.id == partID }) else { return }
                drawnParts[index].isThinkingRevealed = revealed
            }
        )
        // The row's own reply grew elsewhere, so the sheet follows it. The
        // reader's collapse is kept by part id, which a grown part keeps.
        .onChange(of: parts) { _, fresh in
            drawnParts = fresh.map { part in
                guard let kept = drawnParts.first(where: { $0.id == part.id })?
                    .isThinkingRevealed else { return part }
                var copy = part
                copy.isThinkingRevealed = kept
                return copy
            }
        }
    }
}
