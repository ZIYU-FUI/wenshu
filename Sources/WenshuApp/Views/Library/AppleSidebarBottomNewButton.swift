// AppleSidebarBottomNewButton.swift
//
// Bottom '+' button (= safe-area-inset, = pinned to the bottom of
// the sidebar). Used by AppleSidebarView (= the macOS 27
// Apple HIG List(.sidebar) sidebar). Clicking calls `action`
// (= AppleSidebarView wires it to `appState.choiceRequestCount += 1`
// to trigger the choice sheet via .onChange in the parent).
//
// AppleSidebarView owns the sidebar tree (= List(data, children:));
// = this button is the only chrome element AppleSidebarView itself
// does NOT render (= List(.sidebar) handles the row chrome natively).
// Lives in its own file (= not in AppleSidebarView.swift) so the
// chrome button is unit-testable in isolation (= matches the v1.68
// AppleSidebarView MVVM split: data = SidebarNode, business =
// SidebarService, view = AppleSidebarView + SidebarRowView + this
// button).

import SwiftUI

struct AppleSidebarBottomNewButton: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: action) {
                HStack(spacing: DesignTokens.spacingTight) {
                    SFIcon("plus", style: .inlineSmall, color: IconColor.secondary)
                    Text(String(localized: "sidebar.new_button.label"))
                        .font(.callout)
                }
                .frame(width: nil, height: DesignTokens.chromeHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.spacingStandard)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(String(localized: "sidebar.new_button.help"))
        }
    }
}