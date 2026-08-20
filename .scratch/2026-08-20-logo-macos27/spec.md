# Spec — 项目 LOGO dark/light + 菜单栏 + 设置菜单清理 (老板 2026-08-20 拍)

> Date: 2026-08-20 10:35
> 老板 2026-08-20 10:35 拍 "LOGO 有了, 但没有跟随系统主题. APP 名 = 中文文枢. 菜单栏第一个菜单从 wenshu 改成文枢, 文枢下设置菜单有两个, 保留官方自带的"
> 老板 拍板 Q1=A (dark+light 都塞进项目 + 保留原 AppIcon.icns) / Q2=A (删 .commands 段, NSMenu 独家) / Q3=B (保留 设置…, 但要 trigger SettingsView)

## 真因链

### 1. LOGO 不跟随主题真因

- macOS 27 AppKit 范式 = Resources 目录同时塞 `AppIcon.icns` (fallback) + `AppIcon.dark.icns` + `AppIcon.light.icns`
- AppKit 按 `effectiveAppearance` (dark/light) 自动选 icns, **不需 App.swift runtime 装**
- 当前项目内只有 `AppIcon.icns` (473 KB / 11 reps, 8/20 9:26 落地, 通用版), 没有 dark/light 分版
- 桌面 `wenshu-icon-dark.icns` (367481 bytes) + `wenshu-icon-light.icns` (369946 bytes) = 8/11 v0.03.0 LOGO master 工具链重导的真值
- 真因 = 桌面 dark/light 文件没复制进项目

### 2. 菜单栏 wenshu 第一菜单真因

- NSMenu L236 `NSMenu(title: "文枢")` 已是中文 ✅
- 但 SwiftUI `.commands` 段 L175-209 + `CommandGroup(replacing: .appSettings) { SettingsLink }` 装 SettingsLink → macOS 27 lazy populate (Q15/Q16 翻车链, 8/19 ticket 01 真值报告) → SwiftUI 注入英文 "wenshu" 第一菜单 + 重复设置项
- 老板看到的 "菜单栏第一个菜单从 wenshu 改成文枢" = SwiftUI 注入的英文 wenshu, 不是 NSMenu 装的中文文枢
- 真因 = NSMenu + SwiftUI .commands 重复装菜单 (两个装菜路径) → SwiftUI .commands 在 macOS 27 占上风

### 3. 设置菜单真因

- 当前 L237-241 = 3 项: `关于文枢` + `设置…` + `退出文枢`
- `关于文枢` + `退出文枢` = NSApplication 标准 2 项 (orderFrontStandardAboutPanel + terminate)
- `设置…` = NSMenu 自己加的 + SwiftUI SettingsLink 也装 = 重复
- 老板拍 Q3=B = "保留 设置…, 但要 trigger SettingsView" → `设置…` 保留, 必须 trigger 真 SettingsView (不能 action=nil)

## 修法 (1 ticket 1 commit 硬约束)

### Ticket 07 — LOGO dark/light 自动跟随系统主题

#### 业务语言

- macOS 系统 = Dark Mode, Dock + Launchpad + cmd+tab 显示 LOGO 深色版
- macOS 系统 = Light Mode, Dock + Launchpad + cmd+tab 显示 LOGO 浅色版
- 用户切换系统外观, LOGO 自动跟随

#### 改法真值 (3 步)

1. 复制 `wenshu-icon-dark.icns` (367481, 8 reps ic04/07/10/11/12/13/14/info) → `Sources/WenshuApp/Resources/AppIcon.dark.icns`
2. 复制 `wenshu-icon-light.icns` (369946, 8 reps) → `Sources/WenshuApp/Resources/AppIcon.light.icns`
3. 改 `Scripts/build-app.sh` 同步 cp 两份到 `build/Wenshu.app/Contents/Resources/AppIcon.dark.icns` + `AppIcon.light.icns`

#### Apple HIG 真值引用

- App icon dark/light: https://developer.apple.com/design/human-interface-guidelines/app-icons
- Asset catalog dark/light variant: https://developer.apple.com/documentation/xcode/supporting-multiple-appearances-in-your-app-s-icons
- macOS 27 Resources 范式: `AppIcon.dark.icns` / `AppIcon.light.icns` 后缀, AppKit 按 effectiveAppearance 自动选

#### 不动

- `AppIcon.icns` (fallback 通用版, 保留)
- App.swift / Package.swift / Info.plist / 菜单栏 (跟本 ticket 无关)

### Ticket 08 — 菜单栏去重 + 设置菜单 trigger SettingsView

#### 业务语言

- 菜单栏第 1 菜单 = "文枢" (中文, 不再是英文 wenshu)
- "文枢" 下设置菜单保留 2 个官方自带 = `关于文枢` + `退出文枢` + 1 个真 `设置…` (点开触发 SettingsView)
- macOS 27 不会同时看到 SwiftUI 注入的英文菜单

#### 改法真值 (3 步)

1. 删 App.swift L183-209 SwiftUI `.commands` 段 (`CommandMenu("视图")` + `CommandGroup(replacing: .appSettings) { SettingsLink }`)
   - 视图菜单走 `恢复默认布局` 是 NSMenu 真值, SwiftUI .commands 删, NSMenu 装
2. App.swift L239 `设置…` 改 action 不为 nil, 接真 trigger SettingsView
   - 加 `SettingsView` 真值 (`App.swift` 同文件 struct, 默认空 content placeholder 即可)
   - action 用 `Selector(("showSettingsWindow:"))` 或 `@objc func showSettingsWindow(_ sender: Any)`
3. 修 menu structure 跟 8/10 真值一致: `Apple, 文枢, 文件, 编辑, 显示, 窗口, 帮助`

#### Apple HIG 真值引用

- Settings window macOS 范式: https://developer.apple.com/design/human-interface-guidelines/settings
- NSMenu Apple menu 自动加: macOS LaunchServices 自动加 Apple menu 在第一, 我们装 6 项 + Apple 自动 = 7 项
- 删 SwiftUI .commands: 真因 8/19 ticket 01 report (vdhamer/Photo-Club-Hub-HTML#248 macOS 27 beta lazy populate bug)

#### 不动

- AppIcon 真值 (跟本 ticket 无关)
- LayoutShellView / ZoneModule / 拖拽线 (跟本 ticket 无关)
- ChatView / AgentRuntime (跟本 ticket 无关)

## po main flow 6 步

1. ✅ grill-with-docs (Q1=Q2=Q3 选项已拍)
2. ✅ to-spec (本文件)
3. → to-tickets (`.scratch/2026-08-20-logo-macos27/issues/07-08-*.md`)
4. → implement (1 ticket 1 commit 拆 07 + 08)
5. → code-review (双轴 Standards + Spec)
6. → domain-modeling (CONTEXT.md 加 macOS27AppearanceIcon domain word)

## Q22 真验证 (commit 后必跑)

1. `./Scripts/build-app.sh` exit 0
2. `codesign --verify --verbose=2 build/Wenshu.app` exit 0
3. `ls -la build/Wenshu.app/Contents/Resources/AppIcon*.icns` 确认 3 份都到位
4. `open build/Wenshu.app` 启新 binary, 系统外观切 dark/light → 老板 macOS 验 Dock LOGO 自动跟随
5. macOS 系统外观切 dark/light + cmd+shift+3 截图 (老板真验)
6. 菜单栏真验: 切到 SettingsView 看 SettingsView 渲染 (不需要功能, 占位即可)