//
//  InspectorCardSurface.swift
//  wenshu
//
//  The one card surface the trailing inspector column's three pages
//  wear.
//
//  The column carries three pages (= the todos, the sub-agent tasks and
//  the task board), and each page draws its own cards. When each page
//  draws its own surface, the three sets drift (= a different corner
//  radius, = a different fill, = a different edge), and the column
//  reads as three apps stitched together.
//
//  So the surface lives here, once, and every card in the column wears
//  it (= the shared surface is what keeps the three pages' cards
//  looking like one family, = not a promise that a page remembers to
//  match).
//
//  The surface is Apple's Liquid Glass (= the `glassEffect` modifier,
//  = the material macOS 26 and later ship for a floating surface that
//  sits above the window's content). The project already wears it on
//  the chat's input bar, so the column's cards and the app's other
//  floating surfaces are one material.
//
//  Apple's own guidance for the shape is the system's shape factory
//  (= `.rect(cornerRadius:)`, = the rounded rectangle Apple's shape
//  vocabulary provides) and the system's glass variant (= `regular`).
//  The corner radius is the column's card radius, so every card in the
//  column rounds the same way.
//
//  Apple's own guidance for a set of glass surfaces is one
//  `GlassEffectContainer` (= it is how the system groups glass, = and
//  it is what lets neighbouring glass blend instead of stacking).
//  Apple's warning about it is that a container spacing LARGER than the
//  layout spacing makes neighbouring glass blend AT REST (= the cards
//  melt into one another while the column sits still), so the
//  container's spacing is the card spacing the column already uses.
//

import SwiftUI

/// The card surface the trailing inspector column's cards wear.
///
/// The surface wears Apple's Liquid Glass (= `.glassEffect`). The
/// radius is the column's card radius, so every card in the column
/// rounds the same way.
struct InspectorCardSurface: ViewModifier {
    /// Whether the card can be pressed (= the glass is interactive when
    /// it can, = the system's own reaction to a touchable surface).
    var isInteractive: Bool = false

    /// Whether the card carries the status edge (= the board's cards
    /// carry their group's colour on the left edge; = the plan's and
    /// the sub-agent's cards carry no edge).
    var showsStatusEdge: Bool = false

    /// The status edge's colour (= the group's colour on the board).
    var statusEdgeColor: AnyShapeStyle = AnyShapeStyle(Color.clear)

    /// The status edge (= the coloured band on the card's left edge).
    @ViewBuilder
    private var statusEdge: some View {
        Rectangle()
            .fill(statusEdgeColor)
            .frame(width: DesignTokens.kanbanCardStatusEdgeWidth)
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.spacingStandard)
            // The glass is the surface (= no hand-drawn fill and no
            // hand-drawn edge: = the system draws both, = and the
            // system's edge tracks the system's radius).
            .glassEffect(
                isInteractive ? .regular.interactive() : .regular,
                in: .rect(cornerRadius: DesignTokens.surfaceCornerRadiusCard)
            )
            .overlay(alignment: .leading) {
                if showsStatusEdge {
                    statusEdge
                }
            }
    }
}

extension View {
    /// Wear the trailing column's card surface.
    ///
    /// - Parameters:
    ///   - isInteractive: Whether the card can be pressed (= the glass
    ///     reacts to the press).
    ///   - showsStatusEdge: Whether the card carries the status edge
    ///     on its left edge.
    ///   - statusEdgeColor: The colour of the status edge (= the
    ///     board's cards carry their group's colour there).
    func inspectorCardSurface(
        isInteractive: Bool = false,
        showsStatusEdge: Bool = false,
        statusEdgeColor: AnyShapeStyle = AnyShapeStyle(Color.clear)
    ) -> some View {
        modifier(
            InspectorCardSurface(
                isInteractive: isInteractive,
                showsStatusEdge: showsStatusEdge,
                statusEdgeColor: statusEdgeColor
            )
        )
    }
}
