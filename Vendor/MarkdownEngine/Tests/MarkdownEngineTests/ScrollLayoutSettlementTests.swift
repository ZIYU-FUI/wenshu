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
//  - the ticks that follow an edit walk only the band they moved into, and a
//    jump that lands outside the settled band goes back to the head walk.
//
//  And the claim itself has a life cycle, tested on both halves of it: a
//  mutation retires it even on the paths that never restyle (raw source mode,
//  a Writing-Tools proofread, a composition that posts no `textDidChange`), and
//  every site that moves text WITHOUT mutating it — two resizes, the clip-view
//  width observer, `updateNSView`'s inset and image-cache branches — drops it
//  explicitly, because a mutation stamp cannot see any of those.
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
    /// Past the end of any document this suite builds, so a tick that still
    /// believes the claim takes the zero-work return instead of walking.
    private static let sentinelFrontierY: CGFloat = 9_999_999

    /// Scroll view + container + text view, wired the way `makeNSView` wires
    /// them, with a coordinator holding a laid-out document.
    @MainActor
    private static func makeEditor(
        paragraphs: Int, rawSourceMode: Bool = false
    )
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
        coordinator.configuration.rawSourceMode = rawSourceMode
        textView.configuration.rawSourceMode = rawSourceMode
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

    /// A claim past the end of any document, armed over a band the case has just
    /// proven, so the only thing that can take it away is the site under test.
    /// Written through `settledLayoutFrontierY` (the accessor the sites use), and
    /// every case pairs it with a check that the storage generation did not move
    /// across the event — so the claim cannot have gone unreadable for a
    /// mutation's reason instead of a drop's.
    @MainActor
    private static func armUntouchableClaimOverAProvenBand(
        _ textView: NativeTextView, _ scrollView: ClampedScrollView, _ coordinator: NativeTextViewCoordinator
    ) {
        Self.scroll(scrollView, to: (textView.frame.height - viewportSize.height) / 2)
        #expect(Self.settle(textView, fromHead: true).head == true)
        #expect(textView.settledLayoutFrontierY != nil, "proving the band has to leave a claim behind")
        textView.settledLayoutFrontierY = sentinelFrontierY
    }

    /// Is the armed claim still readable, untouched?
    @MainActor
    private static func claimStillArmed(_ textView: NativeTextView) -> Bool {
        textView.settledLayoutFrontierY == sentinelFrontierY
    }

    /// The other half of a drop case, run after the case fired its event: the
    /// generation stamp has to be where it was (so a retired claim can only be a
    /// drop's doing), the armed claim has to be gone, and the tick scrolling into
    /// the bottom of the document as it stands NOW — a band nothing has proven,
    /// since the only claim in play was the sentinel or one the event's own ticks
    /// made around the middle — has to walk the document from its head. A retired
    /// claim makes it do that; a claim the site failed to retire covers the band,
    /// the tick does no layout work at all, and both numbers read the other way.
    /// `ticksOnScroll` is true in a hosted tree, where the clip view's own bounds
    /// observer is the tick; in the hand-wired tree the test is.
    @MainActor
    private static func expectDropAndRewalk(
        _ textView: NativeTextView, _ scrollView: ClampedScrollView, _ coordinator: NativeTextViewCoordinator,
        generation: UInt64, ticksOnScroll: Bool
    ) throws {
        #expect(coordinator.parseGeneration == generation,
                "the event mutated storage, so a claim it no longer reads is not proof of a drop")
        #expect(!Self.claimStillArmed(textView), "the site dropped the claim")
        Self.scroll(scrollView, to: max(0, textView.frame.height - viewportSize.height))
        if !ticksOnScroll { textView.ensureVisibleLayout(settlingFromDocumentHead: false) }
        let pass = try #require(
            textView.lastVisibleLayoutSettle,
            "the tick into the unproven band recorded no settle pass — the case would measure nothing"
        )
        #expect(pass.fromDocumentHead, "the first tick into an unproven band walks from the head")
        #expect(pass.visitedFragments > 1)
    }

    /// The wrapper's OWN view tree, hosted. Three of the invalidating sites live
    /// inside `makeNSView`'s clip-view observer and two inside `updateNSView`,
    /// and neither is reachable from a hand-wired view — an `NSHostingView` is
    /// what gives the representable the SwiftUI `Context` those methods need.
    @MainActor
    private static func hostEditor(
        configuration: MarkdownEditorConfiguration,
        paragraphs: Int,
        width: CGFloat
    ) throws -> (window: NSWindow, hosting: NSHostingView<NativeTextViewWrapper>,
                 scrollView: ClampedScrollView, textView: NativeTextView,
                 coordinator: NativeTextViewCoordinator) {
        _ = NSApplication.shared
        let size = NSSize(width: width, height: viewportSize.height)
        let hosting = NSHostingView(rootView: Self.hostedWrapper(configuration, paragraphs: paragraphs))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        let scrollView = try #require(Self.hostedScrollView(in: hosting) as? ClampedScrollView,
                                       "makeNSView did not build the editor view tree")
        let textView = try #require(scrollView.nativeTextView)
        let coordinator = try #require(textView.delegate as? NativeTextViewCoordinator)
        return (window, hosting, scrollView, textView, coordinator)
    }

    @MainActor
    private static func hostedWrapper(
        _ configuration: MarkdownEditorConfiguration, paragraphs: Int
    ) -> NativeTextViewWrapper {
        NativeTextViewWrapper(
            text: .constant(makeDoc(paragraphs: paragraphs)),
            configuration: configuration,
            fontName: "SF Pro Text",
            fontSize: 14
        )
    }

    /// Resize the host the way a window drag does: the clip view's width is what
    /// the wrap width follows.
    @MainActor
    private static func resize(_ hosting: NSHostingView<NativeTextViewWrapper>, width: CGFloat) {
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: width, height: viewportSize.height))
        hosting.layoutSubtreeIfNeeded()
    }

    /// Hand the same document to a new configuration — the pass `updateNSView`
    /// runs when an embedder changes a setting, where the inset and the
    /// image-cache sites live.
    @MainActor
    private static func reconfigure(
        _ hosting: NSHostingView<NativeTextViewWrapper>,
        configuration: MarkdownEditorConfiguration,
        paragraphs: Int
    ) {
        hosting.rootView = Self.hostedWrapper(configuration, paragraphs: paragraphs)
        hosting.layoutSubtreeIfNeeded()
    }

    @MainActor
    private static func hostedScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView, scroll.nativeTextView != nil { return scroll }
        for subview in view.subviews {
            if let found = Self.hostedScrollView(in: subview) { return found }
        }
        return nil
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
    /// whole prefix — exactly the guarantee the engine
    /// documents (a fragment's Y is the sum of the heights above it). The band
    /// at the TOP of the document has no prefix, so this asks from the bottom,
    /// where the head walk still has to run once: on an edit, not on a tick.
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
        // Each tick stayed inside its own band: a head walk here would cover
        // every fragment up to the visible bottom, i.e. up to `total`.
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

    /// The other half of the tick: the code-block overlay does not publish a
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
    /// exit on every tick, and that exit publishes `[]` once, not on each call.
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

    // MARK: - An edit that never restyles still retires the claim
    //
    // The tick is allowed to trust the claim because a mutation cannot leave one
    // standing. It cannot rest on "every mutation path ends in a restyle", and
    // it does not: raw source mode is a Settings toggle, and in it a keystroke
    // returns from `textDidChange` ("skip the restyle") and out of
    // `restyleTextView`; a Writing-Tools proofread returns even earlier; and a
    // composition posts no `textDidChange` at all. These three are the paths that
    // would strand a stale claim without the stamp, and they pin
    // the two halves of the rule separately: the drop on the paths that reach the
    // delegate, and the generation stamp on the ones that never do.

    /// Raw source mode, the reviewer's counter-example: after a keystroke the
    /// document is NOT proven settled any more. In styled mode the restyle
    /// re-proves it and this assertion would fail — which is the point: the
    /// claim's life cycle cannot depend on a restyle that this mode never runs.
    @Test func aRawModeKeystrokeRetiresTheClaimNothingRestyles() throws {
        let (scrollView, textView, coordinator) = Self.makeEditor(
            paragraphs: Self.paragraphs, rawSourceMode: true
        )
        let total = Self.fragmentCount(textView)
        Self.scroll(scrollView, to: textView.frame.height - Self.viewportSize.height)
        #expect(Self.settle(textView, fromHead: true).head == true)
        // The state the fix buys: inside a proven band a tick does no layout work.
        #expect(Self.settle(textView, fromHead: false).visited == 0)

        textView.insertText("x", replacementRange: NSRange(location: 40, length: 0))

        // The observable invariant, not which half of the fix bought it: after a
        // raw-mode keystroke nothing may still claim the document is settled. In
        // styled mode the restyle re-proves the prefix and this reads the other
        // way, which is the point — the claim's life cycle cannot depend on a
        // pass this mode never runs.
        #expect(textView.settledLayoutFrontierY == nil,
                "raw mode restyles nothing, so the claim has to be retired by the mutation itself")
        let after = Self.settle(textView, fromHead: false)
        #expect(after.head == true)
        #expect(after.visited > total / 2)
    }

    /// A composition mutates the storage and posts no `textDidChange` — the
    /// engine says so where it bumps the generation for it — so no drop can run.
    /// The stored proof is therefore STILL THERE, and only its stamp makes it
    /// unreadable: this is the half the delegate's drop cannot cover.
    @Test func aCompositionThatSkipsTextDidChangeIsRetiredByTheGenerationStamp() throws {
        let (scrollView, textView, coordinator) = Self.makeEditor(
            paragraphs: Self.paragraphs, rawSourceMode: true
        )
        Self.scroll(scrollView, to: textView.frame.height - Self.viewportSize.height)
        #expect(Self.settle(textView, fromHead: true).head == true)
        let provenY = try #require(textView.settledLayoutFrontierY)
        let generation = coordinator.parseGeneration

        textView.setSelectedRange(NSRange(location: 40, length: 0))
        textView.setMarkedText(
            "n",
            selectedRange: NSRange(location: 1, length: 0),
            replacementRange: NSRange(location: 40, length: 0)
        )

        #expect(coordinator.parseGeneration > generation, "the composition moved the storage generation")
        // The claim is not readable any more, and no drop can have erased it: a
        // composition posts no `textDidChange`, so the stamp is the only thing
        // here that retires it.
        #expect(provenY > 0)
        #expect(textView.settledLayoutFrontierY == nil, "the stale stamp is what retires the claim")
        #expect(Self.settle(textView, fromHead: false).head == true)
    }

    /// Writing Tools proofread: a batch that lands in the storage without a
    /// proposed edit never moves the generation either, and the delegate returns
    /// at its proofread exit before any restyle. The drop at the top of
    /// `textDidChange` is the half that catches it — asserted by the stored proof
    /// being GONE while the stamp has NOT moved, the mirror image of the case
    /// above.
    @Test func aWritingToolsProofreadBatchIsRetiredByTheDelegateDrop() throws {
        let (scrollView, textView, coordinator) = Self.makeEditor(paragraphs: Self.paragraphs)
        let total = Self.fragmentCount(textView)
        Self.scroll(scrollView, to: textView.frame.height - Self.viewportSize.height)
        #expect(Self.settle(textView, fromHead: true).head == true)
        let generation = coordinator.parseGeneration
        coordinator.isWritingToolsActive = true
        coordinator.wtDetectedMode = .proofread

        textView.textStorage?.replaceCharacters(in: NSRange(location: 40, length: 4), with: "XXXX")
        coordinator.textDidChange(
            Notification(name: NSText.didChangeNotification, object: textView)
        )

        #expect(coordinator.parseGeneration == generation,
                "nothing bumped the stamp, so the stamp cannot be what retired the claim")
        #expect(textView.settledLayoutFrontierY == nil, "the drop before the early returns is")
        let after = Self.settle(textView, fromHead: false)
        #expect(after.head == true)
        #expect(after.visited > total / 2)
    }

    // MARK: - The sites that drop the claim without any mutation
    //
    // A generation stamp cannot see an event that moves text without touching
    // storage, so five sites say it out loud: the managed resize and
    // `setFrameSize` (both re-wrap), the clip-view width observer `makeNSView`
    // installs, and `updateNSView`'s inset and image-cache branches. Each case
    // arms a claim nothing but its own site can retire and then ticks.

    /// `NativeTextView+FrameAndOverscroll.swift:278` — the width branch of
    /// `setFrameSize`, which is what the container's width propagation calls.
    @Test func aReWrapRetiresTheClaim() throws {
        let (scrollView, textView, coordinator) = Self.makeEditor(paragraphs: Self.paragraphs)
        Self.armUntouchableClaimOverAProvenBand(textView, scrollView, coordinator)
        let generation = coordinator.parseGeneration

        textView.setFrameSize(NSSize(width: 420, height: textView.frame.height))

        try Self.expectDropAndRewalk(textView, scrollView, coordinator,
                                     generation: generation, ticksOnScroll: false)
    }

    /// `NativeTextView+FrameAndOverscroll.swift:224` — the managed resize, whose
    /// width change re-wraps through `super.setFrameSize` and so never reaches
    /// the site above. Height-only growth must NOT retire the claim: it moves
    /// nothing above the viewport, and the case says so on the same view.
    @Test func aManagedResizeRetiresTheClaimAndItsHeightGrowthDoesNot() throws {
        let (scrollView, textView, coordinator) = Self.makeEditor(paragraphs: Self.paragraphs)
        Self.armUntouchableClaimOverAProvenBand(textView, scrollView, coordinator)
        let generation = coordinator.parseGeneration

        textView.applyManagedFrameSize(width: 420)

        try Self.expectDropAndRewalk(textView, scrollView, coordinator,
                                     generation: generation, ticksOnScroll: false)

        // The same call at the width it already has changes height only.
        let provenY = try #require(textView.settledLayoutFrontierY)
        textView.applyManagedFrameSize(width: textView.frame.width)
        #expect(textView.settledLayoutFrontierY == provenY,
                "a height-only resize moved nothing above the viewport")
    }

    /// `NativeTextViewWrapper.swift:358` — the clip-view width observer
    /// `makeNSView` installs. Driven in READING-COLUMN mode, where a narrower
    /// viewport recenters the fixed-width column instead of resizing the text
    /// view, so no re-wrap site runs and this observer is the only thing that can
    /// retire the claim.
    @Test func aViewportWidthChangeRetiresTheClaim() throws {
        var configuration = MarkdownEditorConfiguration.default
        configuration.readingWidth = 400
        configuration.rawSourceMode = true      // no restyle may re-prove behind our back
        let (window, hosting, scrollView, textView, coordinator) = try Self.hostEditor(
            configuration: configuration, paragraphs: 120, width: 800
        )
        defer { window.orderOut(nil) }
        Self.armUntouchableClaimOverAProvenBand(textView, scrollView, coordinator)
        let generation = coordinator.parseGeneration

        Self.resize(hosting, width: 520)

        try Self.expectDropAndRewalk(textView, scrollView, coordinator,
                                     generation: generation, ticksOnScroll: true)
    }

    /// `NativeTextViewWrapper.swift:548` — the inset branch of `updateNSView`.
    /// The inset comes off the wrap width and offsets the first line, so a
    /// changed inset moved everything above the viewport.
    @Test func aTextInsetChangeRetiresTheClaim() throws {
        var configuration = MarkdownEditorConfiguration.default
        configuration.rawSourceMode = true
        configuration.textInsets = TextInsets(horizontal: 6, vertical: 6)
        configuration.services.images = FingerprintedImages(version: 1)
        let (window, hosting, scrollView, textView, coordinator) = try Self.hostEditor(
            configuration: configuration, paragraphs: 120, width: 800
        )
        defer { window.orderOut(nil) }
        Self.armUntouchableClaimOverAProvenBand(textView, scrollView, coordinator)
        let generation = coordinator.parseGeneration

        var wider = configuration
        wider.textInsets = TextInsets(horizontal: 30, vertical: 12)
        Self.reconfigure(hosting, configuration: wider, paragraphs: 120)

        #expect(textView.textContainerInset.width == 30, "the update pass is the one that applies an inset")
        try Self.expectDropAndRewalk(textView, scrollView, coordinator,
                                     generation: generation, ticksOnScroll: true)
    }

    /// `NativeTextViewWrapper.swift:569` — the image-cache branch of
    /// `updateNSView`, which dirties the whole document's layout. Run in RAW mode
    /// on purpose: in styled mode the restyle that follows re-proves the prefix
    /// from the head anyway, and the site would be untestable — the concession
    /// this card's first version made and then forgot to cover.
    @Test func anImageArrivalRetiresTheClaim() throws {
        var configuration = MarkdownEditorConfiguration.default
        configuration.rawSourceMode = true
        configuration.services.images = FingerprintedImages(version: 1)
        let (window, hosting, scrollView, textView, coordinator) = try Self.hostEditor(
            configuration: configuration, paragraphs: 120, width: 800
        )
        defer { window.orderOut(nil) }
        Self.armUntouchableClaimOverAProvenBand(textView, scrollView, coordinator)
        let generation = coordinator.parseGeneration

        var landed = configuration
        landed.services.images = FingerprintedImages(version: 2)
        Self.reconfigure(hosting, configuration: landed, paragraphs: 120)

        try Self.expectDropAndRewalk(textView, scrollView, coordinator,
                                     generation: generation, ticksOnScroll: true)
    }
}

/// An image provider whose fingerprint a test can move, so `updateNSView`'s
/// image-cache branch fires on the next SwiftUI pass exactly the way an
/// embedder's cache filling in does.
private struct FingerprintedImages: EmbeddedImageProvider {
    let version: Int
    func image(for reference: EmbeddedImageRequest) -> NSImage? { nil }
    func fingerprint() -> AnyHashable { version }
}
