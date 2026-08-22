# 12 — Add File + Edit menus (老板 2026-08-21 23:50 ruled)

**What to build:**
老板 8/21 23:50 ruled:
- 'The menu items work and the popup also works; stop touching the menubar code.'
- 'There are no File or Edit menus.'
- 'Look into how, on top of the current implementation, to add the File and Edit menus.'
- 'Stop flip-flopping. Lock onto one implementation method and continue from there.'

= Lock onto current implementation = macOS SwiftUI 14+ `Settings { } Scene + .commands { CommandGroup }` 12-placement paradigm (commit `a69a42401` is the truth). No flip-flopping = don't revert to `NSApp.mainMenu` install path + don't write self-created `NSWindow` popup.
= Missing File (`.newItem`) + Edit (`.undoRedo`) = 2 of the 12 `CommandGroup` placements. Fix: add 2 `CommandGroup`s to the `.commands` block.

**Blocked by:** None.

**Status:** ready-for-agent

## Fix specification (principles 1 + 4 satisfied; 1 ticket 1 commit; no flip-flopping)

1. **`App.swift` `.commands` block adds 2 `CommandGroup`s**:
   - `CommandGroup(after: .newItem) { Button("New Project", action: {}) }` = File
   - `CommandGroup(replacing: .undoRedo) { Button("Undo") + Button("Redo") }` = Edit
2. **Keep `CommandGroup(after: .sidebar) { Divider(); Button("Restore Default Layout") }`** (= View; 老板 8/21 23:50 ruled "don't touch" = keep)
3. **Keep `CommandGroup(replacing: .appSettings) { SettingsLink() }`** (= Settings; commit `a69a42401` truth = 1 ⌘, "Settings…")
4. **Keep `Settings { SettingView() } Scene`** (= macOS automatically installs ⌘, "Settings…", commit `a69a42401` truth)

## Dual-axis code-review (Q34: 老板 corrected "execute the PO full chain"; this round must run)

## Acceptance

- [ ] `App.swift` `.commands` block adds `CommandGroup(after: .newItem) { Button("New Project") }` (= File)
- [ ] `App.swift` `.commands` block adds `CommandGroup(replacing: .undoRedo) { Button("Undo") + Button("Redo") }` (= Edit)
- [ ] Keep `CommandGroup(after: .sidebar)` (= View; 老板 ruled "don't touch")
- [ ] Keep `CommandGroup(replacing: .appSettings)` (= Settings; 1 ⌘, "Settings…")
- [ ] Keep `Settings { SettingView() } Scene` (= macOS auto-install)
- [ ] 6 menu items (`Apple` / 文枢 / File / Edit / View / Window / Help) (post-fix = 老板 8/21 23:50 ruled)
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS verification: 6 menu items + File / Edit entries are clickable
- [ ] **Dual-axis code-review report** (Standards + Spec in parallel; 老板 8/21 ruled "execute the PO full chain")

## Out of scope (Q20 hard constraint)

- v0.20 LOGO + menubar
- v0.21 chat-streak tickets 02-06
- `Provider` / `ProviderKeychain` / `ProviderFetcher` / `ProviderCatalog`
- `ProviderKeyPrompt`
- `MiniMaxModelFetcher`
- `SettingView` (commits `6a3d93f5d` + `1f086051a` kept; Pages paradigm)
- `ZoneModule` parent component (post-commit `d0c642273`; other 5 zone cases untouched)
- `ZoneBottomToolbar` parent component (5 zones' bottom bars keep "placeholder strings")
- `ChatZoneView` (post-commits `f1fe8e64c` + `d0c642273`)
- `AppIcon.icon/`

## Apple HIG references

- https://developer.apple.com/documentation/swiftui/commandgroup
- https://developer.apple.com/documentation/swiftui/commandgroupplacement
- https://developer.apple.com/documentation/swiftui/commandgroupplacement/newitem
- https://developer.apple.com/documentation/swiftui/commandgroupplacement/undoredo

## References

- Depends on: none
- Required by: none
