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
# v1.51 boss 2026-09-16 i18n root fix: Package.swift also embeds the same
# Info.plist into the Mach-O __TEXT,__info_plist section via linkerSettings
# (= the binary-side mirror for bare-Mach-O dev runs). For .app bundles,
# Contents/Info.plist (= this cp) takes precedence; the __info_plist
# section is benign but redundant. Both sources of truth are kept in
# sync because `Sources/WenshuApp/Resources/Info.plist` is the source.
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

# SPM-generated resource bundle (= Wenshu_WenshuApp.bundle) ships
# alongside the executable in .build/out/Products/{Debug,Release}/.
# Probe the canonical SPM locations first, then fall back to a
# recursive find (= SPM nesting varies across versions).
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
if [ -n "$SPM_BUNDLE_PATH" ]; then
    cp -R "$SPM_BUNDLE_PATH" "$RES_DIR/"
    echo ">>> copied SPM bundle: $SPM_BUNDLE_PATH -> $RES_DIR/$(basename "$SPM_BUNDLE_PATH")"
fi

# Promote the SPM-compiled .lproj/Localizable.strings to .app/Contents/Resources/
# so Bundle.main (= String(localized:) / NSLocalizedString) can resolve them.
# Without this promotion, the user sees the raw key string (e.g.
# "onboarding.library.choose_location") instead of the translated value,
# because Foundation's Bundle.main does NOT recurse into the nested
# Wenshu_WenshuApp.bundle (= it reads only the top-level Resources/). The
# SPM-generated .lproj inside the nested bundle is the canonical source
# (= compiled at swift-build time from Sources/WenshuApp/Resources/Localizable.xcstrings;
# no xcstringstool invocation needed here). Apple HIG canonical pattern:
# all app-localized resources must live directly under Contents/Resources/.
# Source-tree per-locale .lproj directories are excluded from the SPM target
# (= Package.swift exclude list) so they are NOT shipped and the SPM bundle's
# .xcstrings-derived .lproj is the canonical runtime catalog.
if [ -n "$SPM_BUNDLE_PATH" ]; then
    for lproj in "$SPM_BUNDLE_PATH/Contents/Resources/"*.lproj; do
        if [ -d "$lproj" ]; then
            cp -R "$lproj" "$RES_DIR/"
            echo ">>> promoted .lproj: $(basename "$lproj") -> $RES_DIR/"
        fi
    done
fi

# Source catalogs are the per-language truth in this repository. The
# SPM resource bundle can retain a stale incremental copy, so refresh the
# top-level app catalogs from source after every release build.
for source_lproj in Sources/WenshuApp/Resources/*.lproj; do
    if [ -d "$source_lproj" ]; then
        locale="$(basename "$source_lproj" .lproj)"
        mkdir -p "$RES_DIR/${locale}.lproj"
        cp "$source_lproj/Localizable.strings" "$RES_DIR/${locale}.lproj/Localizable.strings"
        echo ">>> refreshed source localization: ${locale}.lproj"
    fi
done
# Copy all third-party SPM-generated resource bundles into the .app
# (= Highlighter_Highlighter, GRDB_GRDB, Defaults_Defaults, etc.) so
# their `Bundle.module` lookups succeed at runtime. Without these,
# wenshu SIGKILLs at launch with 'unable to find bundle named X' (= e.g.
# Highlighter's fatal in Highlighter/resource_bundle_accessor.swift:44).
# Iterate every SPM-generated bundle (= *.bundle directory in
# .build/out/Products/Release/) and copy it to .app/Contents/Resources/.
for spmbundle in .build/out/Products/Release/*.bundle; do
    if [ -d "$spmbundle" ]; then
        bundle_name="$(basename "$spmbundle")"
        # Skip the wenshu one (= handled separately above)
        if [ "$bundle_name" != "Wenshu_WenshuApp.bundle" ]; then
            cp -R "$spmbundle" "$RES_DIR/"
            echo ">>> copied SPM bundle: $spmbundle -> $RES_DIR/$bundle_name"
        fi
    fi
done

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