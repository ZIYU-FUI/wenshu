// EditorTabBarBar.swift · Wenshu (文枢) · v0.34 B-26
//
// Safari-style tab strip (= NSTabView-like) for the editor zone top
// bar. Boss 2026-09-03 OOB '把整个这一栏改成 teb 栏, 把后面的三个
// ICON 按钮先全都去掉, 我换个位置实现' = replace the editor top
// toolbar with a tab bar showing every tab in appState.openTabs;
// remove the 3 trailing icon buttons (= mode toggle, expand, close);
// boss will re-implement the 3 buttons elsewhere.
//
// Apple HIG tabbed-document pattern (= NSTabView / Safari tab strip):
// - single-line HStack, scrollable horizontally when tabs overflow
// - active tab = visually distinct (= underline + accent tint + bolder font)
// - each tab has a small close button on hover (= the only per-tab
//   affordance in this bar; = everything else moves elsewhere per
//   boss OOB).
//
// Place = top of editor zone (= above the markdown body / TextEditor);
// = 32 PT height (= matches PaneTabBar precedent from v0.34 B-02).

import SwiftUI

/// v0.34 B-26: Safari-style tab strip (= per-tab title + close button +
/// active highlight). Reads from a passed-in tabs array (= openTabs from
/// AppState; = caller owns the data, this view is presentational).
struct EditorTabBarBar: View {
    let tabs: [EditorTab]
    let activeTabId: UUID
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void

    /// v0.34 B-26 (= Apple HIG .bar background = same as the rest of
    /// the editor zone chrome; = .regularMaterial for the floating tab
    /// strip = see ticket 027-35 for material tuning).
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(tabs) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .frame(height: 36)
        // v0.34 B-26: Apple HIG tab-strip background. `.regularMaterial`
        // (= standard Liquid Glass tint = matches RegionTabBar + PaneTabBar
        // precedent from B-02 = single source of truth for chrome
        // surface = wenshu-apple-api-first skill Rule 1 + 4).
        .background(.regularMaterial)
        // v0.34 B-26: Apple HIG window-bottom divider = 1 PT hairline
        // under the tab bar (= separates the bar from the editor body).
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
        }
    }

    /// v0.34 B-26: per-tab pill (= title + close X on hover). Active
    /// tab = .tint background + bold text; inactive = transparent
    /// background + .secondary text (= Apple HIG tab strip pattern).
    @ViewBuilder
    private func tabButton(for tab: EditorTab) -> some View {
        let isActive = (tab.id == activeTabId)
        let title = tabDisplayTitle(for: tab)
        Button(action: { onSelect(tab.id) }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                    .lineLimit(1)
                    .padding(.leading, 10)
                if tabs.count > 1 {
                    // v0.34 B-26: per-tab close button. Hidden when only
                    // one tab remains (= Apple HIG convention: don't
                    // offer close on the last tab).
                    Button(action: { onClose(tab.id) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
            }
            .frame(minWidth: 80, maxWidth: 200)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    // v0.34 B-26: active tab background = Apple HIG tab strip
                    // selected tint = .tint at 0.18 (= visible enough to
                    // read as "selected" against the .regularMaterial
                    // chrome = wenshu-apple-api-first Rule 1 + 4).
                    .fill(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    // v0.34 B-26: active tab border = .tint at 0.5 (= subtle
                    // but visible; = Apple HIG window-tab selected ring).
                    .stroke(isActive ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(title)
    }

    /// v0.34 B-26: derive display title from `documentPath` (= same
    /// logic as the previous toolbar's left slot before this commit;
    /// = active tab's filename = " world/文枢是什么.md " or
    /// " preview-sample.md " for the placeholder).
    private func tabDisplayTitle(for tab: EditorTab) -> String {
        if let path = tab.documentPath, !path.isEmpty {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return "preview-sample.md"
    }
}