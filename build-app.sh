#!/bin/bash
# build-app.sh · Wenshu (Wenshu) · build script that produces a real .app bundle
#
# Boss 19:35: "现在这个窗口不在程序栏中, 切窗口也找不到他, 他现在也没有菜单.
#                感觉你在用一个移动端的东西".
#
# SwiftPM `.executableTarget` produces a bare Mach-O binary, NOT a .app bundle.
# Cocoa apps need the bundle wrapper (= Finder / Dock / Cmd+Tab / `open` integration).
# This script:
#   1. swift build (= produces binary + embeds Info.plist via linker section)
#   2. Manually assembles .app bundle (= Wenshu.app/Contents/MacOS/Wenshu + Info.plist)
#   3. open Wenshu.app (= registered with Launch Services, shows in Dock + Cmd+Tab)
#
# Out of scope: code-signing (= 装机 user / dev only), AppIcon.icns (= 7-zone scaffold
# is placeholder; v0.02.0+ adds proper icon).

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

echo "== Step 1: swift build =="
swift build -c debug

echo "== Step 2: Assemble .app bundle =="
BIN_PATH=".build/debug/WenshuApp"
APP_NAME="Wenshu"
APP_BUNDLE=".build/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy the SwiftPM-built binary (= already has Info.plist embedded in __TEXT section)
cp "$BIN_PATH" "$MACOS_DIR/${APP_NAME}"
chmod +x "$MACOS_DIR/${APP_NAME}"

# Build the bundle Info.plist with CFBundleExecutable expanded (= system needs the
# literal name to find the executable, not the "$(EXECUTABLE_NAME)" variable).
# Source Info.plist has CFBundleExecutable="$(EXECUTABLE_NAME)" for SwiftPM linker embed;
# the bundle copy needs the resolved name.
plutil -replace "CFBundleExecutable" -string "${APP_NAME}" \
    "Sources/WenshuApp/Resources/Info.plist" -o "${CONTENTS}/Info.plist"

# Copy PkgInfo (optional, but standard)
printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "== Bundle structure =="
ls -la "$APP_BUNDLE/Contents/"
echo ""
plutil -p "$CONTENTS/Info.plist" | head -15

echo ""
echo "== Step 3: Open the .app bundle via Launch Services =="
open "$APP_BUNDLE"

echo ""
echo "Done. Wenshu.app built at $APP_BUNDLE"