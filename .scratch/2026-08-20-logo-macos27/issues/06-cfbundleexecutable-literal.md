# 06 — Info.plist CFBundleExecutable literalize (老板 2026-08-20 拍)

**What to build:**

老板 2026-08-20 10:25 拍 "LOGO is in, but there is a wrong identifier" + "and it still has no rounded corners". The root cause is not the icon not being applied, it's that the entire .app bundle cannot launch: `open build/Wenshu.app` reports `The application cannot be opened because its executable is missing`. Dock shows the macOS "missing icon" prohibition placeholder (no rounded corners = no real icon applied, system renders per placeholder).

## Root cause

- `Sources/WenshuApp/Resources/Info.plist` L10 `CFBundleExecutable = "$(EXECUTABLE_NAME)"`
- This is an Xcode build setting placeholder, **SwiftPM does not expand** the `$(EXECUTABLE_NAME)` variable
- SwiftPM copies Info.plist as a raw plist into `.app/Contents/Info.plist`, literal string = `$(EXECUTABLE_NAME)`
- AppKit expects `Contents/MacOS/$(EXECUTABLE_NAME)` binary file to exist → not found (actual file is `WenshuApp`) → "executable missing" error
- Consequence: `open build/Wenshu.app` fails → Dock tile falls back to the macOS system "missing icon" prohibition placeholder (gray box + red prohibition circle + blurred pictograph)

## Fix

Modify `Sources/WenshuApp/Resources/Info.plist`:
- L10 `CFBundleExecutable` from `"$(EXECUTABLE_NAME)"` → `"WenshuApp"` literal

## Acceptance

- `plutil -p build/Wenshu.app/Contents/Info.plist | grep CFBundleExecutable` = `WenshuApp`
- `open build/Wenshu.app` exit 0
- `pgrep -lf WenshuApp` shows `build/Wenshu.app/Contents/MacOS/WenshuApp` running
- Dock 文枢 LOGO visible + Apple HIG auto rounded-corner mask applied

## Root-cause references (Apple HIG)

- CFBundleExecutable: https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleexecutable
- "Bundle executable name (literal string). The name must match the executable in Contents/MacOS/."

## Do not touch

- AppIcon.icns ground truth (473 KB / 11 reps, v0.20 ticket 04 landed)
- Scripts/build-app.sh (50 lines, ticket 05 landed)
- Package.swift linker flag deletion (ticket 04 landed)
- App.swift runtime applicationIconImage deletion (ticket 04 landed)
- menu / splitter / drag line / other (unrelated to this ticket)

## Related commit

- `cbfa0b20c` — fix(wenshu): v0.20 ticket 06 Info.plist CFBundleExecutable changed to literal 'WenshuApp' (老板 2026-08-20 拍 'no rounded corners + Dock prohibition placeholder')