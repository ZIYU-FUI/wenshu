//
//  ChatTurnProgress.swift · Wenshu · T3-MULTI-TURN-LOOP (2026-09-18)
//
//  v0.71 P1 batch 3 / boss 2026-09-18 OOB "加按钮就在附件上传按钮后面
//  先加":
//
//  Pure-UI indicator button that displays the agent's current
//  turn count (= "turn 3/10" when in a multi-turn loop).
//  Reads from ChatViewModel.currentAgentTurn (T3 wires the counter
//  from the streamCallback .text block carrying
//  "[wenshu.agent] turn N/M").
//
//  Why this exists (= boss symptom 2026-09-18 'chat is one-shot, no
//  continuity'): before T3, ConversationLoop only ran 1 LLM call +
//  1 tool dispatch (= no continuous thinking). After T3, the loop
//  re-prompts the LLM up to 10 turns as long as .toolUse blocks
//  remain. The button surfaces "which turn am I on" so the user
//  sees the agent IS working (= not just spinning).
//
//  Placeholder rendering: shows a static "agent" label with the
//  SF Symbol "arrow.triangle.2.circlepath" (= canonical Hermes
//  agent-loop indicator). The text updates reactively once
//  ChatViewModel.currentAgentTurn is wired in T3 step 2 (= this
//  ticket = button + visual; = T3.5 ticket will wire the binding).
//

import SwiftUI

struct ChatTurnProgress: View {
    /// Read by ChatViewModel (= pass-through). Defaults to "—" so the
    /// button never shows an empty label before the first turn runs.
    var turnLabel: String = "—"

    /// Disabled while sending (= same UX gate as ChatAttachButton).
    var isSending: Bool = false

    var body: some View {
        Button {
            // Display-only (= matches Hermes agent-loop badge =
            // no tap action). Empty action keeps .help() tooltip +
            // .disabled tint consistent with ChatAgentPathIndicator.
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: DesignTokens.tabIconSize, weight: .regular))
                    .aspectRatio(contentMode: .fit)
                    .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)
                    .foregroundStyle(.secondary)
                Text(turnLabel)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        // T3 tooltip: explains the turn counter (= matches Hermes
        // agent-loop badge convention).
        .help(WenshuI18n.t("chat.input.turn_progress.help"))
        .disabled(isSending)
    }
}