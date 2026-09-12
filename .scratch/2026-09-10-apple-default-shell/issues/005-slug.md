# Ticket 005 — delete ⌘K Command Palette `.newItem` replacement

## Rule
AppRootScene.swift lines 120-124 replace macOS-default `CommandGroup(replacing: .newItem)` with a custom `Button("...") { CommandPaletteController.show() }` + `.keyboardShortcut("k", modifiers: .command)`. Delete the entire replacement block — restore default `.newItem` (macOS-standard File > New with ⌘N for new document).

## Diff scope
`Sources/WenshuApp/App/AppRootScene.swift` lines 120-125 — delete the `CommandGroup(replacing: .newItem) { ... }` block.

## Why
Per boss 2026-09-10 "\u6240\u6709\u83dc\u5355\u9879\u90fd\u4e0d". The ⌘K palette was a hermes parity carryover from v0.40. The remaining file menu (New Project submenu + Import at lines 126-160) is the post-`.newItem` block which stays.

## Verify
- swift build → exit 0
- launch app → File > New (⌘N) shows macOS default New File behavior
- ⌘K does nothing (CommandPaletteController.show() no longer wired)
