//
//  InspectorCard.swift
//  wenshu
//
//  The one card the trailing inspector column draws.
//
//  The column carries three pages (= the todos, the sub-agent tasks and
//  the task board), and each page draws its own cards. When each page
//  draws its own card, the three sets drift (= a different fill, = a
//  different corner radius, = a different marker column, = a different
//  edge), and the column reads as three apps stitched together.
//
//  So the card lives here, once, and every card in the column is one
//  of these. The shared card is what keeps the three pages' cards
//  looking like one family (= not a promise that a page remembers to
//  match).
//
//  The layout is the same for every card in the column:
//
//      [ marker ] [ content ]        [ trailing ]
//
//  The marker sits in a column of its own width, so every card's words
//  start at the same place. The content is the card's own words, and it
//  may be one line or three (= the cards differ in HEIGHT, = never in
//  LAYOUT).
//
//  The surface is Apple's Liquid Glass (= the `glassEffect` modifier,
//  = the material macOS 26 and later ship for a floating surface that
//  sits above the window's content). The project already wears it on
//  the chat's input bar, so the column's cards and the app's other
//  floating surfaces are one material.
//
//  Apple's own guidance for a set of glass surfaces is one
//  `GlassEffectContainer` (= it is how the system groups glass, = and
//  it is what lets neighbouring glass blend instead of stacking).
//  Apple's warning about it is that a container spacing LARGER than the
//  layout spacing makes neighbouring glass blend AT REST (= the cards
//  would melt into one another while the column sits still), so the
//  container's spacing is the card spacing the column already uses.
//

import SwiftUI

/// The trailing inspector column's card.
///
/// The card wears Apple's Liquid Glass and carries a marker column, so
/// every card in the column reads the same way.
struct InspectorCard<Content: View, Trailing: View>: View {
    /// The card's marker (= the state symbol, = a marker column of its
    /// own width so the words start at the same place in every card).
    let marker: AnyView

    /// The card's own words (= what the card is about).
    let content: Content

    /// What sits at the card's trailing edge (= a time, = a count, = a
    /// label; = nothing when the card carries no trailing piece).
    let trailing: Trailing

    /// The colour of the card's status edge (= the band's colour; = the
    /// card carries no edge when the colour is clear).
    let statusEdgeColor: AnyShapeStyle

    init(
        marker: AnyView,
        hasStatusEdge: Bool = false,
        statusEdgeColor: AnyShapeStyle = AnyShapeStyle(Color.clear),
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.marker = marker
        self.hasStatusEdge = hasStatusEdge
        self.statusEdgeColor = statusEdgeColor
        self.content = content()
        self.trailing = trailing()
    }

    /// Whether the card carries a status edge (= the edge is the band's
    /// colour, = and a card whose group has no colour carries no edge).
    private let hasStatusEdge: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingIconic) {
            // The marker sits in a column of its own width, and it sits
            // at the column's LEADING edge (= the column holds the
            // markers by their left edge, = so every symbol's ink starts
            // at the same place, = and the words of every card start at
            // the same place).
            marker
                .frame(width: DesignTokens.inspectionMarkerColumnWidth, alignment: .leading)
                .padding(.top, 1)
            content
            Spacer(minLength: 0)
            trailing
        }
        .padding(DesignTokens.spacingStandard)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The glass is the surface (= no hand-drawn fill and no
        // hand-drawn edge: = the system draws both, = and the system's
        // edge tracks the system's radius).
        //
        // The tint is white at 30% (= the glass scatters white light, =
        // and a tinted glass reads as a raised sheet of glass on a flat
        // ground, = while an untinted one leaves the ground showing
        // through unchanged and the card disappears into it). Measured
        // on the column's pale ground: untinted 229, = tinted 222, =
        // against a ground of 235.
        .glassEffect(
            .regular.tint(.white.opacity(0.30)),
            in: .rect(cornerRadius: DesignTokens.surfaceCornerRadiusCard)
        )
        .overlay(alignment: .leading) {
            if hasStatusEdge {
                Rectangle()
                    .fill(statusEdgeColor)
                    .frame(width: DesignTokens.kanbanCardStatusEdgeWidth)
            }
        }
    }
}

extension InspectorCard where Trailing == EmptyView {
    /// A card that carries no trailing piece.
    init(
        marker: AnyView,
        hasStatusEdge: Bool = false,
        statusEdgeColor: AnyShapeStyle = AnyShapeStyle(Color.clear),
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            marker: marker,
            hasStatusEdge: hasStatusEdge,
            statusEdgeColor: statusEdgeColor,
            content: content,
            trailing: { EmptyView() }
        )
    }
}
