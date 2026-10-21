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

echo ">>> swift build -c debug (= the dev binary; = the
              dev cycle uses the debug binary for
              faster incremental builds; = the
              release binary is used for the
              canonical .app bundle. The .app
              bundle currently copies the RELEASE
              binary; = the user-visible behavior
              is identical between debug and
              release for our code paths, but the
              log statements added in dev = e.g.
              \`os_log(\"[wenshu.pane.openCard] v7.2 ...\")\`
              = are stripped in release; = the
              \`bash Scripts/build-app.sh\` here
              ALSO copies the freshly-built debug
              binary into the .app bundle to
              match the dev cycle (= the boss
              reported \"log 空\" because the
              previous .app binary was the
              stripped release build). 2026-10-14
              hot-fix: build the debug binary too
              and copy it = the .app uses the
              dev build for the local wenshu.app
              until a follow-up ticket migrates
              the build script to a proper
              multi-config setup.)"
swift build -c debug

echo ">>> 拼 $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp ".build/release/$BIN_NAME" "$MACOS_DIR/$BIN_NAME"

# 2026-10-14 hot-fix: also
# overwrite with the
# freshly-built DEBUG
# binary so the .app
# contains the same
# v7.4 source-of-truth
# (= the .build/debug
# /WenshuApp just
# compiled by the
# `swift build -c debug`
# line above). The
# release binary is
# kept in the .app for
# canonical Apple HIG
# alignment but the
# dev cycle (= the
# `bash Scripts/build-app.sh`
# invocation) uses
# the debug binary so
# the dev `os_log`
# statements survive
# the build (= the
# `wenshu.pane.openCard`
# / `wenshu.preview.card`
# debug logs added in
# v7.4 = the boss's
# "log 空" diagnostic
# for the card
# double-click bug).
# When the boss
# confirms the bug
# fix, this debug-copy
# line should be
# removed (= the
# canonical .app binary
# should be the release
# build for shipping).
cp ".build/debug/$BIN_NAME" "$MACOS_DIR/$BIN_NAME"

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

# Promote the build system's compiled .lproj folders to .app/Contents/Resources/
# so Bundle.main (= String(localized:) / NSLocalizedString) can resolve them.
# Without this promotion, the user sees the raw key string (e.g.
# "onboarding.library.choose_location") instead of the translated value,
# because Foundation's Bundle.main does NOT recurse into the nested
# Wenshu_WenshuApp.bundle (= it reads only the top-level Resources/). The
# SPM-generated .lproj inside the nested bundle is the canonical source
# (= compiled at swift-build time from the String Catalogs in
# Sources/WenshuApp/Resources/; = no catalog-compiler invocation is
# needed here).
# Apple HIG canonical pattern: all app-localized resources must live directly
# under Contents/Resources/. Both tables ride along in the same per-locale
# folder (= Localizable.strings + InfoPlist.strings), because Bundle.main
# reads one .lproj per locale and the system reads the Info.plist names from
# the same folder.
if [ -n "$SPM_BUNDLE_PATH" ]; then
    for lproj in "$SPM_BUNDLE_PATH/Contents/Resources/"*.lproj; do
        if [ -d "$lproj" ]; then
            cp -R "$lproj" "$RES_DIR/"
            echo ">>> promoted .lproj: $(basename "$lproj") -> $RES_DIR/"
        fi
    done
fi

: # noop — every runtime table arrives via the SPM promote step above
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