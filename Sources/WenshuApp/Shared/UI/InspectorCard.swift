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
///
/// ⇒ ⇒ ⇒ AND WHEN THE CARD OPENS SOMETHING, = = THE WHOLE CARD IS
/// THE CONTROL: = = the hover answers over the whole card, = = and the
/// click answers over the whole card, = = and the pointer says "this
/// opens" over the whole card (= = including over the card's own
/// words, = = which is why the card's words are not selectable text =
/// = a selectable text answers the pointer with a text cursor, = = and
/// a text cursor over a card says "this is a document", = = not "this
/// opens something").
struct InspectorCard<Content: View, Trailing: View>: View {
    /// The card's marker (= the state symbol, = a marker column of its
    /// own width so the words start at the same place in every card).
    let marker: AnyView

    /// The card's own words (= what the card is about).
    let content: Content

    /// What sits at the card's trailing edge (= a time, = a count, = a
    /// label; = nothing when the card carries no trailing piece).
    let trailing: Trailing

    /// What opens the card (= nothing when the card opens nothing, = =
    /// and a card that opens nothing must NOT wear the open card's
    /// answers, = = because a card that lights up under the pointer
    /// and then does nothing is a lie the user pays for).
    let onOpen: (() -> Void)?

    /// Whether the pointer is over the card (= = the card's own answer
    /// to the pointer, = = and the card's own words draw it).
    ///
    /// ⇒ ⇒ ⇒ WHY THE CARD HOLDS IT AND NOT THE WASH: = = the wash
    /// lives INSIDE the Button's label, = = and a tracking area inside
    /// a label is rebuilt whenever the label re-renders, = = so a wash
    /// that owned its own tracking area FLICKERS (= = the pointer
    /// enters, = = the wash draws, = = the label re-renders, = = the
    /// tracking area is rebuilt, = = the pointer is reported as gone,
    /// = = the wash clears, = = = = and again). = = ⇒ The tracking
    /// area hangs on the Button, = = outside the label, = = where a
    /// label's re-render cannot reach it.
    @State private var isHovering: Bool = false

    init(
        marker: AnyView,
        onOpen: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.marker = marker
        self.onOpen = onOpen
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
        if let onOpen {
            // The card IS the control (= = the whole card is the
            // button, = = so the click answers over the card's
            // padding and its empty space, = = and not only over
            // its words).
            //
            // ⇒ AND THE BUTTON IS PLAIN: = = the card draws its own
            // surface, = = and a button style that drew a bezel
            // would put Apple's own chrome on top of it.
            //
            // ⇒ AND THE POINTER IS THE SYSTEM'S OWN: = = a hand
            // over a thing that opens, = = which is the one answer
            // macOS has that says "this opens something" (= = the
            // arrow says nothing, = = and the text cursor says the
            // opposite).
            Button(action: onOpen) {
                cardSurface
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            // ⇒ THE TRACKING AREA HANGS HERE, = = on the control
            // and NOT inside its label, = = so the wash's own
            // re-render cannot tear it down (= = which is what
            // made the wash FLICKER).
            .onHover { isHovering = $0 }
        } else {
            cardSurface
        }
    }

    /// The card's own surface (= its words, = its material, = its
    /// hairline, = and its hover wash).
    private var cardSurface: some View {
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
        // The HOVER WASH (= Apple's own .quaternary, = = the system's
        // own hierarchical fill, = = so it adapts to light, = = to dark
        // and to Increase Contrast by itself).
        //
        // ⇒ ⇒ ⇒ WHY IT IS PAINTED OVER THE MATERIAL AND NOT UNDER IT:
        // = = the material is opaque enough to bury a wash painted
        // under it, = = which is why the app's old hover did NOTHING on
        // a card (= = the card's surface was drawn over the wash).
        //
        // ⇒ ⇒ ⇒ AND WHY IT WEARS THE CARD'S OWN CORNER: = = a wash
        // in a smaller radius floats inside the card's rounded corner
        // instead of following it, = = and the card's radius is the
        // app's own token, = = not a number invented here.
        //
        // ⇒ ⇒ ⇒ AND WHY IT ANSWERS OVER THE WHOLE CARD: = = the wash
        // is drawn over the card's own frame, = = so the pointer
        // anywhere on the card lights the card, = = and not only the
        // pointer over its words.
        .hoverWashOverlay(
            cornerRadius: DesignTokens.surfaceCornerRadiusCard,
            isHovering: $isHovering
        )
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
        onOpen: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            marker: marker,
            onOpen: onOpen,
            content: content,
            trailing: { EmptyView() }
        )
    }
}
