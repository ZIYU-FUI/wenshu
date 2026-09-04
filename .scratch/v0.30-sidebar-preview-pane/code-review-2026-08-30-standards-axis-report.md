# Standards Axis Report — v0.30 sidebar + preview pane (4 commits)

> Date: 2026-08-30
> Sub-agent: Standards axis (AGENTS.md §5-12 hard rules + boss-protocol carve-outs)
> Commits reviewed: c5ed76169, 1955fc131, 009f5bbd8, d5a02d751
> Branch: wt/multi-agent-dispatch
> Reviewer tools: ripgrep (CJK scan), git show/diff/grep, swiftlint
> Carve-out precedent: prior `.scratch/reviews/015.xxx-*-standards.md` reports (= established project convention for `Boss 8/<date> OOB` markers + UI strings + boss verbatim quotes)

## Verdict: CONDITIONAL PASS

`CONDITIONAL PASS` (= 1 hard violation cluster + several soft findings). The 4 commits are shippable: they implement the boss OOB scope, the build is clean, all CJK in commit bodies is either UI strings or Boss verbatim quotes (= established carve-out). However, three real issues need cleanup before the v0.30 final cut:

1. **H-1 (highest priority)**: `c5ed76169` and `009f5bbd8` introduced or persisted un-attributed CJK in code-line comments outside the Boss-verbatim-quote carve-out. Not a release blocker (file compiles, behavior correct) but a HARD rule violation against AGENTS.md §5-6.
2. **S-1 (process)**: Q34 step 7 not yet executed — `SidebarItem` + `EntitySortOrder` public types added to source but no `feat(wenshu): v0.30 — domain word add (SidebarItem + EntitySortOrder)` commit touching `CONTEXT.md`. Self-flagged in spec.md as out-of-scope.
3. **S-2 (process)**: 8 SwiftLint `comma` warnings pre-existing in `NewLibraryOutlineView.swift` L284-288 (= the `(name, displayName, icon)` tuple) — formatting defect carried forward, not introduced by c5ed76169 but the file was rewritten and the warnings were not fixed in passing.

The remaining 7 rules pass cleanly.

## Findings (= FAIL / H = hard violation)

### Finding H-1: un-attributed CJK in code-line comments (c5ed76169, 009f5bbd8)

- **Commits**: c5ed76169, 009f5bbd8 (and the doc comment block inherited by d5a02d751 from the prior `e38c96ad4`-era EntityPreviewPane writing)
- **Files**: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`, `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift`
- **Rule violated**: AGENTS.md §5-6 — English-only hard rule. "All commit messages, comments, prompts... follow the same English-only rule." Carve-outs per prior `.scratch/reviews/015.xxx` reports: Boss verbatim quotes, audit markers (= `Boss 8/<date> OOB`), user-facing UI strings. Code-line comments describing implementation MUST be English.
- **Severity**: HARD. Affects file readability, future maintainer audit (`git grep` for `Boss 8/30 OOB` becomes polluted with non-boss-quoted CJK), and the same `015.005 / 015.012 / 015.062` cleanup pattern that the project has been running for 4 weeks. The prior reports' judgment on this exact pattern (see `.scratch/reviews/015.012-zone-bottom-toolbar-restore-standards.md` line 99): "Cleanup did NOT cover this commit. The dominant Standards violation... mirroring exactly the F1 finding of the 015.005 Standards report."

**Verbatim code excerpts (header `//`/`///` comments NOT inside Boss-quote quotes):**

H-1.a — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:1`

```
// NewLibraryOutlineView.swift · Wenshu (文枢) · v0.30 Apple HIG sidebar
```

`(`文枢`)` = project brand in header comment, not a Boss quote.

H-1.b — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:280-281` (added by c5ed76169)

```
/// v0.30: 5 user-facing standard folder names + icons (= per spec
/// v5 ticket 001 + ticket 026). 3 hidden folders (LLM 会话, 伏笔,
/// 占位符) NOT shown per boss 8/30 sidebar cleanup.
```

`(LLM 会话, 伏笔, 占位符)` are folder-name references inside a comment without being enclosed in `Boss … OOB '...'` quote-bracket form. Per precedent reports (`015.062-*-standards.md` line 18-22) the carve-out applies only to CJK inside `Boss 8/<date> OOB '...'` brackets; here the CJK appears outside the boss-quote phrase structure.

H-1.c — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:314`

```
// MARK: - Zone header buttons (= 新建 + 入驻)
```

`(= 新建 + 入驻)` is a section-header label with no boss-quote prefix.

H-1.d — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:318` (added by c5ed76169)

```
// "+" button (= main app toolbar, not sidebar header) drives the "新建书 / 新建书架" menu.
```

`"新建书 / 新建书架"` is CJK in comment prose, not in a string literal and not enclosed in `Boss … OOB '...'` brackets.

H-1.e — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:323-324`

```
/// trailing area. Per boss 8/27 OOB #3 (= commit bca226704): 新建 Menu +
/// 入驻 plain Button. Both use the editor-expand + chat-archive
```

The `Per boss 8/27 OOB #3` prefix is correct audit-marker, but `新建 Menu +` continues past the boss quote into un-attributed CJK. Same pattern as the H-1.b bracket analysis.

H-1.f — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:330-331`

```
/// - 新建 icon = "square-plus" (Lucide canonical, NOT SF "plus")
/// - 入驻 icon = "square-arrow-right" (Lucide canonical)
```

CJK outside any boss-quote bracket.

H-1.g — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:334`

```
/// for the 新建 icon (= losing the Lucide canonical name + visual
```

CJK outside any boss-quote bracket.

H-1.h — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:340`

```
// 新建 Menu (= tap → menu with 新建书 / 新建书架).
```

Inline comment starts with CJK term.

H-1.i — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:356`

```
            // 入驻 plain Button (= tap directly fires .wenshuImportRequested
```

CJK outside any boss-quote bracket.

H-1.j — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:462`

```
// MARK: - Sheets (= 新建书 / 新建书架 modals)
```

`(= 新建书 / 新建书架 modals)` is CJK in section-header comment.

H-1.k — `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:10`

```
// card-flow grid (= 无边记-style sticky-note layout).
```

`(= 无边记-style sticky-note layout)` is CJK in comment for an external product name. No boss-quote prefix.

H-1.l — `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:282-284` (added by 009f5bbd8)

```
            // (= 无边记 sticky-note style). Sort by current `sortOrder`
            // (= boss 8/30 OOB: default 拼音首字母; user can pick
            // 创建时间 or 修改时间 via top-right sort menu icon).
```

`(= 无边记 sticky-note style)` is CJK without boss-quote prefix. `default 拼音首字母; user can pick 创建时间 or 修改时间` references enum cases (`.pinyinFirstLetter` / `.createdAt` / `.modifiedAt`) using CJK enum-case labels — the project convention per the prior reports is to use the IDENTIFIER name (= `.pinyinFirstLetter`), not the user-facing rawValue.

H-1.m — `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:366-367` (added by 009f5bbd8)

```
    /// kCFStringTransformStripDiacritics). Example: "李白" → "L",
    /// "未分类研究材料" → "W", "宋朝海上丝绸之路" → "S".
```

CJK examples in doc-comment. The doc-comment block is reasonable (CJK example helps reader understand the algorithm) but the AGENTS.md §5-6 rule with no exception for examples applies. Either translate or move examples to private debug printout.

H-1.n — `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:370` (added by 009f5bbd8)

```
        // Convert CJK characters to latinized pinyin (e.g. "李白" → "Lǐ Bái").
```

CJK example in inline comment.

H-1.o — `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:411` (pre-existing in `EntityCard` doc-comment block)

```
/// card a strong visual identity at a glance (= matches 无边记 / Notion
/// "card cover" pattern).
```

`(= matches 无边记 / Notion "card cover" pattern)` is CJK in doc-comment. Pre-existing — not introduced by any of the 4 commits under review, but the file is `EntityPreviewPane.swift` and the diff for `d5a02d751` lands within 25 lines of this comment.

**Total: 14 distinct code-line comment CJK hits outside the Boss-verbatim-quote carve-out, 13 introduced or persisted by c5ed76169/009f5bbd8, 1 (H-1.o) pre-existing in EntityCard doc-comment untouched by these 4 commits.**

**Fix per H-1**: replace each violation with the English equivalent. Reference rewrites from prior cleanup commits:

| Line | Current | Suggested English |
|---|---|---|
| L1 | `(文枢)` brand parens | drop brand parens, or move `(Wenshu in Chinese: 文枢)` to .scratch/spec.md where the audience is 老板 not lint-grammarian |
| L280-281 | `(LLM 会话, 伏笔, 占位符)` | `(LLM sessions / foreshadowing / placeholders)` |
| L314 | `(= 新建 + 入驻)` | `(= create + import buttons)` |
| L318 | `"新建书 / 新建书架" menu` | `"new book / new shelf" menu` |
| L323-324 | `新建 Menu + 入驻 plain Button` | `create Menu + import plain Button` |
| L330-331 | `新建 icon = "square-plus"` / `入驻 icon = "square-arrow-right"` | `create icon = "square-plus"` / `import icon = "square-arrow-right"` |
| L334 | `for the 新建 icon` | `for the create icon` |
| L340 | `// 新建 Menu (= tap → menu with 新建书 / 新建书架).` | `// Create Menu (= tap → menu with "New Book" / "New Shelf").` |
| L356 | `// 入驻 plain Button` | `// Import plain Button` |
| L462 | `(= 新建书 / 新建书架 modals)` | `(= new book / new shelf modals)` |
| L10 | `(= 无边记-style sticky-note layout)` | `(= Notion-like sticky-note layout)` |
| L282-284 | `default 拼音首字母; user can pick 创建时间 or 修改时间 via top-right sort menu icon` | `default .pinyinFirstLetter; user can pick .createdAt or .modifiedAt via top-right sort menu icon` |
| L282 | `(= 无边记 sticky-note style)` | drop or replace with `(= sticky-note style)` |
| L366-367 | `Example: "李白" → "L", "未分类研究材料" → "W", "宋朝海上丝绸之路" → "S"` | drop examples or move to a `[Test Examples]` section in spec.md |
| L370 | `(e.g. "李白" → "Lǐ Bái")` | drop example |
| L411 | `(= matches 无边记 / Notion "card cover" pattern)` | `(= matches Notion "card cover" pattern)` |

A single `fix(wenshu): v0.30 — CJK-in-comments cleanup (c5ed76169 + 009f5bbd8 residual)` commit sweeping all 15 sites is the right shape (= same pattern as `ab098f1e7` for ticket 015.062 in `.scratch/reviews/015.062-sidebar-f1-cleanup-cjk-58th-oob-standards.md`).

### Finding H-1 does NOT include

These CJK hits were checked and judged **acceptable** per the Boss-verbatim-quote carve-out + UI-string carve-out established in `.scratch/reviews/015.005-...standards.md` line 138, `.scratch/reviews/015.018-...standards.md` line 23, `.scratch/reviews/015.022-...standards.md` line 24, `.scratch/reviews/015.030-...standards.md` line 23, and consistently across 015.xxx:

| File:line | Excerpt | Why OK |
|---|---|---|
| NewLibraryOutlineView.swift:3 | `'如果你要 100% Apple native, 我想选这个'` | Inside `Boss 2026-08-30 OOB '...'` quote brackets |
| NewLibraryOutlineView.swift:154 | `Text("资料库")` | UI string (Text) |
| NewLibraryOutlineView.swift:238-239 | `'目录树有一个按文字从这里开始...'` | Boss-verbatim quote |
| NewLibraryOutlineView.swift:284-288 | `("world", "世界观", "globe")` etc. | UI string tuple literal displayed in sidebar |
| NewLibraryOutlineView.swift:316 | `'复用 v0.25.x 现有的 toolbar "+" 按钮'` | Boss-verbatim quote |
| NewLibraryOutlineView.swift:328 | `'恢复那两个按钮, 还有 icon'` | Boss-verbatim quote |
| NewLibraryOutlineView.swift:342, 345 | `Button("新建书")`, `Button("新建书架")` | UI string (Button) |
| NewLibraryOutlineView.swift:473, 480, 482, 488, 490, 516, 523, 529, 531 | `Text(...)` / `TextField(...)` / `Button(...)` CJK payloads | UI strings |
| EntityPreviewPane.swift:3-6 | OOB verbatim 4-line Boss quote | Boss-verbatim quote |
| EntityPreviewPane.swift:20 | `'双击卡片才会在编辑器里打开'` | Boss-verbatim quote |
| EntityPreviewPane.swift:32-33, 76, 80-81, 125, 276-278, 383, 405 | Boss OOB quotes | Boss-verbatim quote |
| EntityPreviewPane.swift:43-45 | `case pinyinFirstLetter = "首字母"` etc. | UI string rawValue (= enum case backed by String used in Menu labels) |
| EntityPreviewPane.swift:178 | `.help("排序方式: ...")` | UI string (.help tooltip) |
| EntityPreviewPane.swift:220 | `Text("(空文档)")` | UI string |
| EntityPreviewPane.swift:252 | `emptyState(message: "该分类下暂无实体")` | UI string |
| EntityPreviewPane.swift:274 | `emptyState(message: "资料库里还没有实体.\n...")` | UI string |
| EntityPreviewPane.swift:429 | `(= boss OOB: 卡片要加缩略图)` | Boss-verbatim quote (parenthesized) |
| EntityPreviewPane.swift:496 | `.help("... — 双击在编辑器中打开")` | UI string (.help tooltip) |

All four commit bodies' CJK is Boss verbatim quotes — also acceptable per precedent.

## Findings (= SUG / soft = nice-to-have)

### Finding S-1: Q34 step 7 (domain-modeling) not executed

- **Files**: `CONTEXT.md`, `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`, `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift`
- **Rule**: AGENTS.md §6 / project Q34 step 7 = "domain-modeling commit (= add new domain words to CONTEXT.md)"
- **Affected types**: `SidebarItem` (new public enum, c5ed76169), `EntitySortOrder` (new public enum, 009f5bbd8). Both should add a row to the CONTEXT.md domain-words table.
- **Severity**: SOFT — acknowledged out-of-scope in `.scratch/v0.30-sidebar-preview-pane/spec.md` line 151-152 ("Domain-modeling commit (= add new domain words: SidebarItem, EntitySortOrder, adaptiveColumns to CONTEXT.md) — listed under 'Out of scope (= future batches, separate spec needed)'").
- **Fix**: one `docs(wenshu): v0.30 — domain word add (SidebarItem + EntitySortOrder + adaptiveColumns)` commit touching `CONTEXT.md` only. Can include `adaptiveColumns(width:)` as a related SwiftUI method (= pair with the GeometryReader pattern established for v0.26 free-layout).

### Finding S-2: SwiftLint comma-spacing warnings pre-existing

- **File**: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:284-288`
- **Rule**: SwiftLint `comma` rule (`.swiftlint.yml` defaults)
- **Verbatim output** (`swiftlint lint --quiet Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`):
  ```
  :284:21: warning: Comma Spacing Violation: There should be no space before and one after any comma (comma)
  :284:33: warning: Comma Spacing Violation
  :285:32: warning: Comma Spacing Violation
  :286:24: warning: Comma Spacing Violation
  :286:34: warning: Comma Spacing Violation
  :287:24: warning: Comma Spacing Violation
  :287:34: warning: Comma Spacing Violation
  :288:22: warning: Comma Spacing Violation
  :288:34: warning: Comma Spacing Violation
  ```
- **Verbatim line 284** (file post-commit):
  ```
              ("world",      "世界观",      "globe"),
  ```
- **Severity**: SOFT. These are pre-existing warnings (the pre-c5ed76169 file had `("世界观", "globe", "world")` etc. = same-shape tuple with the same comma-spacing pattern). c5ed76169 did not introduce them. They are surface-level format warnings, not type/build/correctness issues. The project convention per spec.md is "SwiftLint ran: skip if 'No linter for .swift files'" but the linter IS installed, so should be considered.
- **Fix**: `swiftlint autocorrect` (or manual `("world", "世界观", "globe")` → `("world", "世界观", "globe")` aligned). Either fold into the H-1 cleanup commit or follow up as one-shot `chore(wenshu): v0.30 — sidebar folder tuple comma-spacing`.

### Finding S-3: post-hoc Q5.6 partial commit 接管规范 self-acknowledged

- **File**: `.scratch/v0.30-sidebar-preview-pane/spec.md` line 138-145
- **Verbatim**:
  ```
  ## Q34 audit (= post-hoc)

  This batch was implemented without the Q34 8-step chain (= no grill,
  no spec/ticket pre-write, no code-review sub-agent). Spec + tickets
  committed post-hoc (= this batch + the previous pre-pane batch).

  Going forward: every new ticket walks full chain (= grill → spec →
  tickets → implement → code-review → domain-modeling).
  ```
- **Severity**: SOFT — self-acknowledged. The 4 commits were authored without the Q34 walkthrough (= no grill-with-docs → no spec → no tickets → no implement → no code-review → no domain-modeling). The retroactive doc commit `7dc139b9 docs(wenshu): v0.30 sidebar Apple HIG List + preview pane polish spec + 4 tickets` (= 20:59:07 today) brings the chain back into compliance per Q5.6 partial commit 接管规范 (post-hoc acceptable if added before code-review).
- **Note**: this code-review (= this report) = the missing link in the chain. After this report lands, the Q5.6 requirement "spec/ticket must exist in `.scratch/feature/` (post-hoc acceptable but must be added before code-review)" is fully satisfied.

### Finding S-4: dual-axis code-review not yet symmetric

- **Files**: this report (= Standards axis) + `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-spec-axis-report.md` (Spec axis report = 14.7 KB, already exists)
- **Severity**: SOFT (resolved in this turn). The companion spec-axis report already exists at 14.7 KB. This Standards-axis report (= this file) provides the second axis. Q125 dual-axis pattern satisfied.

### Finding S-5: commit message format (= feat/fix docs/refactor)

- **Rule**: AGENTS.md §6 + project convention = `feat(wenshu):` for new features, `fix(wenshu):` for fixes, `docs(wenshu):` for docs, `refactor(wenshu):` for refactors.
- **Verified**:
  - `c5ed76169` = `feat(wenshu): v0.30 — sidebar migrated to Apple HIG standard List` — `feat` correctly applied (new Apple HIG integration). PASS.
  - `1955fc131` = `fix(wenshu): v0.30 — sidebar tree row selection highlight` — `fix` correctly applied. PASS.
  - `009f5bbd8` = `feat(wenshu): v0.30 — preview pane sort menu` — `feat` correctly applied (new sort menu + new enum + new sort helpers). PASS.
  - `d5a02d751` = `fix(wenshu): v0.30 — preview pane = adaptive 2-column card flow` — `fix` correctly applied (modifies existing `columns` array to `adaptiveColumns(width:)`). Borderline — could be argued as `refactor` (= changes behavior to match boss preference, not bug-fix). Acceptable per `fix` precedent in 015.012 / 015.018 / 015.021 / 015.030 / 015.061 / 015.062 (boss OOB "fix" tickets). PASS.
- **Severity**: PASS (no action).

### Finding S-6: atomic-coupling rule (boss 8/22)

- **Rule**: multi-file commits must justify the coupling in commit body.
- **Verified**:
  - `c5ed76169` = 1 file (`NewLibraryOutlineView.swift`). Single-file = no coupling required. PASS.
  - `1955fc131` = 1 file (`NewLibraryOutlineView.swift`). PASS.
  - `009f5bbd8` = 1 file (`EntityPreviewPane.swift`). PASS.
  - `d5a02d751` = 1 file (`EntityPreviewPane.swift`). PASS.
- **Severity**: PASS (no action). All 4 commits adhere to the stricter single-file ideal (= avoids coupling justification burden entirely).

### Finding S-7: 1 ticket 1 commit (Q29)

- **Verified**:
  - `c5ed76169` ↔ `.scratch/v0.30-sidebar-preview-pane/issues/01-sidebar-apple-hig-list.md`. PASS.
  - `1955fc131` ↔ `.scratch/v0.30-sidebar-preview-pane/issues/02-sidebar-selection-highlight.md`. PASS.
  - `009f5bbd8` ↔ `.scratch/v0.30-sidebar-preview-pane/issues/03-preview-sort-menu.md`. PASS.
  - `d5a02d751` ↔ `.scratch/v0.30-sidebar-preview-pane/issues/04-adaptive-2col-cards.md`. PASS.
- **Severity**: PASS (no action). Spec.md line 43-48 documents the commit-to-OOB mapping verbatim.

### Finding S-8: AGENTS.md 修真 12-token forbidden list

- **Verified**: ripgrep over both modified files + 4 commit bodies for `修真|渡劫|筑基|返虚|结丹|金丹|元婴|飞升|天劫|雷劫|心魔|魔障` returns 0 hits. Same pattern as `.scratch/reviews/015.062-...standards.md` line 14 (passing 015.xxx).
- **Severity**: PASS (no action).

### Finding S-9: AGENTS.md forbidden English modals (12+1 list)

- **Verified**: ripgrep for `\b(may|might|should|could|perhaps|probably|consider|tries?|尽量|大概|也许|可能|应当|或许|应该|建议|试图|任意|大概率|通常|一般来说|和 FCP 一样)\b` over both modified files returns 0 hits. Same precedent.
- **Severity**: PASS (no action).

### Finding S-10: `Boss 8/<date> OOB` audit-marker convention (Rule 9 inverse)

- **Verified**: every commit body and every comment block uses `Boss 2026-08-30 OOB` or `Boss 8/30 OOB` (English-only audit markers, NOT CJK "老板") per the established project convention documented in `.scratch/reviews/015.018-...standards.md` line 23 and `.scratch/reviews/015.022-...standards.md` line 24. The user's literal "老板" is reserved for CJK-side citations (`.md` files, doc comments) and is NOT used inside `.swift` source. This is the English-only carve-out pattern, not a violation of the AGENTS.md §7 / §12 "sole address = 老板" rule (which constrains CJK-side prose, not English-side commit-message prose that addresses the user).
- **Severity**: PASS (no action).

## Per-commit summary

| Commit | Files | Lines | H (hard) | S (soft) | Violations detail |
|---|---|---|---|---|---|
| c5ed76169 | 1 file | 259 + / 719 - | 1 cluster (9 hits: H-1.a, H-1.b, H-1.c, H-1.d, H-1.e, H-1.f, H-1.g, H-1.h, H-1.i, H-1.j) | 1 (S-2 surface, 8 lint) | NewLibraryOutlineView.swift full rewrite introduces un-attributed CJK in code-line comments at 10 distinct sites. Plus 8 pre-existing SwiftLint comma warnings L284-288 (NOT introduced by this commit, but the rewrite passed without correcting them). |
| 1955fc131 | 1 file | 60 + / 2 - | 0 | 0 | Clean. All added code-line comments are English. Diff-added text uses `Boss 8/30 OOB` audit markers only. |
| 009f5bbd8 | 1 file | 167 + / 21 - | 1 cluster (5 hits: H-1.l, H-1.m, H-1.n, plus the L429 case re-flavor) | 0 | EntityPreviewPane.swift adds 14 new code-line comment CJK hits; H-1.k persists from prior era (not introduced by this commit). 5 hard violations in this commit's diff. |
| d5a02d751 | 1 file | 52 + / 15 - | 0 | 0 | Clean. All added comments are Boss-verbatim English. No new CJK in this commit's diff. (H-1.k and H-1.o persist in file but outside the diff scope.) |
| **TOTAL** | 4 commits, 2 files | 538 + / 757 - | **H-1 cluster (= 15 distinct code-line comment sites; 14 attributable to these 4 commits)** | **S-1 (= CONTEXT.md), S-2 (= 8 swiftlint warnings), S-3 (= post-hoc Q34 self-acknowledged), S-4 (= spec-axis companion ok)** | One hard finding to clean (H-1) before v0.30 ship, one soft follow-up (S-1) for Q34 step 7. |

## Q5.6 partial commit 接管规范 compliance

- spec.md exists at `.scratch/v0.30-sidebar-preview-pane/spec.md`: YES (= 7.2 KB, line 1-156, covers all 4 commits with commit-to-OOB mapping at line 43-48, scope at line 39-89, fix plan at line 90-120, post-hoc Q34 audit at line 138-145, out-of-scope list at line 147-156).
- issues/ exist: YES (= 4 issues: `01-sidebar-apple-hig-list.md`, `02-sidebar-selection-highlight.md`, `03-preview-sort-menu.md`, `04-adaptive-2col-cards.md`).
- commit hashes documented in spec.md: YES (= line 43-48 carries `c5ed76169` / `1955fc131` / `009f5bbd8` / `d5a02d751` in the Boss OOB driving table).
- post-hoc acknowledgement: YES (= `docs(wenshu): v0.30 sidebar Apple HIG List + preview pane polish spec + 4 tickets` commit at `7dc139b9`, 2026-08-30 20:59:07 +0800, brought both spec.md + 4 issues into `.scratch/v0.30-sidebar-preview-pane/` before this Standards report landed).

Q5.6 partial commit 接管规范 compliance: **PASS** (= post-hoc acceptable per rule, docs commit landed before code-review = timing requirement met).

## Q34 8-step chain compliance (= post-hoc audit)

| Step | Required | Done? | Notes |
|---|---|---|---|
| 1. grill-with-docs | interview 老板 + lock spec | NO | Pre-implementation grill did NOT run. Pattern: 老板 sent 4 OOB messages via OOB protocol; cc-runner implemented directly against each OOB without a structured grill-with-docs session. Same gap as `.scratch/v0.30-pre-pane-fixes/spec.md` line 138-145. |
| 2. to-tickets commit | issues/01..N under `.scratch/feature/` | YES (post-hoc) | 4 issue files created post-hoc via commit `7dc139b9` (2026-08-30 20:59:07). Pre-Q5.6 partial-commit-接管 gap closed before this report. |
| 3. implement commit | code lands per ticket | YES | 4 implementation commits landed in direct chronological order (`d5a02d751` 18:57 → `1955fc131` 19:12 → `009f5bbd8` 19:21 → `c5ed76169` 20:04). |
| 4. swift build exit 0 | compile clean | YES | spec.md "Build clean" cited in 4 commit bodies; spec.md line 135 "Build exit 0: ✓". |
| 5. code-review 双轴 | Standards + Spec reports | YES (this turn) | Spec-axis report = `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-spec-axis-report.md` (14.7 KB, already exists). Standards-axis report = this file. Q125 dual-axis satisfied. |
| 6. hard violation 修法 | fix H-1 + rerun | PENDING | H-1 cleanup commit needed. Recommended shape: single `fix(wenshu): v0.30 — CJK cleanup in code-line comments (c5ed76169 + 009f5bbd8 + EntityPreviewPane header)`. Sweep 15 sites per H-1 fix table. Reference pattern: `ab098f1e7` for 015.062. |
| 7. domain-modeling commit | `SidebarItem` + `EntitySortOrder` → CONTEXT.md | PENDING | `feat(wenshu): v0.30 — domain-modeling: SidebarItem + EntitySortOrder + adaptiveColumns` (= docs commit touching only `CONTEXT.md`). Self-flagged as out-of-scope in spec.md line 151-152. S-1 follow-up. |
| 8. Q22 真验证 | screenshot + AX tree + 老板 verify | PARTIAL | spec.md line 136 "Screenshot verified" ✓. Per Q22 (boss OOB 8/22 真验证 = pixel + AX tree + boss OK): pixel screenshot = present (per spec.md), AX tree capture = MISSING (= Apple Accessibility API tree dump not yet captured), 老板 OK flag = NOT YET (this report still needs 老板 to read + ack). S-4 follow-up. |

## Summary

The 4 v0.30 sidebar + preview-pane commits deliver on the boss OOB scope and follow the established project conventions for `Boss 8/<date> OOB` audit markers, Boss-verbatim-quote carve-outs, and UI-string carve-outs. The 4 commit bodies + 4 issue files + spec.md = the full Q5.6 chain (post-hoc). The Q124 atomic-coupling rule is naturally satisfied (all 4 commits are 1-file). The Q29 1-ticket-1-commit and Q34 step mapping are documented in spec.md line 43-48.

The single actionable finding is **H-1**: 15 distinct sites in `NewLibraryOutlineView.swift` + `EntityPreviewPane.swift` carry un-attributed CJK in code-line comments (= outside the Boss-verbatim-quote bracket pattern that the prior 015.005/012/018/062 cleanup reports established). 14 of these were introduced or persisted by the 4 commits under review; 1 is pre-existing in `EntityCard`'s doc-comment block. Recommended fix is a single `fix(wenshu):` cleanup commit sweeping all 15 sites — see the H-1 fix table for the verbatim English rewrites.

S-1 (CONTEXT.md domain word add for `SidebarItem` + `EntitySortOrder`) is a process follow-up, not a standards blocker. S-2 (8 SwiftLint comma warnings in the folder tuple) is a pre-existing surface defect carried forward by c5ed76169.

Verdict: **CONDITIONAL PASS**. H-1 cleanup commit + S-1 domain-modeling commit before v0.30 final ship.
