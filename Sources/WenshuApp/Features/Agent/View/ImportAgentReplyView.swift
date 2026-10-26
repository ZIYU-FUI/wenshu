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

    init(parts: [ChatMessagePart], isStreaming: Bool = false) {
        self.parts = parts
        self.isStreaming = isStreaming
    }

    var body: some View {
        ChatMessageBodyView(
            message: ChatMessage(
                role: .agent,
                content: "",
                parts: parts,
                streamState: isStreaming ? .streaming : .sealed
            ),
            isStreaming: isStreaming
        )
    }

}
