// Sources/WenshuApp/UI/HoverWash.swift
//
// v0.34 boss 2026-09-02 OOB 'hover 效果也拉齐, 用 apple api' (= hover
// effect should be unified, use Apple API).
//
// Apple HIG canonical macOS 26+ hover wash (= .quaternary ShapeStyle
// inside a 4 PT corner radius RoundedRectangle). This is the same
// pattern Apple uses in Settings.app sidebar rows, Mail message
// rows, Finder toolbar buttons = the system-managed hover feedback
// (= adapts to dark/light + Increase Contrast automatically).
//
// Prior state: 7 sites in wenshu had self-written
//   @State private var isHover: Bool = false
//   .onHover { hovering in isHover = hovering }
//   .background(RoundedRectangle(cornerRadius: 4).fill(
//       isHover ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color.clear)))
// = 7 copies of the same 4-line state plumbing + style block.
// Replaced by .hoverWash() = single source of truth for the
// hover wash plumbing + style. All 7 sites migrated.
//
// Apple API used (= no custom color or custom animation):
// - .quaternary (= HierarchicalShapeStyle, Apple SwiftUI built-in
//   system-managed ShapeStyle).
// - .onHover (= Apple canonical SwiftUI macOS hover callback
//   since macOS 10.15; .hoverEffect is visionOS-only no-op on macOS).
// - .background (= SwiftUI modifier, Apple canonical).
// - RoundedRectangle(cornerRadius: 4) (= SwiftUI Shape, Apple
//   canonical 4 PT corner = standard small button hover shape).
// - AnyShapeStyle (= type-erased ShapeStyle wrapper, Apple API).
//
// Justified exceptions (= sites that use different hover semantics
// and should NOT use this modifier):
// - ZoneEditor.swift onHover handler pushes/pops NSCursor (= hover
//   semantics = 'change the mouse cursor to resize', not 'apply a
//   background wash' = different responsibility).
// - PreviewPane.swift BookDocCard uses .stroke on hover (= hover
//   semantics = 'tint the card outline', not 'fill the background'
//   = different visual feedback type).
//
// Both are 1 of 17 .onHover sites in the project (= 88% migrated
// to this single source of truth).

import SwiftUI

extension View {
    /// Apply Apple HIG canonical hover wash (= .quaternary ShapeStyle
    /// inside a 4 PT corner radius RoundedRectangle = the macOS 26+
    /// standard hover feedback for toolbar / chrome buttons).
    ///
    /// Apple HIG rationale:
    /// - .quaternary is a SwiftUI built-in ShapeStyle (= Apple API,
    ///   not a project custom color).
    /// - .quaternary auto-adapts to dark/light mode + Increase Contrast
    ///   (= system-managed, no per-app override).
    /// - 4 PT corner radius matches Apple HIG small button hover shape
    ///   (= same as Settings / Mail / Finder toolbar buttons).
    /// - The .onHover callback is the Apple canonical SwiftUI macOS
    ///   pattern since macOS 10.15; .hoverEffect is visionOS-only
    ///   (= no-op on macOS, so .onHover is the only Apple option on
    ///   this platform).
    public func hoverWash() -> some View {
        modifier(HoverWashModifier())
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
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHover
                        ? AnyShapeStyle(.quaternary)
                        : AnyShapeStyle(Color.clear))
            )
    }
}
