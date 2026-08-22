# Spec — Project LOGO dark/light + Menu bar + Settings menu cleanup (老板 2026-08-20 拍)

> Date: 2026-08-20 10:35
> 老板 2026-08-20 10:35 拍 "LOGO is in, but does not follow the system theme. APP name = 文枢 in Chinese. The first menu bar item should change from wenshu to 文枢, and the 文枢 menu has two Settings items — keep the official one only"
> 老板 拍板 Q1=A (pack dark+light into project + keep the existing AppIcon.icns) / Q2=A (remove the .commands block, NSMenu only) / Q3=B (keep 设置…, but it must trigger SettingsView)

## Root cause chain

### 1. LOGO does not follow the theme — root cause

- macOS 27 AppKit paradigm = the Resources directory simultaneously contains `AppIcon.icns` (fallback) + `AppIcon.dark.icns` + `AppIcon.light.icns`
- AppKit picks the icns automatically based on `effectiveAppearance` (dark/light), **no App.swift runtime install needed**
- The project currently only has `AppIcon.icns` (473 KB / 11 reps, landed 8/20 9:26, universal version), no dark/light variants
- Desktop `wenshu-icon-dark.icns` (367481 bytes) + `wenshu-icon-light.icns` (369946 bytes) = the 8/11 v0.03.0 LOGO master tool-chain re-export ground truth
- Root cause = the desktop dark/light files have not been copied into the project

### 2. Menu bar `wenshu` first menu — root cause

- NSMenu L236 `NSMenu(title: "文枢")` is already in Chinese ✅
- But the SwiftUI `.commands` block L175-209 + `CommandGroup(replacing: .appSettings) { SettingsLink }` installs SettingsLink → macOS 27 lazy populate (Q15/Q16 crash chain, 8/19 ticket 01 ground-truth report) → SwiftUI injects English "wenshu" as the first menu + a duplicate Settings item
- What 老板 sees as "the first menu bar item should change from wenshu to 文枢" = the English wenshu injected by SwiftUI, not the 文枢 installed by NSMenu
- Root cause = NSMenu + SwiftUI .commands install the menu twice (two install paths) → SwiftUI .commands wins on macOS 27

### 3. Settings menu — root cause

- Current L237-241 = 3 items: `关于文枢` + `设置…` + `退出文枢`
- `关于文枢` + `退出文枢` = NSApplication's two standard items (orderFrontStandardAboutPanel + terminate)
- `设置…` = NSMenu's own addition + SwiftUI's SettingsLink also installs it = duplicate
- 老板 拍 Q3=B = "keep 设置…, but it must trigger SettingsView" → `设置…` is kept, must trigger the real SettingsView (cannot use action=nil)

## Fix (1 ticket 1 commit hard rule)

### Ticket 07 — LOGO dark/light automatically follows the system theme

#### Business language

- macOS system = Dark Mode, Dock + Launchpad + cmd+tab shows the dark LOGO
- macOS system = Light Mode, Dock + Launchpad + cmd+tab shows the light LOGO
- When the user switches system appearance, LOGO follows automatically

#### Fix ground truth (3 steps)

1. Copy `wenshu-icon-dark.icns` (367481, 8 reps ic04/07/10/11/12/13/14/info) → `Sources/WenshuApp/Resources/AppIcon.dark.icns`
2. Copy `wenshu-icon-light.icns` (369946, 8 reps) → `Sources/WenshuApp/Resources/AppIcon.light.icns`
3. Modify `Scripts/build-app.sh` to also `cp` both into `build/Wenshu.app/Contents/Resources/AppIcon.dark.icns` + `AppIcon.light.icns`

#### Apple HIG ground-truth references

- App icon dark/light: https://developer.apple.com/design/human-interface-guidelines/app-icons
- Asset catalog dark/light variant: https://developer.apple.com/documentation/xcode/supporting-multiple-appearances-in-your-app-s-icons
- macOS 27 Resources paradigm: `AppIcon.dark.icns` / `AppIcon.light.icns` suffix, AppKit picks automatically based on effectiveAppearance

#### Do not touch

- `AppIcon.icns` (fallback universal version, keep)
- App.swift / Package.swift / Info.plist / menu bar (unrelated to this ticket)

### Ticket 08 — Menu bar deduplicate + Settings menu triggers SettingsView

#### Business language

- Menu bar first menu = "文枢" (Chinese, no longer English wenshu)
- Under "文枢" the Settings menu keeps the 2 official built-in items = `关于文枢` + `退出文枢` + 1 real `设置…` (clicking it triggers SettingsView)
- macOS 27 will not simultaneously show the English menu injected by SwiftUI

#### Fix ground truth (3 steps)

1. Delete App.swift L183-209 SwiftUI `.commands` block (`CommandMenu("视图")` + `CommandGroup(replacing: .appSettings) { SettingsLink }`)
   - The View menu's `恢复默认布局` is the NSMenu ground truth — delete SwiftUI .commands, install via NSMenu
2. In App.swift L239, change `设置…` action so it is not nil, hooked up to a real trigger for SettingsView
   - Add `SettingsView` ground truth (struct in `App.swift` same file, empty content placeholder is enough)
   - Use `Selector(("showSettingsWindow:"))` or `@objc func showSettingsWindow(_ sender: Any)` for the action
3. Fix menu structure to match 8/10 ground truth: `Apple, 文枢, 文件, 编辑, 显示, 窗口, 帮助`

#### Apple HIG ground-truth references

- Settings window macOS paradigm: https://developer.apple.com/design/human-interface-guidelines/settings
- NSMenu Apple menu auto-add: macOS LaunchServices auto-adds the Apple menu as the first item, we install 6 items + Apple auto = 7 items
- Delete SwiftUI .commands: root cause 8/19 ticket 01 report (vdhamer/Photo-Club-Hub-HTML#248 macOS 27 beta lazy populate bug)

#### Do not touch

- AppIcon ground truth (unrelated to this ticket)
- LayoutShellView / ZoneModule / drag line (unrelated to this ticket)
- ChatView / AgentRuntime (unrelated to this ticket)

## po main flow 6 steps

1. ✅ grill-with-docs (Q1=Q2=Q3 options decided)
2. ✅ to-spec (this file)
3. → to-tickets (`.scratch/2026-08-20-logo-macos27/issues/07-08-*.md`)
4. → implement (split 1 ticket 1 commit into 07 + 08)
5. → code-review (dual axis Standards + Spec)
6. → domain-modeling (add macOS27AppearanceIcon domain word to CONTEXT.md)

## Q22 real verification (must run after commit)

1. `./Scripts/build-app.sh` exit 0
2. `codesign --verify --verbose=2 build/Wenshu.app` exit 0
3. `ls -la build/Wenshu.app/Contents/Resources/AppIcon*.icns` confirm all 3 in place
4. `open build/Wenshu.app` launch new binary, toggle system appearance dark/light → 老板 macOS verifies Dock LOGO follows automatically
5. Toggle macOS system appearance dark/light + cmd+shift+3 screenshot (老板 real verification)
6. Menu bar real verification: switch to SettingsView to see SettingsView render (no functionality needed, placeholder is enough)