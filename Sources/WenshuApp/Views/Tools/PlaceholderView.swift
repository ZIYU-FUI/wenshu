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
        // v0.30 boss 8/31 OOB: same fill treatment as ForeshadowingView
        // (= content stretches to fill the pane width; previously
        // was a centered VStack leaving the right half blank).
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                LucideIconSystemFallback("square-dashed", size: 28)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("占位符")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("内联占位引用追踪 (= v0.30+ 实现)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 8) {
                    LucideIconSystemFallback("square-dashed-mouse-pointer", size: 16)
                        .foregroundStyle(.tertiary)
                    Text("占位 #\(i + 1)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.06))
                )
            }
            Spacer(minLength: 0)
            Text("真实内容见 v0.30+ 实现 (= [占位符: topic] tags in body)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}