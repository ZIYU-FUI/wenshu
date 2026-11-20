//
//  ScrollLayoutSettlementTests.swift
//  MarkdownEngineTests
//
//  The scroll tick must not re-layout the whole document. Every claim here is a
//  count of the layout fragments one settle visited — no clocks, no wall-clock
//  budgets — because the defect was a cost that grows with the document while
//  the frame budget does not.
//
//  Two halves, and the second is the reason the first is allowed:
//  - an EDIT still settles from the document head (a fragment's Y is the sum of
//    the heights above it, so an edit leaves the prefix untrustworthy, and a
//    viewport-scoped walk there caused content shifts and a bistable frame
//    height — see `ensureVisibleLayout`);
// - the ticks that follow an edit walk only the band they moved into, and a
//   jump that lands outside the settled band goes back to the head walk.
//

import AppKit
import SwiftUI
import Testing
@testable import MarkdownEngine

/// Prose plus fenced blocks, so the document has real block boundaries and the
/// code-block overlay has something to publish.
@MainActor
private func makeDoc(paragraphs: Int, codeBlockEvery: Int = 25) -> String {
    var out = ""
    for index in 0..<paragraphs {
        if codeBlockEvery > 0, index % codeBlockEvery == 0 {
            out += "```swift\nlet value\(index) = \(index)\n```\n\n"
        }
        out += "Paragraph \(index) " + String(repeating: "lorem ipsum dolor ", count: 8) + "\n\n"
    }
    return out
}

@MainActor
@Suite("Scroll-tick layout settlement")
struct ScrollLayoutSettlementTests {

    private static let viewportSize = NSSize(width: 700, height: 600)
    private static let paragraphs = 700

    /// Scroll view + container + text view, wired the way `makeNSView` wires
    /// them, with a coordinator holding a laid-out document.
    @MainActor
    private static func makeEditor(paragraphs: Int)
        -> (scrollView: ClampedScrollView, textView: NativeTextView, coordinator: NativeTextViewCoordinator)
    {
        let text = makeDoc(paragraphs: paragraphs)
        let scrollView = ClampedScrollView(frame: NSRect(origin: .zero, size: viewportSize))
        let textView = NativeTextView(frame: NSRect(origin: .zero, size: viewportSize))
        textView.configuration = .default
        textView.isEditable = true
        let container = NativeTextViewContainer(frame: NSRect(origin: .zero, size: viewportSize))
        container.textView = textView
        container.autoresizingMask = [.width]
        textView.frame = NSRect(x: 0, y: 0, width: viewportSize.width, height: 0)
        container.addSubview(textView)
        scrollView.documentView = container

        let coordinator = NativeTextViewCoordinator(
            text: .constant(text), fontName: "SF Pro Text", fontSize: 14,
            isWikiLinkActive: .constant(false), onLinkClick: nil, onInlineSelectionChange: nil
        )
        textView.delegate = coordinator
        coordinator.textView = textView
        // The overlay geometry reads through the bridge, which `makeNSView`
        // installs between the layout manager and the coordinator.
        if let tlm = textView.textLayoutManager {
            let bridge = LayoutBridge(tlm)
            coordinator.layoutBridge = bridge
            textView.layoutBridge = bridge
        }
        // Opening a document lays out and settles the whole thing (the wrapper's
        // `makeNSView` does the same with its init-time full-document layout).
        coordinator.rebuildTextStorageAndStyle(textView, from: text)
        coordinator.didEnsureLayoutForCurrentDocument = true
        let contentHeight = textView.measuredBaseContentHeight(minimumHeight: 16, forceFullLayout: true)
        textView.frame = NSRect(x: 0, y: 0, width: viewportSize.width, height: contentHeight)
        return (scrollView, textView, coordinator)
    }

    @MainActor
    private static func fragmentCount(_ textView: NativeTextView) -> Int {
        guard let tlm = textView.textLayoutManager else { return 0 }
        var count = 0
        tlm.enumerateTextLayoutFragments(from: tlm.documentRange.location, options: []) { _ in
            count += 1
            return true
        }
        return count
    }

    /// Move the viewport, the way a scroll tick's clip view does.
    @MainActor
    private static func scroll(_ scrollView: ClampedScrollView, to offsetY: CGFloat) {
        let clip = scrollView.contentView
        clip.scroll(to: NSPoint(x: 0, y: max(0, offsetY)))
        scrollView.reflectScrolledClipView(clip)
    }

    @MainActor
    private static func settle(_ textView: NativeTextView, fromHead: Bool) -> (head: Bool, visited: Int) {
        textView.ensureVisibleLayout(settlingFromDocumentHead: fromHead)
        let pass = textView.lastVisibleLayoutSettle
        return (pass?.fromDocumentHead ?? true, pass?.visitedFragments ?? -1)
    }

    /// Opening the document is the ONE full-document settle: with the whole
    /// layout claimed settled, a tick has nothing to walk at all.
    @Test func openDocumentClaimsTheWholeLayoutSettledSoATickWalksNothing() {
        let (scrollView, textView, _) = Self.makeEditor(paragraphs: Self.paragraphs)
        let total = Self.fragmentCount(textView)
        #expect(total > 200)   // a document long enough for the claim to mean something

        Self.scroll(scrollView, to: textView.frame.height - Self.viewportSize.height)
        textView.noteDocumentLayoutSettled()
        let pass = Self.settle(textView, fromHead: false)

        #expect(pass.visited == 0)
        #expect(pass.head == false)
    }

    /// An edit is not a tick. The restyle settles from the head and pays for the
    /// whole prefix, exactly as before this fix — the guarantee the engine
    /// documents (a fragment's Y is the sum of the heights above it). The band
    /// at the TOP of the document has no prefix, so this asks from the bottom,
    /// where the walk that used to run on every tick still has to run once.
    @Test func anEditStillSettlesTheWholePrefixFromTheHead() {
        let (scrollView, textView, _) = Self.makeEditor(paragraphs: Self.paragraphs)
        let total = Self.fragmentCount(textView)
        Self.scroll(scrollView, to: textView.frame.height - Self.viewportSize.height)

        let pass = Self.settle(textView, fromHead: true)

        #expect(pass.head == true)
        // From the head to the bottom of a document this size is the document.
        #expect(pass.visited > total / 2)
    }

    /// The WIRING, not the mechanism. `anEditStillSettlesTheWholePrefixFromTheHead`
    /// asks the method directly, so it would still pass if a caller flipped its
    /// argument. This one drives the production restyle call the editor makes on
    /// every edit, so flipping THAT is a red here.
    @Test func theRestyleCallerIsTheOneThatSettlesFromTheHead() {
        let (scrollView, textView, coordinator) = Self.makeEditor(paragraphs: Self.paragraphs)
        let total = Self.fragmentCount(textView)
        Self.scroll(scrollView, to: textView.frame.height - Self.viewportSize.height)

        let full = NSRange(location: 0, length: (textView.string as NSString).length)
        coordinator.restyleTextView(textView, paragraphCandidates: [full])
        let pass = textView.lastVisibleLayoutSettle

        #expect(pass?.fromDocumentHead == true)
        #expect((pass?.visitedFragments ?? 0) > total / 2)
    }

    /// THE POINT OF THE FIX: scroll a long document tick by tick and no tick
    /// walks the document. The band is ~20 fragments against ~2,000.
    @Test func scrollingAfterAnEditNeverWalksTheDocumentAgain() {
        let (scrollView, textView, _) = Self.makeEditor(paragraphs: Self.paragraphs)
        let total = Self.fragmentCount(textView)
        let contentHeight = textView.frame.height
        let visibleHeight = Self.viewportSize.height

        // The state a real scroll starts from: an edit settled the prefix at the
        // top, so the frontier is a Y inside the document rather than a claim
        // about the whole thing.
        Self.scroll(scrollView, to: 0)
        #expect(Self.settle(textView, fromHead: true).head == true)

        var headWalks = 0
        var worstTick = 0
        var offsetY = visibleHeight * 0.5
        while offsetY < contentHeight - visibleHeight {
            offsetY += visibleHeight * 0.1          // ~ one finger notch
            Self.scroll(scrollView, to: offsetY)
            let pass = Self.settle(textView, fromHead: false)
            if pass.head { headWalks += 1 }
            worstTick = max(worstTick, pass.visited)
        }

        #expect(headWalks == 0)
        // Each tick stayed inside its own band: the walk that used to run here
        // visited every fragment up to the visible bottom, i.e. up to `total`.
        #expect(worstTick * 8 < total)
    }

    /// The safety hatch. A viewport that starts above the settled band (a
    /// scrollbar drag, a find jump, a restored offset) cannot trust the
    /// fragments between them, so it goes back to the head walk.
    @Test func aJumpOutsideTheSettledBandFallsBackToTheHeadWalk() {
        let (scrollView, textView, _) = Self.makeEditor(paragraphs: Self.paragraphs)
        let total = Self.fragmentCount(textView)

        // Settle at the top, then claim only the top band is settled by walking
        // away from the open-document claim.
        Self.scroll(scrollView, to: 0)
        #expect(Self.settle(textView, fromHead: true).head == true)
        textView.settledLayoutFrontierY = Self.viewportSize.height   // only the top band

        Self.scroll(scrollView, to: textView.frame.height - Self.viewportSize.height)
        let pass = Self.settle(textView, fromHead: false)

        #expect(pass.head == true)
        #expect(pass.visited > total / 2)
    }

    /// The other half of the tick: the code-block overlay used to publish a
    /// freshly-built array on every call. Same output is not a change.
    @Test func identicalCodeBlockOverlayIsPublishedOnce() {
        let (scrollView, textView, coordinator) = Self.makeEditor(paragraphs: 120)
        Self.scroll(scrollView, to: 0)
        var published: [[CodeBlockSelection]] = []
        coordinator.onCodeBlockSelectionChange = { published.append($0) }

        // Warm the token cache the way a keystroke does, so the pass below is
        // the one that has blocks to place.
        coordinator.updateCodeBlockSelection(textView: textView,
                                             parsed: coordinator.parsedDocument(for: textView.string))
        let warmed = published.count
        #expect(warmed == 1)
        #expect(published.first?.isEmpty == false)
        coordinator.lastEmittedCodeBlockSelections = nil

        // The scroll tick's own call shape: no parse handed in, so the geometry
        // re-derives every time (the copy buttons have to follow the text).
        coordinator.updateCodeBlockSelection(textView: textView)
        let afterFirst = published.count
        #expect(afterFirst == warmed + 1)
        coordinator.updateCodeBlockSelection(textView: textView)
        #expect(published.count == afterFirst)

        // A moved viewport is a different answer, and it does get published.
        Self.scroll(scrollView, to: 240)
        coordinator.updateCodeBlockSelection(textView: textView)
        #expect(published.count == afterFirst + 1)
        #expect(published.last != published.first)
    }

    /// A document with no fenced block in it — the common one — takes the early
    /// exit on every tick, and that exit used to publish `[]` every time too.
    @Test func anEmptyOverlayIsPublishedOnceAcrossTicks() {
        let (scrollView, textView, coordinator) = Self.makeEditor(paragraphs: 60)
        Self.scroll(scrollView, to: 0)
        var published: [[CodeBlockSelection]] = []
        coordinator.onCodeBlockSelectionChange = { published.append($0) }

        for offset in stride(from: CGFloat(0), through: 600, by: 60) {
            Self.scroll(scrollView, to: offset)
            coordinator.updateCodeBlockSelection(textView: textView)
        }

        #expect(coordinator.cachedCodeBlockTokens.isEmpty)
        #expect(published.count == 1)
        #expect(published.first?.isEmpty == true)
    }
}
