// ChatPanelView.swift · 文枢 · v0.02.0 WO-LT-04 → v0.03.0 V0-fix-4 → V0-fix-6 → V0-fix-8 → V0-fix-11
// 下左聊天区：聊天实装，时间线/关系图/大纲为 disabled 占位。
//
// V0-fix-4 Fix 4: Picker `.segmented` 改 `.iconOnly` (走 PickerStyle+IconOnly
// 别名, macOS 14+ SegmentedPickerStyle 配合 Image-only content 自动隐藏文
// 字标签)。 V0-fix-4 Fix 6: 4 tab 居左对齐 (FCP timeline 范式) — 改
// .padding(.horizontal, 12) → .padding(.leading, 12) + 删 Picker 块
// .frame(maxWidth: .infinity) 让 Picker 自适应宽度居左, 加 Spacer 把右
// 边留白。 删 "聊天区视图" H1 残留 (Picker a11y 改 "")。
//
// V0-fix-6 (B5 装机 user 8/10 17:35 OOB): tabContent 加居中
// (`.frame(maxWidth: .infinity, alignment: .center)`) — 4 tab 居左
// OK (沿 V0-fix-4 Fix 6), 内容区居中 (本期新加)。
//
// V0-fix-8 (装机 user 8/11 真机拍 4 红字批注 #3): Picker(.iconOnly)
// 改 HStack + 4 Button(Image) + `.buttonStyle(.plain)` — 红字
// "所有 ICON 按钮, 只保留 ICON, 不要矩形背景, 仿 FCP"。 修真前
// Picker(.iconOnly) 走 SegmentedPickerStyle 仍有 macOS 系统矩形分段
// 框背景, 修真后 HStack + Button(.plain) 纯 ICON, 无矩形背景, 对齐
// FCP timeline 范式。 4 SF Symbol 沿 on-disk ChatPanelTab.symbolName
// 真值 (AIF 未列新值, 不改)。
//
// V0-fix-11 修真 #5 (装机 user 8/11 14:35 5 红字批注): 4 chat tab
// 修真 size 14→13 + frame 32×24→28×22 + HStack spacing 4→2 +
// padding vertical 8→4 (FCP timeline 紧凑范式, memi §3.5 layout
// 修真 28pt toolbar, hit area ≥ 24pt HIG 修真, 本卡直接修真数值
// 不引入 IconButton 组件)。

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

    // B+ 重 (t_0f6bd6f6): @EnvironmentObject → @Environment(ChatViewModel.self)
    // — ChatViewModel 已 @Observable, .environment(chatVM) (App.swift) 自动
    // 注册为 Observation framework 环境值, 这里用 typed environment 读取。
    @Environment(ChatViewModel.self) private var chatVM
    @State private var activeTab: ChatPanelTab = .chat
    @State private var navPath = NavigationPath()

    static func shouldRenderChat(for vm: ChatViewModel) -> Bool {
        vm.currentProject != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // V0-fix-11 修真 #5: 4 chat tab 修真 size 14→13 + frame
            // 32×24→28×22 + padding vertical 8→4 + spacing 4→2 (FCP
            // timeline 紧凑范式, 修真装机 user 8/11 14:35 5 红字批注 #5).
            //
            // V0-fix-8 (修真 #3): Picker(.iconOnly) 改 HStack + 4
            // Button(Image) + `.buttonStyle(.plain)` — 红字"所有 ICON
            // 按钮, 只保留 ICON, 不要矩形背景, 仿 FCP"。 修真前
            // SegmentedPickerStyle 仍有 macOS 系统矩形分段框背景 (装机
            // user 8/11 真机拍), 修真后纯 ICON, 对齐 FCP timeline 范式。
            HStack(spacing: 2) {
                ForEach(ChatPanelTab.allCases) { tab in
                    Button {
                        activeTab = tab
                    } label: {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 28, height: 22)
                            .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(tab.rawValue)
                    .disabled(tab.isDisabled)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.vertical, 4)

            Divider()

            // V0-fix-6: 内容区居中 (B5 装机 user 8/10 17:35 OOB 实机拍
            // "tab 居左 OK, 内容居中")。 加 .frame(maxWidth: .infinity,
            // alignment: .center) 撑满 + 内容居中 (FCP timeline 范式)。
            // V0-fix-8: 修真 #3 不动内容区居中 (修真仅 tab 渲染方式)。
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        .disabled(true)
    }
}
