# Spec — 菜单栏不可见修法 (老板 2026-08-19 拍)

> Date: 2026-08-19
> Spec 走 po `to-spec` skill 7 段模板

## Problem Statement

老板 2026-08-19 反馈多次: 启 wenshu app 后整个 macOS 顶部菜单栏没看到 (比"找不到设置"更严重, 整个菜单栏不存在).

deleg_a9c4fde9 跑 47 分钟 + 120 tool calls 查 Apple 真值找到真因 (P0):
- vdhamer/Photo-Club-Hub-HTML#248 (open since 2026-08-13) 公开记录
- `CommandGroup(replacing: X) { }` 不删除 group — 它替换为空 group, 每个空 group 仍然贡献 separator
- SwiftUI 层 API 不能清理自己留下的东西
- WenshuAppDelegate 在 SwiftUI 完成 main menu 之前动了 NSWindow
- macOS 27 beta lazy menu populate = 整个顶部菜单栏根本没安装

## Solution (老板 2026-08-19 19:55 拍 A: 注释 WenshuAppDelegate + .commandsReplaced 强制 install)

业务语言描述 (老板懂):
- macOS 系统的 menu 加载机制在 macOS 27 beta 改了: SwiftUI 自己装菜单栏, 但如果有人先动了 NSWindow (像我们 WenshuAppDelegate.applicationDidFinishLaunching 在 setContentSize / center 那样), macOS 系统就放弃装菜单栏了
- 修法: 让 SwiftUI 自己装菜单栏, 我们 WenshuAppDelegate 不再提前动 NSWindow — 改在 SwiftUI 自己装好菜单栏后再 setContentSize / center
- 加 `.commandsReplaced` 强制 install (Apple 官方提供, 不知道是不是真有效先加, 验过删)

### Implementation Decisions

- 修法 (选项 A):
  1. 删 `WenshuAppDelegate.applicationDidFinishLaunching` 里的 `setContentSize` / `center` 提前动 NSWindow 代码
  2. 改在 WenshuApp.body 加 `.commandsReplaced(...)` 强制 install main menu
  3. WindowGroup contentLayout 改用 `LayoutTokens.designW` × `designH` 比例算子
  4. WenshuAppDelegate 留 `applicationDidFinishLaunching` 但只做 SelfScreenshot (WS_SCREENSHOT env)
- 备选 (选项 B): 加 `NSApp.mainMenu?.items.forEach { $0.submenu?.update() }` 在 applicationDidFinishLaunching 末尾 (如果 A 失败, 加这一行再 build)
- 备选 (选项 C): 用 `.commandsReplaced` 强制 install (跟 A 同时加)

### Implementation Steps

1. WenshuApp.body WindowGroup 加 `.commandsReplaced { ContentView() }` (强制 install main menu)
2. WenshuAppDelegate.applicationDidFinishLaunching:
   - 删 `setContentSize` + `center` + `guards` (提前动 NSWindow 的代码)
   - 留 SelfScreenshot 调用
3. WenshuApp.body 用 `.windowStyle(.titleBar)` + `.defaultSize` (SwiftUI 提供 initial size hint)
4. WenshuApp.body layout 内部用 GeometryReader + 比例算子自适应 resize

## User Stories

1. As 老板, I want macOS 顶部菜单栏可见, so that 整个 app 跟 Pages / Numbers / Xcode 一样
2. As 老板, I want "文枢" 顶级下能看到 "设置..." (⌘,), so that 跟 macOS 标准一致
3. As 老板, I want "文件" 顶级下能看到 "新建项目" (⌘N), so that 老板能新建项目
4. As 老板, I want "视图" 顶级下能看到 "恢复默认布局" (⌘⇧R), so that 老板能一键重置布局
5. As 老板, I want 菜单栏其他项不变 (Apple / 文枢 / 文件 / 编辑 / 显示 / 视图 / 窗口 / 帮助)
6. As 老板, I want `swift build` exit 0

## Implementation Decisions

- 修法 (老板拍 A):
  - 注释 / 删 `WenshuAppDelegate.applicationDidFinishLaunching` 里的 `setContentSize` / `center` / `guards` (提前动 NSWindow 的代码)
  - 加 `.commandsReplaced { LayoutShellView() }` 强制 install main menu (Apple 官方 API, macOS 14+)
  - 留 WenshuAppDelegate 但只做 SelfScreenshot (WS_SCREENSHOT env)

## Testing Decisions

- 仅 `swift build clean` (exit 0), 老板自己启 app 截图验
- 验证: 顶部菜单栏可见, "文枢" → "设置..." / "文件" → "新建项目" / "视图" → "恢复默认布局"

## Out of Scope

- 不动 macOS chrome 52 PT
- 不动 LayoutTokens / bandH / toolbar 宽度
- 不动拖拽线 (cursor / hover / drag / 1 PT fill / 颜色 全保持)
- 不重写 .commands {} 内容 (只是命令组菜单项本身)
- 不加新菜单项

## Further Notes

- 真因报告: vdhamer/Photo-Club-Hub-HTML#248 (open since 2026-08-13)
- 老板只能验截图可见的需求 (cursor 切 / 菜单栏 / hover / 1 PT / 颜色 / 圆头 = 6 个), 拖动响应不能验
- 老板拍 A: 最小改动 (只改 WenshuAppDelegate.applicationDidFinishLaunching 提前动 NSWindow 那一块 + 加 .commandsReplaced)
- Apple HIG 真值引用 (8/15 bug debugging rule 要求):
  - https://developer.apple.com/documentation/swiftui/commandsreplaced
  - https://developer.apple.com/documentation/swiftui/app/commands
  - https://github.com/vdhamer/Photo-Club-Hub-HTML/issues/248