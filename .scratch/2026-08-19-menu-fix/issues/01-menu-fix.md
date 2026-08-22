# 01 — Menu bar visible fix (option A: comment WenshuAppDelegate + .commandsReplaced, 老板 2026-08-19 拍)

**What to build:**
老板 2026-08-19 reported: entire macOS top menu bar not visible (commit `4c42fa79` already wrote `.commands` but 老板 actual test shows not displayed).
deleg_a9c4fde9 47 minutes + 120 tool calls to check Apple truth, found root cause (P0):
- vdhamer/Photo-Club-Hub-HTML#248 public record
- `CommandGroup(replacing: X) { }` does not delete group, replacing with empty group still contributes separator
- WenshuAppDelegate touched NSWindow before SwiftUI finished main menu
- macOS 27 beta lazy menu populate = entire top menu bar never installed

Business-language description (老板 understands):
- macOS 27 changed: SwiftUI installs menu bar itself, but if someone touches NSWindow first, macOS system gives up installing menu bar
- Fix (option A): let SwiftUI install menu bar itself, WenshuAppDelegate no longer touches NSWindow early
- Add `.commandsReplaced` force install (Apple official provided)

After change:
- `WenshuAppDelegate.applicationDidFinishLaunching` delete `setContentSize` / `center` (early NSWindow-touching code)
- WenshuAppDelegate keep SelfScreenshot (WS_SCREENSHOT env)
- WindowGroup add `.commandsReplaced { LayoutShellView() }` force install main menu
- Splitters / dividers / cursor / 1 PT / color / rounded caps / hover all unchanged

**Blocked by:** None (subagent report + root cause + fix ready)
**Status:** ready-for-agent → impl done → waiting for 老板 verify screenshot

## Acceptance criteria

- [ ] macOS top menu bar visible (老板 screenshot verify)
- [ ] Under "文枢" top-level can see "Settings..." (⌘,)
- [ ] Under "File" top-level can see "New Project" (⌘N)
- [ ] Under "View" top-level can see "Restore Default Layout" (⌘⇧R)
- [ ] Menu bar other items unchanged (Apple / 文枢 / File / Edit / Show / View / Window / Help)
- [ ] `WenshuAppDelegate.applicationDidFinishLaunching` no longer touches NSWindow early
- [ ] WindowGroup adds `.commandsReplaced` force install main menu
- [ ] `swift build` exit 0
- [ ] Splitters / dividers / cursor / 1 PT / color / rounded caps / hover all unchanged (cursor ticket 03 commit `f65bb329` preserved)
- [ ] macOS chrome 52 PT unchanged
- [ ] LayoutTokens / bandH / toolbar width unchanged

## Root-cause references

- vdhamer/Photo-Club-Hub-HTML#248: https://github.com/vdhamer/Photo-Club-Hub-HTML/issues/248
- SwiftUI `.commands`: https://developer.apple.com/documentation/swiftui/app/commands
- SwiftUI `.commandsReplaced`: https://developer.apple.com/documentation/swiftui/commandsreplaced

## Business-language fix description (老板 understands)

- Don't let wenshu touch NSWindow before SwiftUI installs menu bar
- Let macOS system install menu bar itself
- Add `.commandsReplaced` force install, don't let macOS skip