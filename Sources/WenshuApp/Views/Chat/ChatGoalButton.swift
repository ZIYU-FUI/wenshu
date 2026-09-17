//
//  ChatGoalButton.swift · Wenshu · v1.28 C3.4.6
//
//  v1.28 C3.4.6: split the Goal button (= ⌘⇧G → startLongRunningGoal
//  → GoalsManager.runGoal) out of ChatView (= god-view split step 6
//  = the WIRE-AGENT-003 Ralph-loop trigger button).
//
//  Originally at ChatView.swift:1589-1610 (= 22 lines: Button +
//  SF Symbols 6 'scope' icon + .buttonStyle(.bordered) +
//  .controlSize(.regular) + .frame height + .disabled + .help).
//
//  Behavior preserved (= tapping the button spawns Task that calls
//  `vm.startLongRunningGoal()`; = the button is disabled when the
//  draft is empty (= no goal text to run); = it does NOT block on
//  isSending because the Ralph loop runs in background (= the user
//  can keep chatting).
//

import SwiftUI

struct ChatGoalButton: View {
    var vm: ChatViewModel

    var body: some View {
        Button {
            Task { await vm.startLongRunningGoal() }
        } label: {
            // SF Symbols 6 'scope' (= the canonical Apple HIG
            // target / scope metaphor for the Ralph loop = "fire
            // this goal at the agent and let it run until done").
            // Replaces the v0.27 'Lucide .target' choice per
            // boss 2026-09-15 OOB 'use SF Symbols 6' (= supersedes
            // the 2026-09-09 'Lucide only' reversal).
            Image(systemName: "scope")
                .font(.system(size: DesignTokens.tabIconSize, weight: .regular))
                .aspectRatio(contentMode: .fit)
                .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)
                .foregroundStyle(.secondary)
        }
        // v0.61 boss 2026-09-10 OOB 'the attach button and the
        // send button should match styles': all 3 buttons (attach +
        // send + goal) use .bordered = the standard macOS Liquid
        // Glass secondary button style.
        .buttonStyle(.bordered)
        .controlSize(.regular)
        // v0.25.1 ticket 033 chat send button 30 PT height:
        // matches TextField's 32 PT frame so all controls align
        // flush. .controlSize(.regular) button default ≈ 24 PT
        // glyph; .frame(height: 30 PT) keeps the button at Apple's
        // standard control height.
        .frame(height: LayoutTokens.chromeControlHeight)
        // WIRE-AGENT-003 (2026-09-04): the button is disabled when
        // the draft is empty (= no goal text to run); it does NOT
        // block on isSending because the Ralph loop runs in
        // background (= the user can keep chatting).
        .disabled(vm.inputText.isEmpty)
        .help(WenshuI18n.t("chat.ralphLoop.goalHelp"))
    }
}
