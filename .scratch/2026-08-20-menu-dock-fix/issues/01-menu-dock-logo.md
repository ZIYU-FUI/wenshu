# 01 — 菜单栏可见 + Dock logo (老板 2026-08-20 拍)

**What to build:**
老板 2026-08-20 拍 "macOS 还是没有菜单栏, dock 里也没有应用 LOGO". 修法 ticket 01.

改完:
- WenshuAppDelegate.applicationDidFinishLaunching 删 setContentSize/center (避免 SwiftUI 完成 main menu 之前动 NSWindow, 真因 macOS 27 lazy menu populate bug)
- NSApplication.shared.applicationIconImage = NSImage(named: "AppIcon") 启动时设 (Dock logo 真值)
- 保留 .commands { CommandMenu/CommandGroup/SettingsLink } (v0.17 ticket 07 commit 4c42fa79)

**Blockers:** 老板 2026-08-20 拍 "先解决这两个再去解决聊天区".

**Acceptance:**
- swift build exit 0
- 老板启 wenshu 看到菜单栏 (截图验, 老板 8/19 evening 拍 "我只能验截图就能验的需求了")
- 老板看到 Dock logo (wenshu logo 替换 generic icon)
- 不动: hermes / 6 区 layout 框架 / 拖拽线视觉 / WenshuCore 14 真值模块 / ChatView
