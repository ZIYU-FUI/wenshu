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
        VStack(spacing: 12) {
            // v0.27 boss 8/27 OOB: Lucide canonical icon (= 'git-fork' for
            // foreshadowing = branches merging back together = matches the
            // 伏笔 folder icon in the sidebar).
            LucideIconSystemFallback("git-fork", size: 48)
                .foregroundStyle(.tertiary)
            Text("伏笔")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("跨章节伏笔追踪 (= v0.30+ 实现)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}