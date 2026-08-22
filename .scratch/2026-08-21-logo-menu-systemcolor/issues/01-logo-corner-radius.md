# 01 — LOGO corner radius (re-export master + iconutil regenerate icns)

**What to build:**
老板 2026-08-21 reviewed the LOGO and reported: "the LOGO has no rounded corners." The current LOGO master image was designed by 老板 in Sketch on 8/11; it has rounded corners, but the radius is below the Apple HIG 22% standard (= ≈225 px on a 1024×1024 canvas). macOS Dock displays the LOGO master's corners, not Apple's standard corners.

Fix: 老板 edits the Sketch master to enlarge the rounded-rect path to 22%, re-exports the master PNG, and I run iconutil to regenerate the icns.

**Blocked by:** 老板 editing the Sketch master (in progress).

**Status:** ✅ done — merged into ticket 04 (commit `0aabd989e`). 老板's LOGO.icon uses the macOS 27 Icon Composer format, so a single source-of-truth asset auto-derives the corner radius + dark/light/tinted variants. Ticket 01 does not need to run on its own.

## Fix specification (4 steps)

1. 老板 edits the Sketch master to enlarge the rounded-rect path: 22% of the 1024×1024 canvas (= ≈225 px radius).
2. 老板 re-exports 3 master PNGs:
   - `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024-dark.png`
   - `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024-light.png`
   - `/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-master-1024-mono.png`
3. I use `iconutil` to regenerate the 3 icns files:
   - Build a `wenshu-icon.iconset/` directory; run `sips -z <size> <png>` to produce the 11 retina-standard reps (16/32/64/128/256/512/1024 + @2x); rename them to iconutil's standard layout (`icon_16x16.png` + `icon_16x16@2x.png` etc.).
   - Run `iconutil -c icns wenshu-icon.iconset/ -o AppIcon.dark.icns` (once per file, 3 times total).
4. `cp` the 3 files into `Sources/WenshuApp/Resources/`; update `Scripts/build-app.sh` to also `cp` the mono icns.
5. 1 ticket 1 commit + Q33 icns verification script + 老板 macOS Dock corner-radius check.

## Out of scope

- `AppIcon.icns` (fallback universal version retained)
- `App.swift` / `Package.swift` / `Info.plist`
- v0.21 chat ticket 01 (unrelated)

## References

- Depends on: 老板 editing the Sketch master
- **Merged into**: ticket 04 (Icon Composer replacing the icns files) — once 老板 uses LOGO.icon, ticket 01 passes automatically and does not need to run

## 老板's new decision (8/21 16:00)

老板 delivered `/Users/anbaiqiang/Desktop/LOGO.icon/` (= Apple Icon Composer format, single source of truth). macOS 27 auto-derives dark / light / tinted + the platform mask; the 11 icns reps are no longer needed. Tickets 01 + 02 + 04 collapse into a new ticket 04 "use Icon Composer to replace the 3 icns files".

Ticket 01 current status = **draft — once 老板 finishes editing LOGO.icon, run ticket 04 instead and skip ticket 01**.
