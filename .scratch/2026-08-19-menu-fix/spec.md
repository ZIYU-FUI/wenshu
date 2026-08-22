# Spec — Menu bar invisible fix (老板 2026-08-19 拍)

> Date: 2026-08-19
> Spec uses po `to-spec` skill 7-section template

## Problem Statement

老板 2026-08-19 reported multiple times: after launching wenshu app, the entire macOS top menu bar is not visible (more serious than "can't find settings", the entire menu bar doesn't exist).

deleg_a9c4fde9 ran 47 minutes + 120 tool calls to check Apple truth, found root cause (P0):
- vdhamer/Photo-Club-Hub-HTML#248 (open since 2026-08-13) public record
- `CommandGroup(replacing: X) { }` does not delete group — it replaces with empty group, each empty group still contributes separator
- SwiftUI-layer API cannot clean up what it itself left behind
- WenshuAppDelegate touched NSWindow before SwiftUI finished main menu
- macOS 27 beta lazy menu populate = entire top menu bar never installed

## Solution (老板 2026-08-19 19:55 拍 A: comment WenshuAppDelegate + .commandsReplaced force install)

Business-language description (老板 understands):
- macOS system menu loading mechanism changed in macOS 27 beta: SwiftUI installs menu bar itself, but if someone touches NSWindow first (like our WenshuAppDelegate.applicationDidFinishLaunching doing setContentSize / center), macOS system gives up installing menu bar
- Fix: let SwiftUI install menu bar itself, our WenshuAppDelegate no longer touches NSWindow early — change to setContentSize / center after SwiftUI installs menu bar itself
- Add `.commandsReplaced` force install (Apple official provided, not sure if it really works, add first, verify then delete)

### Implementation Decisions

- Fix (option A):
  1. Delete `WenshuAppDelegate.applicationDidFinishLaunching` `setContentSize` / `center` early NSWindow-touching code
  2. Change WenshuApp.body to add `.commandsReplaced(...)` force install main menu
  3. WindowGroup contentLayout change to use `LayoutTokens.designW` × `designH` ratio operator
  4. WenshuAppDelegate keep `applicationDidFinishLaunching` but only do SelfScreenshot (WS_SCREENSHOT env)
- Backup (option B): add `NSApp.mainMenu?.items.forEach { $0.submenu?.update() }` at end of `applicationDidFinishLaunching` (if A fails, add this line then build)
- Backup (option C): use `.commandsReplaced` force install (add with A simultaneously)

### Implementation Steps

1. WenshuApp.body WindowGroup add `.commandsReplaced { ContentView() }` (force install main menu)
2. WenshuAppDelegate.applicationDidFinishLaunching:
   - Delete `setContentSize` + `center` + `guards` (early NSWindow-touching code)
   - Keep SelfScreenshot call
3. WenshuApp.body use `.windowStyle(.titleBar)` + `.defaultSize` (SwiftUI provides initial size hint)
4. WenshuApp.body layout internally use GeometryReader + ratio operator adaptive resize

## User Stories

1. As 老板, I want macOS top menu bar visible, so that the entire app matches Pages / Numbers / Xcode
2. As 老板, I want under "文枢" top-level see "Settings..." (⌘,), so that matches macOS standard
3. As 老板, I want under "File" top-level see "New Project" (⌘N), so that 老板 can create new projects
4. As 老板, I want under "View" top-level see "Restore Default Layout" (⌘⇧R), so that 老板 can one-click reset layout
5. As 老板, I want menu bar other items unchanged (Apple / 文枢 / File / Edit / Show / View / Window / Help)
6. As 老板, I want `swift build` exit 0

## Implementation Decisions

- Fix (老板 拍 A):
  - Comment / delete `WenshuAppDelegate.applicationDidFinishLaunching` `setContentSize` / `center` / `guards` (early NSWindow-touching code)
  - Add `.commandsReplaced { LayoutShellView() }` force install main menu (Apple official API, macOS 14+)
  - Keep WenshuAppDelegate but only do SelfScreenshot (WS_SCREENSHOT env)

## Testing Decisions

- Only `swift build clean` (exit 0), 老板 self-launches app + screenshots to verify
- Verify: top menu bar visible, "文枢" → "Settings..." / "File" → "New Project" / "View" → "Restore Default Layout"

## Out of Scope

- Do not touch macOS chrome 52 PT
- Do not touch LayoutTokens / bandH / toolbar width
- Do not touch splitters (cursor / hover / drag / 1 PT fill / color all preserved)
- Do not rewrite `.commands {}` content (just the command group menu items themselves)
- Do not add new menu items

## Further Notes

- Root-cause report: vdhamer/Photo-Club-Hub-HTML#248 (open since 2026-08-13)
- 老板 can only verify screenshot-visible requirements (cursor switch / menu bar / hover / 1 PT / color / rounded caps = 6), drag response cannot verify
- 老板 拍 A: minimum change (only modify WenshuAppDelegate.applicationDidFinishLaunching early NSWindow-touching part + add .commandsReplaced)
- Apple HIG truth references (8/15 bug debugging rule requires):
  - https://developer.apple.com/documentation/swiftui/commandsreplaced
  - https://developer.apple.com/documentation/swiftui/app/commands
  - https://github.com/vdhamer/Photo-Club-Hub-HTML/issues/248