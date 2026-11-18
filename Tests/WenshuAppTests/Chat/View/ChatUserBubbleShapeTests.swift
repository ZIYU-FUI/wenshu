//
//  ChatUserBubbleShapeTests.swift
//
//  The user's own message must read as a BUBBLE: a pill that hugs its
//  words, sized to the message, sitting on the trailing edge of the
//  chat column, with fully rounded ends.
//
//  These assertions measure the RENDERED GEOMETRY of the real
//  `ChatMessageView` (= the production view tree SwiftUI lays out
//  under an `NSHostingView`), not the source text: the bubble's laid
//  out frame, its width against the chat column's, and its trailing
//  edge are all read back from the laid out views.
//
//  WHY THE LAYOUT AND NOT THE PIXELS: the bubble's surface is Apple's
//  own Liquid Glass (= `.glassEffect`), and an offscreen read
//  (`cacheDisplay(in:to:)`) does not composite a glass surface at all
//  (= the same limit the house recorded for the macOS 27 tab strip: = a
//  control's appearance must be measured on a SCREEN capture, = never on
//  `cacheDisplay`). The bubble's GEOMETRY is a layout question, and the
//  layout is what the production view tree hands over exactly.
//
//  The layout is MainActor-isolated (= it reads the actor-isolated
//  DesignTokens), so the suite runs on the main actor too.
//

import Foundation
import Testing
import SwiftUI
import AppKit
@testable import WenshuApp

@MainActor
@Suite("Chat user bubble shape — the outgoing bubble hugs its words")
struct ChatUserBubbleShapeTests {

    /// The chat column width the bubble is measured inside (= the
    /// width the running app's chat column measures).
    private static let columnWidth: CGFloat = 723

    /// The bubble's laid out frame, in points, in the hosting view's
    /// coordinate space.
    private struct Frame {
        let origin: CGPoint
        let size: CGSize
        var right: CGFloat {
            origin.x + size.width
        }
        var height: CGFloat {
            size.height
        }
    }

    /// Lay the REAL outgoing message view out inside a chat column and
    /// read the bubble's frame back.
    ///
    /// The hosting view is deliberately windowless: the bubble's
    /// geometry is a pure layout question, and a window would raise a
    /// panel on the user's screen for nothing.
    private func render(_ text: String) throws -> Frame {
        let message = ChatMessage(role: .user, source: .user, content: text)
        let root = ChatMessageView(message: message)
            .frame(width: Self.columnWidth, alignment: .leading)

        let hosting = NSHostingView(rootView: AnyView(root))
        hosting.frame = NSRect(x: 0, y: 0, width: Self.columnWidth, height: 200)
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        // The outgoing row lays out exactly one child: the bubble. If
        // that stops being true, the locator below would silently
        // measure the wrong view, so the count is asserted.
        let children = hosting.subviews
        #expect(
            children.count == 1,
            "The outgoing row must lay out exactly one view (= the bubble); it laid out \(children.count)"
        )
        let bubble = try #require(children.first, "the outgoing row laid out no bubble")
        let frame = bubble.frame
        return Frame(origin: frame.origin, size: frame.size)
    }

    /// A message long enough to wrap onto a second line inside the
    /// bubble's capped width (= so the bubble grows taller than its
    /// resting height).
    private static let longMessage =
        "Please summarize the research notes we collected for the current review."

    @Test("The outgoing bubble is narrower than the chat column and respects the canonical bubble width")
    func bubbleIsNarrowerThanTheColumn() throws {
        let frame = try render(Self.longMessage)

        #expect(
            frame.size.width < Self.columnWidth - 1,
            "The bubble must not span the chat column; laid out \(frame.size.width) PT of a \(Self.columnWidth) PT column"
        )
        #expect(
            frame.size.width <= DesignTokens.chatBubbleMaxWidth + DesignTokens.spacingModerate * 2,
            "The bubble must respect the canonical chat-bubble width; laid out \(frame.size.width) PT"
        )
    }

    @Test("The outgoing bubble hugs its words: a longer message lays out a wider bubble")
    func bubbleWidthGrowsWithTheMessage() throws {
        let shortFrame = try render("Hi")
        let longFrame = try render(Self.longMessage)

        #expect(
            longFrame.size.width > shortFrame.size.width + 1,
            "A longer message must lay out a wider bubble; short = \(shortFrame.size.width) PT, long = \(longFrame.size.width) PT"
        )
        #expect(
            shortFrame.size.width < DesignTokens.chatBubbleMaxWidth / 2,
            "A short message must lay out a bubble far narrower than the canonical cap; laid out \(shortFrame.size.width) PT"
        )
    }

    @Test("The bubble's ends are fully rounded: the shared shape rounds a bubble-sized surface all the way")
    func bubbleEndsAreFullyRounded() throws {
        let frame = try render(Self.longMessage)

        // The shared chat-surface shape rounds at min(half the surface
        // height, its own cap), so a bubble whose height is within
        // twice that cap is a capsule: its ends are rounded all the
        // way. The height floor is the composer's field height, so the
        // resting bubble is a capsule and a bubble that wraps once is
        // still one.
        let cap = DesignTokens.controlHeightLarge
        #expect(
            frame.height <= cap * 2,
            "The bubble must stay within twice the shape's cap, or its ends stop being fully rounded; laid out \(frame.height) PT of a \(cap * 2) PT budget"
        )
        // The shape itself is the shared one, and it rounds by half the
        // surface height up to that cap.
        let shape = try SourceLocator.read("Sources/WenshuApp/Features/Chat/View/ChatSurfaceShape.swift")
        #expect(
            shape.contains("min(rect.height / 2, maxCorner)"),
            "The shared chat-surface shape must round by half the surface height, up to its cap"
        )
    }

    @Test("The bubble sits against the chat column's trailing edge")
    func bubbleSitsAtTheTrailingEdge() throws {
        let frame = try render(Self.longMessage)
        print("DIAG bubble=\(frame.origin) \(frame.size) right=\(frame.right) column=\(Self.columnWidth)")

        #expect(
            abs(frame.right - Self.columnWidth) <= 2,
            "The bubble's trailing edge must sit at the column's trailing edge; laid out right edge = \(frame.right) PT of \(Self.columnWidth)"
        )
    }
}
