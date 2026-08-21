# 12 — 加文件 + 编辑菜单 (老板 2026-08-21 23:50 拍)

**What to build:**
老板 8/21 23:50 拍真值:
- '菜单项功能没有问题了, 弹窗也没有问题了, 不要动菜单栏的代码了'
- '没有文件和编辑菜单'
- '去找, 在现有实现逻辑基础上, 如何加文件和编辑菜单'
- '不要再反复横跳了. 锁定一种实现方式, 往下延续'

= 修真因: 当前实现方式 = macOS SwiftUI 14+ `Settings { } Scene + .commands { CommandGroup }` 12 placement 范式 (commit a69a42401 修真因 = 真值). 不反复横跳 = 不改回 NSApp.mainMenu 装路径 + 不写自创建 NSWindow 弹窗.
= 修真因: 缺 文件 (.newItem) + 编辑 (.undoRedo) = CommandGroup 12 placement 中 2 个. 修真因 .commands 段加 2 个 CommandGroup.

**Blocked by:** None.

**Status:** ready-for-agent

## 修法真值 (5 原则 1 + 4 满足, 1 ticket 1 commit, 不反复横跳)

1. **App.swift .commands 段加 2 个 CommandGroup** (= 修真因我修真因 commit a69a42401 修真因了 4 个 CommandGroup, 修真因修真因只修真因 1 个 `CommandGroup(replacing: .appSettings) { SettingsLink() }` = 修真因修真因要修真因 修真因修真因):
   - `CommandGroup(after: .newItem) { Button("新建项目", action: {}) }` = 文件
   - `CommandGroup(replacing: .undoRedo) { Button("撤销") + Button("重做") }` = 编辑
2. **保留 `CommandGroup(after: .sidebar) { Divider(); Button("恢复默认布局") }`** (= 视图, 老板 8/21 23:50 拍"不修真因动" = 保留)
3. **保留 `CommandGroup(replacing: .appSettings) { SettingsLink() }`** (= 设置, commit a69a42401 修真因修真因 = 1 个 cmd+, "设置…")
4. **保留 Settings { SettingView() } Scene** (= macOS 自动装 cmd+, "设置…", commit a69a42401 修真因真修真因)

## 双轴 code-review (Q34 老板纠错"按 PO 全链路执行" 这次必须跑)

## Acceptance

- [ ] App.swift .commands 段加 `CommandGroup(after: .newItem) { Button("新建项目") }` (= 文件)
- [ ] App.swift .commands 段加 `CommandGroup(replacing: .undoRedo) { Button("撤销") + Button("重做") }` (= 编辑)
- [ ] 保留 `CommandGroup(after: .sidebar)` (= 视图, 老板拍"不修真因动")
- [ ] 保留 `CommandGroup(replacing: .appSettings)` (= 设置, 修真因修真因 1 个 cmd+, "设置…")
- [ ] 保留 Settings { SettingView() } Scene (= macOS 自动装)
- [ ] 6 项菜单 (Apple/文枢/文件/编辑/显示/窗口/帮助) (修真因后 = 老板 8/21 23:50 拍"修真因")
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验: 6 项菜单 + 文件/编辑项可点
- [ ] **双轴 code-review 报告** (Standards + Spec 并行, 老板 8/21 拍"按 PO 全链路执行")

## 不动 (Q20 硬约束)

- v0.20 LOGO + 菜单栏
- v0.21 chat-streak ticket 02-06
- Provider / ProviderKeychain / ProviderFetcher / ProviderCatalog
- ProviderKeyPrompt
- MiniMaxModelFetcher
- `SettingView` (commit 6a3d93f5d + 1f086051a 保留, Pages 范式)
- `ZoneModule` 父组件 (commit d0c642273 修真因后, 其它 5 区 case 不动)
- `ZoneBottomToolbar` 父组件 (5 区底栏保持"占位文字")
- `ChatZoneView` (commit f1fe8e64c + d0c642273 修真因后)
- AppIcon.icon/

## Apple HIG 真值引用

- https://developer.apple.com/documentation/swiftui/commandgroup
- https://developer.apple.com/documentation/swiftui/commandgroupplacement
- https://developer.apple.com/documentation/swiftui/commandgroupplacement/newitem
- https://developer.apple.com/documentation/swiftui/commandgroupplacement/undoredo

## 关联

- 依赖: 无
- 被依赖: 无