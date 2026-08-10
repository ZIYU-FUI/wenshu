// ChatPanelView.swift · 文枢 · v0.02.0 WO-LT-04 → v0.03.0 V0-fix-1 (Fix B + Fix C) → v0.03.0 V0-fix-2 (Fix G)
// 下左聊天区：聊天实装，时间线/关系图/大纲为 disabled 占位。
//
// V0-fix-1 Fix C: 4 个 chat tab 改成 ICON-only (FCP 风格)。 Text label
// 从 Picker 里删了, 走 `.help(tab.rawValue)` tooltip 显示中文。 SF
// Symbol 映射也按装机 user 8/10 拍板的 fix19 风格精简 (bubble.left /
// clock / person.2 / list.bullet.rectangle)。
//
// V0-fix-1 Fix B: 删 Picker 字符串标签 "聊天区视图" (= 原 H1 残留),
// 改空字符串 (a11y label 由 .help() 提供, 不再冗余)。
//
// V0-fix-2 Fix G: `.pickerStyle(.segmented)` 改 `.pickerStyle(.iconOnly)` —
// macOS 13 上 segmented picker 即便只放 Image 也 fallback 显 SF Symbol 名字
// ("bubble.left" / "clock" / "person.2" / "list.bullet.rectangle" 这 4 个字符
// 串), 必须 iconOnly 才真 ICON-only.

import SwiftUI

enum ChatPanelTab: String, CaseIterable, Identifiable {
    case chat = "聊天"
    case timeline = "时间线"
    case relationships = "关系图"
    case outline = "大纲"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        // V0-fix-1 Fix C: SF Symbol 简化 — bubble.left (单边气泡, 不带
        // 对话双方标识) / clock (无 arrow.circlepath 装饰) / person.2
        // (不变) / list.bullet.rectangle (替代 indent, 大纲 视觉更明确)。
        case .chat: return "bubble.left"
        case .timeline: return "clock"
        case .relationships: return "person.2"
        case .outline: return "list.bullet.rectangle"
        }
    }

    var isDisabled: Bool { self != .chat }
    var placeholder: String { "v0.04.0 实现" }
}

struct ChatPanelView: View {
    static let chatPlaceholder = "先在项目里开始一次创作"

    @EnvironmentObject private var chatVM: ChatViewModel
    @State private var activeTab: ChatPanelTab = .chat
    @State private var navPath = NavigationPath()

    static func shouldRenderChat(for vm: ChatViewModel) -> Bool {
        vm.currentProject != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // V0-fix-1 Fix B + Fix C + V0-fix-2 Fix G: Picker a11y 标签
            // 改 "" (H1 残留 "聊天区视图" 已删), 4 个 tab 改 ICON-only
            // 走 Image(systemName:) + .help(tab.rawValue) tooltip 兜中文.
            // Picker 风格走 .iconOnly (不是 .segmented) — macOS 13 上
            // segmented picker 即便只放 Image 也 fallback 显 SF Symbol 名字
            // ("bubble.left" / "clock" / "person.2" / "list.bullet.rectangle"
            // 这 4 个字符串), 必须 iconOnly 才真 ICON-only.
            Picker("", selection: $activeTab) {
                ForEach(ChatPanelTab.allCases) { tab in
                    Image(systemName: tab.symbolName)
                        .tag(tab)
                        .help(tab.rawValue)
                        .disabled(tab.isDisabled)
                }
            }
            .pickerStyle(.iconOnly)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Group {
                switch activeTab {
                case .chat:
                    chatContent
                case .timeline, .relationships, .outline:
                    disabledContent(for: activeTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var chatContent: some View {
        if let project = chatVM.currentProject {
            NavigationStack(path: $navPath) {
                ChatView(vm: chatVM, project: project, navPath: $navPath)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: ChatPanelTab.chat.symbolName)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
                Text(Self.chatPlaceholder)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func disabledContent(for tab: ChatPanelTab) -> some View {
        VStack(spacing: 10) {
            Image(systemName: tab.symbolName)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text(tab.placeholder)
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(true)
    }
}
