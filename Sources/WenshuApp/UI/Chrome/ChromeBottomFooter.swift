// Sources/WenshuApp/UI/Chrome/ChromeBottomFooter.swift
//
// 2026-10-12: the editor status bar (`EditorStatusBarView`) and the
// chat token-count footer (`ChatInputBarView.tokenCountFooter`)
// have been diverging across 5 visual round-trips. The boss's
// 2026-10-12 directive "你去看一下聊天区的底栏的写法. 照抄就行了,
// 那是已经实现过的逻辑" — and the alternate "或者你把聊天区的低栏
// 抽象个组件. 让编辑器区直接应用也可以" — converge on the same
// solution: extract a single shared `ChromeBottomFooter` component
// and use it from BOTH call sites. The shared component is the
// canonical Apple HIG sidebar-bottom-accessory surface recipe
// (= `VStack(spacing: 0) { Divider; content; .frame(maxWidth:
// .infinity, alignment: .leading); .padding(.vertical, 8);
// .padding(.horizontal, 8) } .background(.bar)`). Chat
// `tokenCountFooter` AND editor `EditorStatusBarView` both
// render their content slot inside this same shell. Single
// source of truth for the bottom-chrome shape; = no visual
// drift between the two call sites; = Apple-default 1:1.
import SwiftUI

/// Canonical Apple HIG sidebar-bottom-accessory chrome surface
/// (= the bottom row of `Mail` / `Notes` / `Finder` /
/// `System Settings` sidebar rows + `ChatInputBarView` token
/// footer + `EditorStatusBarView` status bar). Use this for
/// ANY column-bottom accessory row (= footer text, status
/// indicator, secondary action button, etc.) so all column
/// bottoms in wenshu have the same surface recipe: `Divider`
/// above + content + `.bar` material + 8 PT all-around
/// padding (= the canonical Apple HIG sidebar-bottom-
/// accessory height of ~38 PT).
///
/// any new column-bottom chrome
/// row MUST go through this component. The outer shell
/// (= VStack + Divider + padding + .background) is fixed
/// here; the only per-call-site decision is the `content:`
/// closure (= a horizontal HStack of SFIcon + Text chunks,
/// = Pages / Numbers / Xcode inspector status row shape).
struct ChromeBottomFooter<Content: View>: View {
    /// The column-bottom content (= a horizontal HStack of
    /// SFIcon + Text chunks). Caller supplies the HStack;
    /// this shell anchors it to the leading edge of the
    /// column (= Apple HIG inspector status row format).
    @ViewBuilder let content: Content
    /// Optional tooltip (= maps to the surface's `.help(...)`
    /// modifier; = Apple HIG accessibility surface for the
    /// bottom-chrome row).
    let help: LocalizedStringKey?

    init(
        help: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.help = help
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, DesignTokens.spacingStandard)
                .padding(.horizontal, DesignTokens.spacingStandard)
        }
        .background(.bar)
        .help(help ?? "")
    }
}
