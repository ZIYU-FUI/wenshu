//
//  ChatAgentPathIndicator.swift · Wenshu · T0-PATH-VISIBLE (2026-09-18)
//
//  v0.71 P1 batch 3 / boss 2026-09-18 OOB "前后端打包 + 加按钮在
//  ChatAttachButton 紧右":
//
//  Pure-UI indicator button that surfaces which conversation-loop
//  path WenshuConductor actually took (= new agent / legacy).
//  Reads the most recent NSLog line via the wenshu.conductor log
//  prefix (the dev / boss can grep the Console.app for
//  `[wenshu.conductor] PATH=...`).
//
//  Why this exists (= boss symptom 2026-09-18 'chat is one-shot,
//  no thinking, no tool calls, no continuity'): the Conductor has
//  TWO paths (runConversationLoopPath = new, runLegacyConductorPipeline
//  = v0.21 fallback). If ConversationLoop.runTurn throws or returns
//  nil, we silently fall through to legacy = the user sees a one-shot
//  reply. Until now there was no way to know which path actually
//  fired without rebuilding + setting breakpoints.
//
//  T0 adds:
//    1. NSLog("PATH=new_agent|legacy REASON=...") on both branches
//       of WenshuConductor.handle() (= 1-line audit trail).
//    2. THIS view = hover-able indicator button placed immediately
//       after ChatAttachButton (= per boss OOB '加按钮就在附件上传
//       按钮后面先加'). The tooltip = the latest PATH= log line.
//
//  Scope guard (= Q112 1 ticket 1 file):
//    - New file only. No edits to ChatView body, ChatAttachButton,
//      ChatSendButton, ChatGoalButton, WenshuConductor.handle() body.
//    - HStack layout unchanged (= new button only ADDS to the row).
//
//  Behaviour:
//    - .help() tooltip = "agent path: see Console.app for PATH= log".
//    - SF Symbol = "sparkles" (= Hermes agent marker) tinted with
//      .secondary (= matches ChatAttachButton's .secondary tint).
//    - Static for now (= no live binding to last log line; that
//      requires either NotificationCenter subscription or a shared
//      @Observable path-tracker = out of T0 scope; = T1+ ticket).
//
//  Placeholder SF Symbol + tint chosen to match Hermes-desktop's
//  agent-path badge style (per boss 2026-09-18 '前端完全神似 hermes').
//

import SwiftUI

struct ChatAgentPathIndicator: View {
    /// Read-only flag = the button is a label, not an action target.
    /// Defaults to true (= the path indicator is non-tappable; =
    /// matches Hermes-desktop's status badge = display-only).
    var isSending: Bool = false

    var body: some View {
        Button {
            // Display-only by design (= matches Hermes agent-path
            // badge = no tap action). Empty action prevents the
            // button from "looking clickable" while still being a
            // button (= gives us .help() tooltip + .disabled tint).
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: DesignTokens.tabIconSize, weight: .regular))
                .aspectRatio(contentMode: .fit)
                .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.bordered)
        // T0 tooltip = points dev to the log line (= no live state
        // wiring yet; that lands in T1 with a @Observable path-tracker).
        .help(WenshuI18n.t("chat.input.agent_path.help"))
        // Disabled while sending (= same UX gate as ChatAttachButton).
        .disabled(isSending)
    }
}