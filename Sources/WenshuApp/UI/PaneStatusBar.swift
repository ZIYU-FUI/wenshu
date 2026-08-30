// Sources/WenshuApp/UI/PaneStatusBar.swift
//
// v0.28 followup Boss UX round A (Boss 2026-08-30 OOB '你需要做一个组件索引,
// 以后如果有新的地方用到相同的东西, 会自然而然的找到组件, 而不是默认自动
// 写个新的'): Phase 5 of 5-phase component refactor.
//
// Higher-level wrapper around RegionStatusBar with built-in left/right status
// text + Apple HIG standard padding. Listed in ComponentIndex.md Level 2.6.
//
// = replaces the duplicated HStack { Text + Spacer + Text }.padding(...)
// pattern (= was duplicated in ZoneBottomToolbar + ZonePerRegionChrome.bottomBar
// + 2 inline HStack patterns in WorkspaceView + ChatView = ~120 LOC total).
//
// Use this for any pane that shows simple "left status + right status" at
// the bottom (= most common pattern, e.g. "章节: 5" + "字数: 1234").

import SwiftUI

/// Canonical per-pane bottom status bar with left + right status text.
/// Wraps `RegionStatusBar` (= the canonical Liquid Glass 30 PT chrome)
/// and provides the standard 13 PT tertiary text on left + right with
/// Apple HIG padding.
///
/// **Use this** for any pane that needs simple left/right status display
/// (= replaces the ZoneBottomToolbar legacy component deleted in Phase 4
/// and the inline `RegionStatusBar { HStack { Text + Spacer + Text } }`
/// pattern in ZonePerRegionChrome.bottomBar).
///
/// Example:
/// ```swift
/// PaneStatusBar(
///     leftText: "书架: 3",
///     rightText: "书: 5"
/// )
/// ```
@MainActor
public struct PaneStatusBar: View {
    /// Left-aligned status text (= e.g. "书架: 3", "章节: 5"). Empty
    /// string = shows the placeholder text "占位文字" (= backward
    /// compatibility with the legacy ZoneBottomToolbar behavior).
    public let leftText: String

    /// Right-aligned status text (= e.g. "书: 5", "字数: 1234"). Empty
    /// string = no right text rendered (= clean right edge).
    public let rightText: String

    public init(leftText: String = "", rightText: String = "") {
        self.leftText = leftText
        self.rightText = rightText
    }

    public var body: some View {
        RegionStatusBar {
            HStack(spacing: 0) {
                // Left status text (= .tertiary + .system(size: 13)
                // = Apple HIG secondary text on toolbar/statusbar)
                Text(leftText.isEmpty ? "占位文字" : leftText)
                    .font(DesignTokens.statusFont)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .padding(.leading, DesignTokens.chromePaddingLeading)
                    .padding(.bottom, DesignTokens.chromePaddingVertical / 2)
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
                // Right status text
                if !rightText.isEmpty {
                    Text(rightText)
                        .font(DesignTokens.statusFont)
                        .foregroundStyle(DesignTokens.statusForeground)
                        .padding(.trailing, DesignTokens.chromePaddingTrailing)
                        .padding(.bottom, DesignTokens.chromePaddingVertical / 2)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}