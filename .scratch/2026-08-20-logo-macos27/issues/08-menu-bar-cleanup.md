# 08 — 菜单栏去重 + 设置菜单 trigger SettingsView (老板 2026-08-20 拍)

**What to build:**

老板 2026-08-20 10:35 拍 "APP 名 = 中文文枢. 菜单栏第一个菜单从 wenshu 改成文枢, 文枢下设置菜单有两个, 保留官方自带的". 工程管理老板授权 (8/19 拍 "你自行决策") + 1 ticket 1 commit 硬约束 + po main flow 6 步.

## 修法真值

1. 删 App.swift L183-209 SwiftUI `.commands` 段 (`CommandMenu("视图")` + `CommandGroup(replacing: .appSettings) { SettingsLink }`)
   - 真因: SwiftUI .commands 在 macOS 27 lazy populate, 注入英文 wenshu 第一菜单 (8/19 ticket 01 翻车链, vdhamer/Photo-Club-Hub-HTML#248)
   - NSMenu 已装"文枢" 真值, 不需要 SwiftUI 重复装
2. App.swift L239 `设置…` action 改 trigger SettingsView
   - 加 `SettingsView` SwiftUI struct (`App.swift` 同文件, 占位 content 即可)
   - action 用 `@objc func showSettingsWindow(_ sender: Any)`
3. NSMenu 6 项 + Apple menu 自动 = 7 项真值: `Apple, 文枢, 文件, 编辑, 显示, 窗口, 帮助`

## Acceptance

- 启动 `open build/Wenshu.app`, 菜单栏第 1 菜单 = "文枢" (中文, 不是英文 wenshu)
- "文枢" 下 = `关于文枢` + `设置…` + `退出文枢` (3 项, `设置…` 可点开)
- 点 `设置…` 真触发 SettingsView 窗口 (SwiftUI 占位)
- 6 项 + Apple menu 自动 = 7 项真值, 顺序 `Apple, 文枢, 文件, 编辑, 显示, 窗口, 帮助`
- 老板 macOS 截图验菜单栏无英文 wenshu

## 不动

- AppIcon 真值 (跟本 ticket 无关, ticket 07 落地)
- LayoutShellView / ZoneModule / 拖拽线 (跟本 ticket 无关)
- ChatView / AgentRuntime (跟本 ticket 无关)

## 真值引用 (Apple HIG)

- Settings window macOS 范式: https://developer.apple.com/design/human-interface-guidelines/settings
- NSMenu Apple menu 自动加: macOS LaunchServices 自动加 Apple menu 在第一, 我们装 6 项 + Apple 自动 = 7 项