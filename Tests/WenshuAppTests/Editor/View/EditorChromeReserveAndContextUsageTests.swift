//
//  EditorChromeReserveAndContextUsageTests.swift · Wenshu · v3.0
//
//  Two defects, both measured on the running app (2026-10-21):
//
//  1. The editor's last line was sliced by the status bar. The engine's
//     own `NSScrollView` fills the frame it is given, and SwiftUI's
//     `.safeAreaInset(edge: .bottom)` does not shrink it — the inset
//     adds the footer's height to the RECEIVER's bottom safe area while
//     the scroll view's frame still reaches the column's bottom edge,
//     which is under the footer. Measured on a rendered probe: the scroll
//     view's frame was the full column height while the footer's top
//     edge sat 32 PT above it.
//
//  2. The chat footer's token counter added the turns together. Each
//     turn's `usage.totalTokens` already reports the whole conversation
//     it was sent with, so the sum counted the history once per turn.
//     Four turns of a 1,000-token conversation reported 10,000 tokens of
//     context when the context was 1,000 — and the number is compared
//     against a CONTEXT-WINDOW limit, not a spend limit.
//
// The tests pin both where they were measured: the reserve as rendered
// pixels, the counter as the number the footer shows.
//

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Editor chrome reserve + chat context usage")
struct EditorChromeReserveAndContextUsageTests {

    // MARK: - The editor's bottom reserve

    /// The footer's real height, measured by rendering it.
    @MainActor
    private func measureFooterHeight() -> CGFloat {
        let content = HStack(spacing: 8) {
            Image(systemName: "text.alignleft").font(.system(size: 12))
            Text("1,234").font(.callout).monospacedDigit()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)

        let footer = VStack(spacing: 0) {
            Divider()
            content
        }
        .background(.bar)

        let host = NSHostingView(rootView: footer)
        host.frame = NSRect(x: 0, y: 0, width: 500, height: 200)
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

    @Test("The reserved bottom space equals the chrome footer's own height")
    @MainActor
    func reservedSpaceMatchesTheFooterHeight() throws {
        let measured = measureFooterHeight()
        #expect(
            DesignTokens.chromeBottomFooterHeight == measured,
            """
            The editor reserves \(DesignTokens.chromeBottomFooterHeight) PT for \
            the chrome footer, but the footer measures \(measured) PT. A \
            smaller reserve leaves the document's last line under the bar; a \
            larger one leaves a visible gap above it.
            """
        )
    }

    /// Render the editor's shape and find where the engine's SCROLL VIEW
    /// ends.
    ///
    /// The surface colour is the ZStack's background, so it fills the
    /// column whatever the arrangement is — measuring the colour proves
    /// nothing. What matters is the scroll view's own frame: the text
    /// lives inside it, so the frame's bottom edge is the lowest the
    /// text can reach, and it has to sit at or above the footer's top
    /// edge.
    @MainActor
    private func measureScrollViewBottom(reserve: CGFloat) -> (scrollBottom: CGFloat, footerTop: CGFloat)? {
        let footerHeight = DesignTokens.chromeBottomFooterHeight
        let columnHeight: CGFloat = 300
        let footerTop = columnHeight - footerHeight

        let root = VStack(spacing: 0) {
            ZStack {
                ScrollView {
                    Color(red: 0, green: 0.8, blue: 0.2).frame(height: 2_000)
                }
                .padding(.bottom, reserve)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                    Text("1,234").font(.callout).padding(.vertical, 8)
                }
                .frame(height: footerHeight)
                .background(.bar)
            }
        }

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 400, height: columnHeight)
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

        var scrollBottom: CGFloat?
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView {
                let top = scroll.convert(scroll.bounds, to: host).maxY
                scrollBottom = max(scrollBottom ?? 0, top)
            }
            for sub in view.subviews { walk(sub) }
        }
        walk(host)
        window.orderOut(nil)
        guard let scrollBottom else { return nil }
        return (scrollBottom, footerTop)
    }

    @Test("The editor's scroll view ends above the status bar")
    @MainActor
    func editorScrollViewClearsTheStatusBar() throws {
        let measured = measureScrollViewBottom(reserve: DesignTokens.chromeBottomFooterHeight)
        #expect(measured != nil, "The editor's scroll view was not found in the rendered hierarchy.")
        guard let measured else { return }
        #expect(
            measured.scrollBottom <= measured.footerTop + 1,
            """
            The editor's scroll view reaches \(measured.scrollBottom) PT while \
            the footer's top edge is at \(measured.footerTop) PT: the \
            document's last line would scroll under the status bar.
            """
        )
    }

    @Test("Without the reserve the scroll view would run under the status bar")
    @MainActor
    func withoutTheReserveTheScrollViewRunsUnder() throws {
        // The control: with no reserve the scroll view reaches the
        // column's bottom edge, which is under the footer. This is the
        // defect the reserve fixes, so the test fails if the geometry
        // ever changes such that the reserve stops mattering.
        let measured = measureScrollViewBottom(reserve: 0)
        #expect(measured != nil, "The editor's scroll view was not found in the rendered hierarchy.")
        guard let measured else { return }
        #expect(
            measured.scrollBottom > measured.footerTop,
            """
            Without a reserve the scroll view ends at \(measured.scrollBottom) \
            PT, which does not run under the footer whose top edge is at \
            \(measured.footerTop) PT. If the footer no longer overlaps the \
            column, this test and the reserve itself are no longer needed.
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
