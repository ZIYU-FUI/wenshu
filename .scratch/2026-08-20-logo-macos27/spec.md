# Spec — 项目 LOGO 符合 Apple macOS 27 标准应用 (老板 2026-08-20 拍)

> Date: 2026-08-20
> 老板 2026-08-20 09:25 拍 "不光是 dock 的 LOGO,是整个项目的 LOGO 符合 APPLE MAC OS 27 标准应用"
> 老板 8/20 09:25 拍 保留 NSMenu 自带 6 项 + 鼠标变形已实现 + Dock 有图标但没 LOGO

## 真因 (Q22 cua-driver + AXTree 真值)

- ticket 01 commit `7ead2e0c4` 在 `applicationWillFinishLaunching` 装 `NSApp.applicationIconImage = NSImage(contentsOfFile: "/Users/anbaiqiang/Desktop/LOGO/wenshu-icon.icns")`
- 老板真验: Dock 有应用图标但**不带 LOGO** = 装了一个系统 fallback 的 generic icon(不是 wenshu-icon.icns 内容)
- 真因真值链:
  1. Info.plist `CFBundleIconFile="AppIcon"` + `CFBundleIconName="AppIcon"` (line 11-12)
  2. 项目**没有** AppIcon.icns / AppIcon.appiconset 文件
  3. `applicationWillFinishLaunching` 之前,macOS 27 Dock tile 已从 Info.plist 拿 CFBundleIconFile="AppIcon" → 找不到 → fallback generic
  4. `applicationWillFinishLaunching` 装 `NSApp.applicationIconImage` 太早,macOS 27 Dock tile 已生成 cached bitmap 不重画
  5. 老板 Dock 看到的 = cached fallback generic,不是 wenshu-icon.icns 内容

## 工程真值约束 (老板 8/19 + 8/20 反复拍)

- 用现成 wenshu App icon 真值 (项目内 `Sources/WenshuApp/Resources/AppIcon.icns`,473 KB icns,11 个 representation: ic04/ic05/ic07/ic08/ic09/ic10/ic11/ic12/ic13/ic14/info,RGB+alpha,覆盖 16/32/64/128/256/512/1024 PT + info dictionary). 真值校验命令见 `references/v0.20-logo-appicon-app-bundle.md` Q33
- 不复制文件到项目 (老板 8/19 拍 "项目根 = /Volumes/ANAN/Engineering/wenshu/",不在 ~/wenshu-plugin/ 之外建项目目录)
- macOS-only (`.macOS(.v27)`),不 iOS/iPadOS/Catalyst
- 工程管理老板授权 (8/19 拍 "你自行决策") + 不需要验收

## 修法 (1 ticket 1 commit)

**Ticket 04 — 项目 LOGO 符合 macOS 27 标准应用 (1 commit)**

### 业务语言 (老板懂)

- Dock 文枢 LOGO 可见 (不再 generic 系统图标)
- macOS 27 标准应用范式 (Pages / Numbers / Xcode 同款)
- 不依赖 `/Users/anbaiqiang/Desktop/LOGO/` 桌面文件 (老板可能清桌面,丢失 = 图标丢失)

### 改法真值 (5 步)

1. 复制 `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024*.png` (8/11 v0.03.0 LOGO master 源) → 走 `iconutil` 工具重导 `AppIcon.icns` (master png → icns 工具链 = Apple HIG 标准范式)
   - 项目内 icns 真值 (v0.20 ticket 04 commit `a97719b92`) = 473 KB, 11 reps ic04/05/07/08/09/10/11/12/13/14/info, 覆盖 16/32/64/128/256/512/1024 PT
   - macOS 27 standard: CFBundleIconFile="AppIcon" 必须对应 `AppIcon.icns` 或 `AppIcon.png`
   - icns 11 个 representation 全有 (ic04/ic05/ic07/ic08/ic09/ic10/ic11/ic12/ic13/ic14/info, 16/32/64/128/256/512/1024 PT) = Dock 全尺寸全清晰
2. **改 Info.plist**:
   - 保留 `CFBundleIconFile = "AppIcon"` (已对)
   - 保留 `CFBundleIconName = "AppIcon"` (已对)
3. **改 Package.swift**: `Resources/Info.plist` 旁边加 `AppIcon.icns` = SwiftPM **resources** 范畴,但 SwiftPM `.executableTarget` 不自动 copy resources
   - 真值: `executableTarget` 的 resources 走 `.copy()` resource 处理
   - 或者: 维持 Info.plist 嵌入 __TEXT section,AppIcon.icns 单独 copy 到 `.build/.../WenshuApp.app/Contents/Resources/AppIcon.icns`
   - **真修法**: SwiftPM `resources: [.process("Resources")]` + `Resources/Info.plist` exclude 列表保留(已 exclude)+ 加 AppIcon.icns 进 resources
3. **改 `Sources/WenshuApp/App.swift`**:
   - 删 line 234-244 `applicationWillFinishLaunching` 装 applicationIconImage(已不需要,Info.plist + AppIcon.icns 自动)
   - 删 `if NSApp.applicationIconImage == nil` 守卫 (已不需要)
   - **不保留** runtime fallback — Apple HIG 标准 Cocoa .app bundle 范式是权威源, runtime 装入代码会跟 AppKit Dock tile 冲突
4. **改** `applicationDidFinishLaunching` — **不动**, runtime safety net 已废弃, 见 ticket 04 + 05 决定 + CONTEXT.md macOS27AppIcon 行

### Apple HIG 真值引用

- NSApplication applicationIconImage: https://developer.apple.com/documentation/appkit/nsapplication/applicationiconimage
- CFBundleIconFile 真值: https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleiconfile
- CFBundleIconName 真值: https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleiconname
- NSApplication dockTile: https://developer.apple.com/documentation/appkit/nsapplication/docktile
- NSDockTile display: https://developer.apple.com/documentation/appkit/nsdocktile/display()
- macOS 27 App icon 真值: https://developer.apple.com/design/human-interface-guidelines/app-icons

### 不动 (老板 8/18 拍死原则)

- /Volumes/ANAN/.hermes/ 任何文件 (老板 8/11 拍 'hermes 不动')
- ~/wenshu-plugin/ 之外的项目目录
- macOS chrome 52 PT (.windowStyle(.titleBar))
- 菜单栏 NSMenu 6 项 (老板 8/20 09:25 拍保留)
- 拖拽线视觉 (ticket 02 已 commit 88c30efe6)
- WenshuCore 14 真值模块
- ChatView (v0.20 ticket 01)

## po main flow 6 步

1. ✅ grill-with-docs (老板 8/20 反馈:保留 + 整个项目 LOGO + wenshu-icon.icns)
2. ✅ to-spec (本文件)
3. → to-tickets (`.scratch/2026-08-20-logo-macos27/issues/04-*.md`)
4. → implement (1 commit 改 Package.swift + Info.plist + App.swift + 加 AppIcon.icns)
5. → code-review (双轴 Standards + Spec)
6. → domain-modeling (CONTEXT.md 加 1 domain word: macOS27AppIcon)

## Q22 真验证 (commit 后必跑)

1. pkill 旧 wenshu + 启新 binary
2. swift scripts/quartz-winid.swift 拿 windowID
3. screencapture -l <windowID> 抓 wenshu 窗口 + 全屏
4. vision_analyze 看 Dock logo 真值
5. 老板真验 cmd+shift+3 截图 (老板 8/19 evening 拍)

## 业务语言描述 (老板懂)

- Dock LOGO 不显示真因: macOS 27 Dock tile 在 `applicationWillFinishLaunching` 之前已经从 Info.plist 拿了 CFBundleIconFile="AppIcon" → 找不到文件 → cached fallback generic 图标
- 修法真值: 加 `AppIcon.icns` 进项目,SwiftPM resources 自动 copy 到 `Contents/Resources/`,macOS 27 Dock 标准范式加载
- 不依赖桌面文件 (复制到项目内,持久化)