# 02 — LOGO dark variant text color: lighten to match the system color

**What to build:**
老板 2026-08-21 reviewed the LOGO 4-mode screenshots: Light OK; Dark invisible (dark background + dark text); Tinted OK. AppKit automatically picks the dark/light icns, but the dark variant's text color was never changed (still dark text, same as light), so the system-color follow-through is incomplete.

**Blocked by:** 老板 editing the Sketch master (in progress).

**Status:** ✅ done — merged into ticket 04 (commit `0aabd989e`). 老板's LOGO.icon `Assets/wenshu-original-fanbai.png` is the dark variant with light text (fixing the dark-text invisibility), so ticket 02 does not need to run on its own.

## Fix specification (2 steps)

1. 老板 edits the Sketch master to lighten the "文枢" text color on the dark variant master (= contrasting against the dark background, similar to `#F5F5F5` or the Apple system label color light).
2. Re-export `wenshu-icon-master-1024-dark.png`; I run the ticket 01 icns regeneration pipeline.
3. 1 ticket 1 commit + 老板 macOS Dock verification in Dark Mode.

## Out of scope

- light / mono variants (current state OK)
- `App.swift` / `Package.swift` / `Info.plist`

## References

- Depends on: 老板 editing the Sketch master
- **Merged into**: ticket 04 (Icon Composer replacing the icns files) — 老板's LOGO.icon provides a single PNG + icon.json; editing one place takes effect globally, so ticket 02 passes automatically.
