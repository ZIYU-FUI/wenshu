// PaneTrailingIconButton.swift · Wenshu
//
// Canonical trailing-button helper for a tab bar's trailing slot
// (= the editor's expand/shrink button). Extracted from
// PaneTabBar.swift when that file's other 3 types were deleted
// (= PaneTabBar / PaneTabItem / PaneIconTab had 0 constructors).
//
// Apple HIG rationale: the trailing slot in a tab bar is for action
// buttons (separate from selection tabs). This helper unifies the
// self-written copies that had drifted between WorkspaceView.swift
// (= EditorExpandShrinkTrailingButton) and the chat-zone archive
// button.

import SwiftUI

@MainActor
struct PaneTrailingIconButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    init(icon: String, tooltip: String, action: @escaping () -> Void) {
        self.icon = icon
        self.tooltip = tooltip
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Color.clear
                .frame(width: DesignTokens.paneTabHotArea, height: DesignTokens.paneTabHotArea)
                .overlay(alignment: .center) {
                    SFIcon(icon, style: .paneTab, color: IconColor.secondary)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverWash()
        .help(tooltip)
    }
}
