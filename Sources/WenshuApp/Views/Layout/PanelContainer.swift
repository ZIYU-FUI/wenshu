// PanelContainer.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01 → LT-01-fix5
//
// One of the 5 slots in the 5-zone shell. Renders just the panel content
// inside a thin background + border — **no header bar**. The panel
// "自我识别" (H1 inside content) is delegated to each panel's own
// placeholder / real content View, mirroring the FCP / Pages / Numbers
// convention where the browser / timeline / inspector has no title chrome.
//
// LT-01-fix3: the header's chevron collapse button was GONE earlier. Per
// macOS HIG / Final Cut Pro, show-hide is a menu-bar command (View →
// Cmd+1…5), not panel chrome. `CollapsedGutter` likewise lost its
// button and is now a passive strip rendered from persisted collapse
// state.
//
// LT-01-fix5 优化3: 装机 user 8/7 拍板"标题栏全删, 用功能告诉用户".
// 沿用 FCP 范式: 浏览器 / 时间线 / 检视器 都没标题栏, 只露功能. 每块
// panel 自己的 content 最上方自带 H1 ("项目列表" / "文档" / "检视" /
// "聊天" / "状态"), 让功能区自我标识.
//
// Collapsed width/height is supplied by the caller via `frame(width:)`
// / `frame(height:)` modifiers — the container itself only renders the
// inner chrome. This keeps the parent's GeometryReader-based layout
// arithmetic in one place (LayoutShellView).
//
// Why no header bar?
// - FCP 范式 + 装机 user 实机拍板: 用功能告诉用户 "这是啥" (= content
//   内的 H1 / placeholder), 不用 chrome title 告诉.
// - 卸载冗余: 之前是 "headerBar (icon + name)" + "content (再显示一遍
//   name)", 删 headerBar 后只剩一处 self-identity.

import SwiftUI

struct PanelContainer<Content: View>: View {
    let panelID: PanelID
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
            .overlay(
                Rectangle()
                    .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
            )
    }
}

// MARK: - Convenience: vertical "collapsed" gutter for upper row panels
//
// When the upper row's panel is collapsed, the panel itself is replaced
// by a 50px-wide vertical icon strip. We render this as a vertical
// variant of the collapsed chrome so the visual rhythm matches.
//
// LT-01-fix3: no button — the gutter is a passive indicator. Use
// View → <panel name> in the menu bar to bring a panel back.
//
// LT-01-fix5 优化3: 跟 `PanelContainer` 的 headerBar 一起被删, 此
// gutter 简化成纯 icon strip (无 text 标题, 因为 panel title 已无法
// 隐藏状态去 title bar 上找). 用户在 collapsed gutter 上看到 SF Symbol
// 就能知道是哪个 panel.

struct CollapsedGutter: View {
    let panelID: PanelID

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 4) {
                Image(systemName: panelID.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48)
            .padding(.vertical, 8)

            Spacer(minLength: 0)
        }
        .frame(width: LayoutSnapshot.topCollapsedPixels)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .overlay(
            Rectangle()
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
        )
        // Q2 折叠态 (t_c6f48f43): 双击展开 (DESIGN §1.3 触发器 B). 沿
        // LT-01-fix3 拍板"折叠 chrome 上不画展开按钮", 用户直 chrome 双击
        // 反向. 直接调 VM 的 toggle (line 94), 持久化沿 PanelStatesEnvelope
        // 自动落盘.
        .onTapGesture(count: 2) {
            LayoutShellViewModel.shared.toggle(panelID)
        }
    }
}

// MARK: - Convenience: horizontal "collapsed" header for lower row panels
//
// Q2 折叠态 (t_c6f48f43): 下半 2 panel (bottomLeft / bottomRight) 折叠态
// 视觉. 沿 CollapsedGutter 范式 (SF Symbol + title + 同 background /
// border), 但形态 = 全宽 × 30pt 水平 header bar (DESIGN §1.5 下半范式).
// bottomLeft 不可折叠 (DESIGN §1.2), 但代码防御性保留 — LayoutShellView
// panel() 函数目前只对 3 可折叠 panel 走 CollapsedHeader / CollapsedGutter
// 分支, bottomLeft 永远不会进来.
//
// 双击手势 (DESIGN §1.3 触发器 B) 同 CollapsedGutter, 展开 = vm.toggle.

struct CollapsedHeader: View {
    let panelID: PanelID

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: panelID.symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text(panelID.title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(height: LayoutSnapshot.bottomCollapsedPixels)
        .padding(.horizontal, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .overlay(
            Rectangle()
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
        )
        .onTapGesture(count: 2) {
            LayoutShellViewModel.shared.toggle(panelID)
        }
    }
}
