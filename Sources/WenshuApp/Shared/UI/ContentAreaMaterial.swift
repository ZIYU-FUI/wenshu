// Shared/UI/ContentAreaMaterial.swift · WenshuApp
//
// The app's ONE content-area material (= the surface the column's
// interior chrome and the column's cards wear).
//
// WHY IT IS AN APPKIT VIEW AND NOT A SWIFTUI `Material`: = SwiftUI's
// `Material` family (= `.regularMaterial`, `.bar`, …) is a BEHIND-WINDOW
// material on macOS: = it paints whatever is BEHIND the window, = and this
// window is translucent (= one behind-window material at the root), = = so a
// SwiftUI material would paint the DESKTOP through the app's own content. =
// ⇒ That is the defect the column's card had with its glass surface: = the
// card's value TRACKED THE WALLPAPER behind the window (= 255 on a pale
// desktop, = 244 on a dark one, = 228 on another), = = so the card's tone
// changed with the DESKTOP rather than with the app. =
// ⇒ ⇒ ⇒ AND `.withinWindow` blending is the half that fixes it: = it
// samples the app's OWN content behind the surface, = = so the surface
// belongs to the column it sits in.
//
// WHY IT IS ONE FILE AND NOT A RECIPE PER CALL SITE: = the rule lives in
// two doors (= the column's bottom bar, = and the column's cards), = and a
// rule that lives in each door separately is a rule that drifts.
//
// WHY IT LIVES IN SHARED: = the bottom bar is a feature's view and the
// card is the column's shared view, = = and the surface they share is
// neither feature's property.
import AppKit
import SwiftUI

/// The system's own content-area material (= the surface drawn over
/// content, in the within-window blending).
///
/// ⇒ ⇒ ⇒ AND IT SHOWS THE COLUMN IT SITS IN (= = so a surface drawn over
/// it reads as a row of its column instead of a plate pasted onto it): = =
/// MEASURED on screen in the real app (= = both appearances, = = and the
/// capture's foreground PROVEN to be the app before its pixels were read):
/// = = the window-edge bars resolve to 28 (dark) / 255 (light), = = and
/// this material resolves to 48 (dark) / 222 (light), = = so it sits
/// BETWEEN its own column's ground (= = 78 dark / 190 light) and the bars'
/// value, = = and the STEP against that ground is 30 (dark) / 32 (light) = =
/// where the opaque plate's was 50 (dark) / 67 (light) (= = a white slab in
/// the light appearance, = = the foreign plate).
///
/// WHY A MATERIAL AND NOT A COLOUR: = the window is TRANSLUCENT (= one
/// behind-window material at the root), = = so a colour painted on top of
/// it = = = an opaque plate = = = and a plate pasted onto a translucent
/// column is exactly what the eye reads as "a foreign slab". = = A
/// MATERIAL paints what is BEHIND it, = = so the surface belongs to the
/// column it sits in.
///
/// WHY THE CONTENT-AREA MATERIAL AND NOT A TITLE-BAR ONE: = `.bar` (= =
/// and every behind-window material) paints the DESKTOP through this
/// translucent window, = = so the surface would change value whenever the
/// desktop changed = = and in the light appearance it would paint a WHITE
/// slab across the editor's dark paper. = = The content-area material
/// samples what is INSIDE the window, = = so the surface belongs to the
/// column it sits in.
enum ContentAreaMaterial {
    /// The material surface (= the content-area material, = = in the
    /// WITHIN-WINDOW blending).
    static var surface: some View {
        ContentAreaMaterialView()
    }
}

/// The content-area material, = = in the WITHIN-WINDOW blending (= = it
/// samples the app's OWN content behind the surface, = = not the desktop
/// behind the window).
private struct ContentAreaMaterialView: NSViewRepresentable {
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
