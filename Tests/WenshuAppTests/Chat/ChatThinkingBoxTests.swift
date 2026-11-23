//
//  ChatThinkingBoxTests.swift · Wenshu
//
//  The reasoning block is a bounded rectangle.
//
//  WHY
//  ===
//  A streamed trace is read inside a rectangle of its own: the rectangle
//  holds the words, the words scroll inside it, and the transcript's
//  height does not follow the length of the thinking. = A trace laid out
//  as one tall body pushes the transcript down with every token, and the
//  reader's place in the conversation is carried away by the length of
//  the thinking.
//
//  The rectangle also has to behave like a reader's own space:
//
//    * it follows the stream while the reader is at its bottom,
//    * it stops the moment the reader scrolls up (the reader's position
//      wins, and the new words pile up below it),
//    * it does not collapse when the turn ends (= the block that showed
//      its words arriving keeps its shape),
//    * a short trace holds a short rectangle (the cap is a maximum, not
//      a height).
//
//  AND THE STATE THAT DECIDES ALL OF IT LIVES ON THE PART, NOT IN THE
//  ROW: a `LazyVStack` tears the row down and builds it again (= the
//  reply grows, and the transcript scrolls), so a latch kept in the row
//  is a latch that is lost, and the block collapses again under the
//  reader.
//
//  WHAT IS MEASURED, AND WITH WHAT
//  ================================
//  Every claim is a measurement of the rendered tree. The transcript is
//  hosted in an offscreen window (the same harness the transcript's own
//  scroll suite uses) and read through AppKit's numbers: a SwiftUI
//  ScrollView is backed by an NSScrollView, so the rectangle's height,
//  the height of the words inside it and its scroll offset are the
//  scroll view's own. What is DRAWN is read through the repo's own
//  accessibility reader (= InspectorAXTree).
//
//  No claim rests on a rendered label: an offscreen host paints raw
//  localization keys, so every search below looks for words this
//  fixture wrote itself.
//

import AppKit
import Observation
import SwiftUI
import Testing
@testable import WenshuApp

// MARK: - The fixture

/// The words this fixture writes into the reasoning block.
///
/// They are data, not a localized string, so the built tree can be
/// searched for them.
private enum ThinkingBoxText {
    /// The phrase every line carries (= the search's needle).
    static let marker = "the model weighed the options"

    /// A trace of the given number of paragraphs.
    ///
    /// The paragraphs are separated by a blank line (= markdown's own
    /// rule: a blank line ends a block), so the trace is as tall as the
    /// number of lines says it is (= a paragraph's lines are one
    /// paragraph, so a single-newline trace would be one wrapped run).
    static func lines(_ count: Int) -> String {
        (0 ..< count).map { "\(marker) \($0)" }.joined(separator: "\n\n")
    }
}

/// The transcript the reasoning block is drawn in.
///
/// The block's part is the model (= the reader's own choices live
/// there), and the view is handed the part's words.
@MainActor
@Observable
private final class ThinkingBoxTranscript {
    /// The reasoning block's part.
    var part: ChatMessagePart
    /// Whether the turn is still running.
    var isRunning: Bool

    init(reasoning: String, isRunning: Bool = true) {
        part = ChatMessagePart.reasoning(reasoning)
        self.isRunning = isRunning
    }

    /// The words the block shows.
    var reasoning: String {
        if case let .reasoning(text) = part.kind {
            return text
        }
        return ""
    }

    /// The words that arrived with the turn.
    func receive(_ words: String) {
        part.kind = .reasoning(reasoning + words)
    }
}

/// The transcript: the reasoning block, and the answer that follows it.
private struct ThinkingBoxTranscriptView: View {
    let transcript: ThinkingBoxTranscript

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
                ChatReasoningPartView(
                    text: transcript.reasoning,
                    isRunning: transcript.isRunning,
                    isRevealed: .constant(true)
                )
                Text("the answer that follows the thinking")
            }
        }
    }
}

// MARK: - The probe (= AppKit's own numbers)

/// The harness the measurements are taken through.
@MainActor
private enum ThinkingBoxProbe {
    /// Hosts the transcript in a window far offscreen.
    ///
    /// The window has to exist: a SwiftUI scroll view only lays its
    /// content out once it is in a window (= a detached hosting view
    /// never gets a document height, and the measurement would read
    /// zeros).
    static func host(
        _ transcript: ThinkingBoxTranscript
    ) -> (host: NSHostingView<AnyView>, window: NSWindow) {
        let hosting = NSHostingView(rootView: AnyView(ThinkingBoxTranscriptView(transcript: transcript)))
        let window = NSWindow(
            contentRect: NSRect(x: -20000, y: -20000, width: 720, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        return (hosting, window)
    }

    static func teardown(_ hosted: (host: NSHostingView<AnyView>, window: NSWindow)) {
        hosted.window.orderOut(nil)
        hosted.window.contentView = nil
    }

    /// Lets the layout, the lazy rows and the scroll geometry settle.
    static func settle(_ turns: Int = 12) {
        for _ in 0 ..< turns {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    /// Every scroll view in a tree, outermost first.
    static func scrollViews(in view: NSView) -> [NSScrollView] {
        var found: [NSScrollView] = []
        if let scroll = view as? NSScrollView {
            found.append(scroll)
        }
        for subview in view.subviews {
            found.append(contentsOf: scrollViews(in: subview))
        }
        return found
    }

    /// The transcript's own scroll view (= the outer one).
    static func transcriptScrollView(in root: NSView) -> NSScrollView? {
        scrollViews(in: root).max { $0.frame.height < $1.frame.height }
    }

    /// The rectangle's scroll view (= the inner one).
    static func rectangleScrollView(in root: NSView) -> NSScrollView? {
        scrollViews(in: root).min { $0.frame.height < $1.frame.height }
    }

    /// The height of what a scroll view holds.
    static func contentHeight(of scroll: NSScrollView) -> CGFloat {
        scroll.documentView?.frame.height ?? 0
    }

    /// How far a scroll view is from its own bottom.
    static func gap(of scroll: NSScrollView) -> CGFloat {
        contentHeight(of: scroll) - scroll.contentView.bounds.origin.y - scroll.frame.height
    }

    /// The rows of a host's paint that carry a SOLID line, inside a band.
    ///
    /// A solid line (= the rectangle's edge) is a row whose pixels are
    /// all painted, from end to end. A row of TEXT is not: the glyphs
    /// are short runs with the unpainted background between them.
    ///
    /// The host (= not the scroll view) is what is painted: a SwiftUI
    /// overlay belongs to the hosting view's own layer, = = so a scroll
    /// view's own `cacheDisplay` does not contain it.
    ///
    /// "Painted" means the pixel carries ink (= its alpha is above
    /// nothing), = = so the probe does not assume a theme.
    static func solidLineRows(in host: NSView, within band: NSRect) -> [CGFloat] {
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return [] }
        host.cacheDisplay(in: host.bounds, to: rep)
        let wide = rep.pixelsWide
        let high = rep.pixelsHigh
        let scale = host.bounds.width > 0 ? CGFloat(wide) / host.bounds.width : 1
        guard wide > 0, high > 0 else { return [] }

        let firstRow = max(0, Int(band.minY * scale))
        let lastRow = min(high, Int(band.maxY * scale))
        let firstColumn = max(0, Int(band.minX * scale))
        let lastColumn = min(wide, Int(band.maxX * scale))
        let bandWidth = max(1, lastColumn - firstColumn)

        var found: [CGFloat] = []
        for y in firstRow ..< lastRow {
            var longest = 0
            var run = 0
            for x in firstColumn ..< lastColumn {
                var alpha: CGFloat = 0
                if let color = rep.colorAt(x: x, y: y) {
                    alpha = color.alphaComponent
                }
                if alpha > 0.05 {
                    run += 1
                    longest = max(longest, run)
                } else {
                    run = 0
                }
            }
            if CGFloat(longest) >= CGFloat(bandWidth) * 0.85 {
                found.append(CGFloat(longest))
            }
        }
        return found
    }

    /// Every string the built tree publishes.
    static func publishedTexts(of root: NSView) -> [String] {
        InspectorAXTree.elements(of: root).map(\.published)
    }
}

// MARK: - The tests

@MainActor
@Suite("the thinking box: a bounded, streaming, non-collapsing block")
struct ChatThinkingBoxTests {
    // MARK: - The rectangle holds the words

    @Test("A long trace does not grow the transcript")
    func longTraceDoesNotGrowTheTranscript() {
        let short = ThinkingBoxTranscript(reasoning: ThinkingBoxText.lines(20))
        let long = ThinkingBoxTranscript(reasoning: ThinkingBoxText.lines(200))
        let shortHost = ThinkingBoxProbe.host(short)
        defer { ThinkingBoxProbe.teardown(shortHost) }
        let longHost = ThinkingBoxProbe.host(long)
        defer { ThinkingBoxProbe.teardown(longHost) }
        ThinkingBoxProbe.settle()

        guard let shortTranscript = ThinkingBoxProbe.transcriptScrollView(in: shortHost.host),
              let longTranscript = ThinkingBoxProbe.transcriptScrollView(in: longHost.host)
        else {
            Issue.record(Comment("the transcript must have a scroll view"))
            return
        }
        let shortHeight = ThinkingBoxProbe.contentHeight(of: shortTranscript)
        let longHeight = ThinkingBoxProbe.contentHeight(of: longTranscript)
        #expect(abs(longHeight - shortHeight) <= 1,
                Comment("the transcript's height followed the trace's length (\(shortHeight) -> \(longHeight))"))

        // The measurement is not vacuous: the words really are taller
        // than the cap, and the cap really holds them.
        guard let rectangle = ThinkingBoxProbe.rectangleScrollView(in: longHost.host) else {
            Issue.record(Comment("the reasoning block must have a scroll view of its own"))
            return
        }
        let rectangleHeight = rectangle.frame.height
        #expect(rectangleHeight <= DesignTokens.reasoningBoxMaxHeight + 1,
                Comment("the rectangle is \(rectangleHeight) tall (= the cap is \(DesignTokens.reasoningBoxMaxHeight))"))
        #expect(ThinkingBoxProbe.contentHeight(of: rectangle) > DesignTokens.reasoningBoxMaxHeight * 4,
                Comment("the words inside the rectangle are not taller than the cap (= the cap is holding nothing)"))
    }

    @Test("A short trace holds a short rectangle")
    func shortTraceHoldsAShortRectangle() {
        let transcript = ThinkingBoxTranscript(reasoning: ThinkingBoxText.lines(2))
        let hosted = ThinkingBoxProbe.host(transcript)
        defer { ThinkingBoxProbe.teardown(hosted) }
        ThinkingBoxProbe.settle()

        guard let rectangle = ThinkingBoxProbe.rectangleScrollView(in: hosted.host) else {
            Issue.record(Comment("the reasoning block must have a scroll view of its own"))
            return
        }
        let height = rectangle.frame.height
        #expect(height > 0, "the rectangle has no height at all")
        #expect(height < DesignTokens.reasoningBoxMaxHeight,
                Comment("a two-line trace still holds the full-height rectangle (\(height))"))
        #expect(ThinkingBoxProbe.contentHeight(of: rectangle) <= height + 1,
                "the words inside the rectangle are taller than the rectangle (= the rectangle is not shrinking to its content)")
    }

    // MARK: - The reader's own space

    @Test("The reader who scrolled up is not dragged back by the next words")
    func scrolledUpReaderIsNotDraggedBack() {
        // The trace arrives the way it arrives in the app: a couple of
        // paragraphs first (= the rectangle holds them whole), and then
        // the rest, until the rectangle has to scroll.
        let transcript = ThinkingBoxTranscript(reasoning: ThinkingBoxText.lines(2))
        let hosted = ThinkingBoxProbe.host(transcript)
        defer { ThinkingBoxProbe.teardown(hosted) }
        ThinkingBoxProbe.settle()

        guard let rectangle = ThinkingBoxProbe.rectangleScrollView(in: hosted.host) else {
            Issue.record(Comment("the reasoning block must have a scroll view of its own"))
            return
        }

        // The rest of the trace arrives.
        transcript.receive("\n\n" + ThinkingBoxText.lines(118))
        ThinkingBoxProbe.settle()

        // The control: while the reader is at the bottom, the rectangle
        // follows the stream. Without this the rest of the case would
        // prove nothing (= a rectangle that never follows proves nothing
        // about a rectangle that stops following).
        let gapBefore = ThinkingBoxProbe.gap(of: rectangle)
        #expect(gapBefore < 2,
                Comment("the rectangle did not follow the stream to its bottom (the gap is \(gapBefore))"))

        // The reader scrolls up.
        let clip = rectangle.contentView
        let bottomOffset = clip.bounds.origin.y
        clip.scroll(to: NSPoint(x: 0, y: bottomOffset - 120))
        rectangle.reflectScrolledClipView(clip)
        ThinkingBoxProbe.settle()
        let heldOffset = clip.bounds.origin.y
        #expect(heldOffset < bottomOffset,
                Comment("the reader's scroll did not move the rectangle (\(bottomOffset) -> \(heldOffset))"))
        #expect(ThinkingBoxProbe.gap(of: rectangle) > 24,
                Comment("the reader's scroll did not open the gate (the gap is \(ThinkingBoxProbe.gap(of: rectangle)))"))

        // The next words arrive.
        transcript.receive("\n\n\(ThinkingBoxText.marker) more")
        ThinkingBoxProbe.settle()
        let offsetAfter = rectangle.contentView.bounds.origin.y
        #expect(offsetAfter == heldOffset,
                Comment("the next words dragged the reader back (\(heldOffset) -> \(offsetAfter))"))
    }

    // MARK: - The end of the turn

    @Test("The block does not collapse when the turn ends")
    func blockDoesNotCollapseWhenTheTurnEnds() {
        let transcript = ThinkingBoxTranscript(reasoning: ThinkingBoxText.lines(40))
        let hosted = ThinkingBoxProbe.host(transcript)
        defer { ThinkingBoxProbe.teardown(hosted) }
        ThinkingBoxProbe.settle()

        guard let rectangle = ThinkingBoxProbe.rectangleScrollView(in: hosted.host),
              let transcriptScroll = ThinkingBoxProbe.transcriptScrollView(in: hosted.host)
        else {
            Issue.record(Comment("the transcript must have a scroll view"))
            return
        }
        let heightWhileRunning = rectangle.frame.height
        let transcriptHeightWhileRunning = ThinkingBoxProbe.contentHeight(of: transcriptScroll)
        let drawnWhileRunning = ThinkingBoxProbe.publishedTexts(of: hosted.host)
        #expect(drawnWhileRunning.contains { $0.contains(ThinkingBoxText.marker) },
                "the block's words are not in the tree while the turn runs (= nothing to compare)")

        // The turn ends.
        transcript.isRunning = false
        ThinkingBoxProbe.settle()

        let drawnAfter = ThinkingBoxProbe.publishedTexts(of: hosted.host)
        #expect(drawnAfter.contains { $0.contains(ThinkingBoxText.marker) },
                "the block's words left the tree when the turn ended (= the block collapsed)")
        #expect(rectangle.frame.height == heightWhileRunning,
                Comment("the rectangle changed height when the turn ended (\(heightWhileRunning) -> \(rectangle.frame.height))"))
        #expect(ThinkingBoxProbe.contentHeight(of: transcriptScroll) == transcriptHeightWhileRunning,
                "the transcript's height changed when the turn ended (= the block moved)")
    }

    // MARK: - A trace that is not growing

    @Test("A finished trace opens at its top, not at its tail")
    func aFinishedTraceOpensAtItsTop() {
        // A trace that is not arriving (= the turn is over, = = the block
        // was restored from the history) must open where the reader
        // expects a document to open: at its first line.
        //
        // MEASURED before the fix: the rectangle's first measurement
        // looked like growth, = = so it scrolled to its own tail before
        // the reader had done anything (= = the reader found the last
        // line of the trace, = = and every re-realization landed there
        // again).
        let transcript = ThinkingBoxTranscript(reasoning: ThinkingBoxText.lines(200), isRunning: false)
        let hosted = ThinkingBoxProbe.host(transcript)
        defer { ThinkingBoxProbe.teardown(hosted) }
        ThinkingBoxProbe.settle()

        guard let rectangle = ThinkingBoxProbe.rectangleScrollView(in: hosted.host) else {
            Issue.record(Comment("the reasoning block must have a scroll view of its own"))
            return
        }
        #expect(ThinkingBoxProbe.contentHeight(of: rectangle) > DesignTokens.reasoningBoxMaxHeight,
                "the trace must be long enough for the rectangle to scroll (= the measurement is meaningful)")
        #expect(ThinkingBoxProbe.gap(of: rectangle) > 2,
                Comment("a finished trace opened at its tail (= it scrolled on its own)"))
    }

    @Test("The rectangle shows an edge, so the reader knows it scrolls")
    func theRectangleShowsAnEdge() {
        // A scroller that draws nothing at its edges looks like a
        // cut-off line of words: the reader cannot tell that there is
        // more below.
        //
        // The proof is the PIXELS: the rectangle's own paint must
        // contain a row that is not the background (= the edge), and
        // that row must span the rectangle's width.
        let transcript = ThinkingBoxTranscript(reasoning: ThinkingBoxText.lines(200))
        let hosted = ThinkingBoxProbe.host(transcript)
        defer { ThinkingBoxProbe.teardown(hosted) }
        ThinkingBoxProbe.settle()

        guard let rectangle = ThinkingBoxProbe.rectangleScrollView(in: hosted.host) else {
            Issue.record(Comment("the reasoning block must have a scroll view of its own"))
            return
        }
        let band = hosted.host.convert(rectangle.frame, from: rectangle.superview)
        print("DIAG-BAND band=\(band) rectFrame=\(rectangle.frame) hostBounds=\(hosted.host.bounds)")
        let solidRows = ThinkingBoxProbe.solidLineRows(in: hosted.host, within: band)
        #expect(!solidRows.isEmpty,
                "the rectangle draws no edge (= the reader is not told that it scrolls)")
    }
}
