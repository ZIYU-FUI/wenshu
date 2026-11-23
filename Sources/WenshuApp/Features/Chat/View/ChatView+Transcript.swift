//
//  ChatView+Transcript.swift · WenshuApp
//
//  The transcript's follow (= = "put the newest content on screen")
//  and the reader's place.
//
//  WHY A SEPARATE FILE
//  ===================
//  ChatView.swift holds the chat's own view (= = the column, the input
//  bar, the export sheet). The transcript's follow is a piece of
//  behaviour with its own rules (= = when it may run, = = what it
//  targets, = = what the reader's place means), = = and it lives here
//  so the view file stays about the view.
//
//  THE RULES, = = AND WHY THEY ARE WHAT THEY ARE
//  ================================================
//  1. The follow runs ONLY while the reader is at the bottom. A reader
//     who scrolled up to re-read an earlier paragraph must not be
//     dragged down by the arriving reply.
//  2. It moves the ANCHOR (= = the row the viewport is bound to), = =
//     not the scroll offset. The anchor is Apple's own mechanism for
//     "which row is at the anchor", = = and it is what holds the
//     reader's place when the content grows underneath them.
//  3. The anchor names the CLEARANCE row (= = the content's bottom
//     edge), = = so the viewport's bottom edge IS the content's bottom
//     edge (= = the transcript's own invariant: the offset follows the
//     content's height across a width change).
//

import SwiftUI

extension ChatView {
    /// Put the transcript at the newest content, when the reader is
    /// there to be put.
    ///
    /// The follow runs ONLY while the reader is at the bottom. A reader
    /// who scrolled up keeps their place while the reply grows under
    /// them, and the floating control offers the way back.
    ///
    /// It moves the BINDING (= = the row the viewport is anchored to),
    /// not the scroll offset. MEASURED: the offset's own `scrollTo`
    /// lands short of the maximum by the transcript's bottom content
    /// margin (= = 176 PT), = = so the last line would sit that far
    /// above the viewport's bottom edge; the binding names the ROW, = =
    /// and the row's own bottom edge is what lands at the anchor.
    ///
    /// - Parameters:
    ///   - proxy: the transcript's scroll proxy.
    ///   - force: put the transcript at the newest content even when
    ///     the reader is not at the bottom (= = the floating control's
    ///     click: it IS the reader asking to go back).
    func followNewestContent(_ proxy: ScrollViewProxy, force: Bool = false) {
        guard force || vm.readerIsAtBottom else { return }
        guard let last = vm.messages.last else { return }
        proxy.scrollTo(last.id, anchor: .bottom)
        // The viewport's anchor names the CONTENT'S BOTTOM EDGE (= = the
        // clearance row), = = so the viewport's bottom edge IS the
        // content's bottom edge (= = the transcript's own invariant: the
        // offset follows the content's height across a width change).
        //
        // It goes through the BINDING, = = not through `scrollTo`:
        // MEASURED, `scrollTo` moved nothing for the clearance row (= =
        // it is below the viewport, = = so the lazy stack never laid it
        // out, = = and there was nothing to scroll to), = = while the
        // binding locates a row that is not on screen.
        vm.anchoredRowID = ChatTranscriptBottom.clearanceID
        if force {
            // The reader asked to go back: they are at the bottom again,
            // = = so the arriving reply keeps them there.
            vm.readerReturnedToTheBottom()
        }
    }
}
