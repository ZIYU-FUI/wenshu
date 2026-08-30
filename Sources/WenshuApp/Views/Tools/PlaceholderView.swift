// Sources/WenshuApp/Views/Tools/PlaceholderView.swift
//
// v0.29 boss 2026-08-30 OOB '替换, 用伏笔替换第一个 teb, 用占位
// 替换第二个 teb. 现在的画布功能以后实现': tools pane tab 2 is now
// 占位符 (= Placeholder) instead of 数据库 (= BaseView). Actual
// Placeholder content (= inline placeholder references scattered
// through the main body text + auto-resolve via LLM) will land in a
// later v0.29+ ticket.
//
// For now, this is a minimal placeholder (= per ComponentIndex.md
// placeholder pattern: show the tool name + icon + "to be implemented"
// message). Uses the same RegionTabBackground helper as the other
// 4 general panes (= consistent Liquid Glass background).

import SwiftUI

/// Tools pane tab 2: 占位符 (= Placeholder) per v0.29 boss OOB.
///
/// **Use this** for the second tab of the specializedTools pane.
/// Replaces the old BaseView (= which moved to a future ticket per
/// '现在的画布功能以后实现').
///
/// Content roadmap (= not implemented yet):
/// - v0.29: this placeholder (= shows tab is reserved for 占位符)
/// - v0.30+: inline placeholder scanner + resolver (find all
///   [占位符: topic] tags in the body, link to LLM extraction)
///
/// For now, renders a simple placeholder matching the editor's
/// EditorContentPlaceholder style (= ComponentIndex.md pattern).
@MainActor
public struct PlaceholderView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            // v0.27 boss 8/27 OOB: Lucide canonical icon (= 'square-dashed'
            // for placeholder = dashed square = matches the 占位符 folder
            // icon in the sidebar).
            LucideIconSystemFallback("square-dashed", size: 48)
                .foregroundStyle(.tertiary)
            Text("占位符")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("内联占位引用追踪 (= v0.30+ 实现)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}