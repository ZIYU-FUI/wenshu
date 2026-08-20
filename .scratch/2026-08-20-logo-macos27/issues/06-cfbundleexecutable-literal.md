# 06 — Info.plist CFBundleExecutable 字面化 (老板 2026-08-20 拍)

**What to build:**

老板 2026-08-20 10:25 拍 "LOGO 有了, 但有一个错误的标识" + "同时还是没有圆角". 真因不是 icon 没应用, 是 .app bundle 整体启不起来: `open build/Wenshu.app` 报 `The application cannot be opened because its executable is missing`. Dock 显示 macOS "missing icon" 禁字符号 placeholder (没圆角 = 没真 icon 应用, 系统按 placeholder 渲染).

## 真因

- `Sources/WenshuApp/Resources/Info.plist` L10 `CFBundleExecutable = "$(EXECUTABLE_NAME)"`
- 这是 Xcode build setting placeholder, **SwiftPM 不展开** $(EXECUTABLE_NAME) 变量
- SwiftPM 把 Info.plist 当 raw plist 复制到 `.app/Contents/Info.plist`,literal string = `$(EXECUTABLE_NAME)`
- AppKit 期望 `Contents/MacOS/$(EXECUTABLE_NAME)` binary 文件存在 → 找不到 (实际文件是 `WenshuApp`) → "executable missing" 错
- 后果: `open build/Wenshu.app` 失败 → Dock tile fallback 到 macOS system "missing icon" 禁字符号 placeholder (灰色方块 + 红色禁止圈 + 模糊象形文字)

## 修法

改 `Sources/WenshuApp/Resources/Info.plist`:
- L10 `CFBundleExecutable` 从 `"$(EXECUTABLE_NAME)"` → `"WenshuApp"` 字面

## Acceptance

- `plutil -p build/Wenshu.app/Contents/Info.plist | grep CFBundleExecutable` = `WenshuApp`
- `open build/Wenshu.app` exit 0
- `pgrep -lf WenshuApp` 显示 `build/Wenshu.app/Contents/MacOS/WenshuApp` 跑起来
- Dock 文枢 LOGO 可见 + Apple HIG 自动圆角 mask 应用

## 真因引用 (Apple HIG)

- CFBundleExecutable: https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleexecutable
- "Bundle executable name (literal string). The name must match the executable in Contents/MacOS/."

## 不动

- AppIcon.icns 真值 (473 KB / 11 reps, v0.20 ticket 04 落地)
- Scripts/build-app.sh (50 行, ticket 05 落地)
- Package.swift linker flag 删 (ticket 04 落地)
- App.swift runtime applicationIconImage 删除 (ticket 04 落地)
- menu / splitter / 拖拽线 / 其他 (跟本 ticket 无关)

## 关联 commit

- `cbfa0b20c` — fix(wenshu): v0.20 ticket 06 Info.plist CFBundleExecutable 改字面 'WenshuApp' (老板 2026-08-20 拍 '没有圆角 + Dock 禁字符号')