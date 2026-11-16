// EditorChatNSController+Layout.swift · Wenshu
//
// The layout (= the thickness bounds, the 50:50 reset, the chat
// zone).
//
// The arrangement and the transition that used to live here are
// gone: the split holds ONE arrangement (= the editor above the
// chat), so there is no arrangement to choose and no transition to
// run.
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
    /// Whether the split has a stored divider position.
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
    /// The clamp follows the split's own axis: the height carries
    /// the split (= the editor is above the chat, = the divider runs
    /// across), so the cap is the split's height.
    func updateAutomaticThicknessBounds() {
        let extent = splitView.bounds.height
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
        applyFiftyFiftyReset()
    }

    /// The 50:50 reset on the split's own axis: the editor is above
    /// the chat, so the divider runs across and the height carries
    /// the split.
    private func applyFiftyFiftyReset() {
        let dividerY = splitView.bounds.height / 2
        splitView.setPosition(dividerY, ofDividerAt: 0)
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
