//
//  ChatHelpTextOverlay.swift · Wenshu · v0.24 boss验收
//
//  Boss 2026-08-24 反馈: 帮助文字应放在聊天视图的上下左右正居中 (was: bottom-right).
//
//  Pattern: ZStack + .frame(maxWidth: .infinity, maxHeight: .infinity)
//  overlay in ChatZoneView body so help text floats centered over the chat zone.
//

import SwiftUI

/// ChatHelpTextOverlay: 帮助文字 (centered, large) shown when no API key configured.
/// Tapping '设置' jumps to Settings → 提供方 API tab.
public struct ChatHelpTextOverlay: View {
    let onSettingsTap: () -> Void

    public var body: some View {
        // v0.40 boss 2026-09-08 OOB '聊天区的提示空态提示, 和编辑器
        // 和卡片区一致': the chat empty state must use the SAME
        // EmptyStateHint pattern as the editor zone (icon + title +
        // body) and the card zone. Previously was a multi-line
        // Text + Button link = visually inconsistent with the
        // canonical empty-state pattern used everywhere else.
        //
        // The Settings link (= formerly an inline underlined
        // "设置" Text) is now a Button below the body (= tap →
        // Settings pane). Apple HIG pattern = the link is part of
        // the empty state CTA, not inline text.
        VStack(spacing: DesignTokens.chromePaddingLarge) {
            EmptyStateHint(
                icon: "message-square",
                title: WenshuI18n.t("chathelp.please_first_goto"),
                body: WenshuI18n.t("auto.chathelptextoverlay.l33.h88773098")
            )
            Button(action: onSettingsTap) {
                Text(WenshuI18n.t("auto.chathelptextoverlay.l25.h61781343"))
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}