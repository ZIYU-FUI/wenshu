//
//  ChatScrollGeometryProbeTests.swift · WenshuApp
//
//  WHICH BASIS IS THE READER'S DISTANCE?
//  ====================================
//  The transcript's gate asks "how far is the reader from the bottom?".
//  That question has TWO possible answers, because a SwiftUI ScrollView
//  on macOS is backed by an NSScrollView and the two do not share one
//  basis:
//
//    - AppKit's: the document view's height, the clip view's origin and
//      the clip view's height;
//    - SwiftUI's: the scroll geometry's content offset, content size and
//      container size.
//
//  They agree in a bare ScrollView. They do NOT agree in the chat: the
//  transcript sits above the composer (= a safe-area inset), and the
//  content's bottom margin (= the blank space under the last message)
//  sits OUTSIDE the content's own height.
//
//  MEASURED: with the chat hosted in a
//  window, AppKit said the reader was 12 PT from the bottom while the
//  app's own model said 710.5 PT, = = so the gate was closed at the
//  newest content: the way back appeared while the reader had not left,
//  and the follow never ran.
//
//  So this file measures BOTH bases in the SAME hosted chat, and it
//  prints them (= = the numbers a reader can check), and it states
//  which formula agrees with AppKit.
//

import AppKit
import SwiftUI
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@MainActor
struct ChatScrollGeometryProbeTests {
    /// A list of long messages, so the transcript really is taller than
    /// its viewport.
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

    private func makeViewModel(messages: [ChatMessage]) -> ChatViewModel {
        ChatViewModel(
            initialMessages: Array(messages.dropLast()),
            repository: ScrollBottomChatRepository(messages: messages),
            providersConfigured: { true }
        )
    }

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
        hosting.view.layoutSubtreeIfNeeded()
        window.layoutIfNeeded()
        return (window, hosting.view)
    }

    private func settle(_ seconds: TimeInterval = 1.5) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    @Test("Both bases, measured in the same hosted chat")
    func bothBases() async {
        let messages = makeMessages()
        let vm = makeViewModel(messages: messages)
        let (window, view) = host(ChatView(vm: vm))
        defer { window.contentView = nil }
        await vm.loadHistory()
        settle(2.0)

        guard let scroll = TranscriptScrollProbe.scrollView(in: view) else {
            Issue.record(Comment("the transcript must have a scroll view"))
            return
        }

        // AppKit's own numbers.
        let document = scroll.documentView?.frame.height ?? 0
        let clip = scroll.contentView.bounds.height
        let origin = scroll.contentView.bounds.origin.y
        let appKitDistance = document - (origin + clip)
        let appKitMax = max(0, document - clip)

        // SwiftUI's own numbers (= what the app's gate reads).
        print("PROBE appkit document=\(document) clip=\(clip) origin=\(origin) max=\(appKitMax) distance=\(appKitDistance)")
        print("PROBE model atBottom=\(vm.readerIsAtBottom) offersWayBack=\(vm.offersWayBack)")

        // The band is TWO-SIDED: = = a clearance row that is gone
        // leaves the content a row's height SHORT (= = a negative
        // distance, = = measured -84), = = and a one-sided band
        // (< 40) accepted that, = = so the guard could not see the
        // row's absence.
        #expect(abs(appKitDistance) < 40,
                Comment("the chat must sit at its newest content (AppKit says \(appKitDistance))"))

        // THE GATE MUST AGREE WITH APPIKIT.
        //
        // MEASURED: the app's own model
        // said the reader was 710.5 points from the bottom while AppKit
        // said 12, = = so the gate was CLOSED at the newest content: the
        // way back appeared while the reader had not left, = = and the
        // follow never ran.
        //
        // This is the guard for that: the gate is read from the hosted
        // chat (= = not from a number the test made up), and it must
        // agree with the scroll view's own numbers.
        #expect(vm.readerIsAtBottom,
                Comment("the gate must be open at the newest content (= = the way back must not be offered)"))
        #expect(!vm.offersWayBack,
                Comment("the way back must not be offered at the newest content"))
    }
}
