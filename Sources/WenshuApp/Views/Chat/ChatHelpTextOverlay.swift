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
        // EmptyStateHint pattern (= icon + title + body) as the
        // editor zone and the card zone. Previously was a multi-line
        // Text + Button link.
        //
        // v0.40 boss 2026-09-08 follow-up '少字了': the title must
        // be the FULL sentence '请先在 设置 中设置好大模型提供方'
        // (not just '请先在'). Per Apple HIG the inline '设置' text
        // inside the title is the clickable link (= the link is
        // inside the title sentence, not a separate Button below).
        //
        // Implementation: use HStack(spacing: 0) with 3 Text views
        // (= plain + clickable + plain). The middle '设置' is
        // wrapped in a Button with .plain style for tap = onSettingsTap.
        VStack(spacing: DesignTokens.chromePaddingLarge) {
            // Icon (= 24 PT = DesignTokens.iconLargeSize).
            // .secondary tone matches the editor / card zone
            // empty state icons.
            LucideIconSystemFallback("message-square", size: DesignTokens.iconLargeSize)
                .foregroundStyle(.secondary)
            // Title (= inline link pattern = Apple's Mail.app /
            // Notes.app convention for empty-state hints that
            // include a "settings" CTA inside the title sentence).
            HStack(spacing: 0) {
                Text(WenshuI18n.t("chathelp.please_first_goto") + " ")
                    .foregroundStyle(.secondary)
                Button(action: onSettingsTap) {
                    Text(WenshuI18n.t("auto.chathelptextoverlay.l25.h61781343"))
                        .foregroundStyle(Color.accentColor)
                        .underline()
                }
                .buttonStyle(.plain)
                Text(" " + WenshuI18n.t("auto.chathelptextoverlay.l30.h53427819"))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 15, weight: .semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 360)
            // Body (= 13 PT tertiary = Apple HIG tertiary detail).
            Text(WenshuI18n.t("auto.chathelptextoverlay.l33.h88773098"))
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}