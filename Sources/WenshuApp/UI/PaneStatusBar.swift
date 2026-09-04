// Sources/WenshuApp/UI/PaneStatusBar.swift
//
// v0.28 followup Boss UX round A (Boss 2026-08-30 OOB '你需要做一个组件索引,
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
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

/// Canonical per-pane bottom status bar with left + center + right
/// status text. Wraps `RegionStatusBar` (= the canonical Liquid
/// Glass 30 PT chrome) and provides the standard 13 PT tertiary
/// text on left + center + right with Apple HIG padding.
///
/// **Use this** for any pane that needs simple status display
/// (= replaces the ZoneBottomToolbar legacy component deleted in
/// Phase 4 and the inline `RegionStatusBar { HStack { Text + Spacer
/// + Text } }` pattern in ZonePerRegionChrome.bottomBar).
///
/// Boss 2026-09-01 OOB: extended from 2-slot (left + right) to
/// 3-slot (left + center + right) so panes can show three pieces
/// of info without re-implementing the chrome. The 3-slot layout
/// matches Apple Finder's bottom status bar (= item count on
/// left, free-space info center, view-mode icon on right).
///
/// Example:
/// ```swift
/// PaneStatusBar(
///     leftText: "书架: 3",
///     centerText: "选中: 测试书",
///     rightText: "书: 5"
/// )
/// ```
@MainActor
public struct PaneStatusBar: View {
    /// Left-aligned status text (= e.g. "书架: 3", "章节: 5"). Empty
    /// string = shows the placeholder text "占位文字" (= backward
    /// compatibility with the legacy ZoneBottomToolbar behavior).
    public let leftText: String

    /// Center-aligned status text (= e.g. "选中: 测试书", "总字数: 1234").
    /// Empty string = no center text rendered (= clean middle).
    /// Boss 2026-09-01 OOB: added so a pane can show three pieces
    /// of info (left + center + right) without re-implementing the
    /// status bar chrome.
    public let centerText: String

    /// Right-aligned status text (= e.g. "书: 5", "字数: 1234"). Empty
    /// string = no right text rendered (= clean right edge).
    public let rightText: String

    /// B-16: optional tap handler on the right-aligned status text.
    /// When non-nil, the right text is rendered as a Button (= clickable);
    /// when nil (= default), it stays plain Text. Boss 9/2 OOB: editor
    /// zone chrome right "反链 0" needs to be clickable to open a
    /// popover with the full BacklinksPanel. `@Sendable` keeps the
    /// struct Sendable (= required by Swift 6 strict concurrency).
    public let rightOnTap: (@Sendable () -> Void)?

    public init(leftText: String = "", centerText: String = "", rightText: String = "", rightOnTap: (@Sendable () -> Void)? = nil) {
        self.leftText = leftText
        self.centerText = centerText
        self.rightText = rightText
        self.rightOnTap = rightOnTap
    }

    public var body: some View {
        RegionStatusBar {
            HStack(spacing: DesignTokens.chromePaddingClusterGap) {
                // Left status text (= .tertiary + .system(size: 13)
                // = Apple HIG secondary text on toolbar/statusbar)
                Text(leftText.isEmpty ? "占位文字" : leftText)
                    .font(DesignTokens.statusFont)
                    .foregroundStyle(DesignTokens.statusForeground)
                    .padding(.leading, DesignTokens.chromePaddingLeading)
                    .padding(.bottom, DesignTokens.chromePaddingVertical / 2)
                    .allowsHitTesting(false)
                // Boss 2026-09-01 OOB: center slot. When non-empty,
                // sits in the middle of the bar between the left
                // and right texts. Spacer() on either side keeps
                // the center text horizontally centered relative
                // to the bar (= Apple Finder status bar pattern).
                if !centerText.isEmpty {
                    Spacer(minLength: 0)
                    Text(centerText)
                        .font(DesignTokens.statusFont)
                        .foregroundStyle(DesignTokens.statusForeground)
                        .padding(.bottom, DesignTokens.chromePaddingVertical / 2)
                        .allowsHitTesting(false)
                }
                Spacer(minLength: 0)
                // Right status text
                if !rightText.isEmpty {
                    // B-16: when rightOnTap is provided, render the
                    // right text as a Button (= clickable affordance
                    // for popover triggers like the editor zone's
                    // "反链 0" label). Plain Button + .plain buttonStyle
                    // = no native button chrome (= Apple HIG inline
                    // action pattern). Hit area = the text + 8 PT
                    // breathing room (= standard Apple HIG small target
                    // padding for status bar actions).
                    if let onTap = rightOnTap {
                        Button(action: onTap) {
                            Text(rightText)
                                .font(DesignTokens.statusFont)
                                .foregroundStyle(DesignTokens.statusForeground)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, DesignTokens.chromePaddingTrailing - 6)
                        .padding(.bottom, DesignTokens.chromePaddingVertical / 2)
                        .help("点击查看详情")
                    } else {
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
}