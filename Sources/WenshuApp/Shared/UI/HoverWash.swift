// Sources/WenshuApp/UI/HoverWash.swift
//
// the product macOS 26+ hover wash (= .quaternary ShapeStyle
// inside the small button's corner radius RoundedRectangle). This is
// the same pattern Apple uses in Settings.app sidebar rows, Mail
// message rows, Finder toolbar buttons = the system-managed hover
// feedback (= adapts to dark/light + Increase Contrast
// automatically).
//
// Migration context: 7 sites in wenshu had self-written
//   @State private var isHover: Bool = false
//   .onHover { hovering in isHover = hovering }
//   .background(RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton).fill(
//       isHover ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color.clear)))
// = 7 copies of the same 4-line state plumbing + style block.
// Replaced by .hoverWash() = single source of truth for the
// hover wash plumbing + style.
//
// Apple APIs used (= no custom color or custom animation):
// - .quaternary (= HierarchicalShapeStyle, Apple SwiftUI built-in
//   system-managed ShapeStyle).
// - .onHover (= SwiftUI's hover callback; the SDK marks it unavailable on
//   tvOS/watchOS, and .hoverEffect is the visionOS equivalent, no-op here).
// - .background (= SwiftUI's own modifier).
// - RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton) (= SwiftUI Shape, Apple
//   wenshu's small-button radius token, reused for the wash shape).
// - AnyShapeStyle (= type-erased ShapeStyle wrapper, Apple API).
//
// Justified exceptions (= sites that use different hover semantics
// and should NOT use this modifier):
// - ZoneEditor.swift onHover handler pushes/pops NSCursor (= hover
//   semantics = 'change the mouse cursor to resize', not 'apply a
//   background wash' = different responsibility).
// - PreviewPane.swift card uses .stroke on hover (= hover
//   semantics = 'tint the card outline', not 'fill the background'
//   = different visual feedback type).

import SwiftUI

extension View {
    /// Apply the product hover wash (= .quaternary ShapeStyle
    /// inside the small button's corner radius RoundedRectangle = the
    /// macOS 26+ standard hover feedback for toolbar / chrome
    /// buttons).
    ///
    /// product rationale:
    /// - .quaternary is a SwiftUI built-in ShapeStyle (= Apple API,
    ///   not a project custom color).
    /// - .quaternary auto-adapts to dark/light mode + Increase Contrast
    ///   (= system-managed, no per-app override).
    /// - The corner radius is the product's own small-button radius token,
    ///   (= the same radius the product's small buttons use, so the wash
    ///   follows the button it washes).
    /// - The .onHover callback is SwiftUI's own hover API; .hoverEffect is the
    ///   visionOS equivalent and a no-op here,
    ///   (= so .onHover is the only SwiftUI option on
    ///   this platform).
    func hoverWash() -> some View {
        modifier(HoverWashModifier())
    }

    /// The SAME wash, painted OVER the view's own content, in the
    /// view's OWN shape, from a hover state the CALLER owns.
    ///
    /// ⇒ ⇒ ⇒ WHY A SECOND ENTRY: = = a wash painted UNDER the
    /// content (= = which is what `.background` does) is BURIED by any
    /// opaque content, = = and a card on a material is exactly that
    /// case. = = ⇒ So the card's wash has to be painted OVER the
    /// material, = = and in the card's own shape (= = so the wash's
    /// corner follows the card's corner, = = instead of a smaller
    /// rectangle floating inside it).
    ///
    /// ⇒ ⇒ ⇒ AND WHY THE CALLER OWNS THE HOVER STATE: = = a tracking
    /// area that lives INSIDE a Button's label is torn down and
    /// rebuilt when the label re-renders, = = and the re-render is
    /// what the hover state causes, = = so the wash FLICKERS (= = the
    /// pointer enters, = = the state flips, = = the label re-renders,
    /// = = the tracking area is rebuilt, = = the pointer is reported
    /// as gone, = = the state flips back, = = = = and again). = = ⇒
    /// The caller hangs the tracking area on the control OUTSIDE the
    /// label, = = where a label's re-render cannot reach it.
    ///
    /// ⇒ AND IT CARRIES NO `.contentShape`: = = the caller's own
    /// shape governs the region, = = and a rectangular hit shape would
    /// reach past a rounded card's corners.
    func hoverWashOverlay(
        cornerRadius: CGFloat,
        isHovering: Binding<Bool>
    ) -> some View {
        modifier(
            HoverWashOverlayModifier(
                cornerRadius: cornerRadius,
                isHovering: isHovering
            )
        )
    }
}

private struct HoverWashModifier: ViewModifier {
    @State private var isHover: Bool = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onHover { hovering in
                isHover = hovering
            }
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton)
                    .fill(isHover
                        ? AnyShapeStyle(.quaternary)
                        : AnyShapeStyle(Color.clear))
            )
    }
}

private struct HoverWashOverlayModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Binding var isHovering: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovering
                        ? AnyShapeStyle(.quaternary)
                        : AnyShapeStyle(Color.clear))
            }
    }
}
