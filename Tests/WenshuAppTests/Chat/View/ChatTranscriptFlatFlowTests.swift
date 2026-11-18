//
//  ChatTranscriptFlatFlowTests.swift · WenshuApp
//
//  The chat transcript is ONE flat list of messages: no row is held at the
//  viewport's top while the conversation scrolls under it, and no row
//  paints a surface of its own across the column.
//
//  WHY
//  ===
//  The transcript renders the user's own message as one row among the
//  others, and every row scrolls with the content. The user's bubble is a
//  card (= it carries its own filled surface), and the assistant's reply
//  is flat text on the leading side; the transcript's viewport follows
//  the newest content.
//
//  WHAT THIS TEST DOES
//  ===================
//  It hosts the REAL ChatView (= the app's own view, not a mock of it)
//  over a host background the app never paints, and reads the PAINTED
//  pixels of the transcript viewport.
//
//  THE INSTRUMENT IS THE CARD'S OWN COLOUR. The user's bubble wears ONE
//  filled surface (= the palette's one colour), and nothing else in the
//  transcript wears it: the agent's reply is bare text on the leading
//  side, and the composer's own bar draws icons, not a fill. So the
//  pixels that carry that colour ARE the user's card, and the
//  measurement can say WHERE the card is instead of "something was
//  painted over there".
//
//  THE MEASUREMENT IS AT THE VIEWPORT'S RESTING POSITION. The transcript
//  rests at its bottom (= the newest content is what the panel shows).
//
//  WHY THE MEASUREMENT IS TRAILING-ONLY
//  ====================================
//  The composer's own bar wears the card's colour too (= 295 pixels of
//  it, measured, on the LEADING side of the window), and it wears it
//  whether the transcript shows a conversation or nothing at all. So a
//  measurement that scans the whole bitmap for the colour is satisfied
//  by the composer's chrome, and it says nothing about the user's
//  bubble. The user's bubble is TRAILING (= it hugs its words on the
//  trailing side of the column), so the control reads the TRAILING
//  region, where the composer's chrome never reaches.
//
//  The two fixtures
//  ================
//  The control needs the user's row ON SCREEN, and the claim needs the
//  conversation scrolled PAST it, so the two use different fixtures:
//
//    - the claim's fixture puts the user's message FIRST and twenty
//      replies after it, so at rest the conversation shows the newest
//      replies and the user's row has scrolled away. Nothing may be
//      held at the viewport's top in its place.
//
//    - the control's fixture puts the user's message LAST, so at rest
//      the viewport shows it: the trailing region of the transcript's
//      visible rows must carry the card. A transcript that rendered no
//      user row at all paints nothing there (= measured: 0 card pixels
//      with an empty conversation), so this control cannot be satisfied
//      by anything but the user's own bubble.
//
//  The second assertion carries the chat-band guard forward: no row of
//  the transcript paints a surface across the column's leading edge (= one
//  material at the window's root, and nothing inside the window painting a
//  surface of its own), while the user's own bubble keeps its own card.
//
//

import AppKit
import SwiftUI
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@MainActor
@Suite("Chat transcript flat flow (= no row is held at the viewport's top)")
struct ChatTranscriptFlatFlowTests {
    /// The host background the chat column cannot be mistaken for.
    ///
    /// Magenta is used because the app's own surfaces never carry it, and
    /// because a material composited over it desaturates it (= it leaves
    /// the magenta family), so the two are told apart by their pixels.
    private static let hostColor = NSColor.magenta

    /// How tall the measured band is.
    ///
    /// The bubble is one row tall (= the composer field's height), so the
    /// band holds it whole.
    private static let bandHeight: CGFloat = 120

    /// The painted pixels of a hosted view, over the host background.
    private struct Painted {
        let bytes: [UInt8]
        let height: Int
        let width: Int
        let bytesPerRow: Int
        let samplesPerPixel: Int
    }

    /// The transcript's scroll view, found in the hosted tree.
    ///
    /// The chat hosts more than one scroll view (= the transcript, and the
    /// composer's own text view), so the transcript is the one with the
    /// TALLEST document: the transcript holds the whole conversation and
    /// nothing else does.
    private static func transcriptScrollView(in root: NSView) -> NSScrollView? {
        var found: NSScrollView?
        var tallest: CGFloat = -1
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView {
                let height = scroll.documentView?.frame.height ?? 0
                if height > tallest {
                    tallest = height
                    found = scroll
                }
            }
            for subview in view.subviews {
                walk(subview)
            }
        }
        walk(root)
        return found
    }

    /// Host the chat over the host background and let it lay out.
    ///
    /// The hosting view goes into a WINDOW: a SwiftUI scroll view only
    /// lays its content out once it is in a window (= a detached hosting
    /// view never gets a document height, and the measurement would read
    /// zeros).
    private func host(
        _ view: some View,
        width: CGFloat = 600,
        height: CGFloat = 500
    ) -> (window: NSWindow, view: NSView) {
        let hosting = NSHostingController(
            rootView: AnyView(view.environment(WorkspaceUIState()))
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = Self.hostColor
        window.contentView = hosting.view
        window.setFrame(NSRect(x: 0, y: 0, width: width, height: height), display: true)
        hosting.view.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()

        // Let the lazy rows materialize and the scroll geometry settle.
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        hosting.view.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()

        return (window, hosting.view)
    }

    /// The painted pixels of the hosted chat, over the host background.
    private func paintedPixels(of view: NSView) -> Painted {
        let bounds = view.bounds
        let rep = view.bitmapImageRepForCachingDisplay(in: bounds)!
        rep.size = bounds.size
        // Paint the host's background first, so a pixel that differs is
        // a pixel the view drew on.
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        Self.hostColor.setFill()
        bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        view.cacheDisplay(in: bounds, to: rep)

        let count = rep.pixelsHigh * rep.bytesPerRow
        return Painted(
            bytes: [UInt8](UnsafeBufferPointer(start: rep.bitmapData!, count: count)),
            height: rep.pixelsHigh,
            width: rep.pixelsWide,
            bytesPerRow: rep.bytesPerRow,
            samplesPerPixel: rep.bytesPerRow / max(rep.pixelsWide, 1)
        )
    }

    /// The user's bubble's own fill, as the palette resolves it.
    ///
    /// The palette's colour is a semantic one, so it resolves per
    /// appearance; it is read under the hosted view's own appearance,
    /// which is the appearance the pixels were drawn in.
    private func cardFill(of view: NSView) -> (r: Int, g: Int, b: Int) {
        var resolved = NSColor.gray
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            if let color = NSColor.unemphasizedSelectedTextBackgroundColor
                .usingColorSpace(.sRGB)
            {
                resolved = color
            }
        }
        return (
            Int((resolved.redComponent * 255).rounded()),
            Int((resolved.greenComponent * 255).rounded()),
            Int((resolved.blueComponent * 255).rounded())
        )
    }

    /// The card-coloured pixels of one side of the column, per bitmap row.
    ///
    /// The palette's colour is resolved per appearance and the drawn
    /// pixels carry it a shade off (= the card's surface is composited),
    /// so the match carries a tolerance wide enough for that step and
    /// narrow enough to miss the panel's own greys.
    ///
    /// The sides are read SEPARATELY (= the trailing half and the leading
    /// half), because the composer's own bar wears the same colour on the
    /// leading side: a whole-bitmap scan cannot tell the user's bubble
    /// from the composer's chrome.
    private func cardRows(
        _ painted: Painted,
        fill: (r: Int, g: Int, b: Int),
        trailing: Bool
    ) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        let split = painted.width / 2
        let range = trailing ? split ..< painted.width : 0 ..< split
        for y in 0 ..< painted.height {
            var inRow = 0
            for x in range {
                let offset = y * painted.bytesPerRow + x * painted.samplesPerPixel
                let r = Int(painted.bytes[offset])
                let g = Int(painted.bytes[offset + 1])
                let b = Int(painted.bytes[offset + 2])
                if abs(r - fill.r) <= 12, abs(g - fill.g) <= 12, abs(b - fill.b) <= 12 {
                    inRow += 1
                }
            }
            if inRow > 0 {
                counts[y] = inRow
            }
        }
        return counts
    }

    /// The share of the leading edge's pixels that carry the host, per row.
    ///
    /// The leading edge (= the left quarter of the column) is the region
    /// the user's own bubble does NOT reach (= the bubble is trailing), so
    /// it is where a surface painted across the whole column shows itself.
    private func hostSharePerRow(_ painted: Painted, rows: Range<Int>) -> [Double] {
        let leadingWidth = max(1, painted.width / 4)
        return rows.map { y in
            var host = 0
            for x in 0 ..< leadingWidth {
                let offset = y * painted.bytesPerRow + x * painted.samplesPerPixel
                let r = Int(painted.bytes[offset])
                let g = Int(painted.bytes[offset + 1])
                let b = Int(painted.bytes[offset + 2])
                if r > 225, g < 60, b > 225 {
                    host += 1
                }
            }
            return Double(host) / Double(leadingWidth)
        }
    }

    /// A conversation of agent replies, with the user's message where the
    /// fixture needs it.
    ///
    /// The replies are short lines on the leading side, so the viewport's
    /// top band carries nothing but text on the leading side.
    private func makeMessages(userLast: Bool) -> [ChatMessage] {
        var replies: [ChatMessage] = []
        for index in 1 ... 20 {
            replies.append(
                ChatMessage(
                    role: .agent,
                    source: .wenshu,
                    content: "Reply \(index)."
                )
            )
        }
        let question = ChatMessage(
            role: .user,
            source: .user,
            content: "The unpinned row probe question."
        )
        return userLast ? replies + [question] : [question] + replies
    }

    /// The claim: the conversation scrolls as ONE flat list, so the user's
    /// own row is not held at the viewport's top while the rest of the
    /// conversation scrolls under it.
    ///
    /// The fixture puts the user's message FIRST and twenty replies after
    /// it, so at rest the viewport shows the newest replies: the user's
    /// row has scrolled away with the content. A row HELD there (= the old
    /// pinned section header) would paint the card in that band instead.
    @Test("no row is held at the viewport's top (= the conversation scrolls as one flat list)")
    func noRowIsHeldAtTheViewportTop() {
        let messages = makeMessages(userLast: false)
        let vm = ChatViewModel(
            initialMessages: messages,
            repository: FixedChatRepository(messages: messages),
            providersConfigured: { true }
        )
        let (window, hosting) = host(ChatView(vm: vm))
        defer { window.orderOut(nil) }

        guard let scroll = Self.transcriptScrollView(in: hosting) else {
            Issue.record(Comment("the chat must have a scroll view"))
            return
        }
        #expect(
            (scroll.documentView?.frame.height ?? 0) > scroll.contentView.bounds.height,
            "the transcript must be taller than its viewport (= there is something to scroll)"
        )

        let painted = paintedPixels(of: hosting)
        let trailing = cardRows(painted, fill: cardFill(of: hosting), trailing: true)

        // The viewport's top band, in bitmap rows (= the bitmap runs
        // top-down, and the viewport's top edge is the window's top edge).
        let scale = Double(painted.height) / Double(scroll.contentView.bounds.height)
        let bandRows = 0 ..< Int(Self.bandHeight * scale)

        // The claim: the card is NOT painted in the viewport's top band.
        //
        // The transcript rests at its bottom, so the top band shows the
        // conversation's middle. A row HELD there (= the old pinned
        // section header) would paint the card in that band; a row that
        // scrolls with the content does not.
        let heldRows = bandRows.filter { (trailing[$0] ?? 0) > 0 }
        #expect(
            heldRows.isEmpty,
            """
            no row may be held at the viewport's top: the user's card is \
            painted in the viewport's top band (= \(heldRows.count) of its \
            \(bandRows.count) rows wear the card's colour), so the row is \
            pinned there instead of scrolling with the content.
            """
        )
    }

    /// The control: the user's own bubble IS painted, on the trailing side
    /// of the transcript's visible rows.
    ///
    /// The fixture puts the user's message LAST, so at rest the viewport
    /// shows it: the trailing region must carry the card. The composer's
    /// own bar wears the same colour on the LEADING side (= 295 pixels,
    /// measured, and present with an empty conversation), so the trailing
    /// region is the only place the user's own bubble can show itself.
    ///
    /// A transcript that never rendered the user's row paints nothing
    /// there (= measured: 0 card pixels in the trailing region with an
    /// empty conversation), so this control cannot be satisfied by
    /// anything but the user's own bubble.
    @Test("the user's own bubble paints its card on the trailing side (= the control)")
    func theUsersBubblePaintsItsCardOnTheTrailingSide() {
        let messages = makeMessages(userLast: true)
        let vm = ChatViewModel(
            initialMessages: messages,
            repository: FixedChatRepository(messages: messages),
            providersConfigured: { true }
        )
        let (window, hosting) = host(ChatView(vm: vm))
        defer { window.orderOut(nil) }

        guard let scroll = Self.transcriptScrollView(in: hosting) else {
            Issue.record(Comment("the chat must have a scroll view"))
            return
        }
        let painted = paintedPixels(of: hosting)
        let trailing = cardRows(painted, fill: cardFill(of: hosting), trailing: true)
        let total = trailing.values.reduce(0, +)

        #expect(
            total > 1000,
            """
            the user's own bubble must paint its card on the trailing side \
            of the transcript's visible rows (= \(total) card-coloured \
            pixels there), so a transcript that never rendered the user's \
            row cannot pass this.
            """
        )
    }

    /// A body pass must not rebuild the transcript's rows.
    ///
    /// The claim is the transcript's IDENTITY rule: a row is identified by
    /// its own message's id, so re-rendering the transcript hands SwiftUI
    /// the same identity for the same row, and the row's views SURVIVE.
    /// A row whose identity were fresh on every body pass (= a new id per
    /// render) would tear its views down and rebuild them, which is what
    /// the transcript's row identity exists to prevent.
    ///
    /// The measurement is on the REAL view: the hosted ChatView's row
    /// views' own object identities, before and after the model's newest
    /// message changes (= the streaming reply's own path). Measured: with
    /// the row's identity broken (= a fresh id per render), the row views
    /// are torn down and eleven new ones appear; with the rule in place,
    /// every row view survives and none is replaced.
    @Test("a body pass keeps the transcript's rows (= the rows are not rebuilt)")
    func aBodyPassKeepsTheTranscriptRows() {
        let messages = makeMessages(userLast: true)
        let vm = ChatViewModel(
            initialMessages: messages,
            repository: FixedChatRepository(messages: messages),
            providersConfigured: { true }
        )
        let (window, hosting) = host(ChatView(vm: vm))
        defer { window.orderOut(nil) }

        guard let scroll = Self.transcriptScrollView(in: hosting),
              let document = scroll.documentView
        else {
            Issue.record(Comment("the chat must have a scroll view with a document"))
            return
        }

        /// The row views' own object identities.
        func rowIdentities() -> Set<ObjectIdentifier> {
            var identities: Set<ObjectIdentifier> = []
            func walk(_ view: NSView) {
                identities.insert(ObjectIdentifier(view))
                for subview in view.subviews {
                    walk(subview)
                }
            }
            walk(document)
            return identities
        }

        let before = rowIdentities()
        #expect(!before.isEmpty, "the transcript must have laid its rows out")

        // The body pass: the newest message's content changes (= the
        // streaming reply's own path).
        vm.messages[vm.messages.count - 1].content = "Reply 20. (grown)"
        RunLoop.current.run(until: Date().addingTimeInterval(0.9))
        hosting.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        let after = rowIdentities()
        let kept = before.intersection(after).count
        let replaced = after.subtracting(before).count
        #expect(
            replaced == 0,
            """
            \(replaced) of the transcript's row views were torn down and \
            rebuilt by one body pass (= \(kept) of \(before.count) survived): \
            the rows are rebuilt on every render, so a row's identity is not \
            its own message's id.
            """
        )
    }

    /// The chat-band guard, carried forward: no row of the transcript
    /// paints a surface across the column's leading edge, and the user's
    /// own bubble keeps its own card.
    @Test("no transcript row paints a surface across the column (= the user's bubble keeps its own card)")
    func noRowPaintsASurfaceAcrossTheColumn() {
        let messages = makeMessages(userLast: true)
        let vm = ChatViewModel(
            initialMessages: messages,
            repository: FixedChatRepository(messages: messages),
            providersConfigured: { true }
        )
        let (window, hosting) = host(ChatView(vm: vm))
        defer { window.orderOut(nil) }

        guard let scroll = Self.transcriptScrollView(in: hosting) else {
            Issue.record(Comment("the chat must have a scroll view"))
            return
        }
        let painted = paintedPixels(of: hosting)
        let trailing = cardRows(painted, fill: cardFill(of: hosting), trailing: true)

        // The rows this test reads: the transcript's own viewport, leaving
        // the composer's own bar alone.
        let scale = Double(painted.height) / Double(scroll.contentView.bounds.height)
        let transcriptRows = 0 ..< Int(Double(painted.height) - 120 * scale)
        let shares = hostSharePerRow(painted, rows: transcriptRows)

        // A surface painted across the whole column fills the leading
        // edge edge to edge, so those rows carry almost no host.
        let banded = shares.filter { $0 < 0.1 }
        #expect(
            banded.count <= 2,
            """
            \(banded.count) of the first \(shares.count) rows of the transcript's \
            leading edge are painted edge to edge by something other than the \
            host: a transcript row paints a surface of its own across the \
            column, instead of leaving the column's own surface visible.
            """
        )

        // And the row is really there: the user's own bubble paints its
        // card on the trailing side, so a transcript that rendered nothing
        // at all cannot pass.
        #expect(
            trailing.values.reduce(0, +) > 1000,
            "the user's own bubble must still paint its card (= the row's own surface was removed, the bubble's was not)"
        )
    }
}
