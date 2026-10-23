//
//  CardCoverSlotWidthTests.swift · Wenshu
//
//  Proves the cover slot does not DECIDE how wide a card is.
//
//  The material column is 240 PT wide at its narrowest, and 33 PT of
//  that is the pane's own chrome (= the padding and the scrollbar),
//  so the content area a card gets is 207 PT.
//
//  A resizable picture with an aspect ratio asks for the width its own
//  ratio implies (= 100 PT tall x 2.40 = 240 PT), so a card whose
//  cover was showing demanded 240 PT inside a 207 PT slot, and the
//  column cut the card's right side off. The picture must be cropped
//  to the slot, never the other way round.
//
//  The measurement is on the REAL view, in the REAL modifier chain,
//  with a REAL picture. A stand-in would not answer the question: the
//  defect lives in the chain of modifiers, not in the pixels.
//

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Card cover slot width")
@MainActor
struct CardCoverSlotWidthTests {

    /// The narrowest width a card gets in the material column.
    ///
    /// Measured in the app: the column's frame is 240 PT at its
    /// minimum (= the split view's `min:`), and 33 PT of that is the
    /// pane's own chrome, so the content area is 207 PT.
    private static let narrowestContentWidth: CGFloat = 207

    /// A picture of the given size, drawn so it has real pixels.
    private func picture(width: CGFloat, height: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.systemTeal.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }

    /// The width the cover slot asks for.
    ///
    /// The chain is the one the card's thumbnail uses: a fixed height
    /// and the width the column gives. The host's fitting size is the
    /// width the slot DEMANDS, which is what overflows the column.
    private func demandedWidth(_ image: NSImage) -> CGFloat {
        let hosting = NSHostingView(rootView: AnyView(
            CardCoverView(imageURL: nil, image: image)
                .frame(height: DesignTokens.panelMinHeight)
                .frame(maxWidth: .infinity)
        ))
        hosting.layoutSubtreeIfNeeded()
        return hosting.fittingSize.width
    }

    @Test("The cover slot fits the narrowest content area")
    func theSlotFitsTheNarrowestContentArea() {
        // The stored banner: 768 x 320 (= 2.40:1).
        let width = demandedWidth(picture(width: 768, height: 320))

        #expect(width <= Self.narrowestContentWidth)
    }

    @Test("The picture's proportions do not change the width the slot asks for")
    func thePictureDoesNotDecideTheWidth() {
        let banner = demandedWidth(picture(width: 768, height: 320))
        let square = demandedWidth(picture(width: 320, height: 320))
        let tall = demandedWidth(picture(width: 320, height: 640))

        // A picture that is not 2.40:1 must not ask for a different
        // width: the slot's width comes from the column, and the
        // picture is cropped to fill it.
        #expect(square == banner)
        #expect(tall == banner)
    }

    @Test("The slot still asks for the height the card gives it")
    func theSlotKeepsTheBannerHeight() {
        let hosting = NSHostingView(rootView: AnyView(
            CardCoverView(imageURL: nil, image: picture(width: 768, height: 320))
                .frame(height: DesignTokens.panelMinHeight)
                .frame(maxWidth: .infinity)
        ))
        hosting.layoutSubtreeIfNeeded()

        #expect(hosting.fittingSize.height == DesignTokens.panelMinHeight)
    }
}
