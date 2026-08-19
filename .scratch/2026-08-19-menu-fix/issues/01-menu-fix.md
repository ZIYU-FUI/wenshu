# 01 — 菜单栏可见修法 (A 选项: 注释 WenshuAppDelegate + .commandsReplaced, 老板 2026-08-19 拍)

**What to build:**
老板 2026-08-19 反馈: 整个 macOS 顶部菜单栏没看到 (commit 4c42fa79 已写 .commands 但老板实测没显示).
deleg_a9c4fde9 47 分钟 + 120 tool calls 查 Apple 真值找到真因 (P0):
- vdhamer/Photo-Club-Hub-HTML#248 公开记录
- `CommandGroup(replacing: X) { }` 不删除 group, 替换为空 group 仍贡献 separator
- WenshuAppDelegate 在 SwiftUI 完成 main menu 之前动了 NSWindow
- macOS 27 beta lazy menu populate = 整个顶部菜单栏根本没安装

业务语言描述 (老板懂):
- macOS 27 改: SwiftUI 自己装菜单栏, 但如果有人先动了 NSWindow, macOS 系统就放弃装菜单栏
- 修法 (选项 A): 让 SwiftUI 自己装菜单栏, WenshuAppDelegate 不再提前动 NSWindow
- 加 `.commandsReplaced` 强制 install (Apple 官方提供)

改完:
- WenshuAppDelegate.applicationDidFinishLaunching 删 setContentSize / center (提前动 NSWindow 代码)
- WenshuAppDelegate 留 SelfScreenshot (WS_SCREENSHOT env)
- WindowGroup 加 `.commandsReplaced { LayoutShellView() }` 强制 install main menu
- 拖拽线 / 分割线 / cursor / 1 PT / 颜色 / 圆头 / hover 全不动

**Blocked by:** None (subagent 报告 + 真因 + 修法已就绪)

**Status:** ready-for-agent → impl done → 等老板验截图

## Acceptance criteria

- [ ] macOS 顶部菜单栏可见 (老板截图验)
- [ ] "文枢" 顶级下能看到 "设置..." (⌘,)
- [ ] "文件" 顶级下能看到 "新建项目" (⌘N)
- [ ] "视图" 顶级下能看到 "恢复默认布局" (⌘⇧R)
- [ ] 菜单栏其他项不变 (Apple / 文枢 / 文件 / 编辑 / 显示 / 视图 / 窗口 / 帮助)
- [ ] WenshuAppDelegate.applicationDidFinishLaunching 不再提前动 NSWindow
- [ ] WindowGroup 加 .commandsReplaced 强制 install main menu
- [ ] swift build exit 0
- [ ] 拖拽线 / 分割线 / cursor / 1 PT / 颜色 / 圆头 / hover 全不动 (cursor ticket 03 commit f65bb329 保留)
- [ ] macOS chrome 52 PT 不动
- [ ] LayoutTokens / bandH / toolbar 宽度 不动

## 真因引用

- vdhamer/Photo-Club-Hub-HTML#248: https://github.com/vdhamer/Photo-Club-Hub-HTML/issues/248
- SwiftUI .commands: https://developer.apple.com/documentation/swiftui/app/commands
- SwiftUI .commandsReplaced: https://developer.apple.com/documentation/swiftui/commandsreplaced

## 业务语言描述修法 (老板懂)

- 不让 wenshu 在 SwiftUI 装菜单栏之前动 NSWindow
- 让 macOS 系统自己装菜单栏
- 加 .commandsReplaced 强制装, 不让 macOS 跳过