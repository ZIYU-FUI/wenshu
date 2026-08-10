// ChatPanelView.swift · 文枢 · v0.02.0 WO-LT-04 → v0.03.0 V0-fix-4
// 下左聊天区：聊天实装，时间线/关系图/大纲为 disabled 占位。
//
// V0-fix-4 Fix 4: Picker `.segmented` 改 `.iconOnly` (走 PickerStyle+IconOnly
// 别名, macOS 14+ SegmentedPickerStyle 配合 Image-only content 自动隐藏文
// 字标签)。 V0-fix-4 Fix 6: 4 tab 居左对齐 (FCP timeline 范式) — 改
// .padding(.horizontal, 12) → .padding(.leading, 12) + 删 Picker 块
// .frame(maxWidth: .infinity) 让 Picker 自适应宽度居左, 加 Spacer 把右
// 边留白。 删 "聊天区视图" H1 残留 (Picker a11y 改 "")。

import SwiftUI

enum ChatPanelTab: String, CaseIterable, Identifiable {
    case chat = "聊天"
    case timeline = "时间线"
    case relationships = "关系图"
    case outline = "大纲"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .timeline: return "clock.arrow.circlepath"
        case .relationships: return "person.2"
        case .outline: return "list.bullet.indent"
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Picker("", selection: $activeTab) {
                    ForEach(ChatPanelTab.allCases) { tab in
                        Image(systemName: tab.symbolName)
                            .tag(tab)
                            .help(tab.rawValue)
                            .disabled(tab.isDisabled)
                    }
                }
                .pickerStyle(.iconOnly)
                .padding(.leading, 12)
                .padding(.vertical, 8)
                Spacer(minLength: 0)
            }

            Divider()

            tabContent
                .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .chat:
            chatContent
        case .timeline, .relationships, .outline:
            disabledContent(for: activeTab)
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
            .frame(maxHeight: .infinity)
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
        .frame(maxHeight: .infinity)
        .disabled(true)
    }
}
