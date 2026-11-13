// Sources/WenshuApp/UI/Chrome/ChromeTopBar.swift The column-top chrome
// rows (the sidebar's switcher band, = the assets column's search band,
// = the inspector column's page band) use this shared `ChromeTopBar`
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
/// `System Settings` sidebar rows). Use this for ANY
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
    /// Whether the band paints the shared chrome material.
    ///
    /// The shared default is FALSE (= the band belongs to its column's
    /// body: the column's own background shows through, so the row reads
    /// as part of the column instead of a separate bar floating above
    /// it). A band that belongs to the WINDOW asks for TRUE: the
    /// window-chrome tint then paints it.
    ///
    /// Why the default moved (2026-11-04): the editor's format-toolbar
    /// band was the one production band that asked for the material, and
    /// that band is gone (= the format commands moved to the inspector
    /// column's format page). Every band the app draws today belongs to
    /// its column, so the default now says so, and a future window-chrome
    /// band asks for the material by name.
    let usesMaterial: Bool

    init(
        help: LocalizedStringKey? = nil,
        horizontalPadding: CGFloat = DesignTokens.spacingStandard,
        usesMaterial: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.help = help
        self.horizontalPadding = horizontalPadding
        self.usesMaterial = usesMaterial
        self.content = content()
    }

    var body: some View {
        Group {
            if usesMaterial {
                band.background(.bar)
            } else {
                band
            }
        }
        .help(help ?? "")
    }

    /// The band's shape (= the content row + its hairline). The chrome
    /// material is a separate, per-call-site decision: see `usesMaterial`.
    ///
    /// The hairline is an OVERLAY on the band's bottom edge, = not a row
    /// of its own. = the band's content row then spans the band's FULL
    /// height (= `paneTabHotArea`), = so the content in it is centred in
    /// the same 28 PT row every other column's content is centred in.
    ///
    /// Why (= 2026-11-12): the boss ruled that every column's top bar
    /// lines up (= "all the columns' top bars need one alignment pass"),
    /// and the editor zone's teb strip is the baseline. = the teb strip's
    /// drawn capsule sits centred in its 28 PT band (= MEASURED: the
    /// pill's own frame is 86..106 in a band of 82..110), = and the side
    /// columns' switcher used to sit 2 PT lower (= 88..108), = because
    /// the divider took a row of the band and the switcher was centred in
    /// what was left. = the pill's own line is now the same line in every
    /// column.
    ///
    /// The overlay draws the hairline at the band's bottom edge (= the
    /// same 109..110 row the divider row drew it in), = so the band
    /// still ends exactly where the column's body starts.
    private var band: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            // The band's hairline is the SHARED one (= `ChromeHairline`),
            // because the editor zone's document strip and the chat zone's
            // session bar close their bands with the same mark, = and a rule
            // that lives in each door separately is a rule that drifts.
            .bandBottomHairline()
    }
}
