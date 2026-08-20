# 04 — 用 Logo Composer (LOGO.icon) 替换 icns 3 份 (老板 8/21 新决策)

**What to build:**
老板 2026-08-21 16:00 提供 `/Users/anbaiqiang/Desktop/LOGO.icon/` (= Apple Icon Composer 格式). 真值 = `Assets/wenshu-original-touming.png` (1280×1920 RGBA 透明背景) + `icon.json` (automatic-gradient + layers + shadow + translucency + supported-platforms).

macOS 27 标准范式: App Icon 用 `.icon` 文件 (= Icon Composer) 1 份真值源, 系统自动派生:
- dark variant (深色背景) + light variant (浅色背景) + tinted variant (accent color)
- platform mask: macOS / iPadOS squares shared + watchOS circles

优势:
- 1 份真值源, 老板改1 张 PNG / 1 个 icon.json 全局生效
- 不需要 icns 11 reps
- 不需要 icns mask chunk (platform mask 自动)
- 不需要手重导 dark/light PNG

**Blocked by:** 老板改完 `/Users/anbaiqiang/Desktop/LOGO.icon/` (进行中).

**Status:** draft (等老板改完)

## 修法真值 (4 步)

1. 老板改 `/Users/anbaiqiang/Desktop/LOGO.icon/icon.json` + `Assets/wenshu-original-touming.png`:
   - 主图圆角矩形路径加大到 22% (Apple HIG 标准, 1024×1024 下 ≈ 225 半径) — 修 ticket 01 圆角问题
   - dark variant "文枢" 字色改浅 (跟深底对比, 跟系统色真值) — 修 ticket 02 跟系统色问题
   - icon.json `automatic-gradient` 改 Apple HIG recommended 蓝绿渐变 (`extended-srgb:0.00000,0.53333,1.00000,1.00000` 当前值 OK)
2. cp `LOGO.icon/` 整目录进 `Sources/WenshuApp/Resources/AppIcon.icon/`:
   ```bash
   cp -R /Users/anbaiqiang/Desktop/LOGO.icon Sources/WenshuApp/Resources/AppIcon.icon
   ```
3. 删 `AppIcon.icns` / `AppIcon.dark.icns` / `AppIcon.light.icns` (3 份老 icns 移除)
4. 改 `Sources/WenshuApp/Resources/Info.plist`:
   - `CFBundleIconFile = AppIcon` (保留, 不变)
   - 加 `CFBundleIconName = AppIcon` (保留)
5. 改 `Package.swift`:
   - exclude 删 3 个 icns (已删)
   - 加 `exclude: ["Resources/AppIcon.icon"]` (SwiftPM 不应处理 .icon 目录)
6. 改 `Scripts/build-app.sh`:
   - 删 3 个 icns cp 行
   - 加 `cp -R Sources/WenshuApp/Resources/AppIcon.icon build/Wenshu.app/Contents/Resources/`
7. 1 ticket 1 commit + Q33 真值校验 (AppIcon.icon/icon  解析 + Assets/ PNG 字节比对) + 老板 macOS Dock 验 4 模式 (默认/深色/透明/色调)

## Acceptance

- [ ] AppIcon.icon/ 整目录进项目 (icon.json + Assets/)
- [ ] 老 3 份 icns 移除
- [ ] Info.plist 不变 (CFBundleIconFile = AppIcon)
- [ ] Package.swift exclude AppIcon.icon
- [ ] build-app.sh cp AppIcon.icon/ 到 bundle
- [ ] codesign --verify exit 0
- [ ] ./Scripts/build-app.sh exit 0
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS Dock 验:
  - [ ] 默认模式 LOGO 圆角 Apple HIG 标准
  - [ ] 深色模式 LOGO 深底 + 浅字 (ticket 02 字色真值)
  - [ ] 透明模式 LOGO transparent 渲染
  - [ ] 色调模式 LOGO accent color 真值

## 不动 (Q20 硬约束)

- App.swift / LayoutShellView / ChatView (跟本 ticket 无关)
- 3 份 icns master PNG (8/11 老板 Sketch 重导, 仍保留桌面作历史 snapshot, 不进项目)
- v0.21 chat ticket 01 (无关)

## Apple HIG 真值引用

- https://developer.apple.com/design/human-interface-guidelines/app-icons
- https://developer.apple.com/documentation/xcode/icon_composer (Icon Composer)
- https://developer.apple.com/documentation/xcode/writing-an-app-icon (macOS 27 .icon 范式)

## 关联

- **合并**: ticket 01 (LOGO 圆角) + ticket 02 (LOGO dark variant 字色) — 用 LOGO.icon 后这 2 个 ticket 自动过, 不需要单独跑
- 依赖: 老板改完 `/Users/anbaiqiang/Desktop/LOGO.icon/`
- 被依赖: 无

## 老板决策真值 (8/21 16:00)

- 老板提供 LOGO.icon, 1 份真值源
- macOS 27 标准范式优先于 icns backward-compatible
- ticket 04 跑 = ticket 01 + 02 + 老 icns 3 份 全部替代, 整体收口