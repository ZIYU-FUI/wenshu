# 05 — Info.plist CFBundleName/IconFile/IconName 中文 + Icon Composer 路径

**What to build:**
老板 2026-08-21 验证 ticket 04 (Logo Composer) 后反馈: Dock LOGO 没显 (空白圆角矩形 + 占位图标). 老板拍 "试改 APP 名中文, 菜单栏自动跟".

**Blocked by:** None.

**Status:** ✅ done — commit e474965.

## 修法真值

1. `CFBundleIconFile=AppIcon.icon` (加 .icon 后缀, 让 AppKit 找 AppIcon.icon/ 目录)
2. `CFBundleIconName=AppIcon.icon` (同上)
3. `CFBundleDisplayName=文枢` (保持中文)
4. `CFBundleName=文枢` (改中文, Finder 显示 + 系统菜单名跟)

## 真因

- ticket 04 commit 0aabd989e 落地 AppIcon.icon/ 进 build bundle, 但 Info.plist CFBundleIconFile=AppIcon (无后缀) → AppKit 找 `AppIcon.icns` (没有) 或 `AppIcon` (没有) → fallback 占位图标
- 老板 CFBundleDisplayName 已是"文枢" 但菜单栏第1 项仍是英文 "wenshu" → SwiftUI 注入 "wenshu" = WindowGroup("文枢") 第 1 参数 title 用 LocalizedStringKey 自动本地化为英文 (macOS 主语言 zh_CN 是但系统主语言可能不是)
- 修法 = Info.plist 3 字段改 + Icon Composer 路径正确注册

## Acceptance

- [x] CFBundleIconFile="AppIcon.icon"
- [x] CFBundleIconName="AppIcon.icon"
- [x] CFBundleDisplayName="文枢"
- [x] CFBundleName="文枢"
- [x] swift build exit 0
- [x] codesign --verify exit 0
- [ ] 老板 macOS 验:
  - [ ] Dock LOGO 显真值 (不是空白圆角矩形)
  - [ ] 系统外观切换, LOGO 自动跟 dark/light/tinted
  - [ ] 菜单栏第 1 项 = "文枢" (中文, 不是英文 wenshu)

## 不动

- AppIcon.icon/ (ticket 04 已落地, 不变)
- Package.swift (不变)
- Scripts/build-app.sh (不变)
- App.swift (不变)
- Sources/WenshuApp/Views/Chat/ChatView.swift (v0.21 chat 跟本 ticket 无关)

## 关联

- 依赖: ticket 04 (Logo Composer)
- 被依赖: ticket 03 (菜单栏 "wenshu" 改 "文枢" 验)