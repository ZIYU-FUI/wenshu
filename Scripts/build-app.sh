#!/bin/bash
# build-app.sh — 拼真 .app bundle, 让 Dock 走 AppIcon.icns 权威源
# Apple HIG 标准 macOS app 范式 (Pages / Numbers / Xcode 同款)
# 老板 2026-08-20 拍 "整个项目 LOGO 符合 APPLE MAC OS 27 标准应用"
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

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

# AppKit 真值: .app bundle 范式必须把 Info.plist 复制到 Contents/Info.plist 让 AppKit 直接读
# (SwiftPM `-sectcreate __TEXT __info_plist` 是裸 run 用的, .app bundle 不需要)
cp "Sources/WenshuApp/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# AppIcon (.icon Icon Composer 格式) → Contents/Resources/AppIcon.icon (CFBundleIconFile="AppIcon" 解析路径)
cp -R "Sources/WenshuApp/Resources/AppIcon.icon" "$RES_DIR/AppIcon.icon"

# macOS 27 dark/light/tinted 自动跟随系统主题: AppKit 按 effectiveAppearance 从 AppIcon.icon 派生.
# Apple Icon Composer 范式: 1 份 LOGO.icon + icon.json + Assets/ 主图 PNG, macOS 27 自动派生 dark/light/tinted + platform mask (squares shared / circles watchOS).
# Apple HIG 范式: https://developer.apple.com/design/human-interface-guidelines/app-icons

echo ">>> ad-hoc codesign"
codesign --force --deep --sign - "$APP_DIR"

echo ">>> done. open with: open $APP_DIR"