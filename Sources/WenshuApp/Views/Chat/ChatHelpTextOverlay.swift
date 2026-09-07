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
        // v0.24 boss验收fix: explicit center alignment (horizontal + vertical)
        // so help text floats in chat zone's geometric center.
        VStack(spacing: 8) {
            Text(WenshuI18n.t("chathelp.please_first_goto"))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Button(action: onSettingsTap) {
                    Text(WenshuI18n.t("auto.chathelptextoverlay.l25.h61781343"))
                        .foregroundStyle(Color.accentColor)
                        .underline()
                }
                .buttonStyle(.plain)
                Text(WenshuI18n.t("auto.chathelptextoverlay.l30.h53427819"))
                    .foregroundStyle(.secondary)
            }
            Text(WenshuI18n.t("auto.chathelptextoverlay.l33.h88773098"))
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .font(.body)
        .multilineTextAlignment(.center)
        .padding(DesignTokens.chromePaddingXLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}