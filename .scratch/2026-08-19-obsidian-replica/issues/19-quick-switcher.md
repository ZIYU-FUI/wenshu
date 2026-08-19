# 19 — Quick Switcher ⌘O fuzzy 搜索 (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian 复刻范围 A 第 8 件: Quick Switcher (⌘O fuzzy 搜索所有 note + 章节)。

**改完:**
- `Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcher.swift` (fuzzy 搜索 note + 章节)
- `Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcherWindow.swift` (SwiftUI Window 弹出, Apple Spotlight 同范式)
- �O 快捷键接 SwiftUI .commands

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria
- [ ] Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcher.swift fuzzy 搜索
- [ ] Sources/WenshuApp/Core/QuickSwitcher/QuickSwitcherWindow.swift Spotlight 范式
- [ ] ⌘O 快捷键接 SwiftUI .commands
- [ ] swift build exit 0
- [ ] 单元测试: QuickSwitcherTests (fuzzy 匹配)
- [ ] 不动 hermes app
- [ ] 不动 LayoutTokens / LayoutShellView

## 业务语言描述 (老板懂)
- 写作 app 强需求: 跨书架快速切换 note / 章节
- Apple Spotlight 同范式 (顶部居中弹出)

## 真值引用
- Obsidian Quick Switcher: https://obsidian.md/help/plugins/quick-switcher
- Apple Spotlight 范式 (macOS 14+ SwiftUI Window)
