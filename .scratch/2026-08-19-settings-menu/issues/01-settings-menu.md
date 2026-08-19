# 01 — 文枢菜单下加 "设置..." 菜单项 (Apple HIG macOS 真值)

**What to build:**
老板 2026-08-19 反馈: wenshu 启 app 后菜单栏 "文枢" 顶级下找不到 "设置..." 菜单项. 代码已经写了 Settings scene 但菜单栏没入口.

改完:
- WenshuApp.body .commands {} 里加 CommandGroup(replacing: .appSettings)
- 用 SettingsLink 打开现有 Settings scene
- 快捷键 ⌘, (Apple 标准)
- 现有 Settings { Form { Picker("外观") } } 保留

**Blocked by:** None

**Status:** ready-for-agent → impl done → 等老板验

## Acceptance criteria

- [ ] .commands {} 加 CommandGroup(replacing: .appSettings) 注入 "设置..." 菜单项
- [ ] 菜单项快捷键 ⌘, (Apple HIG 标准)
- [ ] 点击菜单项 / 按 ⌘, → 打开现有 Settings 弹窗 (外观 dark / light / 跟随系统)
- [ ] 菜单栏其他项不变 (文枢 / 文件 / 编辑 / 显示 / 视图 / 窗口 / 帮助)
- [ ] swift build exit 0
- [ ] 不引入新依赖 (SwiftUI 内置 SettingsLink, macOS 14+)
- [ ] macOS chrome 52 PT 不动
- [ ] D_h / D_v 5 竖拖拽线不动
- [ ] cursor 不动 (backlog 02 待办)
- [ ] Settings scene 内容不动 (外观 Picker)

## 业务语言描述 (老板懂)

- 菜单栏 "文枢" 顶级下加 "设置..." (跟 Pages / Numbers / Xcode 一样)
- 快捷键 ⌘,
- 点击弹现有设置弹窗 (外观 dark / light / 跟随系统)