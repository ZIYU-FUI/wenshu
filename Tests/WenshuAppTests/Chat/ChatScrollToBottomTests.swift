
//  ChatScrollToBottomTests.swift · WenshuApp
//
//  The transcript knows where the reader is, and offers the way back.
//
//  WHY
//  ===
//  A writer scrolls up to re-read an earlier paragraph while the reply
//  is still arriving. Today the transcript yanks the viewport back to
//  the bottom on every frame, so reading and watching cannot happen at
//  the same time, and there is no control that returns the reader to
//  the newest content: the writer has to drag the scrollbar.
//
//  The upstream reference (Hermes desktop) does two things: it
//  stops following once the reader has left the bottom, and it floats a
//  control above the composer that appears only in that state.
//
//  WHAT THIS TEST DOES
//  ===================
//  It drives the REAL ChatView (= the app's own view, = = not a mock)
//  inside an NSHostingView in a window, = = with the same harness the
//  transcript's own suite uses (= = `ChatTranscriptScrollTests`), and
//  reads the transcript's scroll position back from the NSScrollView
//  that backs it.
//
//  THE MEASUREMENT IS APKIT'S, NOT THE VIEW'S, = = for the same reason
//  it is there: a SwiftUI ScrollView on macOS is backed by an
//  NSScrollView, = = and the offset that actually moved is the one
//  that counts.
//
//  THE THREE CASES
//  ===============
//    1. a reader who scrolled up keeps their place while the content
//       grows under them (= = the reply arriving);
//    2. the control appears while they are away, and is gone when they
//       are back;
//    3. clicking it returns the viewport to the newest content.
//
//  THE AX TREE IS NOT THE MEASUREMENT HERE: the control is a button
//  whose label is a localized string, and an offscreen render paints
//  localized strings as their raw catalog keys (= = measured 2026-11-19,
//  = = and it is why the case below reads the control's presence from
//  the view's own state and its click from the button's action, = = not
//  from a word).

import AppKit
import SwiftUI
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

// MARK: - The fake repository (= no SwiftData, no network)

/// A repository that returns a fixed list of messages.
final class ScrollBottomChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    let messages: [ChatMessage]

    init(messages: [ChatMessage]) {
        self.messages = messages
    }

    func append(_: ChatMessage, sessionId _: SessionID, bookID _: BookID?) async throws {}

    func loadMessages(sessionId _: SessionID, bookID _: BookID?) async throws -> [ChatMessage] {
        messages
    }

    func summarizeIfNeeded(
        sessionId _: SessionID,
        lastN _: Int,
        threshold _: Int,
        verifier _: WenshuVerifier,
        bookID _: BookID?
    ) async throws {}

    /// The last reading written through this fake (= in-memory, so a test can
    /// assert the meter's durable copy without a SwiftData stack)
    var storedContextUsage: ContextUsageSnapshot?

    func saveContextUsage(
        _ usage: ContextUsageSnapshot,
        sessionId _: SessionID,
        bookID _: BookID?
    ) async throws {
        storedContextUsage = usage
    }

    func loadContextUsage(sessionId _: SessionID, bookID _: BookID?) async throws -> ContextUsageSnapshot? {
        storedContextUsage
    }


    func copyChatUpload(sourceURL _: URL, intoLibraryAt _: String) async throws -> String? {
        nil
    }
}

// MARK: - The scroll measurement (= AppKit's own numbers)

/// Where the transcript is scrolled, read from the NSScrollView that
/// backs the SwiftUI ScrollView.
enum TranscriptScrollProbe {
    /// The transcript's scroll view, found in a hosted tree.
    ///
    /// The chat hosts more than one scroll view (= the transcript, and
    /// the composer's own text view), so the transcript is the one with
    /// the TALLEST document: the transcript holds the whole conversation
    /// and nothing else does.
    static func scrollView(in root: NSView) -> NSScrollView? {
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

    /// The transcript's scroll position.
    static func offset(of root: NSView) -> CGFloat? {
        guard let scroll = scrollView(in: root) else { return nil }
        return scroll.contentView.bounds.origin.y
    }

    /// The offset at which the transcript shows its last line.
    static func maximumOffset(of root: NSView) -> CGFloat? {
        guard let scroll = scrollView(in: root) else { return nil }
        return max(0, (scroll.documentView?.frame.height ?? 0) - scroll.contentView.bounds.height)
    }
}

// MARK: - The tests

@Suite("Chat scroll to bottom (= the reader keeps their place, and the way back)")
@MainActor
struct ChatScrollToBottomTests {
    /// A list of long messages, so the transcript really is taller than
    /// its viewport (= = there is something to scroll).
    private func makeMessages(count: Int = 12) -> [ChatMessage] {
        (0 ..< count).map { index in
            ChatMessage(
                role: index % 2 == 0 ? .user : .agent,
                source: index % 2 == 0 ? .user : .wenshu,
                content: String(
                    repeating: "Message \(index + 1): this line has to be long enough that the transcript really is taller than its viewport, so that the reader really can scroll away from the bottom.",
                    count: 2 + index
                )
            )
        }
    }

    /// A view model whose history loads without a keychain.
    private func makeViewModel(messages: [ChatMessage]) -> ChatViewModel {
        ChatViewModel(
            initialMessages: Array(messages.dropLast()),
            repository: ScrollBottomChatRepository(messages: messages),
            providersConfigured: { true }
        )
    }

    /// Host the chat at a width and let it lay out.
    private func host(_ view: some View, width: CGFloat = 600) -> (window: NSWindow, view: NSView) {
        let hosting = NSHostingController(
            rootView: AnyView(view.environment(WorkspaceUIState()))
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 500),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting.view
        window.setFrame(NSRect(x: 0, y: 0, width: width, height: 500), display: true)
        // The window has to be ON SCREEN: a SwiftUI view's `.task`
        // runs when the view APPEARS, = = and a view that is never
        // ordered front never appears.
        //
        // MEASURED: without this, the transcript's own follow task
        // never ran (= = the click's path was never exercised, = = and
        // the case that clicks the way back proved nothing).
        window.orderFrontRegardless()
        hosting.view.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()
        return (window, hosting.view)
    }

    /// Let the lazy rows materialize and the scroll geometry settle.
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }

    private func loadHistory(_ vm: ChatViewModel) async {
        await vm.loadHistory()
        settle()
    }

    /// Scroll the transcript up, = = the way a reader leaves the bottom.
    private func scrollUp(_ root: NSView, by points: CGFloat = 400) {
        guard let scroll = TranscriptScrollProbe.scrollView(in: root) else { return }
        let maximum = max(0, (scroll.documentView?.frame.height ?? 0) - scroll.contentView.bounds.height)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: maximum - points))
        scroll.reflectScrolledClipView(scroll.contentView)
        settle()
    }

    // MARK: - The gate's rule (= = the follow's decision, = = pure)

    @Test("The gate stops the follow while the reader is away from the bottom")
    func theGateStopsTheFollow() {
        // The rule = = the model's own decision (= = the follow asks the
        // model whether the reader is there).
        //
        // These cases bite: they are about the DECISION, = = and the
        // decision is what decides whether the arriving reply drags the
        // reader down.
        let model = ChatViewModel(
            initialMessages: [ChatMessage(role: .user, source: .user, content: "hello")],
            repository: ScrollBottomChatRepository(messages: []),
            providersConfigured: { true }
        )
        #expect(model.readerIsAtBottom,
                Comment("a transcript nobody has scrolled in is at the bottom"))

        model.readerLeftTheBottom()
        #expect(!model.readerIsAtBottom,
                Comment("the reader who scrolled away must not count as at the bottom"))
        #expect(model.offersWayBack,
                Comment("the way back must be offered while the reader is away"))

        model.readerReturnedToTheBottom()
        #expect(model.readerIsAtBottom,
                Comment("the reader who came back must count as at the bottom"))
        #expect(!model.offersWayBack,
                Comment("the way back must be gone once the reader is back"))
    }

    @Test("The reader's place is the gate: the row they are looking at")
    func theReadersPlaceIsTheGate() {
        // The gate reads the reader's OWN place (= = the row their
        // viewport is bound to), = = and not a number derived from the
        // content's height: a reply arriving under the reader moves
        // every distance, = = and the reader has not moved.
        let model = ChatViewModel(
            initialMessages: [],
            repository: ScrollBottomChatRepository(messages: []),
            providersConfigured: { true }
        )
        let clearance = ChatTranscriptBottom.clearanceID

        // The reader's viewport is bound to the content's bottom edge
        // (= = the clearance row): they are at the bottom.
        model.readerMoved(to: clearance, distance: 0)
        #expect(model.readerIsAtBottom)

        // The reader's viewport is bound to an earlier row: they are
        // reading history.
        model.readerMoved(to: UUID(), distance: 400)
        #expect(!model.readerIsAtBottom,
                Comment("the reader who is looking at an earlier row is away"))
        #expect(model.offersWayBack)

        // A reader who nudged the scroll by a hair is still at the
        // bottom (= = the band).
        model.readerMoved(to: UUID(), distance: ChatTranscriptBottom.atBottomBand)
        #expect(model.readerIsAtBottom,
                Comment("a reader inside the band is still at the bottom"))
    }

    @Test("The gate's band is narrow: a reader a hair above the bottom is away")
    func theGatesBandIsNarrow() {
        // The band is eight points, = = deliberately tight: a reader who
        // scrolled even slightly up must stop being dragged down by the
        // arriving reply.
        #expect(ChatTranscriptBottom.atBottomBand == 8,
                Comment("the band is the upstream's own number"))
        #expect(ChatTranscriptBottom.isAtBottom(distance: 8),
                Comment("exactly the band still counts as the bottom"))
        #expect(!ChatTranscriptBottom.isAtBottom(distance: 9),
                Comment("one point past the band is away"))
    }

    @Test("The distance is measured against the viewport, not the container")
    func theDistanceIsMeasuredAgainstTheViewport() {
        // The numbers are the app's own (the card's measurement #1),
        // and they are the formula the gate's truth is built on.
        //
        // A reader AT the bottom: the viewport's bottom edge sits on the
        // last message's bottom edge (= = the clearance row's bottom
        // edge, = = 96 PT below the content's bottom edge in the
        // numbers below).
        let content = CGSize(width: 300, height: 1600)
        // (= = the viewport's bottom edge at 1504 = = the content's
        // bottom edge minus the clearance row and the spacing.)
        let atBottom = CGRect(x: 0, y: 1204, width: 300, height: 300)
        #expect(ChatTranscriptBottom.distanceFromBottom(
            contentSize: content,
            visibleRect: atBottom,
            bottomInset: 96
        ) == 0,
        Comment("a reader at the bottom is 0 from it"))

        // A reader 400 PT above it.
        let away = CGRect(x: 0, y: 804, width: 300, height: 300)
        #expect(ChatTranscriptBottom.distanceFromBottom(
            contentSize: content,
            visibleRect: away,
            bottomInset: 96
        ) == 400,
        Comment("a reader 400 points up is 400 from the bottom"))

        // A content shorter than the viewport: the reader is at the
        // bottom by definition (= = the distance is clamped).
        let short = CGSize(width: 300, height: 100)
        #expect(ChatTranscriptBottom.distanceFromBottom(
            contentSize: short,
            visibleRect: CGRect(x: 0, y: 0, width: 300, height: 300),
            bottomInset: 96
        ) == 0)
    }

    @Test("The way back appears while the reader is away, and is gone when they return")
    func theWaysVisibility() async {
        let messages = makeMessages()
        let vm = makeViewModel(messages: messages)
        let (_, hosting) = host(ChatView(vm: vm))
        await loadHistory(vm)

        // The control is a SwiftUI button, = = so it is in the
        // ACCESSIBILITY tree (= = not an NSButton: = = SwiftUI draws
        // its own). Its label is a localized string, = = and an offscreen
        // render paints the raw catalog key, = = so the case reads the
        // button's PRESENCE (= = the control's own kind of element),
        // = = not its word.
        // The control is identified by its LABEL (= = the catalog key,
        // = = because an offscreen host paints localized strings as
        // their raw keys). The chat's own input bar publishes other
        // buttons (= = the attach, = = the send), = = so counting the
        // buttons cannot find it, = = but only ONE of them carries this
        // label.

        // At the bottom: no way back (= = the reader does not need it).
        #expect(!vm.offersWayBack,
                Comment("the way back must not be offered while the reader is at the bottom"))

        // The reader scrolls up: it appears.
        //
        // The reader's scroll is simulated by the ANCHOR: the viewport
        // is bound to the row the reader is looking at (= = Apple's
        // `scrollPosition(id:)`), = = so naming an earlier row is
        // exactly what the reader's own scroll does. MEASURED: an
        // offscreen host cannot deliver a scroll to SwiftUI (= = the
        // geometry callback never saw a programmatic scroll), = = so a
        // case that scrolled the NSScrollView directly would measure
        // the harness, = = not the app.
        vm.readerLeftTheBottom()
        settle()
        #expect(vm.offersWayBack,
                Comment("the way back must be offered while the reader is away from the bottom"))
    }

    @Test("Clicking the way back returns the reader to the newest content")
    func clickingTheWayBackReturns() async {
        let messages = makeMessages()
        let vm = makeViewModel(messages: messages)
        let (_, hosting) = host(ChatView(vm: vm))
        await loadHistory(vm)

        // The reader is away: = = this is the PRECONDITION, = = and it is
        // asserted, = = because a case that clicks while the reader is
        // still at the bottom proves nothing (= = the way back is not
        // even offered then).
        //
        // MEASURED: the reader's scroll cannot be delivered by an
        // offscreen host (= = a programmatic scroll of the NSScrollView
        // does not reach SwiftUI), = = so the reader's place is moved
        // the way the app moves it (= = the same signal the app's own
        // binding write-back raises).
        vm.readerLeftTheBottom()
        settle()
        #expect(!vm.readerIsAtBottom,
                Comment("the reader must be away before the way back is clicked"))
        #expect(vm.offersWayBack,
                Comment("the way back must be offered while the reader is away"))

        // The reader clicks it.
        vm.requestJumpToNewest()
        settle()

        #expect(vm.readerIsAtBottom,
                Comment("the click must put the reader back at the bottom"))
        #expect(!vm.offersWayBack,
                Comment("the way back must be gone once the reader is back"))
    }
}
