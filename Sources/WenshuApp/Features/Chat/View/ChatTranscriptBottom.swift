//
//  ChatTranscriptBottom.swift
//
//  Where the reader is, in the transcript.
//
//  WHY
//  ===
//  A writer scrolls up to re-read an earlier paragraph while the reply
//  is still arriving. The transcript's follow (= = "scroll to the
//  newest row when the newest row grows") must not run in that case,
//  or the reader is dragged back down on every frame and cannot read
//  and watch at the same time.
//
//  This file owns ONE decision: is the reader's viewport parked at the
//  bottom of the transcript? The decision is a pure function of the
//  scroll geometry, so it can be tested without a window, and it lives
//  on its own (= = the view file stays about the view).
//
//  THE MEASUREMENT
//  ===============
//  The distance is between the reader's viewport's bottom edge and the
//  LAST MESSAGE's bottom edge (= = not the content's bottom edge):
//
//      distance = contentSize.height - bottomInset - visibleRect.maxY
//
//  Three things about that formula are MEASURED, not assumed (= = the
//  numbers come from the hosted chat in
//  `ChatScrollGeometryProbeTests`):
//
//  1. THE VISIBLE RECT, NOT THE CONTAINER SIZE. A SwiftUI ScrollView
//     on macOS reports a container size that is SHORTER than the
//     viewport: the transcript sits above the composer (= = a safe-area
//     inset), and the inset is taken out of the container.
//     MEASURED in the hosted chat: containerSize.height = 416 while the
//     viewport is 500 tall, = = and AppKit's clip view says 500.
//     With the container size the distance came out 84 points too
//     large, = = which is exactly the safe-area inset.
//     The visible rect's height is the viewport's (MEASURED: 500), = =
//     so it is the same basis AppKit's clip view uses.
//  2. THE VISIBLE RECT'S ORIGIN IS THE OFFSET. MEASURED: visibleRect
//     = (0, 2368, 600, 500) while contentOffset = (0, 2368), = = so
//     `visibleRect.maxY` is the viewport's bottom edge in the content's
//     own coordinates.
//  3. THE CONTENT'S BOTTOM EDGE IS NOT THE LAST MESSAGE'S. The
//     transcript holds a clearance row (= = the blank space under the
//     last message) after the last message, = = so the content's bottom
//     edge sits below the last message's by that row's height plus the
//     stack's spacing.
//     MEASURED with the chat at its newest content: AppKit's own
//     distance to the content's bottom edge was 12 points, = = and the
//     model's own distance to the last message's bottom edge was 709.5
//     (= = the two differ by the clearance row, the stack's spacing
//     and the 12 points SwiftUI keeps under the last row).
//
//  So the reader is AT the bottom when the viewport's bottom edge has
//  reached the last message's bottom edge (= = the clearance row and
//  the blank space under it do not count as "away"), = = and the
//  distance is clamped at zero (= = the content can be shorter than the
//  viewport, = = and then the reader is at the bottom by definition).
//
//  THE DIRECTION OF `contentOffset` IS MEASURED, NOT ASSUMED. The
//  probe scrolls the real hosted ScrollView to its top and to its
//  bottom and prints the geometry at each end. MEASURED on macOS
//  27.2.1:
//
//      at the top:    offset.y=0    content.h=1600  container.h=300
//      at the bottom: offset.y=1300 content.h=1600  container.h=300
//
//  So `contentOffset.y` counts DOWNWARD from the top (= NOT AppKit's
//  flipped convention, where the origin is at the bottom).
//

import CoreGraphics
import Foundation

/// The transcript's own geometry, reduced to what the follow gate needs.
///
/// This is a small value type on purpose: the view hands it the
/// numbers SwiftUI reports, and the decision function below is pure, so
/// the gate can be tested with numbers instead of a window.
enum ChatTranscriptBottom {
    /// The id of the clearance row (= = the blank space below the last
    /// message).
    ///
    /// The viewport's anchor names THIS row, = = so the content's bottom
    /// edge is what lands at the viewport's bottom edge.
    static let clearanceID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// How far the reader may be from the bottom and still count as
    /// AT the bottom.
    ///
    /// The band is deliberately narrow (= = eight points): a reader who
    /// has scrolled even slightly up must stop being dragged down by
    /// the arriving reply, or the transcript cannot be read while the
    /// reply is still coming. The upstream reference uses the same
    /// eight pixels for the same reason.
    static let atBottomBand: CGFloat = 8

    /// How far the content's bottom edge sits below the last message's
    /// bottom edge.
    ///
    /// The transcript's last item is the clearance row (= = the blank
    /// space under the last message), = = and the stack puts its own
    /// spacing before it, = = so the content's bottom edge is that much
    /// below the last message's.
    ///
    /// This is what makes "the reader is at the bottom" mean "the
    /// reader can see the last message" (= = the blank space below it
    /// does not count as distance).
    @MainActor
    static let bottomInset: CGFloat = DesignTokens.chatInputBarHeight + DesignTokens.spacingStandard

    /// How far the last message's bottom edge is below the viewport's
    /// bottom edge.
    ///
    /// Zero means the reader is at the bottom. A positive value means
    /// the reader is that far above the last message (= = reading
    /// earlier). The value is clamped at zero (= = the content can be
    /// shorter than the viewport, = = and then the reader is at the
    /// bottom by definition).
    ///
    /// - Parameters:
    ///   - contentSize: the size of the scrollable content.
    ///   - visibleRect: the viewport's rectangle in the content's own
    ///     coordinates (= = its bottom edge is `maxY`).
    ///   - bottomInset: how far the content's bottom edge sits below
    ///     the last message's (= = the clearance row + the stack's
    ///     spacing).
    static func distanceFromBottom(
        contentSize: CGSize,
        visibleRect: CGRect,
        bottomInset: CGFloat
    ) -> CGFloat {
        max(0, contentSize.height - bottomInset - visibleRect.maxY)
    }

    /// Whether the reader's viewport is parked at the bottom.
    ///
    /// - Parameter distance: the value
    ///   ``distanceFromBottom(contentSize:visibleRect:bottomInset:)``
    ///   returned.
    static func isAtBottom(distance: CGFloat) -> Bool {
        distance <= atBottomBand
    }

    /// The scroll state the transcript's follow gate reads.
    struct ScrollState: Equatable {
        /// How far the content is scrolled down (= = the content's top
        /// edge's distance above the viewport's top edge).
        var offset: CGFloat = 0
        /// How far the content's bottom edge is below the viewport's
        /// bottom edge (= = zero when the reader is at the bottom).
        var distanceFromBottom: CGFloat = 0
        /// The scrollable content's height.
        var contentHeight: CGFloat = 0

        /// Whether the reader is at the bottom.
        var isAtBottom: Bool {
            ChatTranscriptBottom.isAtBottom(distance: distanceFromBottom)
        }

        /// Whether the viewport moved UP between two states.
        ///
        /// This is how the gate tells "the reader scrolled away" from
        /// "the content grew under the reader":
        ///
        ///   * the content grew under a reader at the bottom = = the
        ///     offset does NOT move (the app's own follow moves it
        ///     afterwards), so the reader is still following;
        ///   * the reader scrolled up = = the offset SHRINKS, and that
        ///     is the reader's own motion.
        ///
        /// A gate that read the distance alone could not tell those
        /// two apart: the content growing under a reader who is AT the
        /// bottom also makes the distance grow.
        func movedUp(from previous: ScrollState) -> Bool {
            offset < previous.offset
        }
    }
}
