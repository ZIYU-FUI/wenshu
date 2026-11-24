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
//  The surface is the app's OWN content-area material (= the surface the
//  column's bottom bar wears, = = the one that samples the app's own
//  content behind it and never the desktop).
//
//  ⇒ ⇒ ⇒ WHY A MATERIAL AND NOT THE GLASS SURFACE THE CARD WORE: = = the
//  glass surface's value TRACKED THE WALLPAPER behind the window (= 255 on
//  a pale desktop, = 244 on a dark one, = 228 on another), = = so the card's
//  tone changed with the DESKTOP rather than with the app, = = and a white
//  30% tint over a pale ground made the card DARKER than the ground
//  (= 228 against 255, = = so it read as a recessed grey slab instead of a
//  card on the column). = ⇒ ⇒ ⇒ AND THE CONTENT-AREA MATERIAL IS THE ONE
//  THAT SHOWS THE COLUMN IT SITS IN: = = measured on the real app's own
//  screen, = = it resolves to 48 (dark) / 222 (light), = = so it sits
//  BETWEEN its column's ground (= 78 dark / 190 light) and the window's
//  bottom edge (= 28 dark / 255 light), = = and the step against its own
//  ground is 30 (dark) / 32 (light), = = where an opaque plate's step was
//  50 (dark) / 67 (light) (= = a white slab pasted onto the column).
//
//  ⇒ ⇒ ⇒ AND THE CARD CARRIES NO COLOURED EDGE: = = the band down the
//  leading edge was the card's loudest element while saying the same
//  thing the state glyph beside the title already said. = The state rides
//  on the glyph and on the card's own words.
//

import SwiftUI

/// The trailing inspector column's card.
///
/// The card wears the app's own content-area material and carries a
/// marker column, so every card in the column reads the same way.
struct InspectorCard<Content: View, Trailing: View>: View {
    /// The card's marker (= the state symbol, = a marker column of its
    /// own width so the words start at the same place in every card).
    let marker: AnyView

    /// The card's own words (= what the card is about).
    let content: Content

    /// What sits at the card's trailing edge (= a time, = a count, = a
    /// label; = nothing when the card carries no trailing piece).
    let trailing: Trailing

    init(
        marker: AnyView,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.marker = marker
        self.content = content()
        self.trailing = trailing()
    }

    /// The card's own shape (= the system's rounded rectangle, = at the
    /// card's radius).
    ///
    /// ⇒ ONE SHAPE FOR BOTH THE EDGE AND THE CLIP: = = the hairline has
    /// to follow the card's own corner exactly, = = and two shapes would
    /// be two chances to drift.
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusCard)
    }

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
        // The surface is the material (= the column's own ground shows
        // through it, = = so the card reads as a card in this column and
        // not as a plate laid on top of it).
        .background {
            ContentAreaMaterial.surface
        }
        // The card's own edge (= the system separator, = = the hairline
        // every bounded surface in the app wears). = The material paints
        // no edge of its own (= a glass surface drew one, = a material
        // does not), = = so without this the card would have no boundary
        // at all.
        .overlay {
            cardShape.strokeBorder(.separator, lineWidth: 1)
        }
        // The clip comes LAST (= the material's blur is a rectangle, = =
        // and the clip is what gives it the card's rounded corners, = =
        // and it has to come after the edge so the edge is clipped with
        // it).
        .clipShape(cardShape)
    }
}

extension InspectorCard where Trailing == EmptyView {
    /// A card that carries no trailing piece.
    init(
        marker: AnyView,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            marker: marker,
            content: content,
            trailing: { EmptyView() }
        )
    }
}
