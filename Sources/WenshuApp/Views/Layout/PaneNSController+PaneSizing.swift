//
//  PaneNSController+PaneSizing.swift · Wenshu · v1.28 C3.2.4
//
//  v1.28 C3.2.4: extract the pane-sizing helpers from PaneNSController.swift
//  into a focused extension file. The 4 helpers (= minThickness + maxThickness
//  + isCollapsiblePane + autosaveKey) all govern the sizing / collapse
//  behavior of individual panes.
//
//  Originally at PaneNSController.swift:1497-1547 + 1640-1647
//  (= 49 LOC including docstrings + MARK comments).
//
//  Behavior preserved (= all 4 helpers unchanged; = same logic; = same
//  return types; = the access level of `isCollapsiblePane` was previously
//  `private` and is now `internal` so the cross-referencing helper
//  `minThickness` (which calls `isCollapsiblePane`) works across files).
//

import AppKit

extension PaneNSController {
    /// a hard minimum so the user can't drag them below Apple HIG
    /// readability; middle panes get a smaller minimum so the editor
    /// can shrink when the sidebar expands).
    func minThickness(for paneID: PaneID, weight: Double) -> CGFloat {
        guard let pane = store.workspace.pane(for: paneID) else { return 100 }
        // Honor the pane's declared minWidth/idealWidth (= user-tunable).
        if pane.frame.minWidth > 0 { return pane.frame.minWidth }
        // Fallback: collapseable side panes default to 200 (= Apple HIG
        // sidebar minimum); non-collapseable panes (= editor, viewer)
        // default to 100 (= can shrink down to almost nothing).
        return isCollapsiblePane(paneID) ? 200 : 100
    }

    /// ZONE-VIS-FIX-002 (2026-09-08): canonical per-TabKind
    /// `maximumThickness` (= the upper bound for a pane's thickness).
    /// Returning `nil` means "no upper bound" (= Apple default).
    /// Per-zone rationale (= see the `maximumThickness` setter in
    /// `makeSplitItems`):
    /// - sidebar: 400 PT (= tree outline natural max)
    /// - cards: 500 PT (= card grid natural max)
    /// - tools: 300 PT (= icon row natural max; = matches FCP
    ///   inspector width)
    /// - editor / chat / dynamic: nil (= no upper bound; =
    ///   always takes remaining space via `preferredThicknessFraction`)
    func maxThickness(for kind: TabKind) -> CGFloat? {
        switch kind {
        case .projectSidebar:   return 400
        case .projectPreview:   return 500
        case .specializedTools: return 300
        case .editor, .aiChat, .aiDynamic: return nil
        }
    }

    /// Which panes can the user collapse (= via the "Display" menu /
    /// sidebar toolbar toggle). Boss 2026-09-01 OOB rule: everything
    /// except the editor is collapsible (= the editor is the one
    /// pane the user is always writing in; collapsing it would
    /// hide the work surface). Sidebar / preview / tools / chat /
    /// dynamic all follow the standard FCP hide/show affordance.
    func isCollapsiblePane(_ paneID: PaneID) -> Bool {
        guard let pane = store.workspace.pane(for: paneID),
              let firstTabID = pane.tabIDs.first,
              let tab = store.workspace.tab(for: firstTabID)
        else { return false }
        switch tab.kind {
        case .projectSidebar, .projectPreview, .specializedTools, .aiChat, .aiDynamic:
            return true
        case .editor:
            return false
        }
    }

    // MARK: - autosaveName key (= per-layout + per-split)

    /// Apple autosaveName key (= scopes divider positions per preset +
    /// per split subtree, so switching presets restores each one's last
    /// divider positions).
    func autosaveKey(for splitID: String) -> String {
        "wenshu.split.\(layoutID).\(splitID)"
    }
}
