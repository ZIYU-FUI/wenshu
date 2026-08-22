# 03 — Menu bar "wenshu" → "文枢" (drop `WindowGroup` title + adopt `SettingsScene`)

**What to build:**
老板 2026-08-21 inspected the menu bar and reported: "I only have wenshu — this menu is English, the rest is fine." `NSMenu` L218-251 already installs the Chinese "文枢" as the real value, but `macOS 27 SwiftUI `WindowGroup("文枢")`` uses the first-parameter `title` = "文枢" → SwiftUI expects to install one menu; macOS 27's lazy-populate injection runs after `NSMenu.applicationWillFinishLaunching`, so SwiftUI overwrites the Chinese "文枢" installed by NSMenu with the English "wenshu".

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Fix specification (3 steps)

1. In `App.swift` L176, drop the `WindowGroup("文枢") { LayoutShellView() }` first-parameter `title`; change it to `WindowGroup { LayoutShellView() }` (so SwiftUI doesn't inject the `wenshu` menu).
2. In `App.swift` L186, replace `Settings { }` Scene with the `SettingsScene` pattern (SwiftUI 5+ / macOS 14+ supports it) so we control menu installation directly.
3. Run `killall Dock` to clear macOS Dock's menu-bar cache.
4. 1 ticket 1 commit + 老板 macOS verifies the first menu item is "文枢", not "wenshu".

## Acceptance

- [ ] `WindowGroup` first-parameter `title` removed (`App.swift` L176)
- [ ] `SettingsScene` replaces `Settings` (`App.swift` L186)
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS verification: menu bar first item = "文枢" (Chinese, not English `wenshu`)

## Out of scope (Q20 hard constraint)

- The 6 Chinese items installed by `NSMenu` L218-251 (already landed in ticket 08)
- `ChatView` / `LayoutShellView` (unrelated to this ticket)
- v0.20 ticket 08 `SettingsLink` trigger mechanism (`SettingsScene` still triggers SwiftUI Settings)

## Apple HIG references

- https://developer.apple.com/documentation/swiftui/windowgroup (the `title` parameter = SwiftUI's lazy-populate menu name)
- https://developer.apple.com/documentation/swiftui/settingsscene
- vdhamer/Photo-Club-Hub-HTML#248 (SwiftUI `.commands` macOS 27 lazy-populate bug)

## References

- Depends on: none
- Required by: none
