# 07 — NSApp.mainMenu + Pages 范式 弹窗 (撤回 .commands + Settings Scene, 老板 2026-08-21 拍)

**What to build:**
老板 8/21 反馈: '两个显示, 没有文件和编辑' (= commit beff63b43 装后, 5 项菜单 + 2 个 设置… + 缺 文件/编辑)
老板 8/21 真值: '按 PO 全链路方法论执行, 不要我每个新会话都和你强调, 你不要跳步骤' (= Q34 双轴 code-review 必须跑, Q32 查官方, 5 原则 1 Apple 真值)

**真因 (Q32 audit 5 原则 1 真硬违反):**
macOS SwiftUI 真值真值 (Q28 swiftinterface + Apple 真值):
- `.commands` 修饰符在 `Settings { } Scene` 之后 = Settings 接管 main menu = .commands 装不到 main menu
- 之前我装在 Settings { } 之后 (commit d194cb66d + 491a6874b + beff63b43) 全部失败
- macOS SwiftUI Settings { } Scene 自动装 1 个 cmd+, (.appSettings)
- 我装 `CommandGroup(replacing: .appSettings) { SettingsLink() }` 重复装 1 个 = 老板截图 2 个 "设置…"

**Blocked by:** None.

**Status:** ready-for-agent

## 修法真值 (3 步, 5 原则 1 + 4 满足, Q32 真硬违反修复)

1. **App body 撤回 .commands { } 段 + Settings { } Scene** (commit d194cb66d + 491a6874b + beff63b43 全装撤回, Q32 5 原则 1 真硬违反)
2. **applicationWillFinishLaunching 撤回 NSApp.mainMenu 装** (commit 31b96953f 装, 时机不对被 SwiftUI 接管)
3. **applicationDidFinishLaunching 装 NSApp.mainMenu = installMainMenu()** (commit 9f77ffa9c 真值, 之前 work 真值真值)
4. **installMainMenu() 装 6 项真值真值** (commit 9f77ffa9c 真值)
5. **openSettingsWindow 自创建 NSWindow 装 SettingView** (commit 3f4faf68f 真值)
6. **SettingView 顶部 toolbar tab + 3 tab Pages 范式** (commit 6a3d93f5d 真值, 老板画的图 2 红框位置)

## 双轴 code-review (Q34 老板纠错"我没发现没走双轴", 这次必须跑)

## Acceptance

- [ ] App body 撤回 .commands + Settings Scene
- [ ] applicationWillFinishLaunching 撤回 NSApp.mainMenu 装
- [ ] applicationDidFinishLaunching 装 NSApp.mainMenu = installMainMenu()
- [ ] 6 项菜单装 (文枢/文件/编辑/显示/窗口/帮助, 老板 8/10 01:43)
- [ ] "设置…" 1 个 (NSMenu 装, 不重复 macOS swiftinterface 接管)
- [ ] "恢复默认布局" 接 NotificationCenter wenshuResetLayout
- [ ] openSettingsWindow 浮 windows 不挤走
- [ ] SettingView 顶部 toolbar tab + 3 tab Pages 范式
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS 真验: 6 项菜单 + 设置… 1 个 + 设置 sheet 浮 windows + 顶部 toolbar tab 切换
- [ ] **双轴 code-review 报告** (Standards + Spec 并行, 老板 8/21 拍"按 PO 全链路执行")

## 不动 (Q20 硬约束)

- v0.20 LOGO + 菜单栏
- v0.21 chat-streak ticket 02-06
- Provider / ProviderKeychain / ProviderFetcher / ProviderCatalog
- ProviderKeyPrompt
- MiniMaxModelFetcher
- `SettingView` 内容 (= commit 6a3d93f5d + 1f086051a 不动)
- `ChatBottomToolbar` (commit efa351f80 不动)
- AppIcon.icon/

## Apple HIG 真值引用

- https://developer.apple.com/documentation/appkit/nsapplication/mainmenu
- https://developer.apple.com/documentation/swiftui/commands
- https://developer.apple.com/documentation/swiftui/settings
- Pages macOS 27 设置面板 (真值真值)

## 关联

- 依赖: 无
- 被依赖: 无