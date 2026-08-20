# Spec — 菜单栏 + Dock logo 真值报告 (老板 2026-08-20 拍)

> Date: 2026-08-20
> 老板 2026-08-20 拍 "1. macOS 还是没有菜单栏, dock 里也没有应用 LOGO 2. 鼠标还是没有变形 3. 先解决这两个再去解决聊天区"

## 真因 (deleg_a9c4fde9 47 分钟 跑完真值报告)

### 真因 1: 菜单栏不可见
- `CommandGroup(replacing: X) { }` 不删除 group — 替换为空 group,每个空 group 仍贡献 separator
- WenshuAppDelegate 在 SwiftUI 完成 main menu 之前动了 NSWindow
- macOS 27 beta lazy menu populate = 整个顶部菜单栏根本没安装
- 真值: vdhamer/Photo-Club-Hub-HTML#248 (open since 2026-08-13) 公开记录

### 真因 2: Dock 没 logo
- wenshu 没设 `NSApplication.shared.applicationIconImage`
- macOS 27 默认 fallback 到 system generic icon
- 真值: NSApplication.applicationIconImage 真值 API

### 真因 3: cursor 不变形
- v0.17 ticket 03 已 commit 47055fc5e + cursor 真因报告 v2 实证: NSHostingView 不 propagate AppKit cursor rects 到 SwiftUI 子树
- commit f65bb3292 加了 `.pointerStyle(orientation == .vertical ? .columnResize : .rowResize)` 但挂错层 = ZStack 父级 vs NativeSplitter body 内部
- 真值: `.pointerStyle` 必须在原生 NSView / NSViewRepresentable 的 SwiftUI view 树外层

## 修法 (老板拍 C: 2 ticket)

### Ticket 1 — 菜单栏 + Dock logo (1 commit)

**修法真值**:
- 菜单栏: 注释 WenshuAppDelegate.applicationDidFinishLaunching setContentSize/center/guards (避免 SwiftUI 完成 main menu 之前动 NSWindow)
- 菜单栏: 保留 .commands { CommandMenu/CommandGroup/SettingsLink } — 真值 (v0.17 ticket 07 改后 commit 4c42fa79)
- Dock logo: NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon") 启动时设
- 工程管理老板授权 (8/19 拍 "你自行决策") + 不需要验收

**改法**:
- Sources/WenshuApp/App.swift WenshuAppDelegate.applicationDidFinishLaunching:
  1. 保留 SelfScreenshot.run() 逻辑
  2. 删 setContentSize / center (避免触发 macOS 27 lazy menu populate bug)
  3. 加 NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon") 真值
  4. 保留 chat agent 注册 (v0.20 ticket 01)
- Assets.xcassets 加 AppIcon appiconset (wenshu logo 真值)
- 修改后 build clean

### Ticket 2 — cursor 切 ↕/↔ (1 commit)

**修法真值**:
- 删 commit f65bb3292 挂在 ZStack 父级的 `.pointerStyle` (位置错, NSViewRepresentable 桥接 SplitterHitAreaRepresentable 不能传 SwiftUI cursor 系统)
- 改挂到 NativeSplitter body 的 Rectangle 视觉上 (SwiftUI view tree 内层) — SwiftUI `.pointerStyle` 修饰符穿透 NSViewRepresentable 桥接到 SwiftUI view tree,NSHostingView 接管 cursor event → SwiftUI PointerStyle 系统 work
- 工程管理老板授权 + 不需要验收

**改法**:
- Sources/WenshuApp/Views/Layout/NativeSplitter.swift:
  1. 删 ZStack 父级 .pointerStyle (commit f65bb3292 挂错位置)
  2. Rectangle 视觉上加 .pointerStyle(orientation == .vertical ? .columnResize : .rowResize)
- 修改后 build clean
- Q22 真验证: Apple HIG 真值 + Apple SDK 真值 (VStack parent) + 真鼠标 hover 验证

## 不动

- /Volumes/ANAN/.hermes/ 任何文件 (老板 8/11 拍 'hermes 不动', read-only 盘)
- wenshu 6 区 layout 框架 (LayoutShellView / LayoutTokens / bandH 全保持)
- macOS chrome 52 PT (.windowStyle(.titleBar))
- 拖拽线视觉 (1 PT fill / 3 PT hover / 1 PT hit area / 系统色 / 不圆头)
- WenshuCore 14 真值模块 (Memory / Skill / Agent / Kanban / Todo / Tools / Cron / Backup / MiniMaxVerifier)
- ChatView (v0.20 ticket 01) (留作后续优化)

## 真值引用 (Apple HIG)

- NSApplication applicationIconImage: https://developer.apple.com/documentation/appkit/nsapplication/applicationiconimage
- NSMenu 真值: https://developer.apple.com/documentation/appkit/nsmenu
- SwiftUI .commands 真值: https://developer.apple.com/documentation/swiftui/scene/commands
- SwiftUI CommandMenu: https://developer.apple.com/documentation/swiftui/commandmenu
- SwiftUI CommandGroup: https://developer.apple.com/documentation/swiftui/commandgroup
- SwiftUI SettingsLink: https://developer.apple.com/documentation/swiftui/settingslink
- SwiftUI .pointerStyle: https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)
- SwiftUI PointerStyle.columnResize: https://developer.apple.com/documentation/swiftui/pointerstyle/columnresize
- SwiftUI PointerStyle.rowResize: https://developer.apple.com/documentation/swiftui/pointerstyle/rowresize

## 业务语言描述 (老板懂)

- 菜单栏不可见: 老板拍 8/19 evening, commit 464d4f344 删 WenshuAppDelegate setContentSize 修了一部分, 但实际启 wenshu 没看到菜单栏
- Dock 没 logo: wenshu 没设 applicationIconImage, dock 显示 generic icon
- cursor 不变形: 8/19 evening commit f65bb3292 加了 .pointerStyle 但位置错, 鼠标实际不变形

修法: 2 ticket 拆 2 commit, 1 ticket 1 commit 真值 (老板 8/19 工程管理授权 + 1 ticket 1 commit 硬规则)

## 老板拍的下一步

- 实施 ticket 1: 菜单栏 + Dock logo
- 实施 ticket 2: cursor 切 ↕/↔
- 修完后再回到 chat UI 优化 (v0.20 ticket 01 chat UI 真正能打字 + AI 回复真值)