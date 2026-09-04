# Standards axis RE-VERIFY — v0.30 pane-routing-splitter-fix (forward-fix #1)

- **Reviewer**: Standards sub-agent (Q34 step 6 / Q5.4 loop gate)
- **Date**: 2026-09-01
- **Branch**: `wt/multi-agent-dispatch`
- **Commit under review (the forward-fix)**: `3fc9441b5 docs(wenshu): v0.30 — H-3 English-only forward-fix on pane-routing-splitter-fix`
- **Prior commits still under standards jurisdiction** (NOT amended per Q5.4 do-not-amend): `bd565247c`, `59bc66d69`, `74c327db9`, `f380a2cd4`, `210d042ba`, `d54451539`
- **Predecessor standards report (the FAIL)**: `.scratch/v0.30-pane-routing-splitter-fix/code-review-standards-axis.md` (14 H-3 violations across 4 surfaces)
- **Spec-axis context (separate loop)**: `.scratch/v0.30-pane-routing-splitter-fix/code-review-spec-axis.md` (PARTIAL with 2 HIGH gaps A + F; both fixed in `0b4084c00`, NOT in this forward-fix)
- **Precedent**: `064e381ce docs(wenshu): v0.30 — H-3 English-only forward-fix on preview-sort-button spec` (same pattern)

## Verdict

**FAIL** — forward-fix commit `3fc9441b5` successfully cleans all 7 in-scope file surfaces (zero CJK outside code fences, zero source-code logic changes, zero new H-1/H-2/H-4 violations) **but introduces 1 new H-3 violation = 4 CJK lines in the forward-fix commit message body itself**, while explicitly claiming "AGENTS.md v0.07.4 §5-6 English-only honored for THIS commit" in the same body (= the same self-contradictory footer pattern flagged in the original FAIL report).

This is a Q5.4 loop-gate FAIL, not a REGRESS (the prior 14 violations are gone; the forward-fix delivers its core promise on in-scope files; the new violation is on a surface the predecessor report also flagged as H-3, just one the forward-fix author missed).

**Recommended next action**: amend the forward-fix commit body (`git commit --amend` BEFORE push) to remove the 4 CJK lines, then this becomes PASS. Alternative: a tiny second forward-fix on top that re-paraphrases the body. Note that the 6 prior commit bodies remain CJK-bearing per the documented Q5.4 do-not-amend carve-out (see §"Out of scope" of forward-fix body).

## Re-check table (14 original H-3 violations)

| # | Original violation (from FAIL report) | Forward-fix status | Evidence |
|---|----------------------------------------|--------------------|----------|
| 1 | `PaneLayout.swift:1` — `文枢` in file-header | **CLEANED** | File now reads `// PaneLayout.swift · Wenshu · v0.30 ticket 01 / 4` (no CJK). |
| 2 | `PaneLayout.swift:3-4` — Boss OOB Chinese quote in 2 contiguous comment lines | **CLEANED** | Replaced with English paraphrase + reference to `.scratch/spec.md` for the verbatim CJK (= correctly moved into the §6 .scratch carve-out surface). |
| 3 | `PaneLayout.swift:33` — Boss OOB Chinese quote in `PaneLayout` protocol doc-comment | **CLEANED** | Now reads: `implementing this protocol (= per boss "each layout is custom-developed"; see spec.md rationale).` |
| 4 | `PaneSplitHost.swift:1` — `文枢` in file-header | **CLEANED** | File now reads `// PaneSplitHost.swift · Wenshu · v0.30 ticket 02 / 4` (no CJK). |
| 5 | `PaneSplitHost.swift:4` — Boss OOB Chinese quote in source comment | **CLEANED** | Replaced with English paraphrase + reference to `.scratch/spec.md`. |
| 6 | `PaneNSController.swift:1` — `文枢` in file-header | **CLEANED** | File now reads `// PaneNSController.swift · Wenshu · v0.30 ticket 03 / 4` (no CJK). |
| 7 | `PaneNSController.swift:3-4` — Boss OOB Chinese quote in 2 contiguous comment lines | **CLEANED** | Replaced with English paraphrase + reference to `.scratch/spec.md`. |
| 8 | `PaneNSController.swift:209` — `显示 menu` Chinese label embedded in English prose (= doc-comment for `isCollapsiblePane`) | **CLEANED** | Now reads: `Which panes can the user collapse (= via the "Display" menu / sidebar toolbar toggle).` (Quoted English label + parenthetical gloss; matches the `PaneNSController.swift:79-83` pattern that already uses `"Display"` quoted.) |
| 9 | Commit `bd565247c` body lines 3-8 — Boss OOB Chinese quotes (4 lines) | **NOT AMENDED** | Per forward-fix "OUT OF SCOPE" section + Q5.4 do-not-amend. Forward-fix commit IS the documented exception. **Still CJK-bearing, by design.** Body has 7 CJK lines (`grep -c '[一-鿿]' git log -1 --format='%b' bd565247c` = 7). |
| 10 | Commit `f380a2cd4` body line 25 — `显示菜单` Chinese label | **NOT AMENDED** | Same Q5.4 carve-out. Body has 1 CJK line. |
| 11 | Commit `210d042ba` body line 1 — Boss OOB Chinese quote | **NOT AMENDED** | Same Q5.4 carve-out. Body has 1 CJK line. |
| 12 | `.scratch/spec.md` — 13 CJK lines (L3, 4, 6, 10, 84, 109, 112, 130, 149, 156, 162, 191, 195) | **CLEANED** | `grep -c '[一-鿿]' spec.md` = 0. Boss OOB Chinese quotes replaced with English paraphrase; verbatim Chinese moved to `[CJK-original]` reference blocks per the same pattern from `064e381ce`. |
| 13 | `.scratch/three-reference-layouts.md` — 10 CJK lines (L3, 29, 33, 47, 66, 73, 80, 82, 92) | **CLEANED** | `grep -c '[一-鿿]' three-reference-layouts.md` = 0. Naked Chinese prose (`360 项`, `项目管理区`, `FCP 8 区`, `Hermes 对话优先`, etc.) all replaced with English. |
| 14 | `.scratch/issues/04-feature-flag-wire.md` — 2 CJK lines (L31, 54) | **CLEANED** | `grep -c '[一-鿿]' 04-feature-flag-wire.md` = 0. `显示菜单` → `"Display" menu`. |

**Hard-violation re-check count: 14 of 14 source-file/scratch-file violations CLEANED; 3 of 3 commit-body violations intentionally LEFT (per Q5.4 carve-out, not in scope of this forward-fix).**

## New violations introduced by forward-fix

| ID | Rule | Location | Evidence | Severity |
|----|------|----------|----------|----------|
| **H-3 (new)** | AGENTS.md v0.07.4 §5-6 English-only in commit message bodies | `3fc9441b5` body L11, L17, L18, L42 | Body line 11: `quotes + 文枢 project name + 显示 menu label embedded in English` (3 CJK chars). Body line 17: `CJK lines (= Boss OOB Chinese quotes + 显示/隐藏 menu label + 360 项` (4 CJK chars). Body line 18: `+ 项目管理区 + FCP 8 区 etc.) with English paraphrase.` (4 CJK chars). Body line 42: `- grep -c '[一-鿿]' on all 7 modified files = 0 (= zero CJK)` (the `'[一-鿿]'` is a grep argument, but it is itself a CJK-range character class used in this English sentence as a quoted regex — flag this as borderline: technically 2 CJK range-bound chars `一` and `鿿` are inside the single quotes, but they appear inside a code-span-style regex argument and are visually a character-class definition, not prose). The commit footer (L44) says `AGENTS.md v0.07.4 §5-6 English-only honored for THIS commit` — self-contradictory with body L11/17/18. This is **the exact same self-contradictory footer pattern** flagged in the original FAIL report (see H-3 #3 footnote re: bd565247c footer). | hard |

**New-violation count: 1 (4 CJK lines in 1 commit body).**

## Spec-axis re-verify (informational — out of standards jurisdiction)

Both HIGH spec gaps from `code-review-spec-axis.md` are implemented in `0b4084c00` (the commit immediately before this forward-fix):

- **Gap A** (AC #4 in ticket 03): `splitView(_:effectiveRect:forDrawnRect:ofDividerAt:)` override now present in `PaneNSController.swift:187-215` (= `nonisolated override func splitView(_:effectiveRect:forDrawnRect:ofDividerAt:) -> NSRect`). The override widens the hit area by `dividerHitPadding = 4` PT on the perpendicular axis (= vertical divider extends in y; horizontal extends in x) so the grabbable region is ~9 PT total (1 PT drawn + 4 PT pad each side). Matches FCP / Xcode / System Settings hit-area feel.
- **Gap F** (AC #9 in ticket 04): `.wenshuToggleZone` notification observer wired in `PaneNSController.swift:84-89` (`NotificationCenter.default.addObserver(self, selector: #selector(handleToggleZone(_:)), name: .wenshuToggleZone, object: nil)`). `handleToggleZone(_:)` at L98-121 maps `ZoneSlot` → `TabKind`, walks `splitViewItems`, and toggles `item.isCollapsed` for items where `canCollapse == true` (= matches FCP sidebar/chat/dynamic hide/show affordance).

The forward-fix did NOT modify any logic that would affect Gap A or Gap F. The English rewording at `PaneNSController.swift:79-83` (the display-menu observer comment block) is purely cosmetic prose.

## Verification artifacts

### (a) All 7 modified files are CJK-free outside code fences

`grep -c '[一-鿿]' <file>` (raw line count, including code fences):

```
Sources/WenshuApp/Views/Layout/PaneLayout.swift            = 0
Sources/WenshuApp/Views/Layout/PaneNSController.swift      = 0
Sources/WenshuApp/Views/Layout/PaneSplitHost.swift         = 0
.scratch/v0.30-pane-routing-splitter-fix/spec.md           = 0
.scratch/v0.30-pane-routing-splitter-fix/three-reference-layouts.md = 0
.scratch/v0.30-pane-routing-splitter-fix/issues/04-feature-flag-wire.md = 0
.scratch/v0.30-pane-routing-splitter-fix/verify-recipe.md  = 0
```

Out-of-fence check (excluding ``` code blocks ```, lines containing CJK):

```
Sources/WenshuApp/Views/Layout/PaneLayout.swift            = 0
Sources/WenshuApp/Views/Layout/PaneNSController.swift      = 0
Sources/WenshuApp/Views/Layout/PaneSplitHost.swift         = 0
.scratch/v0.30-pane-routing-splitter-fix/spec.md           = 0
.scratch/v0.30-pane-routing-splitter-fix/three-reference-layouts.md = 0
.scratch/v0.30-pane-routing-splitter-fix/issues/04-feature-flag-wire.md = 0
.scratch/v0.30-pane-routing-splitter-fix/verify-recipe.md  = 0
```

Broader CJK coverage (CJK Unified + Hiragana/Katakana ranges): all 7 files = 0/0.

### (b) Source code logic unchanged

Forward-fix diff (`git diff 0b4084c00..3fc9441b5 -- Sources/.../*.swift`) touches **only comment/doc-comment lines**. Specifically:

- `PaneLayout.swift`: 3 hunks, all comment lines (file-header + 2 doc-comment lines on `PaneLayout` protocol). 0 code-line changes.
- `PaneSplitHost.swift`: 1 hunk, comment lines (file-header block). 0 code-line changes.
- `PaneNSController.swift`: 3 hunks, all comment lines (file-header + the `显示 menu → NSSplitViewItem.isCollapsed bridge` block comment + the `isCollapsiblePane` doc-comment). 0 code-line changes.

Verification: `git show 3fc9441b5 -- Sources/.../*.swift | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -vE '^[+-][[:space:]]*(//|/\*|\*|///)'` returns **0 lines** = no non-comment code changes.

This means: `PaneNSController.effectiveRect` override is intact (L187-215), `handleToggleZone` observer is intact (L84-121), `isCollapsiblePane` predicate is intact (L356-365), `FCPLayout.makeSplitController` is intact, all imports + protocol conformance is intact. Zero behavior change.

### (c) No new H-1 dead code, H-2 scope creep, H-4 forbidden 修真 tokens

- **H-1 (dead code)**: `git show 3fc9441b5 -- Sources/.../*.swift | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -vE '^[+-][[:space:]]*(//|/\*|\*|///)'` = 0 lines = no new code = no new dead code. No existing dead code was cleaned (= the spec defers the ~1200-line PaneRenderer/NativeSplitter cleanup to PR 6).
- **H-2 (scope creep)**: `git diff 0b4084c00..3fc9441b5 --name-only` = exactly the 7 files the forward-fix body promises (3 .swift + 4 .md). No incidental edits, no drive-by refactors, no debug `print`, no commented-out blocks. Out-of-scope files untouched: `WorkspaceState.swift`, `WorkspaceStore.swift`, `WorkspaceView.swift`, `NativeSplitter.swift`, `PaneSplitter.swift`, `App.swift`, `CONTEXT.md`, `README.md`, `CLAUDE.md` (all 9 verified untouched = the boss OOB "functional preservation" directive honored).
- **H-4 (forbidden 修真 family)**: `grep -F '修真' PaneLayout.swift PaneNSController.swift PaneSplitHost.swift spec.md three-reference-layouts.md 04-feature-flag-wire.md verify-recipe.md` = 0 matches. Same for `渡劫 筑基 返虚 结丹 金丹 元婴 飞升 天劫 雷劫 心魔 魔障`. Plus forbidden neutral modals (`可 应当 或许 可能 应该 建议 考虑 试图 尽量 大概 也许 大概率 通常 一般来说`) on added lines of the 3 .swift files = 0 matches.

### (d) swift build exit 0

```
Building for debugging...
[Computing dependencies]
[Pre-planning 1 / 992]
[Planning deferred tasks]
[8 / 24] Highlighter_Highlighter
Build complete! (1.23秒)
EXIT=0
```

(1.23 sec; pre-existing `case will never be executed` warnings in `NewLibraryOutlineView` are NOT introduced by this forward-fix.)

## Out-of-scope surfaces (= NOT touched by forward-fix, by design)

1. **6 commit message bodies** (`bd565247c`, `59bc66d69`, `74c327db9`, `f380a2cd4`, `210d042ba`, `d54451539`) — per Q5.4 do-not-amend + the forward-fix body's "OUT OF SCOPE" section. Still CJK-bearing (counts: 7 / 0 / 0 / 1 / 1 / 0). Precedent: `064e381ce docs(wenshu): v0.30 — H-3 English-only forward-fix on preview-sort-button spec` followed the same pattern.
2. **`NativeSplitter.swift` + `PaneSplitter.swift`** — pre-existing files outside this PR's scope; CJK there unchanged per boss OOB functional preservation (= "don't touch unrelated commits; sweep in a separate ticket if needed", per the forward-fix body's own OUT OF SCOPE section).
3. **`CONTEXT.md`, `README.md`, `CLAUDE.md`** — verified CJK-free before the forward-fix (no changes needed).

## Recommended fix for the new H-3 violation

Single-line fix: `git commit --amend` on `3fc9441b5` BEFORE push, rewriting the 4 CJK lines as follows:

| Line | Current (CJK) | Proposed (English) |
|------|---------------|---------------------|
| L11 | `quotes + 文枢 project name + 显示 menu label embedded in English` | `quotes + Wenshu project name + "Display" menu label embedded in English` |
| L17 | `CJK lines (= Boss OOB Chinese quotes + 显示/隐藏 menu label + 360 项` | `CJK lines (= Boss OOB Chinese quotes + "Show/Hide" menu label + 360-item bottom bar` |
| L18 | `+ 项目管理区 + FCP 8 区 etc.) with English paraphrase.` | `+ project-management zone + "FCP 8-zone" reference etc.) with English paraphrase.` |
| L42 | `- grep -c '[一-鿿]' on all 7 modified files = 0 (= zero CJK)` | `- grep -c "<CJK range>" on all 7 modified files = 0 (= zero CJK characters; see AGENTS.md §5 for the exact character class)` |

After amend, re-run:
```
git log -1 --format='%b' 3fc9441b5 | grep -c '[一-鿿]'   # expect 0
swift build                                                  # expect exit 0
```

Then this standards-axis re-verify becomes **PASS**.

If amending is not possible (= commit is already pushed), the alternative is a second forward-fix on top (`docs(wenshu): v0.30 — H-3 forward-fix amend: remove CJK from 3fc9441b5 commit body`), but amending before push is preferred.

## Summary

| Surface | Original FAIL count | Forward-fix result | Net |
|---------|---------------------|--------------------|-----|
| Source code comments (.swift) | 8 H-3 violations (3 files) | 8 cleaned | -8 |
| `.scratch/spec.md` | 13 CJK lines | 0 CJK lines | -13 |
| `.scratch/three-reference-layouts.md` | 10 CJK lines | 0 CJK lines | -10 |
| `.scratch/issues/04-feature-flag-wire.md` | 2 CJK lines | 0 CJK lines | -2 |
| `.scratch/verify-recipe.md` (new in this PR, not flagged) | 0 | 0 | 0 |
| Commit bodies (6 prior commits, Q5.4 carve-out) | 9 CJK lines total | unchanged (by design) | 0 |
| **Forward-fix commit body itself (newly introduced)** | **0** | **4 CJK lines** | **+4 (NEW H-3)** |
| H-1 dead code | 0 | 0 | 0 |
| H-2 scope creep | 0 | 0 | 0 |
| H-4 forbidden 修真 tokens | 0 | 0 | 0 |
| `swift build` exit code | 0 | 0 | 0 |

**Final verdict: FAIL (1 new H-3 in forward-fix commit body). Re-loop once with body amended → expected PASS.**
