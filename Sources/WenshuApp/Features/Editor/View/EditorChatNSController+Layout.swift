// EditorChatNSController+Layout.swift · Wenshu
//
// The layout (= the arrangement, the transition, the chat zone).
//
// This file is one part of the editor's split container. The
// controller's declaration, its constants and its state live in
// `EditorChatNSController.swift`; the parts that live here are
// extensions of that class, and their bodies are the ones the
// controller had before the file was split.

import AppKit
import os
import SwiftUI

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "editorchatnscontroller")

extension EditorChatNSController {
    /// The SwiftUI side's entry point: the mode the user picked
    /// in the View menu. The two manual cases pin the
    /// arrangement; the automatic case hands the decision to the
    /// width rule.
    func applyLayoutMode(_ mode: EditorLayoutMode) {
        layoutMode = mode
        switch mode {
        case .stacked:
            requestArrangement(.stacked)
        case .sideBySide:
            requestArrangement(.sideBySide)
        case .automatic:
            applyAutomaticArrangement()
        }
    }

    /// The arrangement a width and a share ask for. Pure (= no
    /// window and no split view): the automatic case follows the
    /// numbers, and the two manual cases pin the arrangement.
    ///
    /// The automatic case resolves to a DEFINITE arrangement at
    /// every width and every share. The old rule kept the current
    /// arrangement for the band between its two thresholds, and a
    /// band that keeps the current value is a band that never
    /// resolves: the window could be dragged narrower and narrower
    /// and the arrangement stayed whatever it had been.
    ///
    /// The width is the width the two columns really compete for,
    /// and the share is the editor's share of it (= the divider's
    /// position). Both are needed, because the panes' negotiated
    /// thicknesses are the width times the shares: a wide split
    /// with the editor on a tenth of it gives the editor a tenth of
    /// the width, and a rule that only looked at the total would
    /// call that viable.
    ///
    /// The rule asks whether each pane's negotiated thickness can
    /// hold that pane's own chrome. When it cannot, side by side is
    /// not a viable arrangement at that width and the rule resolves
    /// to stacked (= the chrome is the point; = it is never hidden
    /// to make room).
    static func arrangement(
        forCompetingWidth width: CGFloat,
        editorShare: CGFloat,
        mode: EditorLayoutMode
    ) -> EditorArrangement {
        switch mode {
        case .stacked:
            return .stacked
        case .sideBySide:
            return .sideBySide
        case .automatic:
            return holdsChrome(width: width, editorShare: editorShare)
                ? .sideBySide
                : .stacked
        }
    }

    /// Whether a width and a share can host BOTH panes' own chrome.
    ///
    /// The panes' negotiated thicknesses are the width times their
    /// shares, so a width alone cannot answer the question: a wide
    /// split with the editor on a tenth of it gives the editor a
    /// tenth of the width, and the editor's chrome does not fit
    /// there. The chrome is the point (= it is never hidden to make
    /// room), so an arrangement that cannot hold it is not viable.
    static func holdsChrome(width: CGFloat, editorShare: CGFloat) -> Bool {
        width * editorShare >= editorPaneMinimumWidth
            && width * (1 - editorShare) >= chatPaneMinimumWidth
    }

    /// Whether a width can host BOTH panes' own chrome when the
    /// panes are STACKED.
    ///
    /// Stacked, the divider runs ACROSS the split, so the height
    /// carries the arrangement and each pane is as wide as the whole
    /// split. The chrome test is therefore the width itself: the
    /// stored height share says nothing about it (feeding that share
    /// into a width test was the bug: it asked whether
    /// `width x heightShare` held the chrome, which is a category
    /// error, and it was false for EVERY stored share at the
    /// screenshot's width, so the 50:50 reset was owed on every
    /// entry into stacked).
    static func holdsStackedChrome(width: CGFloat) -> Bool {
        width >= editorChromeMinimumWidth && width >= chatChromeMinimumWidth
    }

    /// The automatic rule: the arrangement follows the width the
    /// two columns compete for and the editor's share of it (= side
    /// by side when both panes can hold their own chrome; = stacked
    /// when one of them cannot).
    ///
    /// The width is the PARENT's own number (= the width SwiftUI
    /// proposed for this controller), not the split view's own
    /// bounds. The split's own width is the number the split
    /// recomputes as it lays itself out, so it is a
    /// mid-negotiation number: the layout pass reads it while the
    /// parent is still negotiating the width the split is given,
    /// and the value that is read is the one the split would have
    /// liked. The parent's proposal is the number the parent
    /// itself allocates to the split, and it is already net of the
    /// outer NavigationSplitView's columns and of the inspector,
    /// so it is the space the two columns really compete for.
    ///
    /// It runs inside the layout callback, so it only REQUESTS the
    /// arrangement; the structural change runs on the next runloop
    /// turn.
    func applyAutomaticArrangement() {
        guard let width = lastParentWidth, width > 0 else { return }
        requestArrangement(
            Self.arrangement(
                forCompetingWidth: width,
                editorShare: assertedSideBySideEditorShare(),
                mode: layoutMode
            )
        )
    }

    /// Ask for an arrangement and queue its structural change.
    ///
    /// Why the queue: removing a split view item invalidates the
    /// split's constraints, and doing that while AppKit is laying
    /// out re-arms the window's "Update Constraints in Window" pass.
    /// Deferring to the next runloop turn lets the layout pass
    /// finish before the panes move.
    private func requestArrangement(_ target: EditorArrangement) {
        guard target != arrangement else { return }
        guard !arrangementApplyScheduled else { return }
        arrangementApplyScheduled = true
        Task { @MainActor [weak self] in
            self?.applyRequestedArrangement()
        }
    }

    /// Apply the arrangement the width rule asks for, outside the
    /// layout pass.
    ///
    /// The width is read again here: the window may have moved while
    /// the request waited for the runloop turn, and a request the
    /// width no longer supports is dropped (= no structural change
    /// at all).
    private func applyRequestedArrangement() {
        arrangementApplyScheduled = false
        let target: EditorArrangement
        switch layoutMode {
        case .stacked:
            target = .stacked
        case .sideBySide:
            target = .sideBySide
        case .automatic:
            // The width is read again here (= the parent's own
            // number), because the window may have moved while the
            // request waited for the runloop turn, and a request
            // the width no longer supports is dropped (= no
            // structural change at all).
            guard let width = lastParentWidth, width > 0 else { return }
            target = Self.arrangement(
                forCompetingWidth: width,
                editorShare: assertedSideBySideEditorShare(),
                mode: .automatic
            )
        }
        guard target != arrangement else { return }
        transition(to: target)
        wenshuLogger.debug("[wenshu.editorChat] arrangement applied: \(String(describing: target))")
    }

    /// Move the split to an arrangement. The autosave name
    /// follows the arrangement (= each arrangement keeps its own
    /// divider position), the panes follow the arrangement's own
    /// order (= the chat is on the left when the panes stand side
    /// by side), and the 50:50 reset is owed on the next layout
    /// pass when the arrangement being entered has no stored
    /// payload of its own.
    private func transition(to target: EditorArrangement) {
        guard target != arrangement else { return }
        let enteringName = Self.storedAutosaveName(for: target)
        let keepsOwnPosition = keepsStoredPosition(for: target)
        arrangement = target
        assertedShare = nil
        // The axis changed (= the arrangement's own axis: the width
        // when the panes stand side by side, the height when they are
        // stacked), so the divider has to be positioned again on the
        // new axis, and the extent the layout is measured against has
        // to be read fresh (= the old extent is in the old axis's
        // units).
        dividerLatch.reset()
        splitView.isVertical = target.isVertical
        splitView.autosaveName = enteringName
        applyPaneOrder(for: target)
        pendingResetArrangement = keepsOwnPosition ? nil : target
    }

    /// Put the panes in the arrangement's own order.
    ///
    /// Why the order differs per arrangement: the chat zone is on
    /// the LEFT when the panes stand side by side (= the chat is
    /// the companion of the editor, not its continuation), and the
    /// editor stays on TOP when they are stacked (= the Keynote
    /// speaker-notes pattern, = the editor above and the chat
    /// below).
    ///
    /// The order is the ONLY lever AppKit offers here: setting an
    /// added item's `viewController` raises "Cannot remove a
    /// SplitViewItem's viewController if it is currently in a
    /// SplitViewController" (= measured), so the panes are moved by
    /// removing the item and re-inserting it at the other index.
    /// (= measured: the reorder takes effect, the divider keeps
    /// working afterwards, and the layout converges over repeated
    /// passes.)
    ///
    /// The stored frames follow the items (= AppKit writes the
    /// payload in the panes' own order), so each arrangement's
    /// payload is read with that arrangement's order.
    private func applyPaneOrder(for target: EditorArrangement) {
        let editorItem = editorSplitItem
        let chatItem = chatSplitItem
        guard let editorItem, let chatItem else { return }

        let editorIndex = splitViewItems.firstIndex(of: editorItem)
        let chatIndex = splitViewItems.firstIndex(of: chatItem)
        guard let editorIndex, let chatIndex, editorIndex != chatIndex else { return }

        // The order the arrangement wants: the editor first when
        // stacked (= the editor on top), the chat first when side by
        // side (= the chat on the left).
        let editorShouldLead = target == .stacked
        let editorLeads = editorIndex < chatIndex
        guard editorShouldLead != editorLeads else { return }

        removeSplitViewItem(editorItem)
        insertSplitViewItem(editorItem, at: editorShouldLead ? 0 : 1)
    }

    /// Apply the 50:50 reset owed by an arrangement change. It
    /// runs on the next layout pass (= the bounds are final by
    /// then) and only for an arrangement that had no stored
    /// payload of its own.
    ///
    /// Why the reset also OWNS the asserted share: the re-assert
    /// runs after this and writes the divider's position on every
    /// layout pass, so a reset whose share the re-assert does not
    /// agree with is overwritten in the same pass (= the reset would
    /// be a write that nothing can see). Claiming the share here
    /// makes the two agree: the reset puts the divider at the
    /// middle and the re-assert holds it there.
    func runPendingReset() {
        guard let pending = pendingResetArrangement else { return }
        pendingResetArrangement = nil
        assertedShare = 0.5
        applyFiftyFiftyReset(for: pending)
    }

    /// The autosave name that holds an arrangement's divider
    /// position. One name per arrangement.
    static func storedAutosaveName(for arrangement: EditorArrangement) -> String {
        switch arrangement {
        case .stacked: return autosaveName
        case .sideBySide: return sideAutosaveName
        }
    }

    /// Whether an arrangement has a stored divider position.
    /// AppKit stores it under "NSSplitView Subview Frames
    /// <name>" as an ARRAY of strings, so the read that sees the
    /// array is `object(forKey:)`; `data(forKey:)` is always nil
    /// for an array (= the first-launch check used it, = so the
    /// 50:50 reset re-applied on every layout pass and wiped the
    /// user's dragged position).
    func hasStoredPayload(for name: String) -> Bool {
        UserDefaults.standard.object(forKey: "NSSplitView Subview Frames \(name)") != nil
    }

    /// Re-assert Apple automatic bounds after the split view has a
    /// window-backed size. `automaticMaximumThickness` is meaningful only
    /// after attachment; reading it during `viewDidLoad` produced an invalid
    /// hard maximum and let the hosting column collapse.
    ///
    /// The clamp follows the arrangement's own axis: the height
    /// carries the split when stacked, the width carries it when
    /// side by side (= a height clamp in the side-by-side
    /// arrangement pinned both columns to the height and left a
    /// dead gap beside the column).
    func updateAutomaticThicknessBounds() {
        let extent = arrangement.isVertical ? splitView.bounds.width : splitView.bounds.height
        // The cap is written in QUANTA, rounded UP.
        //
        // Why: the cap (= the split's own extent) stops a pane from
        // claiming more than the axis carries, and the extent changes
        // on every frame of a resize (= a zoom's frames, = a widening
        // drag's steps). Writing the live extent on every one of those
        // frames re-arms the window's update-constraints pass once per
        // frame (= the pass AppKit's runaway-layout guard counts).
        //
        // Why rounded UP: the cap must never sit below the extent, or
        // it would clamp a pane the layout has legitimately grown. A
        // cap ABOVE the extent is harmless (= the axis itself is the
        // bound) and it is what lets the write happen once per quantum
        // instead of once per frame.
        let available = (extent / Self.thicknessQuantum).rounded(.up) * Self.thicknessQuantum
        guard available > 0 else { return }
        for item in splitViewItems {
            // Write only when the value differs: a write into the
            // split during the layout pass re-arms the window's
            // update-constraints pass.
            if item.minimumThickness != 0 {
                item.minimumThickness = 0
            }
            if item.maximumThickness != available {
                item.maximumThickness = available
            }
        }
    }

    /// Do the actual 50:50 setPosition (split out so both
    /// viewDidAppear and viewDidLayout can call it).
    func applyFiftyFiftyFirstLaunch() {
        applyFiftyFiftyReset(for: arrangement)
    }

    /// The 50:50 reset along the arrangement's own axis: the
    /// divider is horizontal when stacked (= the height carries
    /// the split) and vertical when side by side (= the width
    /// carries it).
    private func applyFiftyFiftyReset(for arrangement: EditorArrangement) {
        switch arrangement {
        case .stacked:
            let dividerY = splitView.bounds.height / 2
            splitView.setPosition(dividerY, ofDividerAt: 0)
        case .sideBySide:
            let dividerX = splitView.bounds.width / 2
            splitView.setPosition(dividerX, ofDividerAt: 0)
        }
    }

    /// Programmatic toggle (= called from the menu bar View >
    /// Show/Hide Chat Zone item). Uses `animator()` so the collapse
    /// / expand animates per NSSplitView's standard animation.
    /// This is the canonical Apple HIG Keynote speaker-notes API.
    func toggleChatZone() {
        // dual-axis followup: added NSLog when
        // chatItem is nil (= was a silent no-op before; = the menu
        // can fire before viewDidLoad runs in a cold launch race;
        // = logging makes the misfire visible for diagnostics
        // without changing the no-op behavior).
        guard let item = chatItem else {
            wenshuLogger.info("[wenshu.editorChat] toggleChatZone called before viewDidLoad set chatItem (cold-launch race); ignoring")
            return
        }
        item.animator().isCollapsed.toggle()
    }

    /// Query helper for menu state (= show checkmark when chat zone
    /// is currently visible).
    var isChatZoneVisible: Bool {
        chatItem.map { !$0.isCollapsed } ?? true
    }

    /// The width the parent allocated last.
    var lastParentWidth: CGFloat? {
        lastParentProposal?.width
    }

    /// The height the parent allocated last.
    var lastParentHeight: CGFloat? {
        lastParentProposal?.height
    }

    /// A dimension the parent ALLOCATED (= a real, finite, positive
    /// number).
    ///
    /// SwiftUI's proposal stream carries three kinds of number and
    /// only one of them is an allocation: 0 (= the ideal-size pass,
    /// the parent asking "how big would you like to be?"), infinity
    /// (= the unbounded pass), and a real width (= the parent saying
    /// "this is what I am giving you"). Measured 2026-10-27 with a
    /// headless probe of this app's own shape: every layout pass
    /// proposes 0, then infinity, then sometimes nothing, then the
    /// real allocation (= 740 PT at the screenshot's width), and that
    /// cycle repeats for the life of the window.
    ///
    /// So the degenerate passes are the parent's ASKING, not its
    /// allocating, and a layout decision must not read them as an
    /// allocation: infinity compares greater than every number, so a
    /// rule that read it judged every width viable and never resolved
    /// to stacked.
    static func allocatedDimension(_ proposed: CGFloat?) -> CGFloat? {
        guard let proposed, proposed.isFinite, proposed > 0 else { return nil }
        return proposed
    }

    /// Record the size the parent proposes, so a later proposal that
    /// omits a dimension can fall back to the parent's own last
    /// number for it.
    ///
    /// Only a real allocation is recorded (= a finite, positive
    /// number); the degenerate passes leave the previous allocation in
    /// place. Measured 2026-10-27: with the degenerate passes merged
    /// in, the recorded width ended at infinity and the width rule
    /// read infinity (= every width looked viable, so the layout
    /// never returned to stacked).
    func recordParentProposal(_ proposal: ProposedViewSize) {
        var merged = lastParentProposal ?? ProposedViewSize(width: nil, height: nil)
        if let width = Self.allocatedDimension(proposal.width) {
            merged.width = width
        }
        if let height = Self.allocatedDimension(proposal.height) {
            merged.height = height
        }
        lastParentProposal = merged
    }
}
