# 07 — LOGO dark/light automatically follows the system theme (老板 2026-08-20 拍)

**What to build:**

老板 2026-08-20 10:35 拍 "LOGO is in, but does not follow the system theme". Engineering management authorized by 老板 (8/19 拍 "you decide on your own") + 1 ticket 1 commit hard rule + po main flow 6 steps.

## Fix ground truth

1. Copy `wenshu-icon-dark.icns` (367481 bytes, 8 reps ic04/07/10/11/12/13/14/info) → `Sources/WenshuApp/Resources/AppIcon.dark.icns`
2. Copy `wenshu-icon-light.icns` (369946 bytes, 8 reps) → `Sources/WenshuApp/Resources/AppIcon.light.icns`
3. Modify `Scripts/build-app.sh` line 30-31 to add `cp` for both into `build/Wenshu.app/Contents/Resources/AppIcon.dark.icns` + `AppIcon.light.icns`
4. Keep `AppIcon.icns` (fallback universal version, AppKit falls back when dark/light not found)

## Acceptance

- `ls -la Sources/WenshuApp/Resources/AppIcon*.icns` shows 3 files: `AppIcon.icns` + `AppIcon.dark.icns` + `AppIcon.light.icns`
- `ls -la build/Wenshu.app/Contents/Resources/AppIcon*.icns` shows the same 3 files
- macOS system Dark Mode → Dock + Launchpad + cmd+tab shows the dark LOGO
- macOS system Light Mode → Dock + Launchpad + cmd+tab shows the light LOGO
- 老板 macOS toggles system appearance, LOGO follows automatically (cmd+shift+3 screenshot verification)

## Do not touch

- AppIcon.icns fallback kept
- App.swift / Package.swift / Info.plist / menu bar (unrelated to this ticket)

## Ground-truth references (Apple HIG)

- App icon dark/light paradigm: https://developer.apple.com/design/human-interface-guidelines/app-icons
- Asset catalog dark/light variant: https://developer.apple.com/documentation/xcode/supporting-multiple-appearances-in-your-app-s-icons