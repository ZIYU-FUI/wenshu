# Spec — Menu bar + Dock logo ground-truth report (老板 2026-08-20 拍)

> Date: 2026-08-20
> 老板 2026-08-20 拍 "1. macOS still has no menu bar, and the Dock has no app LOGO 2. The mouse still does not change shape 3. Solve these two first before tackling the chat area"

## Root causes (deleg_a9c4fde9 ran the ground-truth report in 47 minutes)

### Root cause 1: Menu bar invisible

- `CommandGroup(replacing: X) { }` does not delete the group — replaces with an empty group, each empty group still contributes a separator
- WenshuAppDelegate touched NSWindow before SwiftUI finished the main menu
- macOS 27 beta lazy menu populate = the entire top menu bar was never installed at all
- Ground truth: vdhamer/Photo-Club-Hub-HTML#248 (open since 2026-08-13) public record

### Root cause 2: Dock has no logo

- wenshu did not set `NSApplication.shared.applicationIconImage`
- macOS 27 defaults to fallback system generic icon
- Ground truth: NSApplication.applicationIconImage ground-truth API

### Root cause 3: cursor does not change shape

- v0.17 ticket 03 already commit 47055fc5e + cursor root-cause report v2 evidence: NSHostingView does not propagate AppKit cursor rects into the SwiftUI subtree
- commit f65bb3292 added `.pointerStyle(orientation == .vertical ? .columnResize : .rowResize)` but attached to the wrong layer = ZStack parent vs NativeSplitter body internals
- Ground truth: `.pointerStyle` must live outside the SwiftUI view tree of the native NSView / NSViewRepresentable

## Fix (老板 拍 C: 2 tickets)

### Ticket 1 — Menu bar + Dock logo (1 commit)

**Fix ground truth**:
- Menu bar: comment out WenshuAppDelegate.applicationDidFinishLaunching setContentSize/center/guards (avoid touching NSWindow before SwiftUI finishes the main menu)
- Menu bar: keep `.commands { CommandMenu/CommandGroup/SettingsLink }` — ground truth (v0.17 ticket 07 change commit 4c42fa79)
- Dock logo: NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon") set at launch
- Engineering management authorized by 老板 (8/19 拍 "you decide on your own") + no acceptance needed

**Changes**:
- Sources/WenshuApp/App.swift WenshuAppDelegate.applicationDidFinishLaunching:
  1. Keep SelfScreenshot.run() logic
  2. Delete setContentSize / center (avoid triggering the macOS 27 lazy menu populate bug)
  3. Add NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon") ground truth
  4. Keep chat agent registration (v0.20 ticket 01)
- Assets.xcassets add AppIcon appiconset (wenshu logo ground truth)
- Build clean after modification

### Ticket 2 — cursor switch ↕/↔ (1 commit)

**Fix ground truth**:
- Delete commit f65bb3292's `.pointerStyle` attached to the ZStack parent (wrong location, NSViewRepresentable bridging SplitterHitAreaRepresentable cannot pass through the SwiftUI cursor system)
- Attach it to NativeSplitter body's Rectangle visually (inside the SwiftUI view tree) — SwiftUI `.pointerStyle` modifier penetrates the NSViewRepresentable bridge into the SwiftUI view tree, NSHostingView takes over cursor events → SwiftUI PointerStyle system works
- Engineering management authorized by 老板 + no acceptance needed

**Changes**:
- Sources/WenshuApp/Views/Layout/NativeSplitter.swift:
  1. Delete ZStack parent .pointerStyle (commit f65bb3292 attached to the wrong location)
  2. Add `.pointerStyle(orientation == .vertical ? .columnResize : .rowResize)` to the Rectangle visually
- Build clean after modification
- Q22 real verification: Apple HIG ground truth + Apple SDK ground truth (VStack parent) + real mouse hover verification

## Do not touch

- /Volumes/ANAN/.hermes/ any files (老板 8/11 拍 'hermes do not touch', read-only volume)
- wenshu 6-zone layout framework (LayoutShellView / LayoutTokens / bandH all kept)
- macOS chrome 52 PT (.windowStyle(.titleBar))
- drag line visuals (1 PT fill / 3 PT hover / 1 PT hit area / system color / no rounded ends)
- WenshuCore 14 ground-truth modules (Memory / Skill / Agent / Kanban / Todo / Tools / Cron / Backup / MiniMaxVerifier)
- ChatView (v0.20 ticket 01) (left for later optimization)

## Ground-truth references (Apple HIG)

- NSApplication applicationIconImage: https://developer.apple.com/documentation/appkit/nsapplication/applicationiconimage
- NSMenu ground truth: https://developer.apple.com/documentation/appkit/nsmenu
- SwiftUI .commands ground truth: https://developer.apple.com/documentation/swiftui/scene/commands
- SwiftUI CommandMenu: https://developer.apple.com/documentation/swiftui/commandmenu
- SwiftUI CommandGroup: https://developer.apple.com/documentation/swiftui/commandgroup
- SwiftUI SettingsLink: https://developer.apple.com/documentation/swiftui/settingslink
- SwiftUI .pointerStyle: https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)
- SwiftUI PointerStyle.columnResize: https://developer.apple.com/documentation/swiftui/pointerstyle/columnresize
- SwiftUI PointerStyle.rowResize: https://developer.apple.com/documentation/swiftui/pointerstyle/rowresize

## Business language description (老板-readable)

- Menu bar invisible: 老板 拍 8/19 evening, commit 464d4f344 deleted WenshuAppDelegate setContentSize fixing part of it, but actually launching wenshu did not show the menu bar
- Dock has no logo: wenshu did not set applicationIconImage, Dock shows generic icon
- cursor does not change: 8/19 evening commit f65bb3292 added .pointerStyle but to the wrong place, the mouse does not actually change

Fix: 2 tickets split into 2 commits, 1 ticket 1 commit ground truth (老板 8/19 engineering management authorization + 1 ticket 1 commit hard rule)

## Next steps 老板 拍

- Implement ticket 1: menu bar + Dock logo
- Implement ticket 2: cursor switch ↕/↔
- Once fixed, return to chat UI optimization (v0.20 ticket 01 chat UI actually able to type + AI reply ground truth)