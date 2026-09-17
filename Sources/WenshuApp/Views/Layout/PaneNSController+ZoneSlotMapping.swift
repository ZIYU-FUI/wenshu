//
//  PaneNSController+ZoneSlotMapping.swift · Wenshu · v1.28 C3.2.1
//
//  v1.28 C3.2.1: extract the `zoneSlotToTabKind` helper (= v0.34 ticket 02
//  ZoneSlot → TabKind canonical mapping) from PaneNSController.swift into
//  a focused extension file.
//
//  Originally at PaneNSController.swift:620-631 (= 12 LOC including the
//  docstring + 8 lines of switch). The extraction moves the helper into
//  a focused extension file (= the god controller's surface area drops
//  by 12 LOC; = the helper is now discoverable via Spotlight / Xcode
//  jump-to-file by its descriptive filename).
//
//  Behavior preserved (= the helper still maps each ZoneSlot to its
//  corresponding TabKind; = the 6 cases are unchanged; = the function
//  remains `private` to the extension scope (= Swift enforces
//  file-private access regardless of which file the helper lives in,
//  as long as it's marked `private`).
//

import AppKit

extension PaneNSController {
    /// v0.34 ticket 02: ZoneSlot → TabKind canonical mapping (= mirror
    /// of the switch in handleToggleZone, factorised out for reuse).
    /// `internal` (= module-internal scope; = the helper is callable
    /// from any site inside the wenshu-app module; = Swift `private`
    /// is too restrictive for cross-file extension member access).
    func zoneSlotToTabKind(_ slot: ZoneSlot) -> TabKind? {
        switch slot {
        case .projectSidebar: return .projectSidebar
        case .projectPreview: return .projectPreview
        case .editor: return .editor
        case .specializedTools: return .specializedTools
        case .aiChat: return .aiChat
        case .aiDynamic: return .aiDynamic
        }
    }
}
