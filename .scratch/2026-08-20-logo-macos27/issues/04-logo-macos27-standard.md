# 04 — 项目 LOGO 符合 Apple macOS 27 标准应用 (老板 2026-08-20 拍)

**What to build:**

老板 2026-08-20 09:25 拍 "不光是 dock 的 LOGO,是整个项目的 LOGO 符合 APPLE MAC OS 27 标准应用". 工程管理老板授权 (8/19 拍 "你自行决策") + 不需要验收 + 1 ticket 1 commit 硬约束 + po main flow 6 步.

**修法真值:**

1. 复制 `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon.icns` → `Sources/WenshuApp/Resources/AppIcon.icns`
   - 473 KB icns, 11 个 representation (ic04/ic05/ic07/ic08/ic09/ic10/ic11/ic12/ic13/ic14/info, 16/32/64/128/256/512/1024 PT)
2. 改 `Package.swift`: `Resources/Info.plist` exclude 保留 + 加 `Resources/AppIcon.icns` 进 resources 处理
   - SwiftPM `.executableTarget` 加 `resources: [.process("Resources")]` 或 `.copy([.init(stringLiteral: "AppIcon.icns")])`
3. 改 `Sources/WenshuApp/App.swift`:
   - 删 `applicationWillFinishLaunching` 装 applicationIconImage 代码 (ticket 05 全面接管, runtime safety net 已废弃, 见 CONTEXT.md macOS27AppIcon 行)
   - **不再保留 runtime fallback**: .app bundle 范式是 Apple HIG 权威源, runtime 装入代码会跟 AppKit Dock tile 冲突
   - `applicationDidFinishLaunching` 不动 (ticket 05 决定)
4. 保留 `Info.plist` line 11-12 `CFBundleIconFile="AppIcon"` + `CFBundleIconName="AppIcon"` (已对,不改)
5. swift build exit 0
6. Q22 真验证: pkill + 启新 + screencapture -l 真截图

**Blockers:** 无

**Acceptance:**

- swift build exit 0
- swift test 12/12 LayoutShellViewModelTests 全过
- 老板启 wenshu, Dock 文枢 LOGO 可见 (不是 generic 系统图标)
- macOS 27 标准应用范式 (Pages / Numbers / Xcode 同款 Dock LOGO 渲染)
- 不依赖 `/Users/anbaiqiang/Desktop/LOGO/` 桌面文件 (持久化进项目)

**不动:**

- /Volumes/ANAN/.hermes/ 任何文件 (老板 8/11 拍 'hermes 不动')
- ~/wenshu-plugin/ 之外的项目目录
- macOS chrome 52 PT (.windowStyle(.titleBar))
- 菜单栏 NSMenu 6 项 (老板 8/20 09:25 拍保留)
- 拖拽线视觉 (ticket 02 已 commit 88c30efe6)
- WenshuCore 14 真值模块
- ChatView (v0.20 ticket 01)

**真值引用 (Apple HIG):**

- NSApplication applicationIconImage: https://developer.apple.com/documentation/appkit/nsapplication/applicationiconimage
- CFBundleIconFile: https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleiconfile
- CFBundleIconName: https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleiconname
- NSApplication dockTile: https://developer.apple.com/documentation/appkit/nsapplication/docktile
- NSDockTile display: https://developer.apple.com/documentation/appkit/nsdocktile/display()
- macOS 27 App icon HIG: https://developer.apple.com/design/human-interface-guidelines/app-icons