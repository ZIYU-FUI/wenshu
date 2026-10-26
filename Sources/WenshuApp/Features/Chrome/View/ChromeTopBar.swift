// Sources/WenshuApp/UI/Chrome/ChromeTopBar.swift The format toolbar
// (`EditorFormatToolbar`) and future top accessory rows use this shared `ChromeTopBar`
// chrome surface (= the wenshu 1:1 Apple HIG top-of-column chrome recipe; = mirror
// image of `ChromeBottomFooter`). Single source of truth for the top-chrome shape; =
// no visual drift between the two call sites; = Apple-default 1:1. Difference from
// `ChromeBottomFooter` (= the bottom chrome): - `ChromeBottomFooter` has the
// `Divider()` AT THE TOP (= separates the body above from the footer below). -
// `ChromeTopBar` has the `Divider()` AT THE BOTTOM (= separates the bar above from the
// body below). The VStack content order is therefore reversed. Both surfaces use the
// same `.background(.bar)` Material (= the wenshu 1:1 macOS 27 canonical chrome tint).

import SwiftUI

/// Canonical Apple HIG top-of-column chrome surface
/// (= the top row of `Mail` / `Notes` / `Finder` /
/// `System Settings` sidebar rows + the `EditorFormatToolbar`
/// format toolbar in the editor zone). Use this for ANY
/// column-top chrome row (= toolbar, search bar, status
/// header above the NSTextView) so all column tops in wenshu
/// have the same surface recipe: `VStack(spacing: 0) { content;
/// .frame(maxWidth: .infinity, alignment: .leading);
/// .padding(.vertical, 8); .padding(.horizontal, 8);
/// .background(.bar) }` (= canonical Apple HIG column-top
/// chrome accessory surface).
///
/// any new column-top chrome
/// row MUST go through this component. The outer shell
/// (= VStack + content + padding + .background) is fixed
/// here; the per-call-site decisions are the `content:`
/// closure (= a horizontal HStack of SFIcon + Text chunks,
/// = Pages / Numbers / Xcode format-toolbar shape) and the
/// band's horizontal inset (= see `horizontalPadding`).
struct ChromeTopBar<Content: View>: View {
    /// The column-top content (= a horizontal HStack of
    /// SFIcon + Text + Button chunks). Caller supplies the
    /// HStack; this shell anchors it to the leading edge
    /// of the column (= Apple HIG format-toolbar format).
    @ViewBuilder let content: Content
    /// Optional tooltip (= maps to the surface's `.help(...)`
    /// modifier; = Apple HIG accessibility surface for
    /// the top-chrome row).
    let help: LocalizedStringKey?
    /// The band's horizontal inset (= the gap between the
    /// band's edge and its content).
    ///
    /// The shared default is 8 PT (= `DesignTokens.spacingStandard`),
    /// and the other call sites keep it. A call site whose column
    /// has a different inner inset passes its own: the sidebar's
    /// chrome band matches the tree's 10 PT row inset
    /// (= `DesignTokens.spacingRelaxed`), so the switcher inside it
    /// lines up with the tree rows below.
    let horizontalPadding: CGFloat

    init(
        help: LocalizedStringKey? = nil,
        horizontalPadding: CGFloat = DesignTokens.spacingStandard,
        @ViewBuilder content: () -> Content
    ) {
        self.help = help
        self.horizontalPadding = horizontalPadding
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
            Divider()
        }
        .background(.bar)
        .help(help ?? "")
    }
}
