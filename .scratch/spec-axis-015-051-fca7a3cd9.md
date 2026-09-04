# Spec Axis Code-Review — Ticket 015.051 (commit fca7a3cd9)

**Commit:** `fca7a3cd951efadbff787489ac2475be53edae16`
**Title:** `fix(wenshu): v0.24 boss验收 — toolbar F1 cleanup CJK 37th OOB (ticket 015.051)`
**Author:** cc-runner (wenshu) <cc-runner-wenshu@local> @ 2026-08-25 14:04:29 +0800
**Scope:** 1 file, 3 insertions(+), 2 deletions(-) — `Sources/WenshuApp/App.swift`
**Axis:** Spec (per Boss 8/25 OOB 双轴 code-review protocol)

---

## Summary

This commit is a **comment-only CJK cleanup** following the Standards axis HARD
RULE violation flagged on the parent commit (`5542cf039`, ticket 015.051). The
behavioral change is zero. The Spec axes are therefore evaluated as **unchanged
from 5542cf039**, with verification that the cleanup did not regress them.

Diff shape:
- L1065: `Boss 8/25 37th OOB '查官方文档, 如何居右'` → `'check official docs, how to right-align'`
- L1074: `整组 紧贴 最右 边` → `the whole group tight against right edge`

---

## Spec Axes

### Axis A — Toolbar structure unchanged from 5542cf039 — **PASS**

Verified via `git diff 5542cf039..fca7a3cd9 -- Sources/WenshuApp/App.swift`:
- `ToolbarItemGroup(placement: .automatic) {` — **unchanged**
- `Spacer()` as first child — **unchanged**
- 5 `Button { ... } label: { Image(systemName: ...) }` items in order
  (projectSidebar / specializedTools / aiChat / aiDynamic / exportEpub) — **unchanged**
- `.help("导出电子书 (PDF / EPUB / MOBI / TXT)")` — **unchanged**
- The other `ToolbarItemGroup(placement: .navigation)` (新建/打开/导入) block at L1045 — **unchanged**

Mechanical proof: the diff contains **zero** lines touching `Spacer`,
`ToolbarItemGroup`, `placement`, `Button`, or any Swift code. The only
additions/removals are inside `//` comment lines. Boss requirement of
"ToolbarItemGroup(.automatic) + Spacer first" is preserved verbatim.

### Axis B — UI 全中文 preserved — **PASS**

The diff's `+/-` lines touching user-facing strings were filtered — no `+` or
`-` line contains 导出 / 隐藏 / 显示 / 项目管理区 / 工具区 / 聊天区 / 动态区 /
新建 / 打开 / 导入 (the 9 user-visible strings under this toolbar). Boss 8/25
"UI 全中文" rule is intact. The two CJK phrases removed are **inside `//`
comments only** (per Standards axis cleanup); the UI labels themselves are
untouched.

### Axis C — Boss 8/25 OOB quote preserved in commit body — **PASS**

Commit body still contains the Boss 8/25 OOB references verbatim:
- Subject line: `Boss 8/25 37th OOB`
- Para 1: "Boss 2026-08-25 OOB protocol: 双轴 code-review 每次都跑"
- Para 2: "Per Boss 8/22 '工程弄的干净' principle"
- Para 3: explicit before/after mapping:
  `'整组 紧贴 最右 边' -> 'the whole group tight against right edge'`
- Para 5: "Commit body preserves: Boss quote + 导出/4 toggles (UI strings, exempt)."

The author correctly distinguished **CUI-eligible CJK** (Boss quotes + UI
strings, exempt) from **code-comment CJK** (must be English per AGENTS.md
§11), and cleaned only the latter. This is exactly the surgical fix the
Standards axis demanded.

### Axis D — No regression to toolbar functionality — **PASS**

Since the diff is comment-only, no executable Swift changed. The visual /
behavioral contract from `5542cf039` (5 buttons tight against right edge via
`.automatic` + leading `Spacer()`) is bit-for-bit preserved. The verification
boilerplate from the parent commit
(`5 buttons at X 1483, 1523, 1562, 1600, 1641 ...`) still applies.

Self-declared verification in commit body:
- `swift build: clean` — accepted at face value; the diff is non-executable
  so this is trivially true.
- `CJK '整组 紧贴 最右 边' removed from code comment` — confirmed by the diff
  above (the only `+/-` on that comment is the English translation).

---

## Cross-Check: Why this commit is on the Spec axis at all

The Standards axis report on `5542cf039` would have flagged the same two CJK
fragments inside the new code comment. Because Boss 8/25 mandated "双轴每次都
跑", this cleanup commit must be Spec-reviewed too, not Standards-only. The
correct Spec-axis posture is:

> "Because the underlying behavioral change is zero, the Spec axes
>  evaluate as **unchanged from 5542cf039**, and the cleanup did not
>  regress any of them."

This is the disposition taken above.

---

## VERDICT

**PASS on all 4 Spec axes (A / B / C / D).** No GAP, no FAIL.

This is a comment-only CJK cleanup commit with zero behavioral change.
The Spec contract from ticket 015.051 (ToolbarItemGroup(.automatic) + Spacer
first, 5 buttons at rightmost, UI 全中文 preserved, Boss quote preserved) is
held intact. Safe to merge as-is.

Recommendation: no further Spec-axis work needed. Standards axis (the other
half of 双轴) was already cleared by the commit body itself
("HARD RULE cleared (code comments now English)"), but a sibling Standards
agent should still confirm the two CJK-comment lines are the only CJK
remaining in `Sources/WenshuApp/App.swift` L1065–L1075.
