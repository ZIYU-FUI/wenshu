// LazySidebarChromeRow.swift · Wenshu · v1.68
//
// Boss 2026-09-22 OOB 'UI 与功能分离, UI 是 UI, 加载的内容是内容,
// 不要混合写大文件': extracted from LazySidebarView.swift (= the
// 957-LOC file that the v1.64 / v1.65 sidebar rewrite produced).
//
// This file owns the sidebar's CHROME rows (= the cosmetic rows
// that bookend the shelf / book / reference tree):
//   - LazySidebarHeader          : top header label (= "书架" title).
//   - LazySidebarBottomNewButton : safe-area-inset bottom '+' button.
//
// These 2 rows are pure UI (= no @State / no callbacks beyond v =
// v one closure). The actual sidebar rows (shelf / book / folder)
// remain in LazySidebarView for now (= future ticket can split them
// once the v1.68 sidebar UI rewrite settles the boundary between
// row rendering and view composition).

import SwiftUI

/// Top header label for the sidebar (= "书架" / "NB: sidebar section").
struct LazySidebarHeader: View {
    var body: some View {
        Text(WenshuI18n.t("sidebar.section.shelves.title"))
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)
    }
}

/// Bottom '+' button (= safe-area-inset, = pinned to the bottom of
/// the sidebar). Clicking calls `action` (= the LazySidebarView
/// wires it to `appState.choiceRequestCount += 1` to trigger the
/// choice sheet via .onChange).
struct LazySidebarBottomNewButton: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text(WenshuI18n.t("sidebar.new_button.label"))
                        .font(.callout)
                }
                .frame(width: nil, height: DesignTokens.chromeHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.chromePaddingLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(WenshuI18n.t("sidebar.new_button.help"))
        }
    }
}