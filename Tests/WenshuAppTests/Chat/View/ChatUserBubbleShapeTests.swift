//
//  ChatUserBubbleShapeTests.swift
//
//  The user's own message reads as a BAND, not a bubble: one
//  content-area material that spans the chat area, ink starting at the
//  band's leading edge, width taken from the column and never from the
//  message.
//
//  These assertions measure the RENDERED GEOMETRY of the real
//  `ChatMessageView` (= the production view tree SwiftUI lays out under
//  an `NSHostingView`), not the source text, except where the rule is a
//  token rule and the source is the only place that token is decided.
//
//  WHY THE LAYOUT AND NOT THE PIXELS: the band's surface is a material
//  (`ContentAreaMaterial.surface`), and an offscreen read
//  (`cacheDisplay(in:to:)`) does not composite a material at all (= the
//  same limit the house recorded for the macOS 27 tab strip: a control's
//  appearance must be measured on a SCREEN capture, never on
//  `cacheDisplay`). The band's GEOMETRY is a layout question, and the
//  layout is what the production view tree hands over exactly.
//
//  The chat area's full 20 PT inset is measured one level up, in
//  `ChatTranscriptFlatFlowTests`, where the real transcript stack hosts
//  the row together with the replies; this suite hosts the row alone,
//  so it measures the row's own inset.
//
//  The layout is MainActor-isolated (= it reads the actor-isolated
//  DesignTokens), so the suite runs on the main actor too.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Chat user band shape — the outgoing band spans the chat area")
struct ChatUserBubbleShapeTests {
    /// The chat column width the band is measured inside (= the width
    /// the running app's chat column measures).
    private static let columnWidth: CGFloat = 723

    /// The laid out band frame and the number of material surfaces the
    /// row paints, in the hosting view's coordinate space.
    private struct Band {
        let origin: CGPoint
        let size: CGSize
        let surfaces: Int
        var right: CGFloat {
            origin.x + size.width
        }

        var height: CGFloat {
            size.height
        }
    }

    /// Lay the REAL outgoing message view out inside a chat column and
    /// read the band back.
    ///
    /// The hosting view is deliberately windowless: the band's geometry
    /// is a pure layout question, and a window would raise a panel on
    /// the user's screen for nothing.
    ///
    /// The band is located by its surface, not by its position in the
    /// child list: the row's view tree carries the text and the
    /// timestamp as their own views, so a child count would measure the
    /// wrong one. Reading the count as part of the result keeps the
    /// locator honest — a second surface would mean a nested plate, and
    /// the assertions below would then be reading the wrong outline.
    private func render(_ text: String) throws -> Band {
        let message = ChatMessage(role: .user, source: .user, content: text)
        let root = ChatMessageView(message: message)
            .frame(width: Self.columnWidth, alignment: .leading)

        let hosting = NSHostingView(rootView: AnyView(root))
        hosting.frame = NSRect(x: 0, y: 0, width: Self.columnWidth, height: 200)
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        let surfaces = Self.materialViews(in: hosting)
        let band = try #require(surfaces.first, "the outgoing row painted no material surface")
        let superview = try #require(band.superview, "the band's surface has no parent to convert from")
        let frame = hosting.convert(band.frame, from: superview)
        return Band(origin: frame.origin, size: frame.size, surfaces: surfaces.count)
    }

    private static func materialViews(in view: NSView) -> [NSVisualEffectView] {
        var found: [NSVisualEffectView] = []
        if let effect = view as? NSVisualEffectView {
            found.append(effect)
        }
        for child in view.subviews {
            found.append(contentsOf: materialViews(in: child))
        }
        return found
    }

    /// A message that fills a line of the band and is the reference for
    /// the width assertions; it does not wrap inside the chat area, so
    /// the wrap assertion below carries its own longer text.
    private static let longMessage =
        "Please summarize the research notes we collected for the current review."

    @Test("The outgoing band paints exactly one material surface")
    func bandPaintsOneSurface() throws {
        let band = try render(Self.longMessage)

        #expect(
            band.surfaces == 1,
            "The outgoing row must paint one material surface (= a second one is a nested plate); it painted \(band.surfaces)"
        )
    }

    @Test("The outgoing band spans the chat area, held off each edge by the row's own inset")
    func bandSpansTheColumnInsideTheRowInset() throws {
        let band = try render(Self.longMessage)
        // The row holds its band off the column by the moderate spacing
        // token; the transcript stack adds the rest of the chat area's
        // inset, and that total is measured in ChatTranscriptFlatFlowTests.
        let inset = DesignTokens.spacingModerate

        #expect(
            abs(band.origin.x - inset) <= 2,
            "The band's leading edge must sit \(inset) PT off the column's leading edge; laid out \(band.origin.x) PT"
        )
        #expect(
            abs(band.right - (Self.columnWidth - inset)) <= 2,
            "The band's trailing edge must sit \(inset) PT off the column's trailing edge; laid out right edge \(band.right) PT of \(Self.columnWidth) PT"
        )
        #expect(
            band.size.width >= Self.columnWidth - (inset * 2) - 1,
            "The band must span the chat area between its insets, not shrink to its words; laid out \(band.size.width) PT"
        )
    }

    @Test("The band's width is the column's, not the message's")
    func bandWidthIsIndependentOfTheMessage() throws {
        let shortBand = try render("Hi")
        let longBand = try render(Self.longMessage)

        #expect(
            abs(shortBand.size.width - longBand.size.width) <= 1,
            "A two-word message and a wrapped paragraph must take the same band width; short = \(shortBand.size.width) PT, long = \(longBand.size.width) PT"
        )
    }

    @Test("The band wears the shared card radius, not the composer's capsule shape")
    func bandWearsTheCardRadius() throws {
        let content = try SourceLocator.read("Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift")

        #expect(
            content.contains("cornerRadius: DesignTokens.surfaceCornerRadiusCard"),
            "The band's outline must come from the shared card radius token (= no new token, no magic literal)"
        )
        #expect(
            !content.contains("ChatSurfaceShape()"),
            "The band must not wear the composer's capsule shape (= a row of the transcript has corners, not a pill)"
        )
    }

    @Test("The band grows taller when its words wrap")
    func bandGrowsWhenTheWordsWrap() throws {
        let shortBand = try render("Hi")
        // The band spans the whole chat area, so a message has to be
        // longer than that span to wrap onto a second line: the
        // paragraph below is roughly three times the band's width.
        let wrappedBand = try render(
            "Please summarize the research notes we collected for the current review, "
                + "keep the argument of each source separate, mark the passages that disagree with the "
                + "others, and leave the open questions at the end so the next pass can answer them."
        )

        #expect(
            wrappedBand.height > shortBand.height,
            "A wrapped message must make the band taller, the band being a row and not a fixed pill; short = \(shortBand.height) PT, wrapped = \(wrappedBand.height) PT"
        )
    }
}
