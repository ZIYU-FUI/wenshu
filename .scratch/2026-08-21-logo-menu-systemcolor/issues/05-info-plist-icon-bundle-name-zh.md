# 05 — Info.plist CFBundleName / IconFile / IconName Chinese + Icon Composer path

**What to build:**
老板 2026-08-21 verified ticket 04 (Icon Composer) and reported: the Dock LOGO didn't appear (blank rounded rectangle + placeholder icon). 老板 ruled: "try changing the APP name to Chinese — the menu bar should follow automatically."

**Blocked by:** None.

**Status:** ✅ done — commit `e474965`.

## Fix specification

1. `CFBundleIconFile = AppIcon.icon` (add the `.icon` suffix so AppKit finds the `AppIcon.icon/` directory).
2. `CFBundleIconName = AppIcon.icon` (same).
3. `CFBundleDisplayName = 文枢` (keep Chinese).
4. `CFBundleName = 文枢` (switch to Chinese — Finder display + system menu name follow).

## Root cause

- Ticket 04 commit `0aabd989e` landed `AppIcon.icon/` inside the build bundle, but `Info.plist` still had `CFBundleIconFile = AppIcon` (no suffix) → AppKit looks for `AppIcon.icns` (missing) or `AppIcon` (missing) → falls back to a placeholder icon.
- 老板's `CFBundleDisplayName` was already "文枢", yet the menu bar's first item was still English "wenshu" → SwiftUI injects "wenshu" because `WindowGroup("文枢")`'s first-parameter `title` goes through `LocalizedStringKey`, which auto-localizes to English (the system primary language may not be `zh_CN`).
- Fix: update the 3 fields in `Info.plist` + register the Icon Composer path correctly.

## Acceptance

- [x] `CFBundleIconFile = "AppIcon.icon"`
- [x] `CFBundleIconName = "AppIcon.icon"`
- [x] `CFBundleDisplayName = "文枢"`
- [x] `CFBundleName = "文枢"`
- [x] `swift build` exit 0
- [x] `codesign --verify` exit 0
- [ ] 老板 macOS verification:
  - [ ] Dock LOGO shows the real asset (not a blank rounded rectangle)
  - [ ] When the system appearance changes, the LOGO automatically follows dark/light/tinted
  - [ ] Menu bar first item = "文枢" (Chinese, not English `wenshu`)

## Out of scope

- `AppIcon.icon/` (already landed in ticket 04; unchanged)
- `Package.swift` (unchanged)
- `Scripts/build-app.sh` (unchanged)
- `App.swift` (unchanged)
- `Sources/WenshuApp/Views/Chat/ChatView.swift` (v0.21 chat, unrelated to this ticket)

## References

- Depends on: ticket 04 (Icon Composer)
- Required by: ticket 03 (menu bar "wenshu" → "文枢" verification)
