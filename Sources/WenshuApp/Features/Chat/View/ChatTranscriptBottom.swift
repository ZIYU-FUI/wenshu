//
//  ChatTranscriptBottom.swift
//
//  The transcript's own identity pieces.
//
//  WHY
//  ===
//  A writer scrolls up to re-read an earlier paragraph while the reply
//  is still arriving. The transcript's follow ("scroll to the newest row
//  when the newest row grows") must not run in that case, or the reader
//  is dragged back down on every frame and cannot read and watch at the
//  same time.
//
//  The old answer was ours: this file measured how far the viewport sat
//  above the content's bottom edge and compared it to a band of 8 points.
//  The boss ruled on 2026-11-25 that a slight scroll-up does NOT count as
//  leaving the bottom (a reader who scrolls up is usually hunting for the
//  first answer to their own question), so the band was both wrong and
//  unnecessary: Apple already answers the question. The view asks
//  `onScrollTargetVisibilityChange` whether the clearance row is on
//  screen, and this file only says what that row IS.
//
//  THE ROW
//  =======
//  The clearance row is the blank space under the last message, and it IS
//  the content's bottom edge. Its height is the input bar's height plus
//  the stack's spacing, so the blank space under the last message is the
//  same 88 points the transcript's old bottom margin gave (the margin is
//  gone, so the two must not both be there).
//

import CoreGraphics
import Foundation

/// The transcript's own identity, reduced to what the gate needs.
///
/// The gate's answer is Apple's (the clearance row is on screen, or it
/// is not), so the only thing left to own is which row that IS.
enum ChatTranscriptBottom {
    /// The id of the clearance row (= = the blank space below the last
    /// message).
    ///
    /// The viewport's anchor names THIS row, = = so the content's bottom
    /// edge is what lands at the viewport's bottom edge.
    static let clearanceID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}
