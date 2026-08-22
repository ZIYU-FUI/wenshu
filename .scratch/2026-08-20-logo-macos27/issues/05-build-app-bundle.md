# Ticket 05 — Assemble .app bundle to make Dock LOGO use Apple's authoritative source (老板 2026-08-20 拍)

> Engineering management authorized by 老板 (8/19 拍 "you decide on your own") + no acceptance needed (8/19 evening 拍) + 1 ticket 1 commit hard rule + po main flow 6 steps.

## Business language (老板-readable)

- Dock 文枢 LOGO visible (same as Pages / Numbers / Xcode, using the `.app` bundle authoritative source)
- Launch method = `./Scripts/build-app.sh && open ./build/Wenshu.app`, no longer bare `swift run`
- macOS 27 standard app paradigm (Apple HIG Principle 1 ground truth)

## Root cause (subagent deleg_303797ae ran in 14 minutes)

Bare SwiftPM binary has no `.app` bundle, AppKit cannot find `Contents/Resources/AppIcon.icns`. Dock falls back to a placeholder. AppIcon.icns ground truth = 473 KB, 11 reps (ic04/05/07/08/09/10/11/12/13/14/info), covering 16/32/64/128/256/512/1024 PT.

- The `applicationIconImage` getter returns the placeholder itself when falling back, not nil → App.swift line 234 `== nil` guard is always false → swift code does not override
- The `applicationIconImage` Apple docs verbatim = "**temporarily change the app icon**" → Dock daemon LaunchPad index rebuild overwrites it back
- Ground-truth source: Apple's `NSApplication.applicationIconImage` JSON endpoint + App icons HIG

## Fix (老板 8/20 拍 "conform to APPLE MAC OS 27 standard app" → follow Apple HIG Principle 1 authoritative source)

### 1. Write `Scripts/build-app.sh` (50 lines, replaces swift run)

```
#!/bin/bash
# build-app.sh — Assemble a real .app bundle so Dock uses the AppIcon.icns authoritative source
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

# Ground-truth Info.plist (Sources/WenshuApp/Resources/Info.plist)
# SwiftPM linker `-sectcreate __TEXT __info_plist` embeds into binary for bare run;
# the .app bundle paradigm must copy Info.plist to Contents/Info.plist for AppKit to read
cp "Sources/WenshuApp/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# AppIcon.icns → Contents/Resources/AppIcon.icns (CFBundleIconFile="AppIcon" resolved path)
cp "Sources/WenshuApp/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"

echo ">>> ad-hoc codesign"
codesign --force --deep --sign - "$APP_DIR"

echo ">>> done. open with: open $APP_DIR"
```

### 2. Modify `Package.swift` (1 line)

Delete the `-Xlinker Sources/WenshuApp/Resources/Info.plist` linker flag (ground truth: the .app bundle paradigm does not need the `__TEXT,__info_plist` section, AppKit reads `Contents/Info.plist` directly).

### 3. Modify `Sources/WenshuApp/App.swift`

- Delete lines 234-244, the applicationIconImage block (Apple HIG Principle 1: no runtime safety net needed, .app bundle authoritative source is automatic)
- `applicationDidFinishLaunching` unchanged
- Comment cleanup (pollution words / 拍板 trace all cleared, Q8 dead principle)

## Do not touch (老板 8/18 拍 dead principle)

- /Volumes/ANAN/.hermes/ any files
- macOS chrome 52 PT (.windowStyle(.titleBar))
- Menu bar NSMenu 6 items (老板 8/20 09:25 拍 keep)
- Drag line visuals
- WenshuCore 14 ground-truth modules
- ChatView (v0.20 ticket 01)

## Apple HIG ground-truth references

- NSApplication applicationIconImage: https://developer.apple.com/documentation/appkit/nsapplication/applicationiconimage
- App icons HIG: https://developer.apple.com/design/human-interface-guidelines/app-icons
- CFBundleIconFile: https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleiconfile
- codesign ground truth: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution

## Q22 real verification (must run after commit)

1. `./Scripts/build-app.sh` exit 0
2. `codesign --verify --verbose=2 build/Wenshu.app` exit 0
3. After `open build/Wenshu.app` check Dock (老板 8/19 evening 拍 self cmd+shift+3 screenshot)
4. AXTree check owner=WenshuApp + window title="文枢"
5. cua-driver capture(app=WenshuApp) verify wenshu content rendering