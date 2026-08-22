# 01 — Toolbar width stretched by VStack stretch to fill zone actual width (v0.16 ticket 01)

**What to build:**
老板 2026-08-19 拍 "zone module components have implementation issues, top bar / bottom bar placed inside zone module, varies with zone module size"

After change: top bar / bottom bar no pass totalW width, VStack sub-view default stretch full width, auto stretch zone actual width

**Blocked by:** None
**Status:** done — commit `ae5bbf82e` (老板 8/19 verified pass)

## Acceptance criteria

- [x] ZoneTopToolbar delete totalW parameter
- [x] ZoneBottomToolbar delete totalW parameter
- [x] Internal no `.frame(width:)`
- [x] Height 30 PT / ICON 18 PT / placeholder text 13 PT / divider 2 PT all preserved
- [x] 6 zones all effective (sidebar / preview / editor / tools / chat / dynamic)
- [x] `swift build` exit 0
- [x] 老板 8/19 actual test verified pass