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
//  THE INSTRUMENT IS THE LAYOUT AND THE SCROLL POSITION. The bubble's
//  surface is Apple's Liquid Glass (= `.glassEffect`), and an offscreen
//  read does not composite a glass surface at all (= the house's rule: =
//  a control's appearance must be measured on a SCREEN capture): = the
//  user's bubble paints NOTHING in an offscreen read, = its words and
//  its surface included (= measured: = the bubble's area carries the
//  panel's own colour, = 0 pixels of any other kind, = while the
//  agent's flat reply text still paints). So the pixels cannot see the
//  user's row any more, and the claims are carried by what IS there: =
//  the rows the production view tree laid out (= the user's bubble is
//  the one that hugs the TRAILING edge, = every reply is flat text on
//  the leading side), = and the transcript's resting scroll position
//  (= a row held at the viewport's top parks the scroll at the top: =
//  the old pinned section header's trigger did exactly that).
//
//  THE MEASUREMENT IS AT THE VIEWPORT'S RESTING POSITION. The transcript
//  rests at its bottom (= the newest content is what the panel shows).
//
//  WHY THE MEASUREMENT IS TRAILING-ONLY
//  ====================================
//  The user's bubble is TRAILING (= it hugs its words on the trailing
//  side of the column) and every agent reply is flat text on the
//  leading side, so the trailing side of the column is where the
//  user's own row can show itself and where nothing else can.
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
//      the viewport shows it: the trailing side of the transcript's laid
//      out rows must carry a row that hugs the trailing edge (= the
//      user's own bubble, = measured: it ends at 592 PT of a 600 PT
//      column, = while every reply ends at 73 PT). A transcript that
//      rendered no user row at all lays out no such row, so this
//      control cannot be satisfied by anything but the user's own
//      bubble.
//
//  The second assertion carries the chat-band guard forward: no row of
//  the transcript paints a surface across the column's leading edge (= one
//  material at the window's root, and nothing inside the window painting a
//  surface of its own), while the user's own bubble keeps its own words.
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

    /// The rows the transcript laid out, in the hosted tree.
    ///
    /// The scroll view's document holds ONE container (= the lazy
    /// stack), and the container's children are the realized rows'
    /// contents: = one view per message, = laid out in the messages'
    /// order.
    private func laidOutRows(in scroll: NSScrollView) -> [NSView] {
        guard let container = scroll.documentView?.subviews.first else { return [] }
        return container.subviews
    }

    /// The row that hugs the TRAILING edge of the column.
    ///
    /// The user's own bubble carries its words on the trailing side and
    /// every agent reply is flat text on the leading side, so the
    /// trailing row is the user's own row and nothing else. (= measured:
    /// it ends at 592 PT of a 600 PT column, = while every reply ends at
    /// 73 PT.)
    private func trailingRow(in scroll: NSScrollView) -> NSView? {
        let column = scroll.documentView?.frame.width ?? 0
        guard column > 0 else { return nil }
        return laidOutRows(in: scroll).first { $0.frame.maxX > column / 2 }
    }

    /// The transcript's resting scroll offset, in points.
    ///
    /// The transcript rests at its bottom (= the newest content is what
    /// the panel shows). A row HELD at the viewport's top parks the
    /// scroll at the top instead (= the old pinned section header's
    /// trigger did exactly that: = the pinned card was painted in the
    /// viewport's top band).
    private func restingOffset(in scroll: NSScrollView) -> CGFloat {
        scroll.contentView.bounds.origin.y
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
    /// pinned section header) would park the scroll at the top and keep
    /// that row in view instead.
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

        // The transcript rests at its BOTTOM. A row held at the viewport's
        // top parks the scroll at the top instead: the old pinned section
        // header's trigger scrolled the newest user row up there and kept
        // it there.
        let offset = restingOffset(in: scroll)
        #expect(
            offset > 0,
            """
            the transcript must rest at its bottom, not at its top: a row \
            held at the viewport's top parks the scroll at the top (offset = \
            \(offset)), and the conversation then scrolls under that row.
            """
        )

        // And the user's own row is NOT among the rows in view: the
        // fixture put that message first and the conversation rests at its
        // bottom, so the row scrolled away with the content.
        #expect(
            trailingRow(in: scroll) == nil,
            """
            the user's own row must not be held in view: the transcript's \
            trailing side carries a row that hugs the trailing edge (= the \
            user's bubble) although that message is FIRST and the \
            conversation rests at its bottom, so the row was held there \
            instead of scrolling away with the content.
            """
        )
    }

    /// The control: the user's own row IS laid out, on the trailing side
    /// of the transcript.
    ///
    /// The fixture puts the user's message LAST, so at rest the viewport
    /// shows it: the trailing side of the laid out rows must carry a row
    /// that hugs the trailing edge (= the user's bubble, = measured: it
    /// ends at 592 PT of a 600 PT column, = while every reply ends at
    /// 73 PT). A transcript that never rendered the user's row lays out
    /// no such row, so this control cannot be satisfied by anything but
    /// the user's own bubble.
    @Test("the user's own row is laid out on the trailing side (= the control)")
    func theUsersRowIsLaidOutOnTheTrailingSide() {
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
        let row = trailingRow(in: scroll)
        #expect(
            row != nil,
            """
            the user's own bubble must be laid out: the transcript's trailing \
            side carries no row that hugs the trailing edge, so a transcript \
            that never rendered the user's row cannot pass this.
            """
        )
        let column = scroll.documentView?.frame.width ?? 0
        if let row {
            #expect(
                row.frame.maxX > column / 2,
                "the user's own bubble must hug the trailing edge of the column; it ends at \(row.frame.maxX) PT of a \(column) PT column"
            )
        }
        // And the transcript rests at its bottom, so the row in view is
        // the newest one.
        #expect(
            restingOffset(in: scroll) > 0,
            "the transcript must rest at its bottom (= the newest content is what the panel shows)"
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
    /// are torn down and ten new ones appear; with the rule in place,
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
    @Test("no transcript row paints a surface across the column (= the user's bubble keeps its own row)")
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

        // And the row is really there: the user's own bubble is laid out
        // on the trailing side, so a transcript that rendered nothing at
        // all cannot pass.
        #expect(
            trailingRow(in: scroll) != nil,
            "the user's own bubble must still be laid out (= the row's own surface was removed, the bubble's was not)"
        )
    }
}
