# 07 — NSApp.mainMenu + Pages paradigm popup (revert `.commands` + Settings Scene, 老板 2026-08-21 ruled)

**What to build:**
老板 8/21 feedback: 'two display entries, no File and Edit' (= after commit `beff63b43`, 5 menu items + 2 settings… items + missing File / Edit)
老板 8/21 truth: 'execute the PO full-chain methodology; don't make me emphasize it at the start of every new session; don't skip steps' (= Q34 dual-axis code-review must run, Q32 look up official docs, 5-principle 1 Apple truth)

**Root cause (Q32 audit, principle-1 hard violation):**
macOS SwiftUI authoritative truth (Q28 swiftinterface + Apple truth):
- The `.commands` modifier placed **after** `Settings { } Scene` → Settings takes over the main menu → `.commands` fails to install into the main menu
- Previous installs (commits `d194cb66d` + `491a6874b` + `beff63b43`) all placed after `Settings { }` and all failed
- macOS SwiftUI `Settings { } Scene` automatically installs one ⌘, (.appSettings)
- I installed `CommandGroup(replacing: .appSettings) { SettingsLink() }` redundantly → 老板's screenshot shows 2 "Settings…"

**Blocked by:** None.

**Status:** ready-for-agent

## Fix specification (3 steps, satisfying principles 1 + 4, Q32 hard-violation fix)

1. **Revert App-body `.commands { }` block + `Settings { }` Scene** (commits `d194cb66d` + `491a6874b` + `beff63b43` all reverted; Q32 principle-1 hard violation)
2. **Revert `applicationWillFinishLaunching` `NSApp.mainMenu` install** (commit `31b96953f` installed, timing was wrong and SwiftUI took over)
3. **`applicationDidFinishLaunching` install `NSApp.mainMenu = installMainMenu()`** (commit `9f77ffa9c` truth — it worked previously)
4. **`installMainMenu()` installs the 6-item truth** (commit `9f77ffa9c` truth)
5. **`openSettingsWindow` self-created `NSWindow` installs `SettingView`** (commit `3f4faf68f` truth)
6. **`SettingView` top toolbar tab + 3-tab Pages paradigm** (commit `6a3d93f5d` truth, 老板's drawing has 2 red boxes)

## Dual-axis code-review (Q34: 老板 corrected "I didn't catch that dual-axis wasn't run"; this round must run)

## Acceptance

- [ ] App body reverts `.commands` + Settings Scene
- [ ] `applicationWillFinishLaunching` reverts `NSApp.mainMenu` install
- [ ] `applicationDidFinishLaunching` installs `NSApp.mainMenu = installMainMenu()`
- [ ] 6 menu items installed (文枢 / File / Edit / View / Window / Help, 老板 8/10 01:43)
- [ ] "Settings…" 1 entry (NSMenu install, not redundantly over macOS swiftinterface take-over)
- [ ] "Restore Default Layout" connects to `NotificationCenter` `wenshuResetLayout`
- [ ] `openSettingsWindow` floats over windows without crowding
- [ ] `SettingView` top toolbar tab + 3-tab Pages paradigm
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS verification: 6 menu items + Settings… 1 entry + settings sheet floats over windows + top toolbar tab switching
- [ ] **Dual-axis code-review report** (Standards + Spec in parallel; 老板 8/21 ruled "execute the PO full chain")

## Out of scope (Q20 hard constraint)

- v0.20 LOGO + menubar
- v0.21 chat-streak tickets 02-06
- `Provider` / `ProviderKeychain` / `ProviderFetcher` / `ProviderCatalog`
- `ProviderKeyPrompt`
- `MiniMaxModelFetcher`
- `SettingView` content (= commits `6a3d93f5d` + `1f086051a` untouched)
- `ChatBottomToolbar` (commit `efa351f80` untouched)
- `AppIcon.icon/`

## Apple HIG references

- https://developer.apple.com/documentation/appkit/nsapplication/mainmenu
- https://developer.apple.com/documentation/swiftui/commands
- https://developer.apple.com/documentation/swiftui/settings
- Pages macOS 27 settings panel (authoritative reference)

## References

- Depends on: none
- Required by: none
