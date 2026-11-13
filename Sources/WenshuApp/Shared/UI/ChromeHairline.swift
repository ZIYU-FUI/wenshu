// Shared/UI/ChromeHairline.swift · WenshuApp
//
// The app's ONE hairline mark (= the edge between chrome and content).
//
// The mark is SwiftUI's own `Divider()` (= the system's separator color,
// so it follows the app's appearance and needs no color of its own),
// and it is drawn as an OVERLAY (= not a row of its own): = a row
// would take height from the band, = and the bands' heights are
// aligned on purpose (= every band is one `paneTabHotArea` row), =
// so an overlay keeps the hairline at the edge without moving
// anything above it.
//
// ONE owner, because the rule lives in four doors (= the editor
// zone's document strip, = the chat zone's session bar, = the shared
// column-top chrome, = and the window's own toolbar) and a rule that
// lives in each door separately is a rule that drifts.
//
// WHY THE APP DRAWS IT (= and does not ask AppKit to):
//
// Apple's own parameter for the window's own edge is
// `NSWindow.titlebarSeparatorStyle` (= `NSTitlebarSeparatorStyle`:
// `.automatic`, `.none`, `.line`, `.shadow`), = and its header names
// the job: "Specifies the style of separator displayed between the
// window's titlebar and content." SwiftUI does not expose it, = so a
// bridge could set it on the window.
//
// MEASURED on this app's own window: the bridge sets the property
// (= the window reads the style back as `.line`) and PAINTS NOTHING.
// A controlled A/B of the same build against the same library (= the
// same bundle id, = the same books, = the same window) shows the rows
// at the toolbar's lower edge are byte-identical with and without
// the bridge: = the titlebar's surface steps 39 -> 38 and stays
// there, = and no hairline appears at 52 PT. = Apple's separator is
// drawn by the titlebar's own background, = and this window paints
// its toolbar background itself (= `.toolbarBackground(.ultraThin
// Material, for: .windowToolbar)`), = so the system edge is not
// drawn there.
//
// Apple's HIG names the other candidate, = and this app's shape does
// not meet its precondition:
//   - toolbars: "use a ScrollEdgeEffectStyle when necessary to
//     distinguish the toolbar area from the content area."
//   - scroll-views: "Only use a scroll edge effect when a scroll view
//     is behind floating interface elements."
// The window's content starts BELOW the toolbar strip (= it does not
// scroll under it), = so there is no scroll view behind a floating
// element, = and the effect has nothing to separate.
//
// So the edge is the app's own decision (= the mark, = the position,
// = and the weight are the app's), = drawn with the same `Divider()`
// every other edge in the app uses, = so the window's edge and the
// columns' edges are ONE kind of line.
import SwiftUI

/// The hairline that separates a chrome band from the content below it.
///
/// ⇒ ⇒ ⇒ THE ORIENTATION IS PINNED, = = and that is not a detail: = =
/// SwiftUI's `Divider()` takes its orientation from the AMBIENT stack, =
/// so the SAME `Divider()` draws a horizontal rule inside a `VStack` and
/// a VERTICAL one inside an `HStack`. ⇒ ⇒ ⇒ The editor zone's document
/// strip is hosted in an `HStack` (= `EditorView.swift:159`), = so an
/// unpinned `Divider()` there painted a one-point VERTICAL STUB at the
/// strip's centre instead of the horizontal edge the band needs. ⇒ ⇒ ⇒
/// MEASURED on the app's own window: = the tip before this pin painted a
/// vertical stub at device columns 1582-1583 spanning rows 104-159, = and
/// the tip at this pin paints none there. (= 104..159 is 56 device rows
/// = 28.0 PT = = exactly the band's height, = so the stub was the band.) ⇒ ⇒ ⇒ Wrapping the `Divider()`
/// in a `VStack` pins the orientation (= a `VStack` inside an `HStack`
/// still draws the horizontal rule), = so the mark is the same in every
/// host.
struct ChromeHairline: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider()
        }
    }
}

extension View {
    /// Closes a column-top band with the shared hairline.
    ///
    /// The overlay is applied to the BAND (= the view that carries the
    /// band's full height), = so the hairline sits on the band's bottom
    /// edge and spans the band's width.
    func bandBottomHairline() -> some View {
        overlay(alignment: .bottom) {
            ChromeHairline()
        }
    }

    /// Closes the window's toolbar strip with the shared hairline.
    ///
    /// The overlay is applied to the window's CONTENT (= the view that
    /// starts where the toolbar strip ends), = so the hairline sits on
    /// the toolbar's lower edge and spans the window's width.
    func windowToolbarBottomHairline() -> some View {
        overlay(alignment: .top) {
            ChromeHairline()
        }
    }
}
