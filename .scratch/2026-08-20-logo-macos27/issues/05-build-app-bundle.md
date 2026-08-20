# Ticket 05 — 拼 .app bundle 让 Dock LOGO 走 Apple 权威源 (老板 2026-08-20 拍)

> 工程管理老板授权 (8/19 拍 "你自行决策") + 不需要验收 (8/19 evening 拍) + 1 ticket 1 commit 硬规则 + po main flow 6 步.

## 业务语言 (老板懂)

- Dock 文枢 LOGO 可见 (跟 Pages / Numbers / Xcode 一样, 走 `.app` bundle 权威源)
- 启动方式 = `./Scripts/build-app.sh && open ./build/Wenshu.app`, 不再裸 `swift run`
- macOS 27 标准应用范式 (Apple HIG 原则 1 真值)

## 真因 (subagent deleg_303797ae 14 分钟跑完)

裸 SwiftPM binary 没有 `.app` bundle, AppKit 找不到 `Contents/Resources/AppIcon.icns`. Dock 走 fallback 占位图. AppIcon.icns 真值 = 473 KB, 11 reps (ic04/05/07/08/09/10/11/12/13/14/info), 覆盖 16/32/64/128/256/512/1024 PT.

- `applicationIconImage` getter 在 fallback 时返回占位图本身, 不是 nil → App.swift line 234 `== nil` 守卫永远 false → swift code 不覆盖
- `applicationIconImage` Apple 文档原话 = "**temporarily change the app icon**" → Dock daemon LaunchPad 索引重建会盖回去
- 真值源: Apple `NSApplication.applicationIconImage` JSON 端点 + App icons HIG

## 修法 (老板 8/20 拍 "符合 APPLE MAC OS 27 标准应用" → 走 Apple HIG 原则 1 权威源)

### 1. 写 `Scripts/build-app.sh` (50 行, swift run 替换)

```
#!/bin/bash
# build-app.sh — 拼真 .app bundle, 让 Dock 走 AppIcon.icns 权威源
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_DIR="$BUILD_DIR/Wenshu.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
BIN_NAME="WenshuApp"

echo ">>> swift build -c release"
swift build -c release

echo ">>> 拼 $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp ".build/release/$BIN_NAME" "$MACOS_DIR/$BIN_NAME"

# 真值 Info.plist (Sources/WenshuApp/Resources/Info.plist)
# SwiftPM linker `-sectcreate __TEXT __info_plist` 嵌进 binary 是裸 run 用的;
# .app bundle 范式必须把 Info.plist 复制到 Contents/Info.plist 让 AppKit 读
cp "Sources/WenshuApp/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# AppIcon.icns → Contents/Resources/AppIcon.icns (CFBundleIconFile="AppIcon" 解析路径)
cp "Sources/WenshuApp/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"

echo ">>> ad-hoc codesign"
codesign --force --deep --sign - "$APP_DIR"

echo ">>> done. open with: open $APP_DIR"
```

### 2. 改 `Package.swift` (1 行)

删 `-Xlinker Sources/WenshuApp/Resources/Info.plist` linker flag (真值: .app bundle 范式不需要 `__TEXT,__info_plist` section, AppKit 直接读 `Contents/Info.plist`).

### 3. 改 `Sources/WenshuApp/App.swift`

- 删 line 234-244 applicationIconImage 整块 (Apple HIG 原则 1: 不需要 runtime 兜底, .app bundle 权威源自动)
- `applicationDidFinishLaunching` 不动
- 注释清理 (修真词 / 拍板 trace 全清, Q8 死原则)

## 不动 (老板 8/18 拍死原则)

- /Volumes/ANAN/.hermes/ 任何文件
- macOS chrome 52 PT (.windowStyle(.titleBar))
- 菜单栏 NSMenu 6 项 (老板 8/20 09:25 拍保留)
- 拖拽线视觉
- WenshuCore 14 真值模块
- ChatView (v0.20 ticket 01)

## Apple HIG 真值引用

- NSApplication applicationIconImage: https://developer.apple.com/documentation/appkit/nsapplication/applicationiconimage
- App icons HIG: https://developer.apple.com/design/human-interface-guidelines/app-icons
- CFBundleIconFile: https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleiconfile
- codesign 真值: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution

## Q22 真验证 (commit 后必跑)

1. `./Scripts/build-app.sh` exit 0
2. `codesign --verify --verbose=2 build/Wenshu.app` exit 0
3. `open build/Wenshu.app` 后看 Dock (老板 8/19 evening 拍 自己 cmd+shift+3 截图)
4. AXTree 看 owner=WenshuApp + window title="文枢"
5. cua-driver capture(app=WenshuApp) 验 wenshu 内容渲染