//
//  PaneNSController+ZoneVisibility.swift · Wenshu · v1.28 C3.2.2
//
// C3.2.2: extract the 3 zone-visibility helpers (= allTabKinds,
//  isZoneVisible, isZoneVisibleRecursive) from PaneNSController.swift into
//  a focused extension file.
//
//  Originally at PaneNSController.swift:549-591 (= 43 LOC: docstring +
//  helper definitions). The extraction moves all 3 helpers (= which all
//  operate on TabKind / TabKind visibility state) into one focused file.
//
//  Behavior preserved (= all 3 helpers unchanged; = same logic; = same
//  return types).
//

import AppKit

extension PaneNSController {
    /// explicit list of all TabKind cases (= TabKind
    /// is not CaseIterable; mirror the enum's 6-case definition here).
    func allTabKinds() -> [TabKind] {
        [.projectSidebar, .projectPreview, .editor,
         .specializedTools, .aiChat, .aiDynamic]
    }

    /// ZONE-VIS-FIX-001 (2026-09-08): query isCollapsed across self
    /// + nested PaneNSControllers for a TabKind. True = zone is
    /// currently visible (= not collapsed). Used by
    /// `collapseAllNonEditorZones` to know which zones to collapse
    /// (= skip the ones already collapsed).
    func isZoneVisible(_ slot: TabKind) -> Bool {
        let kind = slot  // zoneSlotToTabKind was an identity (= TabKind -> TabKind?); inlined.
        for (idx, item) in splitViewItems.enumerated() {
            guard let tab = paneKindByItem[idx], tab == kind else { continue }
            return !item.isCollapsed
        }
        // Check nested controllers (= same flatten as handleToggleZone).
        for child in children {
            if let splitChild = child as? PaneNSController,
               let visible = splitChild.isZoneVisibleRecursive(kind) {
                return visible
            }
        }
        return true
    }

    func isZoneVisibleRecursive(_ kind: TabKind) -> Bool? {
        for (idx, item) in splitViewItems.enumerated() {
            guard let tab = paneKindByItem[idx], tab == kind else { continue }
            return !item.isCollapsed
        }
        for child in children {
            if let splitChild = child as? PaneNSController,
               let visible = splitChild.isZoneVisibleRecursive(kind) {
                return visible
            }
        }
        return nil
    }
}
