// EditorChatNSController+Lifecycle.swift · Wenshu
//
// The controller's lifecycle (= the split's own view lifecycle).
//
// This file is one part of the editor's split container. The
// controller's declaration, its constants and its state live in
// `EditorChatNSController.swift`; the parts that live here are
// extensions of that class, and their bodies are the ones the
// controller had before the file was split.

import AppKit
import SwiftUI

extension EditorChatNSController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Apple HIG thin divider style (= the canonical Keynote
        // speaker-notes divider; = the Apple-standard 1 PT hairline;
        // = matches Pages / Numbers / Keynote).
        splitView.dividerStyle = .thin
        // Pure Apple HIG approach (= let NSSplitView + NSSplitViewItem
        // be transparent; = the chat column shows the window's single
        // root material).
        // Without this, NSVisualEffectView bleeds through (= the
        // gradient observed in the previous attempts).
        //
        // Apple HIG rationale (developer.apple.com/documentation/appkit/nssplitview):
        // NSSplitView by default paints a backgroundColor under both
        // panes (= the "behind the chrome" color). When set to
        // `.clear`, the SwiftUI-hosted content's own background
        // shows through (= no more gradient bleed).
        //
        // NSSplitView is an NSView subclass; = `wantsLayer` and the
        // layer's CGColor are how we make the split view composite
        // correctly with SwiftUI children above (= otherwise macOS
        // draws the content over the parent NSWindow's opaque bg and
        // the chat zone stays black regardless of SwiftUI's bg modifier).
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = NSColor.clear.cgColor
        // Switch the split view to vertical layout (= editor on top,
        // chat on bottom; = top-to-bottom stack). NSSplitView's
        // default `isVertical = true` produces a left-to-right
        // (= editor | chat) layout, but Keynote's speaker-notes
        // pattern (= and the previous SwiftUI VSplitView behavior)
        // is top-to-bottom (= editor above, chat below; = the
        // divider is horizontal). Setting `isVertical = false`
        // makes the divider horizontal (= the user drags the
        // horizontal divider up/down to resize the chat zone =
        // the canonical Keynote speaker-notes pattern).
        //
        // Apple HIG developer.apple.com/documentation/appkit/nssplitview:
        // 'If false, the split view is oriented horizontally
        // (= items are arranged top to bottom).'
        splitView.isVertical = false
        // Pure Apple HIG approach (= autosaveName + the built-in
        // UserDefaults persistence path):
        //   1. Wire autosaveName (= Apple HIG NSSplitView built-in
        //      autosave; = the user's drag-to-resize persists across
        //      relaunches via UserDefaults key
        //      'NSSplitView Subview Frames wenshu.editor.split.autosave').
        //   2. The first-launch 50:50 reset happens in viewDidAppear
        //      (= AFTER the view is in the window hierarchy; = the
        //      autosave path can write the position correctly).
        splitView.autosaveName = Self.autosaveName

        // Top pane (= editor).
        let editorRoot = EditorView()
            .applyOptionalEnvironment(appState: environment.appState, bookStore: environment.bookStore)
        let editorItem = NSSplitViewItem(viewController: NSHostingController(
            rootView: editorRoot
        ))
        editorItem.canCollapse = false // editor is always visible
        editorItem.minimumThickness = NSSplitViewItem.unspecifiedDimension
        editorItem.preferredThicknessFraction = 1.0 / 2.0
        // The NavigationSplitView owns horizontal bounds. This split owns
        // vertical thickness only; AppKit computes its automatic maximum
        // after the controller is attached to the split view.
        addSplitViewItem(editorItem)
        editorSplitItem = editorItem

        // Bottom pane (= chat zone).
        let chatViewController = NSHostingController(
            rootView: ChatZoneView(
                conductor: WenshuAppDelegate.sharedConductor
            )
            // ChatZoneView reads WenshuLibrary + BookStore via
            // @Environment to drive setCurrentBookID(_:) when the
            // user picks a different book (= wired off
            // workspaceUI.sidebarSelection mutations in ChatZoneView.body).
            // Without the env wrapper, the SwiftUI
            // @Environment(WenshuLibrary.self) +
            // @Environment(BookStore.self) wrappers crash with
            // 'No Observable object of type WenshuLibrary found' at
            // view construction time (= SwiftUI's @Environment(T.self)
            // is a hard fatalError when T is absent from the env chain).
            .applyOptionalEnvironment(
                appState: environment.appState,
                bookStore: environment.bookStore,
                library: environment.library
            )
        )
        let chatItemLocal = NSSplitViewItem(viewController: chatViewController)
        chatItemLocal.canCollapse = true // Keynote speaker-notes pattern
        chatItemLocal.minimumThickness = NSSplitViewItem.unspecifiedDimension
        chatItemLocal.preferredThicknessFraction = 1.0 / 2.0
        addSplitViewItem(chatItemLocal)
        chatItem = chatItemLocal
        chatSplitItem = chatItemLocal

        // First-launch divider = 50:50; subsequent launches =
        // persisted ratio (= Apple HIG NSSplitView autosave path
        // handles the persistence; = this block only runs on the
        // user's very first launch ever).
        //
        // Order matters: must run AFTER autosaveName is wired AND
        // AFTER addSplitViewItem has added both panes (= so the
        // divider index 0 (= the divider between editor and chat)
        // is valid for setPosition(ofDividerAt:)). setPosition
        // triggers autosave to write the value into UserDefaults
        // (= subsequent launches skip this block and read the
        // 50:50 value back via autosave).
    }

    /// First-launch flow: first launch UserDefaults has no autosave
    /// value for 'NSSplitView Subview Frames
    /// wenshu.editor.split.autosave'. viewDidAppear fires AFTER
    /// the view is in the window hierarchy AND splitView has
    /// valid bounds (= the setPosition() call below produces real
    /// coordinates).
    ///   1. The firstLaunchSetKey flag only tracks whether
    ///      viewDidAppear has fired the reset once for THIS bundle
    ///      (= if user dragged before we set 50:50, this prevents
    ///      us from overriding their drag). NOTE: this flag is
    ///      distinct from the previous persistent flag (= the
    ///      flag is reset on every relaunch = the 50:50 only
    ///      applies when no autosave value exists; = if user has
    ///      dragged even once, autosave wins).
    ///   2. User drags: NSSplitView writes the new position to
    ///      UserDefaults via autosaveName.
    ///   3. Subsequent launches: Apple autosave restores the
    ///      user's drag position (= viewDidAppear checks: if
    ///      autosave value exists, skip the 50:50 reset).
    override func viewDidAppear() {
        super.viewDidAppear()
        let defaults = UserDefaults.standard
        let hasAutosave = hasStoredPayload(for: Self.storedAutosaveName(for: arrangement))
        // First-launch path: no autosave value exists + flag not
        // set for this run. Apply the 50:50 reset (= the canonical
        // first-launch layout; = writes to autosave via setPosition).
        // Subsequent launches: hasAutosave = true; = the user's
        // drag position is restored by Apple before viewDidAppear
        // (= we don't touch it).
        if !hasAutosave, !defaults.bool(forKey: Self.firstLaunchSetKey) {
            applyFiftyFiftyFirstLaunch()
            defaults.set(true, forKey: Self.firstLaunchSetKey)
        }
    }

    /// In viewDidAppear, splitView.bounds.height isn't final yet
    /// (= macOS is still mid layout pass; = setPosition uses an
    /// off-by-N height). Move the actual setPosition to
    /// viewDidLayout, which fires once bounds are real (and any
    /// layout pass is done). Apple's canonical order is
    /// viewWillLayout -> layoutSubviews -> viewDidLayout; = the
    /// splitView now has its final height here.
    override func viewDidLayout() {
        super.viewDidLayout()
        // This callback reaches the split's structure only through the
        // width rule (= a request). Removing and re-inserting a split
        // view item here invalidates the split's constraints while
        // AppKit is laying out, and each invalidation re-arms the
        // window's "Update Constraints in Window" pass (= the pass
        // AppKit's runaway-layout guard counts).
        updateAutomaticThicknessBounds()
        if layoutMode == .automatic {
            applyAutomaticArrangement()
        }
        runPendingReset()
        let defaults = UserDefaults.standard
        let hasAutosave = hasStoredPayload(for: Self.storedAutosaveName(for: arrangement))
        if !hasAutosave, defaults.bool(forKey: Self.firstLaunchSetKey) {
            // We already tried to set 50:50 in viewDidAppear (=
            // the flag is set) but it didn't take (= bounds were
            // off). Retry now that bounds are final.
            applyFiftyFiftyFirstLaunch()
        } else if hasAutosave {
            applyStoredShare()
        }
    }

    /// Hold the divider at the user's own share of the axis, and
    /// tell AppKit that this is the share it should lay out for.
    ///
    /// Why this exists: the divider has to be positioned at the
    /// user's own share, because that is what makes the layout
    /// convergent. Both items carry `preferredThicknessFraction =
    /// 0.5`, so AppKit lays out for an even split, and the divider
    /// has to be put at that same even split (= 50:50), so the two
    /// agree on every pass and the layout settles.
    ///
    /// The 50:50 reset is what wiped the dragged position whenever
    /// the window was resized, and reading the stored payload with
    /// the API that sees AppKit's array (= `object(forKey:)`) is
    /// what stopped that wipe. But that same change stopped the
    /// assert as well, and with it the agreement went away: AppKit
    /// laid out for 50:50 while the restored divider sat at the
    /// user's position, the two disagreed on every pass, the split's
    /// own width oscillated between two values (= measured: 656 and
    /// 389, on alternate passes), the outer NavigationSplitView
    /// negotiated against a number that kept changing, the window's
    /// "Update Constraints in Window" pass count ran past its limit
    /// (= 322), and AppKit's runaway-layout guard aborted the app.
    ///
    /// So both sides are put on the USER's share: the items'
    /// preferred thickness fractions become that share, and the
    /// divider is positioned at it. The layout then converges on the
    /// user's position (= the drag survives).
    ///
    /// Why the divider is positioned ONCE and not on every layout
    /// pass: a write into the split during the layout pass re-arms
    /// the window's "Update Constraints in Window" pass (= the pass
    /// AppKit's runaway-layout guard counts), and a resize delivers a
    /// layout pass per frame (= a zoom animation's frames, = a
    /// widening drag's steps). Measured on the running app: the
    /// guard's count crossed the window's view count (= 327 against a
    /// limit of 321) during exactly those frames. AppKit scales the
    /// divider with the axis (= measured: a divider positioned once
    /// holds its share through a 40-step zoom and a 40-step
    /// narrowing), so the assert is needed once, not per frame.
    ///
    /// The share comes from the stored payload (= the user's drag),
    /// and the formula is the one measured against the running
    /// split: `setPosition(p)` sets PANE 0's thickness, and the
    /// share is pane 0's thickness over the two panes' thickness
    /// together.
    private func applyStoredShare() {
        if assertedShare == nil {
            assertedShare = storedShare(for: Self.storedAutosaveName(for: arrangement)) ?? 0.5
        }
        guard let share = assertedShare else { return }

        let items = splitViewItems
        guard items.count == 2 else { return }
        // The editor's share, expressed as the LEADING pane's share
        // (= the frames are in the panes' own order, and the chat
        // leads when they stand side by side).
        let editorLeads = arrangement == .stacked
        let leadingShare = editorLeads ? share : 1 - share
        // Write only when the value differs: a write into the split
        // during the layout pass re-arms the window's
        // update-constraints pass.
        if items[0].preferredThicknessFraction != leadingShare {
            items[0].preferredThicknessFraction = leadingShare
        }
        if items[1].preferredThicknessFraction != 1 - leadingShare {
            items[1].preferredThicknessFraction = 1 - leadingShare
        }

        let axis = arrangement.isVertical ? splitView.bounds.width : splitView.bounds.height
        guard axis > 0 else { return }

        // The LEADING pane's thickness in the frames the layout hands
        // out (= the previous pass's frames). The latch reads it
        // against the extent those frames were laid out for.
        let observedLeading = arrangement.isVertical
            ? items[0].viewController.view.frame.width
            : items[0].viewController.view.frame.height

        // The latch owns the state that spans passes (= the axis
        // extent, the settle count, the pending resize, the pending
        // write) and decides what this pass does with the divider.
        let action = dividerLatch.pass(
            axisExtent: axis,
            observedLeading: observedLeading,
            assertedShare: leadingShare
        )

        switch action {
        case .none:
            break
        case let .adopt(share):
            // The user dragged the divider. The drag is their own
            // position and it is adopted as the asserted share, so the
            // fractions follow it (= a write here is what eats the
            // drag).
            assertedShare = editorLeads ? share : 1 - share
        case let .assertAt(share):
            splitView.setPosition(axis * share, ofDividerAt: 0)
        }
    }
}
