# Ticket 003 — empty ShellSidebarColumn bottom sub-area (cards migrated out)

## Rule
ShellSidebarColumn VSplitView bottom sub-area is now empty (= PreviewPane migrated to middle column per ticket 001). Replace `ZoneModuleView(zoneSlot: .projectPreview)` with `Color.clear` (= placeholder for future zone; = preview ticket out of scope).

VSplitView's bottom sub-area stays (= keeps the sidebar's resize handle so the user can collapse the empty region). Removing it entirely is a future cleanup ticket (= requires boss拍).

## Diff scope
`Sources/WenshuApp/UI/Layout/NavigationSplitShell.swift` ShellSidebarColumn body, ~3 lines.

## Why
Ticket 001 migrates the cards out. This ticket makes the sidebar bottom an explicit empty placeholder so the VSplitView divider still has something to drag.

## Verify
- swift build → exit 0
- sidebar VSplitView divider still works (= user can drag to collapse / expand the empty bottom region)
