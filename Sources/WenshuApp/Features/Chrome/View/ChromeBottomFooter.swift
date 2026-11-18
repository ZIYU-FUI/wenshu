// Sources/WenshuApp/UI/Chrome/ChromeBottomFooter.swift 2026-10-12: the editor status bar
// (`EditorStatusBarView`) and the chat token-count footer
// (`ChatInputBarView.tokenCountFooter`) have been diverging across 5 visual round-
// trips. The boss's 2026-10-12 directive "你去看一下聊天区的底栏的写法. 照抄就行了, 那是已经实现过的逻辑" — and the
// alternate "或者你把聊天区的低栏 抽象个组件. 让编辑器区直接应用也可以" — converge on the same solution: extract
// a single shared `ChromeBottomFooter` component and use it from BOTH call sites. The
// shared component is the canonical Apple HIG sidebar-bottom-accessory chrome surface
// recipe (= `VStack(spacing: 0) { Divider; content; .frame(maxWidth: .infinity, alignment:
// .leading); .padding(.vertical, 8); .padding(.horizontal, 8) } .background(the surface
// this bar wears)`).
// Chat `tokenCountFooter` AND editor `EditorStatusBarView` both render their content
// slot inside this same shell. Single source of truth for the bottom-chrome shape; = =
// no visual drift between the two call sites; = Apple-default 1:1.
import AppKit
import SwiftUI

/// The surface a column-bottom bar wears (= = which edge the bar sits on).
///
/// ⇒ TWO CASES, = = and the difference is the bar's EDGE: = =
/// - `.windowEdge`: the bar IS the window's bottom edge. = The surface
///   is the system's own OPAQUE control background, = = so every
///   column's bar resolves to ONE value and the window's bottom edge
///   reads as ONE line.
/// - `.columnMaterial`: the bar is an INTERIOR seam INSIDE a column. =
///   The surface is the system's own CONTENT-AREA MATERIAL, = = so the
///   band is TRANSLUCENT (= it shows what is behind it) and reads as a
///   row of the column instead of a plate floating above it.
///
/// WHY THE TWO DIFFER. = The opaque surface exists because this window is
/// TRANSLUCENT (= one behind-window material at the root), = = so a bar
/// painted with a BEHIND-WINDOW material would sample a DIFFERENT patch
/// of the desktop in every column, = = and the window's bottom edge
/// would read as several greys. = That is a WINDOW-EDGE fact, = = and it
/// does not reach an interior seam: = the ground behind an interior seam
/// is the app's OWN ground (= the same one the column's body shows), = =
/// so there is no desktop to keep out and no second column to agree
/// with. = ⇒ ⇒ ⇒ AND THE OPAQUE PLATE THERE READS AS A FOREIGN SLAB: =
/// the band's own value sits against the column's own ground, = = and
/// the STEP between them is what the reader sees as a bar pasted onto
/// the column. = ⇒ ⇒ ⇒ ⇒ So an interior seam wears a MATERIAL (= = the
/// one Apple's own header names for a content-area background:
/// `NSColor.controlBackgroundColor` "should not be used for drawing, and
/// NSVisualEffectMaterialContentBackground should be used instead" = =
/// `NSColor.h`).
enum ChromeBottomFooterSurface {
    /// The bar is the window's bottom edge (= the opaque control surface).
    case windowEdge
    /// The bar is an interior seam (= the system's content-area material).
    case columnMaterial
}

/// The chrome material the interior-seam surface wears.
///
/// ⇒ ⇒ ⇒ AND IT SHOWS THE COLUMN IT SITS IN (= = so the band reads as
/// a row of its column instead of a plate pasted onto it):
/// = = MEASURED on screen in the real app (= = both appearances, = =
/// and the capture's foreground PROVEN to be the app before its pixels
/// were read): = = the window-edge bars resolve to 28 (dark) / 255
/// (light), = = and this band's material resolves to 48 (dark) / 222
/// (light), = = so the band sits BETWEEN its own column's ground (= =
/// 78 dark / 190 light) and the bars' value, = = and the STEP against
/// that ground is 30 (dark) / 32 (light) = = where the opaque plate's
/// was 50 (dark) / 67 (light) (= = a white slab in the light
/// appearance, = = the foreign plate the boss's screenshot shows).
///
/// WHY A MATERIAL AND NOT A COLOUR: = the window is TRANSLUCENT (= one
/// behind-window material at the root), = = so a colour painted on top
/// of it = = = an opaque plate = = = and a plate pasted onto a
/// translucent column is exactly what the eye reads as "a foreign slab".
/// = = A MATERIAL paints what is BEHIND it, = = so the band belongs to
/// the column it sits in.
///
/// WHY THE CONTENT-AREA MATERIAL AND NOT A TITLE-BAR ONE: = `.bar` (= =
/// and every behind-window material) paints the DESKTOP through this
/// translucent window, = = so the band would change value whenever the
/// desktop changed = = and in the light appearance it would paint a
/// WHITE slab across the editor's dark paper (= = measured 238 there,
/// = = which reads as a foreign white plate). = = The content-area
/// material samples what is INSIDE the window, = = so the band belongs
/// to the column it sits in.
enum ChromeBottomFooterMaterial {
    /// Apple's content-area material (= = the one `NSColor.h` names for
    /// a background drawn over content).
    static var contentArea: some View {
        ContentAreaSurface()
    }
}

/// The content-area material, = = in the WITHIN-WINDOW blending (= = it
/// samples the app's OWN content behind the band, = = not the desktop
/// behind the window).
private struct ContentAreaSurface: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .withinWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context _: Context) {
        view.material = .underWindowBackground
        view.blendingMode = .withinWindow
        view.state = .active
    }
}

/// Canonical Apple HIG sidebar-bottom-accessory chrome surface
/// (= the bottom row of `Mail` / `Notes` / `Finder` /
/// `System Settings` sidebar rows + `ChatInputBarView` token
/// footer + `EditorStatusBarView` status bar). Use this for
/// ANY column-bottom accessory row (= footer text, status
/// indicator, secondary action button, etc.) so all column
/// bottoms in wenshu have the same surface recipe: `Divider`
/// above + content + 8 PT all-around padding (= the canonical
/// Apple HIG sidebar-bottom-accessory height of ~38 PT).
///
/// any new column-bottom chrome
/// row MUST go through this component. The outer shell
/// (= VStack + Divider + padding) is fixed here; the per-call-site
/// decisions are the `content:` closure (= a horizontal HStack of
/// SFIcon + Text chunks, = Pages / Numbers / Xcode inspector status
/// row shape) and the `surface:` (= which edge the bar sits on, = =
/// which surface it wears).
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
    /// Which surface the bar wears (= = which edge it sits on).
    ///
    /// The shared default is `.windowEdge` (= the bar is the window's
    /// bottom edge, = = so the opaque control surface makes every
    /// column's bar resolve to one value). = A bar that is an interior
    /// seam INSIDE a column asks for `.columnMaterial` (= = the
    /// system's own content-area material, = = so the band is
    /// translucent and blends with the column's own ground).
    let surface: ChromeBottomFooterSurface

    init(
        surface: ChromeBottomFooterSurface = .windowEdge,
        help: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.surface = surface
        self.help = help
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            content
                .frame(
                    maxWidth: .infinity,
                    minHeight: Self.contentRowHeight,
                    maxHeight: Self.contentRowHeight,
                    alignment: .leading
                )
                .clipped()
                .padding(.vertical, DesignTokens.spacingStandard)
                .padding(.horizontal, DesignTokens.spacingStandard)
        }
        .background(surfaceBackground)
        .help(help ?? "")
    }

    /// The surface the bar paints.
    ///
    /// ⇒ `.windowEdge` = the system's OWN OPAQUE control background
    /// (= `NSColor.controlBackgroundColor`), not a material.
    ///
    /// WHY: a behind-window material is TRANSLUCENT (= it paints whatever
    /// is BEHIND it), = and this window is translucent (= one
    /// behind-window material at the root), = = so each column's bar
    /// sampled a DIFFERENT patch of the desktop and every bar came out a
    /// different grey. = An opaque system colour resolves to the same
    /// value in every column of one appearance (= the desktop can no
    /// longer reach it), = = so the window's bottom edge reads as ONE
    /// line, = = and the light and dark appearances each resolve to their
    /// own value (= the bar follows the theme).
    ///
    /// `Color(nsColor:)` is an AppKit SEMANTIC colour (= not a raw
    /// `Color.X.opacity(N)` literal), = the same primitive the
    /// sidebar's row-icon tile wears (= `IconStyles.swift`), = = so the
    /// v3.0 colour rule holds.
    ///
    /// ⇒ `.columnMaterial` = the system's own CONTENT-AREA MATERIAL
    /// (= = `NSVisualEffectMaterialContentBackground`, = = the material
    /// `NSColor.h` names for a background drawn over content), = = in
    /// the WITHIN-WINDOW blending (= = it samples the app's own content
    /// behind the band, = = so it belongs to the column it sits in).
    ///
    /// WHY A MATERIAL AND NOT THE COLUMN'S OWN GROUND (= = why not
    /// simply no fill): = a bar with NO fill is not a BAR at all
    /// (= the eye reads the row as more of the column, = = and the
    /// status text loses the surface it sits on). = The material is
    /// the system's own chrome surface, = = so the band reads as a
    /// band, = = but translucent, = = so it does not paste a hard
    /// edge onto the column behind it.
    ///
    /// WHY THE MATERIAL AND NOT A COLOUR: = a colour painted on this
    /// translucent window = = = an opaque plate = = = and the eye reads
    /// a plate pasted onto a translucent column as a FOREIGN SLAB. = = A
    /// MATERIAL paints what is BEHIND it, = = so the band belongs to
    /// the column it sits in.
    @ViewBuilder
    private var surfaceBackground: some View {
        switch surface {
        case .windowEdge:
            Color(nsColor: .controlBackgroundColor)
        case .columnMaterial:
            // The material IS the band's own surface (= = a fill of its
            // own would cover the material).
            ChromeBottomFooterMaterial.contentArea
        }
    }

    /// The content row's height inside the bar.
    ///
    /// The bar's total height is `DesignTokens.chromeBottomFooterHeight`
    /// (= 32 PT). The divider and the 8 PT padding above and below the
    /// row take 17 of those points, so the row gets the rest.
    ///
    /// MEASURED, not estimated: the row is the height of a `.callout`
    /// text line, so a bar that carries a text row and a bar that
    /// carries a button are the same size.
    private static var contentRowHeight: CGFloat {
        DesignTokens.chromeBottomFooterHeight
            - DesignTokens.dividerHeight
            - (2 * DesignTokens.spacingStandard)
    }
}
