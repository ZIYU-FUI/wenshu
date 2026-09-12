# Ticket 004 — delete 7 wenshu View menu items

## Rule
AppRootScene.swift `CommandGroup(after: .sidebar)` block lines 166-228 has 7 wenshu-authored buttons:
1. Toggle Project Sidebar (⇧⌘1) → posts `.wenshuToggleZone(ZoneSlot.projectSidebar)`
2. Toggle Project Preview (no shortcut) → posts `.wenshuToggleZone(ZoneSlot.projectPreview)`
3. Toggle Specialized Tools (⇧⌘2) → posts `.wenshuToggleZone(ZoneSlot.specializedTools)`
4. Toggle AI Chat (⇧⌘3) → posts `.wenshuToggleZone(ZoneSlot.aiChat)`
5. Toggle AI Dynamic (⇧⌘4) → posts `.wenshuToggleZone(ZoneSlot.aiDynamic)`
6. Reset Layout (⇧⌘R) → posts `.wenshuResetLayout`
7. Layout Edit Mode (⇧⌘\) → posts `.wenshuToggleEditMode`

All 7 + the surrounding Divider blocks delete.

## Diff scope
`Sources/WenshuApp/App/AppRootScene.swift` lines 166-228 — delete the entire `CommandGroup(after: .sidebar) { Divider(); ... 7 Buttons + Dividers }` block.

## Why
Per boss 2026-09-10 "\u6240\u6709\u83dc\u5355\u9879\u90fd\u4e0d". NSV automatically provides sidebar toggle via column-header chevron. All other visibility is column-header chevron + inspector chevron + zone Picker toggles inside columns (which the user already has). The 4 ⇧⌘1-4 shortcuts were v0.24 hand-rolled when wenshu's zone model was 6-zone-canvas; with NSV 3-column the same visibility is provided by the NSV system.

## Side effects to verify
- `NotificationCenter.default.publisher(for: .wenshuResetLayout)` in WorkspaceView.swift line 330 will become a dead observer — leave it (deleting it is out of ticket scope; future cleanup).
- `NotificationCenter.default.publisher(for: .wenshuToggleEditMode)` in WorkspaceView.swift line 324 will become a dead observer — leave it (same rationale).
- `NotificationCenter.default.publisher(for: .wenshuToggleZone)` in WorkspaceView — leave it (out of ticket scope).
- The ZonePicker Picker inside column toolbars remains — those are toolbar items not menu items, boss said only menu items.

## Verify
- swift build → exit 0
- launch app → View menu has only system items (Enter Full Screen, etc.) + auto-generated Settings...
- column-header chevrons on each column still work for visibility
