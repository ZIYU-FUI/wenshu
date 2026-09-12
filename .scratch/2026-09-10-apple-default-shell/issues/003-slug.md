# Ticket 003 — delete `InspectorCommands()` from `.commands` block

## Rule
AppRootScene.swift line 92 adds `InspectorCommands()` which auto-renders a "View > Inspector" menu item. Boss 2026-09-10 says "\u6240\u6709\u83dc\u5355\u9879\u90fd\u4e0d，\u5e9f\u5f03\u7684\u83dc\u5355\u9879\u8981\u5220" — delete this single line and the trailing blank comment line.

## Diff scope
`Sources/WenshuApp/App/AppRootScene.swift` lines 88-93 — delete the `InspectorCommands()` block + its preceding v0.48 comment.

## Why
The NSV `.inspector(isPresented:)` modifier already provides a column-header chevron for inspector toggle. The duplicate menu item (⌥⌘I) was wenshu's hand-rolled convenience on top of the system one — boss says drop all custom menu items.

## Verify
- swift build → exit 0
- launch app → View menu has NO Inspector item
- sidebar toggle still works via NSV column-header chevron
