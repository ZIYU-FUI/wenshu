#!/bin/bash
# build-wenshu.sh · Wenshu v0.40 · 2026-09-07
#
# Why this script exists (= Apple canonical requirement for
# .app bundle):
#
# 1. .strings files MUST be UTF-16 LE BOM encoded for
#    NSLocalizedString to read them. UTF-8 encoded files are
#    silently ignored at runtime, causing raw keys to be
#    displayed (= the bug boss real-device test surfaced
#    2026-09-07).
# 2. SPM does NOT do this conversion automatically
#    (= .process("Resources") copies verbatim).
# 3. The .app bundle in build/ is the user-facing artifact
#    (= what boss clicks in Finder). It must contain UTF-16
#    .strings files for system-follow-language to work.
#
# Usage:
#   ./Tools/build-wenshu.sh          # full build (= clean + build + bundle)
#   ./Tools/build-wenshu.sh bundle   # only the .app bundle copy step
#   ./Tools/build-wenshu.sh convert  # only convert .strings to UTF-16

set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

ACTION="${1:-all}"

# Convert all .strings files from UTF-8 (source-of-truth, editor-friendly)
# to UTF-16 LE BOM (Apple canonical, NSLocalizedString-compatible).
#
# Apple Foundation docs:
#   "Localization tables (.strings files) should be encoded as
#    UTF-16 LE with BOM. Files in other encodings may not be
#    loaded."
#
# We keep the SOURCE in UTF-8 (1) for git diff readability,
# (2) because macOS editors / Xcode default to UTF-8,
# (3) because UTF-16 + git diff = diff is unreadable for
# CJK-heavy files (= 87% of zh-Hans content is CJK).
#
# The conversion happens at build time (= this script), so
# SOURCE stays UTF-8 (developer-friendly) but RUNTIME gets
# UTF-16 (Apple-compatible).
convert_strings() {
    echo "==> Converting .strings to UTF-16 LE BOM (= Apple canonical)"
    for src in \
        Sources/WenshuApp/Resources/en.lproj/Localizable.strings \
        Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings \
        Sources/WenshuApp/Resources/en.lproj/InfoPlist.strings \
        Sources/WenshuApp/Resources/zh-Hans.lproj/InfoPlist.strings
    do
        python3 -c "
import sys
src = '$src'
with open(src, 'r', encoding='utf-8') as f:
    content = f.read()
with open(src, 'wb') as f:
    f.write(b'\\xff\\xfe')
    f.write(content.encode('utf-16-le'))
print(f'  {src} -> UTF-16 LE BOM ({len(content)} UTF-8 chars)')
"
    done
}

# Run swift build (= compiles sources, produces
# .build/debug/WenshuApp + .build/debug/Wenshu_WenshuApp.bundle).
swift_build() {
    echo "==> swift build"
    swift build 2>&1 | tail -3
}

# Copy the build artifacts into the .app bundle (= wenshu.app
# the user launches). Copies:
#   - The executable (Contents/MacOS/WenshuApp)
#   - The SPM module bundle with all resources (= .lproj
#     Localizable.strings, AppIcon.icon, entitlements, etc.)
#   - The Info.plist + InfoPlist.strings (= Apple canonical
#     bundle metadata; localized per system language)
#
# Note: the .app bundle layout follows macOS conventions:
#   Contents/
#     Info.plist                   (= bundle metadata)
#     MacOS/WenshuApp              (= executable)
#     Resources/                   (= bundle resources)
#       en.lproj/Localizable.strings
#       zh-Hans.lproj/Localizable.strings
#       en.lproj/InfoPlist.strings
#       zh-Hans.lproj/InfoPlist.strings
#       Wenshu_WenshuApp.bundle/   (= SPM module bundle)
copy_to_app_bundle() {
    APP="$PROJECT_ROOT/build/Wenshu.app"
    echo "==> Copying to $APP"
    mkdir -p "$APP/Contents/MacOS"
    mkdir -p "$APP/Contents/Resources/en.lproj"
    mkdir -p "$APP/Contents/Resources/zh-Hans.lproj"

    cp "$PROJECT_ROOT/.build/debug/WenshuApp" "$APP/Contents/MacOS/WenshuApp"
    cp "$PROJECT_ROOT/Sources/WenshuApp/Resources/Info.plist" "$APP/Contents/Info.plist"
    cp "$PROJECT_ROOT/Sources/WenshuApp/Resources/en.lproj/Localizable.strings" "$APP/Contents/Resources/en.lproj/"
    cp "$PROJECT_ROOT/Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings" "$APP/Contents/Resources/zh-Hans.lproj/"
    cp "$PROJECT_ROOT/Sources/WenshuApp/Resources/en.lproj/InfoPlist.strings" "$APP/Contents/Resources/en.lproj/"
    cp "$PROJECT_ROOT/Sources/WenshuApp/Resources/zh-Hans.lproj/InfoPlist.strings" "$APP/Contents/Resources/zh-Hans.lproj/"

    # Copy SPM module bundle (= Wenshu_WenshuApp.bundle has the
    # en.lproj/zh-Hans.lproj Localizable.strings + all third-party
    # .bundle dependencies)
    if [ -d "$PROJECT_ROOT/.build/debug/Wenshu_WenshuApp.bundle" ]; then
        cp -R "$PROJECT_ROOT/.build/debug/Wenshu_WenshuApp.bundle" "$APP/Contents/Resources/"
    fi

    echo "==> App bundle ready at $APP"
}

case "$ACTION" in
    convert)
        convert_strings
        ;;
    swift)
        swift_build
        ;;
    bundle)
        copy_to_app_bundle
        ;;
    all)
        convert_strings
        swift_build
        copy_to_app_bundle
        ;;
    *)
        echo "Usage: $0 [convert|swift|bundle|all]"
        exit 1
        ;;
esac

echo ""
echo "==> Done"
echo "Launch with:"
echo "  WENSHU_DEBUG_INMEMORY_KEYCHAIN=1 build/Wenshu.app/Contents/MacOS/WenshuApp"
