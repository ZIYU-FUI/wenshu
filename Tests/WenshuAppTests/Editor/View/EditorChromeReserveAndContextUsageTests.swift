//
//  EditorChromeReserveAndContextUsageTests.swift · Wenshu
//
//  Two facts about the editor's bottom chrome and the chat footer's
//  counter, each pinned where it was measured.
//
//  1. The document text and the status bar are one continuous surface.
//     The status bar's height is reserved once, by the `.safeAreaInset`
//     that hosts it. The editor's canvas adds no reserve of its own: the
//     engine's scroll view is an `NSScrollView` inside an
//     `NSViewRepresentable`, and SwiftUI shrinks a representable's frame
//     to the space a safe-area inset leaves over. The engine's frame
//     bottom edge therefore lands on the footer's top edge, so a document
//     scrolled to the very bottom shows its last line directly against
//     the status bar with no empty band between them.
//
//  2. The chat footer's token counter added the turns together. Each
//     turn's `usage.totalTokens` already reports the whole conversation
//     it was sent with, so the sum counted the history once per turn.
//     Four turns of a 1,000-token conversation reported 10,000 tokens of
//     context when the context was 1,000 — and the number is compared
//     against a CONTEXT-WINDOW limit, not a spend limit.
//
//  The geometry test measures the editor's real arrangement: the canvas
//  around the engine's scroll view, inside the status bar's safe-area
//  inset, hosted in a real window. The stand-in it replaces (a
//  `ScrollView { Color }`) did not describe the editor: a SwiftUI
//  `ScrollView` and an `NSViewRepresentable` do not take the same space
//  under a safe-area inset.
//
//

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Editor chrome reserve + chat context usage")
struct EditorChromeReserveAndContextUsageTests {

    // MARK: - The editor's bottom edge

    /// The engine's scroll view, standing in for the markdown engine's
    /// `NativeTextViewWrapper`: the engine's own `NSScrollView`, hosted
    /// in an `NSViewRepresentable`.
    @MainActor
    final class EngineScrollView: NSScrollView {
        override func draw(_ dirtyRect: NSRect) {
            NSColor.green.setFill()
            dirtyRect.fill()
        }
    }

    @MainActor
    struct EngineScrollProxy: NSViewRepresentable {
        typealias NSViewType = EngineScrollView

        func makeNSView(context: Context) -> EngineScrollView {
            let scroll = EngineScrollView()
            // A document taller than the frame, so the scroll view is a
            // real scrolling surface (= the editor's own shape).
            scroll.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 2_000))
            scroll.hasVerticalScroller = true
            return scroll
        }

        func updateNSView(_ nsView: EngineScrollView, context: Context) {}
    }

    /// A marker inside the footer's content, so the footer's own edges
    /// can be found in the rendered hierarchy.
    @MainActor
    final class FooterMarkerView: NSView {
        override func draw(_ dirtyRect: NSRect) {
            NSColor.red.setFill()
            dirtyRect.fill()
        }
    }

    @MainActor
    struct FooterMarker: NSViewRepresentable {
        typealias NSViewType = FooterMarkerView

        func makeNSView(context: Context) -> FooterMarkerView {
            FooterMarkerView()
        }

        func updateNSView(_ nsView: FooterMarkerView, context: Context) {}
    }

    @MainActor
    private func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let hit = view as? T { return hit }
        for sub in view.subviews {
            if let hit = find(type, in: sub) { return hit }
        }
        return nil
    }

    /// The editor's real arrangement, rendered and measured: the canvas
    /// around the engine's scroll view, with the status bar in a bottom
    /// safe-area inset.
    ///
    /// Every edge comes back in ONE space: points measured DOWN from the
    /// host's top edge. The host may or may not flip its own
    /// coordinates, so the rects are converted into that space first —
    /// otherwise the two edges would be measured in different
    /// directions and could not be compared.
    @MainActor
    private func measureEditorBottomEdge() -> (
        engineBottom: CGFloat,
        footerTop: CGFloat,
        columnHeight: CGFloat
    )? {
        let root = ZStack {
            EditorPaperCanvas {
                EngineScrollProxy()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChromeBottomFooter {
                FooterMarker()
                    .frame(height: 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        host.layoutSubtreeIfNeeded()

        guard let engine = find(EngineScrollView.self, in: host),
              let marker = find(FooterMarkerView.self, in: host),
              let engineParent = engine.superview
        else {
            window.orderOut(nil)
            return nil
        }

        let columnHeight = host.bounds.height

        // The engine's FRAME (= the box SwiftUI handed it), not its
        // bounds (= which carries the scrolled content offset).
        let engineRect = engineParent.convert(engine.frame, to: host)
        let markerRect = marker.convert(marker.bounds, to: host)

        // Convert into the one space: points down from the host's top.
        let down: (CGRect) -> CGRect = { rect in
            guard !host.isFlipped else { return rect }
            return CGRect(
                x: rect.minX,
                y: columnHeight - rect.maxY,
                width: rect.width,
                height: rect.height
            )
        }
        let engineDown = down(engineRect)
        let markerDown = down(markerRect)

        // The footer is `VStack(spacing: 0) { Divider; content }` with
        // the content padded 8 PT above and below: the divider's top
        // edge (= the footer's top edge) is 9 PT above the content's
        // top edge.
        let footerTop = markerDown.minY - 9
        let engineBottom = engineDown.maxY

        window.orderOut(nil)
        return (engineBottom, footerTop, columnHeight)
    }

    /// The footer's own rendered height, measured by rendering the
    /// component itself.
    @MainActor
    private func measureFooterHeight() -> CGFloat {
        let footer = ChromeBottomFooter {
            FooterMarker()
                .frame(height: 15)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        let host = NSHostingView(rootView: footer)
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 200)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()
        let height = ceil(host.fittingSize.height)
        window.orderOut(nil)
        return height
    }

    @Test("The editor's document ends at the status bar's top edge")
    @MainActor
    func theDocumentEndsAtTheStatusBar() throws {
        let measured = measureEditorBottomEdge()
        #expect(measured != nil, "The editor's arrangement did not render its engine view or the footer.")
        guard let measured else { return }
        let band = measured.footerTop - measured.engineBottom
        #expect(
            abs(band) <= 1,
            """
            The engine's frame bottom edge sits at \(measured.engineBottom) PT while \
            the footer's top edge is at \(measured.footerTop) PT: \(band) PT of \
            background sits between the document's last line and the status bar.
            """
        )
    }

    @Test("The status bar's space is reserved once, by the safe-area inset")
    @MainActor
    func theStatusBarSpaceIsReservedOnce() throws {
        let measured = measureEditorBottomEdge()
        #expect(measured != nil, "The editor's arrangement did not render its engine view or the footer.")
        guard let measured else { return }
        let footerHeight = measureFooterHeight()
        let reserved = measured.columnHeight - measured.engineBottom
        #expect(
            abs(reserved - footerHeight) <= 1,
            """
            The safe-area inset left \(reserved) PT below the document's clip edge \
            while the footer's own rendered height is \(footerHeight) PT: the space \
            is reserved a different number of times than the footer occupies.
            """
        )
    }

    // MARK: - The chat footer's token counter

    /// The number the chat footer shows for a conversation.
    private func contextUsage(for messages: [ChatMessage]) -> Int {
        messages.last(where: { ($0.tokens ?? 0) > 0 })?.tokens ?? 0
    }

    private func agentMessage(tokens: Int) -> ChatMessage {
        ChatMessage(role: .agent, source: .wenshu, content: "reply", tokens: tokens)
    }

    @Test("The counter reports the conversation's context, not the sum of the turns")
    func counterReportsContextNotTheSum() throws {
        // Each turn's count is the provider's report for that request,
        // and its input side is the whole conversation so far.
        let messages = [
            agentMessage(tokens: 1_000),
            agentMessage(tokens: 1_100),
            agentMessage(tokens: 1_250),
            agentMessage(tokens: 1_400),
        ]
        #expect(
            contextUsage(for: messages) == 1_400,
            """
            The counter reported \(contextUsage(for: messages)) tokens. The \
            conversation's context is the LATEST turn's count (1,400); the \
            turns sum to 4,750, which counts the history once per turn.
            """
        )
    }

    @Test("The counter does not grow when a turn is added to a conversation")
    func counterDoesNotDoubleCount() throws {
        // The failure this guards against is quadratic: every new turn
        // re-adding the whole history to the number.
        var messages: [ChatMessage] = []
        var previous = 0
        for turn in 1...5 {
            let report = turn * 100
            messages.append(agentMessage(tokens: report))
            let current = contextUsage(for: messages)
            #expect(
                current == report,
                "Turn \(turn): the counter reported \(current) instead of the turn's own \(report)."
            )
            #expect(
                current >= previous,
                "The counter went backwards between turns (\(previous) then \(current))."
            )
            previous = current
        }
    }

    @Test("The counter is zero for a conversation with no reported usage")
    func counterIsZeroWithoutUsage() throws {
        #expect(contextUsage(for: []) == 0)
        #expect(contextUsage(for: [ChatMessage(role: .user, source: .user, content: "hi")]) == 0)
        #expect(contextUsage(for: [agentMessage(tokens: 0)]) == 0)
    }

    @Test("The counter's label states that it is the context usage")
    func counterLabelStatesItsScope() throws {
        // The number is compared against a context-window limit, so the
        // label must not read as a cumulative spend.
        let url = SourceLocator.url("Sources/WenshuApp/Resources/Localizable.xcstrings")
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(
            !raw.contains("已使用 %d tokens"),
            """
            The chat footer's label still reads "已使用 %d tokens" (= tokens \
            used), which reads as a cumulative spend. The number is the \
            conversation's context usage.
            """
        )
        #expect(
            raw.contains("上下文 %d tokens"),
            "The chat footer's label must say that the number is the context usage."
        )
    }
}
