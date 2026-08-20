# 07 — LOGO dark/light 自动跟随系统主题 (老板 2026-08-20 拍)

**What to build:**

老板 2026-08-20 10:35 拍 "LOGO 有了, 但没有跟随系统主题". 工程管理老板授权 (8/19 拍 "你自行决策") + 1 ticket 1 commit 硬约束 + po main flow 6 步.

## 修法真值

1. 复制 `wenshu-icon-dark.icns` (367481 bytes, 8 reps ic04/07/10/11/12/13/14/info) → `Sources/WenshuApp/Resources/AppIcon.dark.icns`
2. 复制 `wenshu-icon-light.icns` (369946 bytes, 8 reps) → `Sources/WenshuApp/Resources/AppIcon.light.icns`
3. 改 `Scripts/build-app.sh` line 30-31 加 cp 两份到 `build/Wenshu.app/Contents/Resources/AppIcon.dark.icns` + `AppIcon.light.icns`
4. 保留 `AppIcon.icns` (fallback 通用版, AppKit 找不到 dark/light 时 fallback)

## Acceptance

- `ls -la Sources/WenshuApp/Resources/AppIcon*.icns` 显示 3 份: `AppIcon.icns` + `AppIcon.dark.icns` + `AppIcon.light.icns`
- `ls -la build/Wenshu.app/Contents/Resources/AppIcon*.icns` 显示同样 3 份
- macOS 系统 Dark Mode → Dock + Launchpad + cmd+tab 显示 dark 版 LOGO
- macOS 系统 Light Mode → Dock + Launchpad + cmd+tab 显示 light 版 LOGO
- 老板 macOS 切换系统外观, LOGO 自动跟随 (cmd+shift+3 截图验证)

## 不动

- AppIcon.icns fallback 保留
- App.swift / Package.swift / Info.plist / 菜单栏 (跟本 ticket 无关)

## 真值引用 (Apple HIG)

- App icon dark/light 范式: https://developer.apple.com/design/human-interface-guidelines/app-icons
- Asset catalog dark/light variant: https://developer.apple.com/documentation/xcode/supporting-multiple-appearances-in-your-app-s-icons