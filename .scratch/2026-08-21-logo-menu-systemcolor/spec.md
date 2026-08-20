# Spec — LOGO 圆角 mask + 菜单栏全中文 + LOGO 跟系统色 (老板 2026-08-21 拍)

> Date: 2026-08-21
> 老板 2026-08-21 验 v0.20 logo ticket 08 后反馈: "LOGO 没有圆角, LOGO 没有跟随系统色, 菜单栏的 wenshu 还是没有修复成中文".
> 系统色已实现 (DesignColor 走 NSColor semantic), 本 spec 只盖 LOGO 圆角 + LOGO 跟系统色 + 菜单栏全中文 3 件.

## 业务语言 (老板懂)

### 1. LOGO 圆角

- macOS Dock / Launchpad / cmd+tab 显示 wenshu LOGO 时 = 圆角矩形 (Apple HIG 标准 mask)
- 不论 dark / light 系统外观, LOGO 都是圆角
- LOGO 内容不变, 只是 macOS 加圆角 mask

### 2. LOGO 跟随系统色

- 系统 = Dark Mode → Dock / Launchpad / cmd+tab 显示 dark 版 LOGO
- 系统 = Light Mode → Dock / Launchpad / cmd+tab 显示 light 版 LOGO
- 用户切系统外观, LOGO 自动跟 (这个 ticket 07 已落地, 但老板看到没跟 = 真因待查)

### 3. 菜单栏全中文

- 顶部菜单栏 7 项 = `Apple / 文枢 / 文件 / 编辑 / 显示 / 窗口 / 帮助`, 全中文
- 不再有英文 `File / Edit / View / Window / Help`
- macOS 27 lazy populate 注入的英文菜单不能再出现

## 真因链

### 1. LOGO 没圆角真因

- 当前 3 份 icns (`AppIcon.icns` 通用 + `AppIcon.dark.icns` + `AppIcon.light.icns`) **完全没 mask chunk**
- icns mask chunk 标准命名: `icp4` (16×16) / `icp5` (32×32) / `icp6` (64×64) / `icp7` (128×128) / `icp8` (256×256) / `icp9` (512×512) / `icp10` (1024×1024)
- mask = 8-bit grayscale PNG, 黑色 = 不透明, 白色 = 透明
- macOS Dock / Launchpad / cmd+tab 用 mask 加圆角
- 当前 icns 11 reps 都是 RGB PNG 无 alpha mask → Dock 不加圆角, 显示方角
- 真因 = icns 缺 mask chunk (Apple HIG 不达标准)

### 2. LOGO 没跟系统色真因

- ticket 07 落地了 `AppIcon.dark.icns` (367481 bytes, 8 reps) + `AppIcon.light.icns` (369946 bytes, 8 reps), AppKit 按 effectiveAppearance 自动选
- 但老板 macOS 看, 系统 dark 时 LOGO 还显 light → 不对
- 真因猜测 3 个:
  1. AppKit macOS 27 dark/light 自动选 icns 机制有 bug (但 Pages / Numbers 正常, 排除)
  2. macOS Dock 缓存了 icns (重启 Dock kill `killall Dock` 清缓存)
  3. icns 文件本身缺 macOS 27 required chunk (`ic07` with PNG + alpha channel or `s8mk` mask chunk), AppKit 不认这个 icns 当 dark/light variant

### 3. 菜单栏"wenshu"英文覆盖真因 (老板 8/21 补充)

- 老板截图显示菜单栏 = `Apple / wenshu / 文件 / 编辑 / 显示 / 窗口 / 帮助`
- 只有第 1 项 "wenshu" 是英文 (老板要求改"文枢"), 其他 5 项都是中文 (正确)
- NSMenu L218-251 装的就是中文 "文枢" 真值 (跟 Pages / Numbers / Xcode 同范式)
- 真因 = SwiftUI framework **自动装 1 个空的 "wenshu" 菜单 group** (不是装完整 File/Edit/View/Window/Help), 因为:
  1. `WindowGroup("文枢") { LayoutShellView() }` 第 1 参数 title = "文枢" → SwiftUI 期望装 1 个菜单, 但 macOS 27 lazy populate 注入时机晚于 NSMenu.applicationWillFinishLaunching, SwiftUI 覆盖 NSMenu 装的中文"文枢" 为英文 "wenshu"
  2. `Settings { }` Scene 内部装 1 个空 CommandGroup(.appSettings), 但不影响第 1 菜单
- 老板要求 = "只 wenshu 这个菜单是英文, 其它都对" → NSMenu 已对, 但第 1 项被 SwiftUI 覆盖, 修法 = 删 WindowGroup 第 1 参数 title, 让 NSMenu 装的中文"文枢" 不被 SwiftUI 覆盖

## 修法 (3 ticket, 1 ticket 1 commit)

### Ticket 01 — LOGO 圆角加大 (重导 master + iconutil 重生 icns)

#### 业务语言
- macOS Dock / Launchpad / cmd+tab 显示 wenshu LOGO = Apple HIG 标准圆角 (= 22% 半径, 1024×1024 下 ≈ 225 半径)
- LOGO 设计源头改 = 设计师重导 master, 数据流走 iconutil 自动生 icns
- 3 份 icns (dark / light / mono) 全部按新 master 重导

#### 修法真值 (4 步)
1. 老板去 Sketch master 改主图圆角矩形路径, 1024×1024 下半径加大到 22% (≈ 225 半径)
2. 老板重导 3 个主图 PNG:
   - `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024-dark.png`
   - `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024-light.png`
   - `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024-mono.png`
3. 我用 iconutil 重生 3 份 icns:
   - 建 `wenshu-icon.iconset/` 目录, 跑 `sips -z <size> <png>` 生 11 个 retina 标准 reps (16/32/64/128/256/512/1024 + @2x), 重命名成 iconutil 标准 (`icon_16x16.png` + `icon_16x16@2x.png` 等)
   - 跑 `iconutil -c icns wenshu-icon.iconset/ -o AppIcon.dark.icns` (3 份各跑一次)
4. cp 3 份进 `Sources/WenshuApp/Resources/`, 改 `Scripts/build-app.sh` 加 cp mono. icns
5. 1 ticket 1 commit + Q33 icns 真值校验脚本 + 老板 macOS Dock 验圆角

#### Apple HIG 真值引用
- https://developer.apple.com/design/human-interface-guidelines/app-icons
- Apple App Icon 22% 圆角半径标准 (= macOS 27 Dock mask 自动应用)
- iconutil man page

#### 不动
- AppIcon.icns (fallback 通用版保留 ticket 04 + 05 真值)
- App.swift / Package.swift / Info.plist
- v0.21 chat ticket 01 (无关)

### Ticket 02 — LOGO dark variant 字色改浅 (跟系统色真值)

#### 业务语言
- 系统 Dark Mode → Dock LOGO = 深底 + 浅字 (当前是深底 + 深字, 看不见)
- 系统 Light Mode → Dock LOGO = 浅底 + 深字 (当前 OK, 不动)
- 系统 色调 (accent color) → Dock LOGO = accent 底 + 深字 (老板截图看字色没变, 当前 OK 不动)

#### 修法真值 (2 步)
1. 老板去 Sketch master 把 dark variant 主图的 "文枢" 字色改浅 (= 跟深底对比, 类似 #F5F5F5 或 Apple system label color light)
2. 重导 `wenshu-icon-master-1024-dark.png`, 我跑 ticket 01 流程重导 icns
3. 1 ticket 1 commit + 老板 macOS Dock 切 Dark Mode 验

#### Apple HIG 真值引用
- Apple HIG Dark Mode icon variant = 浅字 + 暗底 (macOS Dark Mode 自动选)
- https://developer.apple.com/design/human-interface-guidelines/app-icons

#### 不动
- light / mono variant (当前 OK)
- App.swift / Package.swift / Info.plist

### Ticket 03 — 菜单栏"wenshu"改"文枢" (删 WindowGroup title + SettingsScene)

#### 业务语言
- 顶部菜单栏第 1 项 = "文枢" (中文, 不是英文 wenshu)
- 其他 5 项 (文件 / 编辑 / 显示 / 窗口 / 帮助) 保持中文 (已对)
- macOS 27 SwiftUI lazy populate 注入的英文菜单不再覆盖 NSMenu 装的中文

#### 修法真值 (4 步)
1. App.swift L176 `WindowGroup("文枢") { LayoutShellView() }` 第 1 参数 title 删, 改 `WindowGroup { LayoutShellView() }` (让 SwiftUI 不注入 wenshu 菜单)
2. App.swift L186 `Settings { }` Scene 改 `SettingsScene` 范式 (SwiftUI 5+ macOS 14+ 支持), 自己 control menu 安装
3. WenshuAppDelegate.applicationWillFinishLaunching NSMenu 装的中文 "文枢" 真值保留 (ticket 08 已落地, 不动)
4. 跑 `killall Dock` 清 macOS Dock 缓存 (Dock 缓存了 menu bar)
5. macOS 27 真验: 系统外观 dark + 切 menu bar → 第 1 项是 "文枢" 不是 "wenshu"

#### Apple HIG 真值引用
- https://developer.apple.com/documentation/swiftui/windowgroup (title 参数 = SwiftUI lazy populate 菜单名)
- https://developer.apple.com/documentation/swiftui/settingsscene
- vdhamer/Photo-Club-Hub-HTML#248 (SwiftUI .commands 在 macOS 27 lazy populate bug)

#### 不动
- NSMenu L218-251 装的中文 6 项 (ticket 08 已落地)
- ChatView / LayoutShellView (跟本 ticket 无关)
- v0.20 ticket 08 SettingsLink trigger 机制 (SettingsScene 仍 trigger SwiftUI Settings)

## po main flow 6 步

1. ✅ grill-with-docs (3 项决策已拍: 全 A 推荐 + LOGO 圆角 + LOGO 跟系统色 + 菜单栏中文)
2. ✅ to-spec (本文件)
3. → to-tickets (`.scratch/2026-08-21-logo-menu-systemcolor/issues/01-03-*.md`)
4. → implement (1 ticket 1 commit, streak 模式)
5. → code-review (双轴 Standards + Spec, 全部 ticket commit 后跑一次)
6. → domain-modeling (CONTEXT.md 加 AppleHIGIconMask + macOS27AppearanceIcon + SwiftUICommandsLazyPopulate 3 domain word)

## 验收标准 (老板 8/19 evening 拍 streak 模式)

- 每个 ticket: `swift build` exit 0 + `swift test` exit 0 + iconutil 真验证 + Apple HIG 标准
- 3 ticket 全 commit 后: 双轴 code-review 跑
- 老板 macOS 真验:
  - Dock LOGO 圆角 (不论 dark/light)
  - 系统切外观, Dock LOGO 自动跟
  - 菜单栏全中文 (无英文 File / Edit / View / Window / Help)

## 不动 (Q20 硬约束)

- v0.20 ticket 04+05 (LOGO dark/light 文件已落地, ticket 02 验证不重做)
- v0.20 ticket 07+08 (dark/light icns + SettingsLink trigger, 已 commit)
- v0.21 ticket 01 (ChatMessage source, 跟本 spec 无关)
- AGENTS.md / CLAUDE.md (基线不动)
- macOS-only (不上 iOS / iPadOS / Catalyst)

## 关联 commit

- `5d8239d0a` — v0.21 ticket 01 ChatMessage source (无关)
- `19ca2561f` — v0.21 spec + 6 tickets (chat-persistent-multi-agent, 无关)
- `fedac8ba3` — v0.20 ticket 07+08 spec + issues (回填)
- `bdc2ce7ef` — v0.20 ticket 08 菜单栏去重 + SettingsView trigger (基础, ticket 03 改造)
- `12da5e626` — v0.20 ticket 07 LOGO dark/light 自动跟随 (基础, ticket 02 验证)