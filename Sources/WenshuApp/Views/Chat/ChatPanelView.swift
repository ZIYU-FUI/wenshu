// ChatPanelView.swift · 文枢 · v0.02.0 WO-LT-04
// 下左聊天区：聊天实装，时间线/关系图/大纲为 disabled 占位。

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
        VStack(spacing: 0) {
            Picker("聊天区视图", selection: $activeTab) {
                ForEach(ChatPanelTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.symbolName)
                        .tag(tab)
                        .disabled(tab.isDisabled)
                }
            }
            .pickerStyle(.segmented)
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
