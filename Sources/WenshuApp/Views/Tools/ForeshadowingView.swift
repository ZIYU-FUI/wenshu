// Sources/WenshuApp/Views/Tools/ForeshadowingView.swift
//
// v0.29 boss 2026-08-30 OOB '替换, 用伏笔替换第一个 teb, 用占位
// 替换第二个 teb. 现在的画布功能以后实现': tools pane tab 1 is now
// 伏笔 (= Foreshadowing) instead of 画布 (= Canvas). Actual Foreshadowing
// content (= cross-chapter plot threads + their tracking) will land in
// a later v0.29+ ticket (= M5-15 LLM Wiki pipeline per spec).
//
// For now, this is a minimal placeholder (= per ComponentIndex.md
// placeholder pattern: show the tool name + icon + "to be implemented"
// message). Uses the same RegionTabBackground helper as the other
// 4 general panes (= consistent Liquid Glass background).

import SwiftUI

/// Tools pane tab 1: 伏笔 (= Foreshadowing) per v0.29 boss OOB.
///
/// **Use this** for the first tab of the specializedTools pane.
/// Replaces the old CanvasView (= which moved to a future ticket per
/// '现在的画布功能以后实现').
///
/// Content roadmap (= not implemented yet):
/// - v0.29: this placeholder (= shows tab is reserved for 伏笔)
/// - v0.30+: SwiftGraph-based visualization of cross-chapter
///   foreshadowing threads (per v0.28 batch 2 ticket 04 = M4
///   ForeshadowingGraph service)
///
/// For now, renders a simple placeholder matching the editor's
/// EditorContentPlaceholder style (= ComponentIndex.md pattern).
@MainActor
public struct ForeshadowingView: View {
    public init() {}

    public var body: some View {
        // v0.30 boss 8/31 OOB '这个栏的内容没有按栏的大小自动适配,
        // 右半边没有显示': the previous layout was a centered
        // VStack (= content packed in the middle, leaving the
        // right half of the pane blank). Now content stretches to
        // fill the pane width (= .frame(maxWidth: .infinity) on
        // the content blocks) and adds multiple placeholder rows
        // so the pane LOOKS filled. The placeholder is still
        // informational (= shows the tab is reserved for 伏笔); the
        // actual foreshadowing content lands in v0.30+ per the
        // SwiftGraph ForeshadowingGraph service ticket.
        VStack(alignment: .leading, spacing: 16) {
            // Header row: icon + label + sub-label (= top-of-pane
            // identity, full width).
            HStack(spacing: 10) {
                LucideIconSystemFallback("git-fork", size: 28)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("伏笔")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("跨章节伏笔追踪 (= v0.30+ 实现)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Placeholder rows showing what the real content will
            // look like (= 3 empty rows + a status hint at bottom).
            // Each row stretches to full pane width so the pane
            // LOOKS used (= the bug boss reported).
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 8) {
                    LucideIconSystemFallback("git-branch", size: 16)
                        .foregroundStyle(.tertiary)
                    Text("伏笔 #\(i + 1)")
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
            Text("真实内容见 v0.30+ 实现 (= SwiftGraph ForeshadowingGraph service)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}