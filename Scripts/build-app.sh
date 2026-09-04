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

# v0.34 Issue 11: regenerate upstreams.json + THIRD_PARTY_NOTICES.md
# (= Apple HIG convention: notice file is always fresh at build
# time; = no manual sync required). Idempotent (= scanner produces
# identical output across runs = Git diff stays clean).
if command -v python3 >/dev/null 2>&1; then
    python3 Tools/wenshu-devtool/upstreams-scan.py || echo "warning: upstreams-scan.py failed (= skipped; check Python 3 path)"
else
    echo "warning: python3 not found (= skipped upstreams-scan.py; notices may be stale)"
fi

# AppIcon (.icon Icon Composer 格式) → Contents/Resources/AppIcon.icon (CFBundleIconFile="AppIcon" 解析路径)
cp -R "Sources/WenshuApp/Resources/AppIcon.icon" "$RES_DIR/AppIcon.icon"

# v0.38 P2: copy SPM-generated i18n bundle into the .app so
# WenshuI18n.bundle resolution finds it at runtime (= Settings tab
# labels and other i18n catalog strings display correctly).
# SPM may place the bundle under .build/release/, .build/debug/, or
# .build/out/Products/{Debug,Release}/ (= multiple spellings observed
# across SPM versions); probe the common locations then fall back to
# a recursive find under .build.
SPM_BUNDLE_PATH=""
for candidate in \
    ".build/release/Wenshu_WenshuApp.bundle" \
    ".build/debug/Wenshu_WenshuApp.bundle" \
    ".build/out/Products/Release/Wenshu_WenshuApp.bundle" \
    ".build/out/Products/Debug/Wenshu_WenshuApp.bundle"; do
    if [ -d "$candidate" ]; then
        SPM_BUNDLE_PATH="$candidate"
        break
    fi
done
if [ -z "$SPM_BUNDLE_PATH" ]; then
    # Fallback: search anywhere under .build (in case SPM nesting changes)
    SPM_BUNDLE_PATH="$(find .build -name 'Wenshu_WenshuApp.bundle' -type d 2>/dev/null | head -1 || true)"
fi
if [ -n "$SPM_BUNDLE_PATH" ] && [ -d "$SPM_BUNDLE_PATH" ]; then
    cp -R "$SPM_BUNDLE_PATH" "$RES_DIR/Wenshu_WenshuApp.bundle"
    echo ">>> copied i18n bundle: $SPM_BUNDLE_PATH -> $RES_DIR/Wenshu_WenshuApp.bundle"
else
    echo ">>> warning: SPM i18n bundle not found under .build/ (WenshuI18n.t will return key paths)"
fi

# macOS 27 dark/light/tinted 自动跟随系统主题: AppKit 按 effectiveAppearance 从 AppIcon.icon 派生.
# Apple Icon Composer 范式: 1 份 LOGO.icon + icon.json + Assets/ 主图 PNG, macOS 27 自动派生 dark/light/tinted + platform mask (squares shared / circles watchOS).
# Apple HIG 范式: https://developer.apple.com/design/human-interface-guidelines/app-icons

echo ">>> ad-hoc codesign (B-10 phase A entitlement embed reverted — SIGKILL on launch)"
codesign --force --deep --sign - "$APP_DIR"

# v0.24 boss验收fix (Boss 8/24 OOB): re-register app with Launch Services
# so Finder picks up UTExportedTypeDeclarations (com.wenshu.workspace +
# com.apple.package conformance = .ws files appear as packages, right-click
# → '显示包内容'). Without lsregister, the new Info.plist is not picked up
# and Finder treats .ws as ordinary directory (= cannot '显示包内容').
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
if [ -x "$LSREGISTER" ]; then
    echo ">>> lsregister -f $APP_DIR (re-register UTI)"
    "$LSREGISTER" -f "$APP_DIR" >/dev/null 2>&1 || true
fi

echo ">>> done. open with: open $APP_DIR"