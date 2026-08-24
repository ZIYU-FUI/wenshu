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
            Text("请先在")
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Button(action: onSettingsTap) {
                    Text("设置")
                        .foregroundStyle(Color.accentColor)
                        .underline()
                }
                .buttonStyle(.plain)
                Text("中设置好大模型提供方")
                    .foregroundStyle(.secondary)
            }
            Text("然后再开始与文枢对话")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .font(.body)
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}