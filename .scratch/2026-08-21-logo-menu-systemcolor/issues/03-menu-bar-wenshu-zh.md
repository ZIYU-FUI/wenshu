# 03 — 菜单栏"wenshu"改"文枢" (删 WindowGroup title + SettingsScene)

**What to build:**
老板 2026-08-21 验菜单栏: "我只有 wenshu, 这个菜单是英文, 其它都对". NSMenu L218-251 装的就是中文"文枢"真值, 但 macOS 27 SwiftUI `WindowGroup("文枢")` 第 1 参数 title = "文枢" → SwiftUI 期望装 1 个菜单, macOS 27 lazy populate 注入时机晚于 NSMenu.applicationWillFinishLaunching, SwiftUI 覆盖 NSMenu 装的中文"文枢" 为英文 "wenshu".

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## 修法真值 (3 步)

1. App.swift L176 `WindowGroup("文枢") { LayoutShellView() }` 第 1 参数 title 删, 改 `WindowGroup { LayoutShellView() }` (让 SwiftUI 不注入 wenshu 菜单)
2. App.swift L186 `Settings { }` Scene 改 `SettingsScene` 范式 (SwiftUI 5+ macOS 14+ 支持), 自己 control menu 安装
3. 跑 `killall Dock` 清 macOS Dock 缓存 (Dock 缓存了 menu bar)
4. 1 ticket 1 commit + 老板 macOS 验第 1 项是"文枢"不是"wenshu"

## Acceptance

- [ ] WindowGroup 第 1 参数 title 删 (App.swift L176)
- [ ] SettingsScene 替换 Settings (App.swift L186)
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 验 menu bar 第 1 项 = "文枢" (中文, 不是英文 wenshu)

## 不动 (Q20 硬约束)

- NSMenu L218-251 装的中文 6 项 (ticket 08 已落地)
- ChatView / LayoutShellView (跟本 ticket 无关)
- v0.20 ticket 08 SettingsLink trigger 机制 (SettingsScene 仍 trigger SwiftUI Settings)

## Apple HIG 真值引用

- https://developer.apple.com/documentation/swiftui/windowgroup (title 参数 = SwiftUI lazy populate 菜单名)
- https://developer.apple.com/documentation/swiftui/settingsscene
- vdhamer/Photo-Club-Hub-HTML#248 (SwiftUI .commands 在 macOS 27 lazy populate bug)

## 关联

- 依赖: 无
- 被依赖: 无