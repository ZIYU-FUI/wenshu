# 08 — Menu bar deduplication + Settings menu triggers SettingsView (老板 2026-08-20 拍)

**What to build:**

老板 2026-08-20 10:35 拍 "APP name = 文枢 in Chinese. The first menu bar item should change from wenshu to 文枢, and the 文枢 menu has two Settings items — keep the official one only". Engineering management authorized by 老板 (8/19 拍 "you decide on your own") + 1 ticket 1 commit hard rule + po main flow 6 steps.

## Fix ground truth

1. Delete App.swift L183-209 SwiftUI `.commands` block (`CommandMenu("视图")` + `CommandGroup(replacing: .appSettings) { SettingsLink }`)
   - Root cause: SwiftUI .commands on macOS 27 lazy populate injects the English wenshu first menu (8/19 ticket 01 crash chain, vdhamer/Photo-Club-Hub-HTML#248)
   - NSMenu has already installed "文枢" ground truth, no need for SwiftUI to reinstall
2. In App.swift L239, change `设置…` action to trigger SettingsView
   - Add `SettingsView` SwiftUI struct (in `App.swift` same file, placeholder content is enough)
   - Use `@objc func showSettingsWindow(_ sender: Any)` for the action
3. NSMenu 6 items + Apple menu auto = 7 items ground truth: `Apple, 文枢, 文件, 编辑, 显示, 窗口, 帮助`

## Acceptance

- Launch `open build/Wenshu.app`, menu bar first menu = "文枢" (Chinese, not English wenshu)
- Under "文枢" = `关于文枢` + `设置…` + `退出文枢` (3 items, `设置…` clickable)
- Clicking `设置…` actually triggers the SettingsView window (SwiftUI placeholder)
- 6 items + Apple menu auto = 7 items ground truth, order `Apple, 文枢, 文件, 编辑, 显示, 窗口, 帮助`
- 老板 macOS screenshot verifies menu bar has no English wenshu

## Do not touch

- AppIcon ground truth (unrelated to this ticket, ticket 07 landed)
- LayoutShellView / ZoneModule / drag line (unrelated to this ticket)
- ChatView / AgentRuntime (unrelated to this ticket)

## Ground-truth references (Apple HIG)

- Settings window macOS paradigm: https://developer.apple.com/design/human-interface-guidelines/settings
- NSMenu Apple menu auto-add: macOS LaunchServices auto-adds the Apple menu as the first item, we install 6 items + Apple auto = 7 items