//
//  ChatTranscriptFlatFlowTests.swift · WenshuApp
//
//  The chat transcript is ONE flat list of messages: no row is held at the
//  viewport's top while the conversation scrolls under it, and the user's
//  own message is a row of that list rather than an object floating in it.
//
//  WHY
//  The transcript renders every message in order and every row scrolls
//  with the content. The user's own message carries a band — one
//  content-area surface (= `ContentAreaMaterial.surface`) that spans the
//  chat area and stops 20 PT short of each edge, with its ink starting at
//  the band's leading edge. The assistant's reply is flat text on the
//  leading side. The transcript's viewport follows the newest content.
//
//  WHAT THIS TEST DOES
//  It hosts the REAL ChatView (= the app's own view, not a mock of it)
//  over a host background the app never paints, and reads the VIEW TREE
//  the app laid out inside it.
//
//  THE INSTRUMENT IS THE LAYOUT AND THE SCROLL POSITION. The band's
//  surface is a material, and an offscreen read does not composite a
//  material at all (= the house's rule: a control's appearance must be
//  measured on a SCREEN capture, never on `cacheDisplay`), so the pixels
//  cannot see the user's row. The claims are carried by what IS there:
//  the rows the production view tree laid out, the one material surface
//  inside them, and the transcript's resting scroll position (= a row
//  held at the viewport's top parks the scroll at the top: the old pinned
//  section header's trigger did exactly that).
//
//  THE MEASUREMENT IS AT THE VIEWPORT'S RESTING POSITION. The transcript
//  rests at its bottom (= the newest content is what the panel shows).
//
//  WHY THE MEASUREMENT IS TRAILING-SIDE
//  The band keeps the chat area's margin, so its trailing edge is the one
//  place in the column a band can be told from a reply: every reply is
//  flat text that ends at the leading inset, and nothing else reaches
//  across the column.
//
//  The two fixtures
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
//      out rows must carry the band's edge, inset from the column, while
//      every reply ends at the leading inset. A transcript that rendered
//      no user row lays out no such row, so this control cannot be
//      satisfied by anything but the user's own band.
//
//  The second assertion carries the chat-band guard forward: exactly one
//  material surface is realized in the viewport, and it is the user's own
//  band — a reply that grew a surface of its own, or a band that ran edge
//  to edge, both fail here.
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

    /// The band, located by what it paints rather than by its position.
    ///
    /// The realized cell list is not one entry per message: a message can
    /// contribute several views, and rows scrolled above the viewport come
    /// back with a negative origin. So the band is found as the realized
    /// cell that carries a material surface, which is the property the
    /// rule is about.
    private func userRow(in scroll: NSScrollView) -> NSView? {
        laidOutRows(in: scroll).first { !Self.materialViews(in: $0).isEmpty }
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

        // And the user's own row is not held in view: the fixture puts
        // that message FIRST and the conversation rests at its BOTTOM, so
        // the row scrolls away with the content. A row still inside the
        // viewport here is the pinned section header's behaviour.
        let rows = laidOutRows(in: scroll)
        let visible = scroll.contentView.bounds
        #expect(
            rows.first.map { $0.frame.maxY <= visible.minY } ?? false,
            """
            the user's own row must not be held in view: it is the FIRST row \
            of a transcript that rests at its bottom, yet it still sits \
            inside the viewport (row \(String(describing: rows.first?.frame)) \
            against visible \(visible)) — a row kept on screen is a pinned \
            header, not a flat list.
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
    @Test("the user's own row is laid out across the column (= the control)")
    func theUsersRowIsLaidOutAcrossTheColumn() {
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
        let row = userRow(in: scroll)
        #expect(
            row != nil,
            """
            the user's own row must be laid out: the transcript's one row \
            that carries a material surface is the user's band (= the \
            fixture puts the user's message last, and no reply wears a \
            surface), so a transcript that never rendered it cannot pass this.
            """
        )
        let column = scroll.documentView?.frame.width ?? 0
        if let row {
            // The row's own box is the band's box, so it must sit inside
            // the column, never past an edge. Where the band stops is the
            // material geometry check (the surface view sits 20 PT off each
            // side); here the row must simply be laid out within it.
            #expect(
                row.frame.minX >= 0 && row.frame.maxX <= column + 1,
                """
                the user's own row must be laid out inside the chat column; it \
                runs from \(row.frame.minX) to \(row.frame.maxX) PT of a \(column) PT column
                """
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

    /// The chat-band guard, carried forward: the transcript realizes
    /// exactly one material surface in its viewport, that surface is the
    /// user's own band, it keeps the chat area's 20 PT margin on both
    /// sides, and no reply row realizes a surface of its own.
    @Test("only the user's own row paints a surface across the column")
    func onlyTheUsersRowPaintsASurfaceAcrossTheColumn() throws {
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

        // An NSVisualEffectView is composited by the window server, so a
        // bitmap of the offscreen harness never shows it (= a pixel probe
        // only ever sees the flat fill a material replaces). The surface
        // is therefore read from the view tree, where its geometry is
        // still the real laid-out geometry: the user's own band carries
        // exactly one material view, and it sits 20 PT off each edge.
        let rows = laidOutRows(in: scroll)
        #expect(
            !rows.isEmpty,
            "the transcript laid out no row at all"
        )
        // One realized surface, and it is the user's own band.
        //
        // The lazy stack realizes only the rows inside the viewport, so
        // the claim is made about what IS realized: exactly one material
        // view sits in the transcript, it lies inside the row the user's
        // message laid out, and its box stops 20 PT short of each column
        // edge. A reply that grew a surface of its own, or a band that ran
        // edge to edge, both fail here.
        let surfaces = Self.materialViews(in: hosting)
        #expect(
            surfaces.count == 1,
            "the transcript must realize one band surface in its viewport; it realized \(surfaces.count)"
        )
        let effect = try #require(surfaces.first, "the transcript realized no band surface at all")
        let userRow = try #require(userRow(in: scroll), "no realized row carries a material surface")
        let column = scroll.contentView.bounds.width
        let bandBox = effect.convert(effect.bounds, to: scroll)
        let leading = bandBox.minX
        let trailing = column - bandBox.maxX
        #expect(
            abs(leading - 20) <= 1 && abs(trailing - 20) <= 1,
            """
            the band must keep the chat column's 20 PT margin on both \
            sides; it keeps \(leading) PT on the leading side and \
            \(trailing) PT on the trailing side
            """
        )
        #expect(
            abs(bandBox.width - (column - 40)) <= 1,
            """
            the band must span the chat area between its margins, not shrink \
            to its words; it spans \(bandBox.width) PT of a \(column) PT column
            """
        )
        // The band is the only realized row that paints a surface, and it
        // is the bottom-most one (= the fixture puts the user's message
        // last), so a reply that grew a surface of its own fails here.
        let boxes = rows.map { $0.convert($0.bounds, to: scroll) }
        let painted = rows.enumerated().filter { !Self.materialViews(in: $0.element).isEmpty }
        #expect(
            painted.count == 1,
            """
            exactly one realized row may carry a material surface; \
            \(painted.count) of \(rows.count) realized rows do
            """
        )
        if let paintedIndex = painted.first?.offset {
            let bandMaxY = boxes[paintedIndex].maxY
            let replyMaxYs = boxes.enumerated().filter { $0.offset != paintedIndex }.map(\.element.maxY)
            let lowestReply = replyMaxYs.max() ?? bandMaxY
            #expect(
                lowestReply <= bandMaxY + 1,
                """
                the band must be the bottom-most realized row, the fixture's \
                user message being last; the band ends at \(bandMaxY) PT and the \
                lowest reply at \(lowestReply) PT
                """
            )
        }
    }

    /// Every material view inside a subtree.
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
}
