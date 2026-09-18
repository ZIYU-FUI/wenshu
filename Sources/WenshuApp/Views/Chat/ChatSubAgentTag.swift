//
//  ChatSubAgentTag.swift · Wenshu · T4-SUBAGENT-UI (2026-09-18)
//
//  v0.71 P1 batch 4 / boss 2026-09-18 OOB "加按钮就在附件上传按钮
//  后面先加":
//
//  Pure-UI indicator button that surfaces the active sub-agent name
//  when WenshuConductor.invokeSkill() is called (= "→ sub-agent: research"
//  style tag). Reads from ChatViewModel.activeSubAgent (T4 wires the
//  state from the streamCallback ".text" block carrying
//  "[wenshu.subagent] <name>"; = same pattern as T3's turn counter).
//
//  Why this exists (= boss symptom 2026-09-18 'one-shot reply, no
//  continuity'): when the agent delegates to a sub-agent (= skill,
//  = sub-task), the user should see WHICH sub-agent is running,
//  not just wait for the final reply. This tag surfaces that signal.
//

import SwiftUI

struct ChatSubAgentTag: View {
    /// Display name of the currently running sub-agent (= defaults to
    /// nil = the tag is hidden until a sub-agent starts).
    var subAgentName: String? = nil

    /// Disabled while sending (= same UX gate as ChatAttachButton).
    var isSending: Bool = false

    var body: some View {
        // Show nothing when no sub-agent is active (= empty view;
        // = the HStack spacing absorbs the missing button).
        if let name = subAgentName {
            Button {
                // Display-only (= matches Hermes agent-loop badge =
                // no tap action).
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "person.2")
                        .font(.system(size: DesignTokens.tabIconSize, weight: .regular))
                        .aspectRatio(contentMode: .fit)
                        .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)
                        .foregroundStyle(.secondary)
                    Text(name)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.bordered)
            .help(WenshuI18n.t("chat.input.subagent_tag.help"))
            .disabled(isSending)
        }
    }
}