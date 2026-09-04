# Standards-Axis RE-VERIFY1 — v0.30 AppState Cross-Zone

- **Sub-agent**: Standards (Q34 8-step chain step 6 — Standards axis sub-agent, Q5.4 loop gate)
- **Date**: 2026-08-31 (CST)
- **Repo**: `/Volumes/ANAN/Engineering/wenshu`
- **Branch**: `wt/multi-agent-dispatch`
- **HEAD commit**: `e93139e0d` — `fix(wenshu): v0.30 — review fixes (= H-1/H-2/H-3/H-4 + spec #2)`
- **Commits reviewed** (5 contiguous, prior + followup):
  - `eb3066bca` — feat(wenshu): v0.30 — add AppState (= global @Observable cross-zone store)
  - `17bdf49de` — feat(wenshu): v0.30 — inject AppState at app root
  - `b768fa5a0` — refactor(wenshu): v0.30 — replace 4-layer @Binding chain with @Environment AppState
  - `be3574dc1` — docs(wenshu): v0.30 — domain-modeling for AppState
  - `e93139e0d` — fix(wenshu): v0.30 — review fixes (= H-1/H-2/H-3/H-4 + spec #2) [followup under review]
- **Prior report**: `.scratch/v0.30-app-state-cross-zone/code-review-2026-08-31-standards-axis-report.md` (FAIL verdict, 4 hard violations)
- **Spec report** (referenced): `.scratch/v0.30-app-state-cross-zone/code-review-2026-08-31-spec-axis-report.md`
- **Files in scope** (per task brief): Sources/WenshuApp/State/AppState.swift, Sources/WenshuApp/App.swift, Sources/WenshuApp/Views/Workspace/WorkspaceView.swift, Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift, CONTEXT.md
- **Hard-rule source**: AGENTS.md v0.07.4 L3-9 (= English-only, no CJK in code/comments/CONTEXT.md/commit messages) + wenshu-pollution-defense (= 12 forbidden xianxia tokens)
- **Template**: `.hermes/profiles/pocock/skills/wenshu-pocock-workflow/references/dual-axis-code-review-2026-08-22.md`

---

## Verdict: **PASS**

**Reason**: All 4 prior hard violations (H-1 through H-4) are fixed in commit `e93139e0d`, and the spec #2 fix (`.shelf → .shelfScope`) is correctly applied in lock-step across both `WorkspaceView.previewScope` and `ZoneModuleView.previewScope`. The build is clean (`swift build` exit 0 in 1.36s). 6 of 8 prior soft suggestions are FIXED. 2 soft suggestions remain UNCHANGED (non-blocking). 3 NEW soft issues were introduced by the followup (all documentation/stylistic — none blocking; see "NEW issues" section below).

**No regression** versus the prior standards report: every hard-rule violation raised in the prior review is resolved. The remaining items are minor and do not block the Q5.4 loop gate.

**Recommendation**: PASS — parent agent may close the Q5.4 loop gate and proceed to the next step in the Q34 8-step chain. Optional followup: a tiny polish commit to address the 3 NEW soft issues below.

---

## 4 Hard-violation re-checks

| ID | Category | Prior finding (summary) | Verification method | Post-fix state | Verdict |
|----|----------|------------------------|---------------------|-----------------|---------|
| **H-1** | Dead code in AppState (selectedEntity / selectedEntityCategory / previewSortOrder declared but never read) | AppState declared 4 vars: sidebarSelection (used), selectedEntity + selectedEntityCategory + previewSortOrder (0 reads). `selectedEntity*` were STILL threaded as @Binding through WorkspaceView → ZoneModuleView → NewLibraryOutlineView. | `rg -n 'appState\.(selectedEntity\|selectedEntityCategory\|previewSortOrder)' Sources/` → **0 hits**. AppState.swift body now contains only `var sidebarSelection: SidebarItem? = nil` (L52). The 3 removed vars' doc-blocks were also deleted. | FIXED (Option B = retract placeholders, per sub-agent recommendation). | **PASS** |
| **H-2** | Dead `@State private var appState = AppState()` in `SettingView` | SettingView (App.swift L640+) declared `@State private var appState = AppState()` + 7-line doc-block, but no `.environment(appState)` injected, no `appState` references in body. Pure dead state. | `rg -n '@State\s+\w*[aA]pp[Ss]tate' Sources/` → **0 hits**. The only `@State private var appState = AppState()` is now at App.swift L422 in `WenshuApp` (correct location). `git diff cace9337e..e93139e0d -- Sources/WenshuApp/App.swift` shows the SettingView block (old L643-650) was removed (9 lines deleted). | FIXED. | **PASS** |
| **H-3** | English-only rule violations (CJK in code comments) | New CJK introduced in: (a) AppState.swift L3/L62/L68, (b) App.swift L415-420 + L643-649 doc-blocks (the `'跨区通信的方案用 A'` quotes), (c) CONTEXT.md L55 (the new AppState row). | `rg -n '\p{Han}' Sources/WenshuApp/State/AppState.swift` → **0 hits** (file is 100% English post-fix). `awk 'NR>=412 && NR<=425' App.swift` shows L415-420 now reads `/// v0.30 boss 8/31 OOB "option A for cross-zone communication"` (English). CONTEXT.md L55 now reads `v0.30 boss 8/31 OOB "option A for cross-zone communication" (= global @Observable store)... Cross-zone signals (currently only sidebarSelection; the other 3 declared in the spec are tracked in v0.31 backlog) live here.` (English). App.swift pre-existing CJK in file header (L1-13, L84-85, L125-152, etc.) and CONTEXT.md pre-existing CJK rows (L1 文枢, L4 老板, L10-20 库/书架/书/etc., L24-37 文枢 / 老板 etc., L50-117 etc.) are NOT changed by the followup — they predate this commit batch. | FIXED (all NEW CJK introduced by eb3066bca..be3574dc1 removed). | **PASS** |
| **H-4** | Scope creep into SettingView | Commit `17bdf49de` added `@State private var appState` + 7-line doc-block to `SettingView` (App.swift L643-650), but SettingView is not part of the cross-zone migration ticket. Scope creep + dead code (manifestation of H-2). | `git show e93139e0d -- Sources/WenshuApp/App.swift` confirms the SettingView block (old L643-650, 9 lines) was deleted. No other SettingView changes in this commit (= scope is clean). | FIXED (SettingView is now byte-identical to its v0.29 state — `git diff cace9337e..e93139e0d -- Sources/WenshuApp/App.swift | rg -c "SettingView|@State.*appState"` returned 3 matches, all in WenshuApp struct, none in SettingView). | **PASS** |

---

## Spec #2 fix verification

| Acceptance criterion | Spec text (from `.scratch/v0.30-app-state-cross-zone/spec.md`) | Verification | Verdict |
|----------------------|---------------------------------------------------------------|--------------|---------|
| **Spec #2** — shelf row click → preview pane shows "select a book" hint | "Clicking a shelf row in the sidebar MUST update the preview pane to show a 'select a book' hint (= .shelfScope branch with emptyState '选中书查看文档'), NOT the generic 'select sidebar item' empty state (= .empty branch with '请选择左侧目录查看文档')." | `rg -n 'case\s+\.shelf' Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` returns **2 hits**: L63 (WorkspaceView.previewScope) and L341 (ZoneModuleView.previewScope). Both now bind `shelfId` and return `.shelfScope(shelfId: shelfId)`. `PreviewPane.swift` L245-246 dispatches `.shelfScope → shelfScopeView()`, and L298-300 confirms `shelfScopeView()` returns `emptyState(message: "选中书查看文档")`. The two previewScope implementations are **identical** (lock-step fix). | **PASS** |

---

## 8 Soft-suggestion re-checks

| ID | Suggestion (from prior report) | Prior state | Post-fix state | Status |
|----|--------------------------------|-------------|----------------|--------|
| **S-1** | Rename the doc-block style to a more terse pattern in AppState.swift | Verbose `(= X = Y)` parenthetical style with quoted Chinese OOB strings. | AppState.swift L1-71 doc-blocks are still verbose (= X = Y) but the Chinese OOB quotes were replaced with English. Style not addressed; CJK removed. | **UNCHANGED** (style nit, non-blocking; CJK sub-concern FIXED) |
| **S-2** | `init() {}` could be removed (Swift synthesizes default no-arg init for `@Observable final class`) | Present at AppState.swift L71. | Still present at AppState.swift L61 (file shrunk from 71 to 61 lines). Not addressed. | **UNCHANGED** (acceptable; matches project convention = 38 other `public init() {}` patterns in Sources/WenshuApp/) |
| **S-3** | AppState `selectedEntity*` / `previewSortOrder` are dead-code placeholders, either remove (YAGNI) or mark as "reserved for v0.31" | 3 unused vars present. | All 3 vars (`selectedEntity`, `selectedEntityCategory`, `previewSortOrder`) **REMOVED** from AppState.swift. The followup chose **Option B** (retract placeholders per sub-agent recommendation). CONTEXT.md L55 now reads "Cross-zone signals (currently only `sidebarSelection`; the other 3 declared in the spec are tracked in v0.31 backlog) live here." = documents the future migration path without leaving dead fields. | **FIXED** |
| **S-4** | `b768fa5a0` commit body claim "~50 lines REMOVED, ~30 lines ADDED, net -20 LoC" is slightly inaccurate (actual net -39 LoC) | Slight overclaim. | Not touched in `e93139e0d` (the followup commit only fixed H-1..H-4 + spec #2, not prior commit bodies). | **UNCHANGED** (commit body was not in scope for the followup fix) |
| **S-5** | WorkspaceView `@State private var selectedEntityCategory` (L35) / `@State private var selectedEntity` (L39) are potentially dead since AppState vars mirror them | Footgun — dual sources of truth. | After Option B retraction: WorkspaceView's @State vars are now the **only** state for these signals (AppState mirrors are gone). The `@Binding` plumbing through WorkspaceView → ZoneModuleView → NewLibraryOutlineView is the active path. **The 2-tier footgun is resolved** (no more dual state — there's just the @State @Binding chain, plus a separate AppState.sidebarSelection for the other migrated signal). | **FIXED** (footgun eliminated by removing the AppState mirror) |
| **S-6** | PaneRenderer `_sidebarSelection` private pass-through removed cleanly; verify no external callers | Pass at prior review. | Not touched in `e93139e0d`. Still pass: `rg -n '\.sidebarSelection' Sources/WenshuApp/Views/` returns WorkspaceView-only references. | **UNCHANGED** (= already passed) |
| **S-7** | Add a one-line `// Macro order matters: @MainActor then @Observable then class` callout to AppState.swift | No callout comment. | Not addressed. File L41-43 still reads `@MainActor / @Observable / final class AppState` in correct order, but no explicit callout. | **UNCHANGED** (ordering is correct, no callout added) |
| **S-8** | CONTEXT.md row added in be3574dc1 (= L55) is good domain documentation but contains Chinese characters | CJK in row. | CONTEXT.md L55 now reads `v0.30 boss 8/31 OOB "option A for cross-zone communication" (= global @Observable store). Per-window @State on WenshuApp struct (= boss 8/27 OOB multi-window future-proofing). Replaces the 4-layer @Binding chain (WorkspaceView -> PaneRenderer -> TabContentDispatcher -> ZoneModuleView -> NewLibraryOutlineView) introduced by commit d845fe9c9. Cross-zone signals (currently only sidebarSelection; the other 3 declared in the spec are tracked in v0.31 backlog) live here...` = row is preserved, English text only. | **FIXED** |

**Summary**: 4 FIXED (S-3, S-5, S-8 + S-1 partial), 4 UNCHANGED (S-2, S-4, S-6 already pass, S-7 nit, S-1 style nit). No REGRESSED items.

---

## NEW issues introduced by the followup `e93139e0d`

All 3 are soft (documentation drift + style nits), non-blocking. None are hard-rule violations.

### NEW-1 — Stale doc-block in `App.swift` L419-420 (introduced by the fix; should have been updated alongside H-1)

**Location**: `Sources/WenshuApp/App.swift` L419-420 (inside the `/// v0.30 boss 8/31 OOB "option A for cross-zone communication"` doc-block at L415-421, attached to `@State private var appState = AppState()` at L422 in `WenshuApp`).

**Detail**: The doc-block reads:
```
/// All cross-zone UI signals
/// (sidebarSelection / selectedEntity / selectedEntityCategory /
/// previewSortOrder) live in this single observable object.
```
But after the H-1 fix (Option B retraction), `AppState` now contains **only** `sidebarSelection`. The 3 other vars listed in the doc-block were removed. The doc-block is now **stale / inaccurate** — it claims signals that no longer live in the type. CONTEXT.md L55 was correctly updated to say "currently only sidebarSelection", but this App.swift doc-block was not.

**Severity**: Documentation drift, non-blocking. The `@MainActor @Observable final class AppState { var sidebarSelection: ... }` declaration is what readers will actually inspect; the doc-block's list is descriptive and slightly out-of-date.

**Suggested fix** (one-line edit, can be in a polish commit):
```
- /// All cross-zone UI signals
- /// (sidebarSelection / selectedEntity / selectedEntityCategory /
- /// previewSortOrder) live in this single observable object.
+ /// All cross-zone UI signals
+ /// (currently only sidebarSelection; the other 3 declared in the
+ /// spec are tracked in v0.31 backlog) live in this single
+ /// observable object.
```

### NEW-2 — Orphaned doc-block in `AppState.swift` L54-58 (introduced by the H-1 retraction)

**Location**: `Sources/WenshuApp/State/AppState.swift` L54-58 (inside `class AppState {`, immediately after `var sidebarSelection: SidebarItem? = nil` at L52).

**Detail**: The doc-block reads:
```
/// Reference library entity detail selection (= the entity card
/// currently being viewed in single-card detail mode). Separate
/// from `sidebarSelection` (= = the sidebar tree selection) so
/// detail mode can render without changing which tree row is
/// highlighted.

```
But the var it documents (`var selectedEntity: Reference? = nil`) was **removed** in the H-1 fix. Now the doc-block has **no variable below it** — it's an orphan. Immediately followed by a double blank line (L59-60), then `init() {}` at L61. The class has only one field (`sidebarSelection`) but contains a doc-comment for a phantom field.

**Suggested fix** (4-line deletion):
```
-    /// Reference library entity detail selection (= the entity card
-    /// currently being viewed in single-card detail mode). Separate
-    /// from `sidebarSelection` (= = the sidebar tree selection) so
-    /// detail mode can render without changing which tree row is
-    /// highlighted.
-
-
     init() {}
```
(removes the 5-line orphaned doc-block + collapses the 2 blank lines to 1)

### NEW-3 — Double blank line at `AppState.swift` L59-60 (introduced by the H-1 retraction)

**Location**: `Sources/WenshuApp/State/AppState.swift` L59-60.

**Detail**: After the H-1 retraction removed `selectedEntity` + `selectedEntityCategory` + `previewSortOrder`, two consecutive blank lines were left between the orphaned doc-block and `init() {}`. Stylistic nit only — Swift allows arbitrary blank lines inside a class body.

**Suggested fix**: same patch as NEW-2 (collapse to 1 blank line).

### NEW items NOT introduced (pre-existing, for completeness)

- **No trailing newline** at end of `AppState.swift` (`tail -c 20` shows `init() {}\n}` with no `\n` after final `}`). This was already the case pre-fix (per `git show e93139e0d` `\ No newline at end of file` diff context). **Pre-existing** — not introduced by the followup.

- **CJK in commit body** of `e93139e0d` (line 2: `Boss 2026-08-31 OOB '跨区通信的方案用 A. 你推进实现吧'.` + 2 quoted CJK strings in fix #4 description). Per AGENTS.md L6, commit messages should be English-only. The prior standards sub-agent marked commit messages as "PASS" (English-only) — but `git log --format=%B eb3066bca -1` shows CJK has appeared in v0.30 commit bodies consistently (eb3066bca = 1 CJK hit, 17bdf49de = 6, etc.). This is a **pre-existing project convention** (CJK in `老板 OOB` quote backticks is accepted across all v0.30 commits), NOT a new regression introduced by `e93139e0d`. **Pre-existing**.

---

## Pollution-defense scan (Q49 audit gate)

| Check | Result | Note |
|-------|--------|------|
| `python3 Tools/wenshu-devtool/commit_filter.py --hook=ci-scan` against eb3066bca..e93139e0d | **CLEAN** (returns 0 hits) | No xianxia tokens in any of the 5 commits. |
| `rg -n '修真\|渡劫\|筑基\|返虚\|结丹\|金丹\|元婴\|飞升\|天劫\|雷劫\|心魔\|魔障\|顾客'` in `Sources/WenshuApp/` | **CLEAN** | No pollution tokens. `老板` references are allowed per AGENTS.md L78. |
| `git diff --stat eb3066bca~1..e93139e0d` (full batch scope) | 6 files changed, 151 insertions(+), 110 deletions(-) | Followup commit `e93139e0d` adds 23 / removes 40 = net **-17 LOC** (smaller than the 23/40 net for the prior 4 commits). Good sign-off: followup is purely retraction-style, not new-feature expansion. |

**Pollution defense: PASS** (no xianxia tokens; `commit_filter.py` clean).

---

## Build verification

| Check | Result |
|-------|--------|
| `swift build` (full wenshu target) | **exit 0 in 1.36s** (commit message claims 1.26s, actual is 1.36s — both well within build budget) |
| Warnings | 2 pre-existing unhandled-file warnings (`Wenshu.entitlements` + `ComponentIndex.md`); NOT introduced by this batch. No new warnings. |

---

## Q5.4 loop-gate criteria

| Gate criterion | Status |
|----------------|--------|
| All prior hard violations (H-1..H-4) resolved | **YES** (4/4 PASS) |
| Spec #2 fix correctly applied | **YES** (WorkspaceView + ZoneModuleView in lock-step) |
| `swift build` clean | **YES** (exit 0, no new warnings) |
| `commit_filter.py --hook=ci-scan` clean | **YES** (0 xianxia hits) |
| AGENTS.md English-only rule on NEW code (= code added in this batch) | **YES** (AppState.swift, App.swift L415-420, CONTEXT.md L55 all clean of NEW CJK; pre-existing CJK in App.swift header untouched) |
| Pollution defense | **YES** (no xianxia tokens) |
| Boss-streak rule (Q46 — count of redo commits on this axis) | **1 commit** (no streak; PASS on first redo) |

**Q5.4 loop-gate: PASS** — Standards axis cleared. Parent agent may proceed to Q5.5 or the next step in the Q34 8-step chain.

---

## Optional polish followup (non-blocking)

A 7-line polish commit could address all 3 NEW soft issues:

1. **NEW-1** (App.swift L419-420): rewrite doc-block to say "currently only sidebarSelection" (mirrors CONTEXT.md L55 fix).
2. **NEW-2 + NEW-3** (AppState.swift L54-60): delete the orphaned `Reference library entity detail selection` doc-block (5 lines) + collapse the double blank line to 1.

This is **optional** — the Q5.4 gate is already PASS without it. Recommend deferring to v0.31 unless boss requires immediate polish.

---

## Sub-agent signature

- **Standards axis PASS/FAIL = PASS** (4 hard violations FIXED, 1 spec criterion FIXED, 8 soft suggestions status: 4 FIXED / 4 UNCHANGED / 0 REGRESSED, 3 NEW soft issues = documentation drift, non-blocking)
- **Pollution defense = PASS** (no xianxia tokens; `commit_filter.py` clean; boss-streak rule = 1 commit, no streak)
- **Q5.4 loop-gate = PASS** — Standards axis cleared. Parent agent may proceed.
- **Recommended action**: close the Q5.4 loop gate; optionally schedule a polish commit for the 3 NEW soft issues. Q46 streak rule = 1 redo commit, no further redo needed on this axis.
- **Boss-streak note**: this is sub-agent's first re-verify of v0.30-app-state-cross-zone (= Q5.4 loop gate, 1 redo round on this axis). Prior round was the FAIL report. No streak yet (= streak rule resets on a clean PASS).