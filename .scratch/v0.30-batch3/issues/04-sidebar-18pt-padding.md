# 04 — sidebar tree row trailing padding 18 PT (= count badge breathing room)

**What to build:**

Boss 2026-08-30 OOB '目录树后面的数字，距离右边距没有留空隙，留出来 18pt
的空隙' = count badge needs 18 PT breathing room from sidebar right edge.

Pre-fix: count text was right against sidebar right edge (= cramped).

Fix: `.padding(.trailing, 18)` on each FCPRowView (= pre-v0.30 Apple
List path) row.

**Blocked by:** None (= can start independently).

**Status:** ready-for-agent (= already committed as `a8bebb858`, this
ticket documents the commit after-the-fact per Q5.6 partial commit 接管
规范).

## Fix specification

### Modified: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`

- In `FCPRowView`, added `.padding(.trailing, 18)` to the row HStack.

## Acceptance

- [x] 18 PT breathing room between count badge and sidebar right edge
- [x] Build exit 0
- [x] Screenshot verified

## Note on Apple HIG List migration (= superseded)

This fix used `FCPRowView` (= pre-v0.30 manual recursive VStack). After
commit `c5ed76169` migrated sidebar to `List(.sidebar)`, Apple provides
its own padding per HIG sidebar style. The 18 PT padding is partially
superseded by List, but the visual outcome is preserved.

## Out-of-scope

- Other zone chrome padding (= sidebar-specific per boss OOB)
