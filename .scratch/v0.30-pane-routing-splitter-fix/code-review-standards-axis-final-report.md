# Standards axis FINAL code-review — v0.30 pane-routing-splitter-fix

> Branch `wt/multi-agent-dispatch`, HEAD = `10dc16964`.
> Scope: post-dead-code-cleanup (= commit 10dc16964 deleted
> `PaneRenderer` / `PaneSplitRenderer` / `NativeSplitter` /
> `PaneSplitter` and extracted `TabContentDispatcher`).
> Reviewer: Standards axis (= H-1 dead code + H-2 scope creep +
> H-3 CJK in comments/commit-bodies + H-4 forbidden tokens).

## Verdict

**FAIL** — H-3 violation in 3 commit bodies.

The active **source code** is clean. The 3 commit bodies that
landed after the Q5.4 loop-gate closure (= commits 10dc16964,
da046a144, 2e685d9a0) contain verbatim CJK boss-quotes that were
NOT covered by the one-time Q5.4 do-not-amend override (= the
override applied to commits b14d32206, 0e55273c3, 674e1f176 = the
prior 3 forward-fix commits).

## Scope (= the 9 active in-scope files)

Verified at HEAD `10dc16964`:

```
Sources/WenshuApp/UI/RegionSelectionBackground.swift          125 lines
Sources/WenshuApp/UI/ComponentIndex.md                        345 lines
Sources/WenshuApp/State/WorkspaceState.swift                  870 lines
Sources/WenshuApp/State/WorkspaceStore.swift                  704 lines
Sources/WenshuApp/Views/Layout/PaneNSController.swift         531 lines
Sources/WenshuApp/Views/Layout/PaneSplitHost.swift             98 lines
Sources/WenshuApp/Views/Layout/PaneLayout.swift                107 lines
Sources/WenshuApp/Views/Workspace/WorkspaceView.swift         689 lines
Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift   308 lines
```

Plus the full `App.swift` (= 2029 lines; only the LayoutTokens
block was touched in v0.30). Deleted files confirmed gone:

```
PaneRenderer.swift        (= 649 lines, deleted in 10dc16964)
PaneSplitRenderer.swift   (= 285 lines, deleted in 10dc16964)
NativeSplitter.swift      (= 285 lines, deleted in 10dc16964)
PaneSplitter.swift        (= 101 lines, deleted in 10dc16964)
```

`swift build` = exit 0 (= "Build complete! 4.30秒"; 1 unused-let
warning unrelated to v0.30 scope).

## H-1 dead code — PASS

| Check | Result |
|---|---|
| Zero code references to deleted types in active files | **PASS** (= 0 hits after stripping strings + comments) |
| All 9 active files referenced elsewhere (= not orphaned) | **PASS** (= 2..15 callers each; ComponentIndex.md alone has 13) |
| `TabContentDispatcher.swift` is the survivor + is in active use | **PASS** (= `PaneNSController.swift:466` instantiates `TabContentDispatcher(kind:title:)` per pane) |
| `PaneLayout` + `FCPLayout` in active use | **PASS** (= `WorkspaceView.swift:112` constructs `PaneSplitHost(layout: FCPLayout(), ...)`; `PaneLayout.swift:100` `return PaneNSController(...)`) |
| `PaneSplitHost` in active use | **PASS** (= `WorkspaceView.swift:111` instantiates `PaneSplitHost(...)`) |
| `PaneNSController` in active use | **PASS** (= `PaneLayout.swift:100` `return PaneNSController(...)`) |
| Comment-level references to deleted types (= 20 in `RegionSelectionBackground.swift`) | Acceptable (= historical "before/after" commentary; H-1 = code-only) |
| `ComponentIndex.md` references to deleted types (= 6) | Acceptable (= history enumeration under "已 ship 的重构" section + deletion note) |

## H-2 scope creep — PASS

Diff vs PR-4 baseline `52c584a20` (= post effectiveRect + display
menu bridge fix):

```
Sources/WenshuApp/UI/ComponentIndex.md             |  40 +-    (history updates)
Sources/WenshuApp/UI/RegionSelectionBackground.swift|  21 +-    (comment update post-deletion)
Sources/WenshuApp/App.swift                        |   6 +-    (H-3 forward-fix in LayoutTokens)
Sources/WenshuApp/State/WorkspaceStore.swift       |  16 +-    (weights 75/25 -> 50/50 + 50/50 -> 70/30)
Sources/WenshuApp/Views/Layout/PaneLayout.swift    |  21 +-    (axis bug fix = .row vs .column)
Sources/WenshuApp/Views/Layout/PaneNSController.swift| 174 +-   (pendingWeights refactor + axis fix)
Sources/WenshuApp/Views/Layout/PaneSplitHost.swift |   9 +-    (useNSSplitView path)
Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift | 308 + (extracted from PaneRenderer)
Sources/WenshuApp/Views/Workspace/WorkspaceView.swift|  57 +-  (overlay -> if-else; PaneSplitHost as primary path)
+ 4 DELETIONS (PaneRenderer, PaneSplitRenderer, NativeSplitter, PaneSplitter)  | 1320 lines deleted
```

All diffs are within the v0.30 pane-routing-splitter scope:
ratio fixes, axis fix, overlay -> if-else refactor, dead-code
deletion, and TabContentDispatcher extraction. Zero changes to
unrelated tickets (sidebar, library, kanban, chat UI, book
schema). 1049 insertions / 1436 deletions net (per `git diff
52c584a20..HEAD --stat Sources/`) — i.e. this PR is a
NET-CODE-REDUCTION PR, not a scope-expansion PR.

## H-3 CJK in non-comment source text — PASS (with caveats on commits, see below)

**Strict check (= 0 CJK in non-comment-non-string code)**:
```
Total CJK in non-string-non-comment code: 0      ✓
```

**CJK in string literals** (= UI labels, zone names, button
captions, AppStorage keys, TabSpec titles): 155 hits across
`App.swift`, `WorkspaceState.swift`, `WorkspaceStore.swift`,
`WorkspaceView.swift`, `TabContentDispatcher.swift`. These are
end-user-visible Chinese UI strings (e.g. `"项目管理区"`,
`"素材预览区"`, `"书架"`, `"展开 (expand)"`). **These are NOT
H-3 violations** — H-3 = "English-only in source comments +
commit bodies + .scratch/ + CONTEXT.md". UI strings surfaced to
the Chinese-locale user are out of scope of section 5-6.

**CJK in source comments (= forward-fix already applied)**:
- `App.swift:139, 146, 152, 155, 157, 213, 214, 278, 281-284,
  335, 390-392, 1390, 1392, 1417-1418, 1480, 1504, 1535, 1582-1584,
  1588-1590, 1604, 1706, 1708, 1715-1717, 1721, 1759, 1988, 2022`
  — these are **trailing comments** after code (= e.g. `// Apple
  系统亮色 (dark/light 自适应)`), dating back to v0.07-v0.28
  (per `git blame`). Pre-existing, not introduced by v0.30
  pane-routing-splitter scope.
- `RegionSelectionBackground.swift` — the v0.30 commit (10dc16964)
  **removed** CJK from the file header (= "整代码, 关于样式的,
  不统一, 你要不盘一下" was the boss quote; was already ASCII-
  paraphrased in the prior forward-fix; commit 10dc16964 added
  English-only "after" state text).
- `WorkspaceView.swift` — CJK removed from `.help()` tooltip and
  trailing comments (forward-fix applied in earlier commits).
- `WorkspaceState.swift:792-793` and `PaneNSController.swift` —
  pure English after prior H-3 forward-fix passes.
- `ComponentIndex.md` — has CJK section headers (e.g.
  "LEVEL 5: Interaction 组件"), but this file is `UI/*.md`
  (= end-user/team-facing component index, not source code or
  `.scratch/`/`CONTEXT.md`). AGENTS.md section 5-6 does not
  cover this file (per the precedent of the prior RE-VERIFY 2
  report which also PASSED this file).

**Net H-3 in source comments**: zero regressions introduced by
the v0.30 pane-routing-splitter scope. PASS.

## H-4 forbidden 修真 tokens — PASS

```
Total forbidden token hits in active files: 0   ✓
```

Full token list checked: `修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹
/ 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障`. Zero hits across all
9 active in-scope files.

## H-3 on commit bodies — **FAIL**

The boss 2026-09-01 OOB "C = most clean" override applied to the
prior 3 commits (b14d32206, 0e55273c3, 674e1f176) covered the
prior loop-gate iteration. **3 new commits landed after the Q5.4
loop-gate closure** (= commits `10dc16964`, `da046a144`,
`2e685d9a0`) and each contains verbatim CJK boss-quotes in its
body that violate AGENTS.md section 5-6 English-only rule:

| SHA | Subject | CJK in body | Forbidden? | Source |
|---|---|---|---|---|
| `10dc16964` | `chore(wenshu): v0.30 -- delete legacy pane renderer / splitter dead code` | 24 CJK chars | No | Boss quote: `既然新代码已经完整复刻了代码, 那旧代码就可以不要了` |
| `da046a144` | `fix(wenshu): v0.30 -- if-else branch instead of overlay (no more double-render)` | 16 CJK chars | No | Boss quote: `现在的 UI 感觉是在原来的 UI 上覆盖了一层` |
| `2e685d9a0` | `fix(wenshu): v0.30 -- outer column upper/lower band 75/25 to 50/50` | 27 CJK chars | No | Boss quote: `上区 四区初始比例 10 20 60 10 + 下区 两区初始比例 70 30 + 上下两区纵向的默认比例 50 50` |
| `8adce156a` | `fix(wenshu): v0.30 -- NSSplitView axis bug = root was always row not column` | 0 | No | Clean English |
| `a05eeef9e` | `fix(wenshu): v0.30 -- lower band chat/dynamic 50/50 to 70/30` | 0 | No | Clean English |

Total CJK in commit bodies (recent v0.30 pane-routing-splitter
scope): 67 chars across 3 commits.

The boss-quotes are appropriately paraphrased in English (= e.g.
`(= since the new code fully replicates the old behavior, the
legacy code can be deleted)`) but the **verbatim CJK was kept**
alongside the paraphrase. The ASCII paraphrase is sufficient
for comprehension; the verbatim CJK is the violation.

Per AGENTS.md section 5: "This file is English only. No Chinese
characters. No CJK punctuation." Per section 6: "All commit
messages ... follow the same English-only rule."

**This was a regression vs RE-VERIFY 2 state** (= which closed
the Q5.4 loop gate on 3 prior commits). The fix commits added
after the loop-gate closure did NOT go through the
filter-branch amend cycle.

## Standards convention: internal-by-default

The 4 new types in the active set honor internal-by-default:

| Type | Declaration | Modifier |
|---|---|---|
| `PaneLayout` (protocol) | `protocol PaneLayout {` | (default = internal) |
| `FCPLayout` | `struct FCPLayout: PaneLayout {` | (default = internal) |
| `PaneSplitHost` | `struct PaneSplitHost: NSViewControllerRepresentable {` | (default = internal) |
| `PaneNSController` | `final class PaneNSController: NSSplitViewController {` | (default = internal) |

**Pre-existing v0.28 anomaly (NOT introduced by v0.30 scope)**:
`Sources/WenshuApp/UI/RegionSelectionBackground.swift:100` —
`public struct RegionSelectionBackgroundStyle: ShapeStyle {` and
its `public init()` + `public func resolve(in environment:) ->
Color {`. This is needed because `ShapeStyle` is a public
protocol (= internal types cannot have public members via
extension `extension ShapeStyle where Self == RegionSelection
BackgroundStyle`). Git blame: `8ea55097e` (= v0.28 followup,
2026-08-29, pre-PR-1 of v0.30). Out of scope of this review.

All other 100+ types in the active set use bare `struct` / `final
class` (= internal-by-default honored).

## Summary table

| Axis | Result | Notes |
|---|---|---|
| H-1 dead code | **PASS** | 0 code refs to deleted types; TabContentDispatcher is the survivor and is in use |
| H-2 scope creep | **PASS** | Net 387-line code reduction; only pane-routing-splitter scope touched |
| H-3 CJK in source code | **PASS** | 0 CJK in non-comment-non-string code; forward-fix already applied to comments |
| H-3 CJK in commit bodies | **FAIL** | 3 commits (10dc16964, da046a144, 2e685d9a0) have verbatim CJK boss-quotes; not covered by Q5.4 override |
| H-4 forbidden 修真 tokens | **PASS** | 0 hits across all 9 active files |
| internal-by-default | **PASS** | All 4 new v0.30 types honor it; pre-existing v0.28 RegionSelectionBackgroundStyle `public` is out of scope |
| Build | **PASS** | `swift build` exit 0 |

## Verdict

**FAIL** — needs H-3 commit-body forward-fix on 3 commits.

## Recommended fix

Apply the same `git filter-branch --msg-filter` recipe used in
the prior Q5.4 override (= RE-VERIFY 2) to strip the verbatim
CJK boss-quotes from the 3 commit bodies, keeping only the ASCII
paraphrase (= which is already present in each body):

```bash
git filter-branch -f --msg-filter '
  python3 -c "
import sys, re
msg = sys.stdin.read()
# Strip CJK between single quotes (= the verbatim boss-quote)
msg = re.sub(r\"'\''[^\"'\'']*[\u4e00-\u9fff]+[^\"'\'']*'\''\", \"(see paraphrase above)\", msg)
sys.stdout.write(msg)
"
' -- 2e685d9a0..HEAD
```

OR: a simpler `git rebase -i 2e685d9a0^` with `reword` on the 3
commits (preserves SHAs for the 3 commit objects but updates
bodies). After amend, push with `--force-with-lease` to update
the remote (= pre-push hook will re-scan; pollution-defense
allows `reword` for boss-quote paraphrasing per Q5.4 precedent).

## Files in this iteration

- ADD: `.scratch/v0.30-pane-routing-splitter-fix/code-review-standards-axis-final-report.md`

## Status of the loop gate

- Standards RE-VERIFY 1 (prior to amend) = FAIL (1 H-3 in
  forward-fix body)
- Standards RE-VERIFY 2 (after amend) = **PASS** (= Q5.4 loop
  gate closed on 3 prior commits)
- Standards FINAL (= this report, post-cleanup) = **FAIL** (= 3
  NEW H-3 in commit bodies added after the loop-gate closure)

The Q5.4 loop gate needs to be re-opened OR a new Q5.4
do-not-amend override must be granted (= the boss 2026-09-01
override was scoped to the prior 3 commits; the 3 new commits
with CJK are not covered).
