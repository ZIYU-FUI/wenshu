# 04 — Use Icon Composer (LOGO.icon) to replace the 3 icns files (老板 8/21 new decision)

**What to build:**
老板 2026-08-21 16:00 delivered `/Users/anbaiqiang/Desktop/LOGO.icon/` (= Apple Icon Composer format). The single source of truth is `Assets/wenshu-original-touming.png` (1280×1920 RGBA, transparent background) + `icon.json` (`automatic-gradient` + `layers` + `shadow` + `translucency` + `supported-platforms`).

macOS 27 standard pattern: the App Icon uses a single `.icon` file (= Icon Composer) as the source of truth; the system auto-derives:
- dark variant (dark background) + light variant (light background) + tinted variant (accent color)
- platform mask: macOS / iPadOS share squares; watchOS uses circles

Advantages:
- Single source of truth — 老板 edits 1 PNG / 1 icon.json, and changes apply globally.
- No need for 11 icns reps.
- No icns mask chunk needed (the platform mask is automatic).
- No need to manually re-export dark/light PNGs.

**Blocked by:** 老板 finishing edits to `/Users/anbaiqiang/Desktop/LOGO.icon/` (in progress).

**Status:** ✅ done — commit `0aabd989e`. 老板's LOGO.icon uses the macOS 27 Icon Composer single-source-of-truth format, and AppKit auto-derives dark/light/tinted + platform mask (squares shared / circles for watchOS). Tickets 01 + 02 are also covered.

## Fix specification (4 steps)

1. 老板 edits `/Users/anbaiqiang/Desktop/LOGO.icon/icon.json` + `Assets/wenshu-original-touming.png`:
   - Enlarge the rounded-rect path on the master to 22% (Apple HIG standard, ≈225 px radius on a 1024×1024 canvas) — fixes ticket 01's corner-radius issue.
   - Lighten the "文枢" text color on the dark variant (contrast against the dark background, matching the system-color truth) — fixes ticket 02's follow-system-color issue.
   - Update `icon.json` `automatic-gradient` to the Apple HIG-recommended blue-green gradient (current `extended-srgb:0.00000,0.53333,1.00000,1.00000` is OK).
2. Copy the entire `LOGO.icon/` directory into `Sources/WenshuApp/Resources/AppIcon.icon/`:
   ```bash
   cp -R /Users/anbaiqiang/Desktop/LOGO.icon Sources/WenshuApp/Resources/AppIcon.icon
   ```
3. Delete `AppIcon.icns` / `AppIcon.dark.icns` / `AppIcon.light.icns` (3 legacy icns files removed).
4. Update `Sources/WenshuApp/Resources/Info.plist`:
   - `CFBundleIconFile = AppIcon` (keep, unchanged)
   - Add `CFBundleIconName = AppIcon` (keep)
5. Update `Package.swift`:
   - Remove the 3 icns files from `exclude` (already deleted).
   - Add `exclude: ["Resources/AppIcon.icon"]` (SwiftPM should not process the `.icon` directory).
6. Update `Scripts/build-app.sh`:
   - Remove the 3 icns `cp` lines.
   - Add `cp -R Sources/WenshuApp/Resources/AppIcon.icon build/Wenshu.app/Contents/Resources/`.
7. 1 ticket 1 commit + Q33 verification (parse `AppIcon.icon/icon` + byte-compare the `Assets/` PNG) + 老板 macOS Dock verification of 4 modes (default / dark / transparent / tinted).

## Acceptance

- [ ] Entire `AppIcon.icon/` directory in the project (`icon.json` + `Assets/`)
- [ ] The 3 legacy icns files removed
- [ ] `Info.plist` unchanged (`CFBundleIconFile = AppIcon`)
- [ ] `Package.swift` excludes `AppIcon.icon`
- [ ] `build-app.sh` copies `AppIcon.icon/` into the bundle
- [ ] `codesign --verify` exit 0
- [ ] `./Scripts/build-app.sh` exit 0
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS Dock verification:
  - [ ] Default mode: LOGO corner radius matches Apple HIG
  - [ ] Dark mode: LOGO dark background + light text (ticket 02 text-color truth)
  - [ ] Transparent mode: LOGO renders transparently
  - [ ] Tinted mode: LOGO shows the accent color truth

## Out of scope (Q20 hard constraint)

- `App.swift` / `LayoutShellView` / `ChatView` (unrelated to this ticket)
- The 3 icns master PNGs (8/11 老板 Sketch re-exports, kept on the Desktop as historical snapshots, not in the project)
- v0.21 chat ticket 01 (unrelated)

## Apple HIG references

- https://developer.apple.com/design/human-interface-guidelines/app-icons
- https://developer.apple.com/documentation/xcode/icon_composer (Icon Composer)
- https://developer.apple.com/documentation/xcode/writing-an-app-icon (macOS 27 `.icon` pattern)

## References

- **Merges**: ticket 01 (LOGO corner radius) + ticket 02 (LOGO dark variant text color) — after LOGO.icon adoption these two tickets pass automatically and do not need to run separately
- Depends on: 老板 finishing edits to `/Users/anbaiqiang/Desktop/LOGO.icon/`
- Required by: none

## 老板's decision record (8/21 16:00)

- 老板 delivers `LOGO.icon`, a single source of truth.
- The macOS 27 standard pattern takes priority over backward-compatible icns.
- Running ticket 04 = tickets 01 + 02 + the 3 legacy icns files are all replaced — full closure.
