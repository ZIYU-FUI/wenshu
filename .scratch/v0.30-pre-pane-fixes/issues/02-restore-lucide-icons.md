# 02 — restore Lucide square-plus + square-arrow-right icons

**What to build:**

Boss 2026-08-30 OOB '恢复那两个按钮, 还有 icon' (= restore the 2 buttons
AND their icons). My v0.30 sidebar rewrite (commit `c5ed76169`) had
simplified the 新建 button label from
`LucideIcon("square-plus", size: 18)` (= v0.27 commit `bca226704`)
to `Image(systemName: "plus")` (= SF Symbol, mixing icon families).

Fix: revert the 新建 button to use `LucideIcon("square-plus", size: 18)`.
入驻 button already used `LucideIcon("square-arrow-right", size: 18)`
(= correct from previous commit, no change needed).

**Blocked by:** None (= 01 was the only blocker and both can be
reordered, but 02 logically follows 01 because the buttons are only
visible after flipping the default).

**Status:** ready-for-agent (= already committed as `0f7f28ede`,
this ticket documents the commit after-the-fact per Q5.6 partial
commit 接管规范).

## Fix specification

1. In `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`,
   locate `zoneHeaderButtons` (~line 320).
2. Find the Menu trigger label that currently uses
   `Image(systemName: "plus")`.
3. Replace with `LucideIcon("square-plus", size: 18)` + add
   `.foregroundStyle(Color.secondary)` (= match the
   `square-arrow-right` button style).
4. Update inline comment to cite v0.27 commit `bca226704` as the
   reference implementation.

## Acceptance

- [ ] 新建 button icon = `square-plus` (Lucide, rounded square with
  +), NOT SF Symbol "plus"
- [ ] 入驻 button icon = `square-arrow-right` (Lucide, already
  correct)
- [ ] Both icons render at 18 PT (= `size: 18` per v0.27 commit)
- [ ] Build exit 0
- [ ] Screenshot verified: 2 Lucide icons visible in trailing area
  (= rounded square shape, NOT SF Symbol raw shape)

## Out-of-scope (= NOT in this ticket)

- Adding additional zone header buttons (e.g. settings, search).
  Out of scope for boss OOB.
