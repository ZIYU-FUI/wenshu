
//  ChatTranscriptScrollTests.swift · WenshuApp
//
//  The chat transcript must keep showing its LAST line when the
//  window's width changes.
//
//  WHY
//  ===
//  The transcript's scroll rules live in ChatView.swift:
//
//    * `.defaultScrollAnchor(.bottom)`
//    * `onChange(of: vm.messages.last?.content)` -> scrollTo(last, .bottom)
//    * `onChange(of: <the latest user message's id>)` -> scrollTo(.top)
//
//  The defect was a GAP between the content's bottom edge and the last
//  message's bottom edge. The transcript padded its content on all
//  sides, so the content's bottom edge sat BELOW the last message's.
//  The chat's "keep showing the last line" rule scrolls the last
//  MESSAGE to the bottom, which therefore landed that gap short of the
//  maximum offset, and a transcript short of the maximum is not
//  anchored: `defaultScrollAnchor(.bottom)` holds the bottom only while
//  the offset IS the maximum. So the next re-wrap (= a narrower column,
//  the bubbles re-wrapping, the content growing) grew the content
//  beneath a transcript that no longer followed it, and the last line
//  fell below the viewport.
//
//  The fix removes the gap (= the padding moves into the content margin
//  below), so the chat's own scroll lands ON the maximum offset, where
//  the anchor holds.
//
//  WHAT THIS TEST DOES
//  ===================
//  It drives the REAL ChatView (= the app's own view, not a mock of
//  it) inside an NSHostingView in a window, with:
//    * a ChatViewModel whose `providersConfigured` returns true
//      (= the chat loads its history; = no keychain needed),
//    * a `repository` that returns a fixed list of LONG messages
//      (= no SwiftData, no network),
//  and then it resizes the window's WIDTH (= what the split view does
//  to the chat column when the window's width changes) and reads the
//  transcript's scroll position back.
//
//  THE MEASUREMENT IS APPKIT'S, NOT THE VIEW'S. A SwiftUI ScrollView
//  on macOS is backed by an NSScrollView, so the test finds that
//  scroll view in the hosted tree and reads ITS OWN numbers: the
//  clip view's offset and the document view's height.
//
//  THE BOTTOM, MEASURED. The offset that shows the last line moves
//  with the content's height (= the maximum offset is the content's
//  height minus the transcript's own height, and the transcript's own
//  height does not change when the column's width does). So the test
//  captures the offset the chat itself settled on after the history
//  loaded (= the bottom, then) and adds the content's height delta.
//
//  MEASURED 2026-10-27 (the app as it was, on the real ChatView): the
//  content's height went 1639 -> 2119 and the offset stayed at 1583
//  (= a bottom of 1695), = the last line was 112 points below the
//  viewport. With the gap removed the offset follows the content's
//  height exactly (= 2375 of a bottom of 2375).

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp
import WenshuAgent
import WenshuData

// MARK: - The fake repository (= no SwiftData, no network)

/// A repository that returns a fixed list of messages.
final class FixedChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    let messages: [ChatMessage]

    init(messages: [ChatMessage]) {
        self.messages = messages
    }

    func append(_ message: ChatMessage, sessionId: SessionID, bookID: BookID?) async throws {}

    func loadMessages(sessionId: SessionID, bookID: BookID?) async throws -> [ChatMessage] {
        messages
    }

    func summarizeIfNeeded(
        sessionId: SessionID,
        lastN: Int,
        threshold: Int,
        verifier: WenshuVerifier,
        bookID: BookID?
    ) async throws {}

    func copyChatUpload(sourceURL: URL, intoLibraryAt path: String) async throws -> String? {
        nil
    }
}

// MARK: - The scroll measurement (= AppKit's own numbers)

/// Where the transcript is scrolled, read from the NSScrollView that
/// backs the SwiftUI ScrollView.
struct TranscriptScroll: Equatable {
    /// How far the transcript is scrolled (= the clip view's origin).
    var offset: CGFloat = 0
    /// The content's full height (= the document view's height).
    var contentHeight: CGFloat = 0

    /// The offset at which the transcript shows its last line.
    ///
    /// The bottom moves with the content's height, so the delta is what
    /// travels: the bottom after a change = the bottom before + the
    /// content's height delta.
    func bottom(after contentDelta: CGFloat, from bottom: CGFloat) -> CGFloat {
        bottom + contentDelta
    }
}

@MainActor
enum TranscriptProbe {
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
            for subview in view.subviews { walk(subview) }
        }
        walk(root)
        return found
    }

    /// The transcript's scroll position.
    static func scroll(of root: NSView) -> TranscriptScroll? {
        guard let scroll = scrollView(in: root) else { return nil }
        return TranscriptScroll(
            offset: scroll.contentView.bounds.origin.y,
            contentHeight: scroll.documentView?.frame.height ?? 0
        )
    }

}

// MARK: - The tests

@Suite("Chat transcript scroll (= the last line stays visible across a width change)")
@MainActor
struct ChatTranscriptScrollTests {

    /// A list of long messages, so a narrower column really does wrap
    /// them into more lines (= the content's height really changes).
    private func makeMessages(count: Int = 10) -> [ChatMessage] {
        (0..<count).map { index in
            ChatMessage(
                role: index % 2 == 0 ? .user : .agent,
                source: index % 2 == 0 ? .user : .wenshu,
                content: String(
                    repeating: "Message \(index + 1): this line has to be long enough that a width change really changes how the bubble wraps, and so really changes the height of the whole content.",
                    count: 2 + index
                )
            )
        }
    }

    /// A view model whose history loads without a keychain.
    ///
    /// The chat starts with the first messages already in place, and the
    /// history load then REPLACES them with the full list. The
    /// replacement changes the last message's content, and that is what
    /// the app's own "keep showing the last line" rule reacts to (= the
    /// state the defect needs: the offset sitting a hair short of the
    /// maximum, because the last message's bottom edge is a hair above
    /// the content's bottom edge).
    private func makeViewModel(messages: [ChatMessage]) -> ChatViewModel {
        ChatViewModel(
            initialMessages: Array(messages.dropLast()),
            repository: FixedChatRepository(messages: messages),
            providersConfigured: { true }
        )
    }

    /// Host the chat at a width and let it lay out.
    ///
    /// The chat reads `WorkspaceUIState` from the environment (= the
    /// app injects it once, at the window's root), so the harness
    /// injects one too (= the real thing, with its defaults).
    ///
    /// The hosting view goes into a WINDOW: a SwiftUI scroll view only
    /// lays its content out once it is in a window (= a detached
    /// hosting view never gets a document height, and the measurement
    /// would read zeros).
    private func host(_ view: some View, width: CGFloat) -> (window: NSWindow, view: NSView) {
        // The root view takes the window's size (= it must NOT carry a
        // fixed width, or a window resize would not reach the chat
        // column, and the bubbles would never re-wrap).
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
        hosting.view.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()
        return (window, hosting.view)
    }

    /// Resize the hosted chat (= what the split view does to the chat
    /// column when the window's width changes).
    private func resize(_ window: NSWindow, to width: CGFloat) {
        window.setFrame(NSRect(x: 0, y: 0, width: width, height: 500), display: true)
        window.layoutIfNeeded()
        window.contentView?.layoutSubtreeIfNeeded()
    }

    /// Let the lazy rows materialize and the scroll geometry settle.
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }

    /// Load the history the way the chat loads it.
    ///
    /// The chat's own `.task` calls `loadHistory()`, gated on the
    /// view's keychain check (= a keychain concern, not a scroll one),
    /// so the harness makes the same call itself.
    private func loadHistory(_ vm: ChatViewModel) async {
        await vm.loadHistory()
        settle()
    }

    @Test("The transcript reaches its last line after the history loads")
    func theTranscriptReachesItsLastLine() async {
        let messages = makeMessages()
        let vm = makeViewModel(messages: messages)
        let (_, hosting) = host(ChatView(vm: vm), width: 600)
        await loadHistory(vm)

        guard let scroll = TranscriptProbe.scroll(of: hosting) else {
            Issue.record(Comment("the chat must have a scroll view"))
            return
        }
        #expect(scroll.contentHeight > 500,
                "the transcript must be taller than its viewport (= there is something to scroll)")
        #expect(scroll.offset > 0,
                "the transcript must be scrolled down to its last line (= the offset is positive)")
    }

    @Test("A width change keeps the last line visible")
    func aWidthChangeKeepsTheLastLineVisible() async {
        let messages = makeMessages()
        let vm = makeViewModel(messages: messages)
        let (window, hosting) = host(ChatView(vm: vm), width: 600)
        await loadHistory(vm)

        guard let before = TranscriptProbe.scroll(of: hosting) else {
            Issue.record(Comment("the chat must have a scroll view"))
            return
        }
        let bottom = before.offset

        // Narrow the column in STEPS (= what a window drag does: the
        // chat column's width changes many times, and every step
        // re-wraps the bubbles and grows the content).
        for width in stride(from: 580, through: 380, by: -20) {
            resize(window, to: CGFloat(width))
            settle()
        }

        guard let after = TranscriptProbe.scroll(of: hosting) else {
            Issue.record(Comment("the chat must have a scroll view"))
            return
        }
        print("WIDTHTEST before=(offset \(before.offset), content \(before.contentHeight)) after=(offset \(after.offset), content \(after.contentHeight)) expectedBottom=\(after.bottom(after: after.contentHeight - before.contentHeight, from: bottom))")

        // The content's height must really have changed (= the bubbles
        // really did re-wrap), or the measurement is a no-op.
        #expect(after.contentHeight != before.contentHeight,
                Comment("the width change must have re-wrapped the bubbles (= the content's height changed)"))

        let expectedBottom = after.bottom(after: after.contentHeight - before.contentHeight, from: bottom)
        #expect(after.offset >= expectedBottom - 2,
                Comment("the transcript must STILL show its last line after the width change (offset \(after.offset), the bottom is \(expectedBottom), the content's height went \(before.contentHeight) -> \(after.contentHeight))"))
    }

    @Test("The offset follows the content's height across a width change")
    func theOffsetFollowsTheContentHeight() async {
        let messages = makeMessages()
        let vm = makeViewModel(messages: messages)
        let (window, hosting) = host(ChatView(vm: vm), width: 600)
        await loadHistory(vm)

        guard let before = TranscriptProbe.scroll(of: hosting) else {
            Issue.record(Comment("the chat must have a scroll view"))
            return
        }

        for width in stride(from: 580, through: 380, by: -20) {
            resize(window, to: CGFloat(width))
            settle()
        }

        guard let after = TranscriptProbe.scroll(of: hosting) else {
            Issue.record(Comment("the chat must have a scroll view"))
            return
        }

        // The invariant the fix buys: the transcript's bottom is
        // ANCHORED, so the offset moves by exactly as much as the
        // content's height moved. When the offset does not follow, the
        // content grows beneath a transcript that is no longer anchored
        // to its bottom, and the last line falls below the viewport.
        let offsetDelta = after.offset - before.offset
        let contentDelta = after.contentHeight - before.contentHeight
        #expect(abs(offsetDelta - contentDelta) <= 2,
                Comment("the offset must follow the content's height (the offset moved \(offsetDelta), the content's height moved \(contentDelta))"))
    }
}
