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
//
// 2026-10-12 boss directive "然后左栏底部的新建按钮的
// 底栏, 也拉成同样的视觉" — the sidebar's bottom
// '+' button now goes through the shared
// `ChromeBottomFooter` component (= the same
// `VStack { Divider; content; .frame(maxWidth:
// .infinity, alignment: .leading); .padding(
// .vertical, 8); .padding(.horizontal, 8) }
// .background(.bar)` shell the chat token-count
// footer and the editor status bar use; = single
// source of truth for the bottom-chrome shape; = no
// visual drift across the three column-bottom rows
// in wenshu). Prior shape was just `VStack { Divider
// + Button }` (= no `.bar` material background, =
// no 8 PT vertical padding around the button row, =
// the button hugged the Divider with no breathing
// room; = the sidebar bottom felt visually thinner
// than the chat footer / editor status bar). The
// `ChromeBottomFooter` shell adds the canonical
// 8 PT vertical padding (= the button row gets
// breathing room) + the `.bar` material background
// (= the sidebar bottom tints with the same sidebar
// / chrome material the chat footer / editor
// status bar use; = all three column-bottom rows
// in wenshu now share one canonical Apple HIG
// sidebar-bottom-accessory surface).

import SwiftUI

struct AppleSidebarBottomNewButton: View {
    let action: () -> Void

    var body: some View {
        ChromeBottomFooter(help: "sidebar.new_button.help") {
            Button(action: action) {
                HStack(spacing: DesignTokens.spacingTight) {
                    SFIcon("plus", style: .inlineSmall, color: IconColor.secondary)
                    Text(String(localized: "sidebar.new_button.label"))
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}