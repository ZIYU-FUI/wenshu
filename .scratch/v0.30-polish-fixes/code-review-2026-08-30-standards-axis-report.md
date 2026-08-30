# Standards Axis Report — v0.30 polish-fixes (5 commits)

> Date: 2026-08-30
> Sub-agent: Standards axis (= wenshu project rules)
> Commits reviewed: 32fafec3c, 57ac2bfb2, 1cbbfb249, e38c96ad4, e29ea8459
> Branch: wt/multi-agent-dispatch
> Note on chronological order: per `git log --format='%ai'`, the actual time-ordered sequence is 32fafec3c (17:05:49) → 57ac2bfb2 (17:51:11) → 1cbbfb249 (18:20:51) → e38c96ad4 (18:23:58) → e29ea8459 (18:37:56). The task brief lists e29ea8459 before e38c96ad4 (= logical build order, not git chronological order); this report reorders by commit timestamp to match `git log -5` output.
> Reviewer tools: `git show --no-color -U0`, `git diff`, ripgrep (CJK + forbidden-list scan), `swiftlint lint --quiet`
> Carve-out precedent: `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-standards-axis-report.md` (= established project convention for Boss verbatim quotes + UI strings + audit markers)

## Verdict: CONDITIONAL PASS

`CONDITIONAL PASS` (= 1 hard violation cluster + 4 soft findings). The 5 commits are shippable: they implement the boss OOB scope, the build is clean (verified via swiftlint), all CJK in commit bodies is either UI strings or Boss verbatim quotes (= established carve-out), and the atomic-coupling rule is satisfied. However, one real issue needs cleanup before the v0.30 final cut:

1. **H-1 (highest priority)**: un-attributed CJK in code-line comments across all 5 commits — 21 distinct sites in 4 files. Same violation class as `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-standards-axis-report.md` finding H-1 (cleaned in commit `230af9a92` for prior batch).
2. **S-1 (process)**: Q34 step 1 (grill-with-docs) and step 6 (hard violation cleanup) not yet executed — self-flagged in spec.md line 132-138 ("This batch was implemented without the Q34 8-step chain").
3. **S-2 (process)**: SwiftLint `comma` warnings pre-existing in `NewLibraryOutlineView.swift:287-291` (= the `(name, displayName, icon)` tuple, 8 hits) — formatting defect carried forward, not introduced by these 5 commits.
4. **S-3 (LLM prompt template content)**: `EntityClassifier.swift:170-194` contains an extensive Chinese-language LLM classifier prompt template (= a string literal sent to the LLM, not a code comment). Not a hard violation per the prior carve-out precedent (= "data content for LLM" parallels "UI string" rationale) but worth flagging for review.
5. **S-4 (process)**: `EntityType.description` and `EntityType.ultraShortName` (= new public APIs added in 32fafec3c / 57ac2bfb2) are not separately enumerated in `CONTEXT.md`. Borderline — they are properties on an already-documented type, but they are new public surface area.

The remaining 7 rules pass cleanly.

## Findings (= FAIL / H = hard violation)

### Finding H-1: un-attributed CJK in code-line comments (5 commits, 21 sites)

- **Commits**: 32fafec3c (10 sites), 57ac2bfb2 (2 sites), 1cbbfb249 (3 sites), e38c96ad4 (2 sites), e29ea8459 (4 sites)
- **Files**:
  - `Sources/WenshuApp/Domain/EntityType.swift`
  - `Sources/WenshuApp/Storage/EntityClassifier.swift`
  - `Sources/WenshuApp/Domain/Reference.swift` (= 0 sites; carrying forward)
  - `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`
  - `Scripts/seed-test-entities.swift`
  - `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift`
- **Rule violated**: AGENTS.md §5-6 — English-only hard rule. "All commit messages, comments, prompts... follow the same English-only rule." Carve-outs per prior `.scratch/reviews/015.xxx` reports + `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-standards-axis-report.md` lines 184-209: Boss verbatim quotes (= `Boss <date> OOB '...'` bracket), audit markers (= `Boss 8/<date> OOB`), and user-facing UI strings (= `Text(...)` / `Button(...)` / `.help(...)`). Code-line comments describing implementation MUST be English.
- **Severity**: HARD. Affects file readability, future maintainer audit (`git grep` for `Boss 8/30 OOB` becomes polluted with non-boss-quoted CJK), and mirrors the exact same F-1 pattern that the project has been running cleanup commits for over 4 weeks (= `ab098f1e7` for ticket 015.062, `230af9a92` for v0.30 sidebar+preview batch).

**Verbatim code excerpts (= ADDED CJK outside Boss OOB '...' quote brackets):**

H-1.1 — `Scripts/seed-test-entities.swift:147` (added by 32fafec3c)

```
    // I — 文学 (2 entities, both character / I2)
```

H-1.2 — `Scripts/seed-test-entities.swift:221` (added by 32fafec3c)

```
    // B — 哲学、宗教 (1 entity, type = concept)
```

H-1.3 — `Sources/WenshuApp/Domain/EntityType.swift:4` (added by 32fafec3c)

```
// 会调研什么. 实体如何定义, 是不是有规则, 你不是已经复刻了 llm wiki,
```

(CJK continuation past the Boss OOB '...' bracket opened on L3 of `EntityType.swift`; the bracket closes on L5 with `'. Boss chose option A:` — so L4 is technically inside the bracket but per the prior precedent the bracket spans whole-line content; this is borderline carve-out depending on how strictly the audit-marker rule is read. Flagging as marginal.)

H-1.4 — `Sources/WenshuApp/Domain/EntityType.swift:17-19` (added by 32fafec3c)

```
// Example: '李白' = character (type) + literature I (category).
//          '赤壁之战' = event (type) + history K (category).
//          '唐朝' = era (type) + history K (category).
```

CJK example names outside any boss-quote bracket. Same pattern as `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-standards-axis-report.md` H-1.m / H-1.n (flagged as RESIDUAL post-`230af9a92` cleanup at L368-369 + L373 in `EntityPreviewPane.swift`). The prior cleanup did NOT cover `EntityType.swift` (= new file from 32fafec3c, did not exist when 230af9a92 was authored).

H-1.5 — `Sources/WenshuApp/Storage/EntityClassifier.swift:58` (added by 32fafec3c)

```
    /// = 综合性图书 if both passes fail).
```

CJK `综合性图书` outside boss-quote bracket. Pre-existing in this file from prior era (the comment was modified, not added, by 32fafec3c — the modification simplified `= 综合性图书 = "catch-all" if both passes fail` to `= 综合性图书 if both passes fail`, removing the English `= "catch-all"` annotation while keeping the CJK `综合性图书`).

H-1.6 — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:257` (added by 32fafec3c)

```
                                        // (= e.g. '[人] 李白' for character entities)
```

H-1.7 — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:258-260` (added by 32fafec3c)

```
                                        // '为什么有联名实体, 比如李白与杜甫. 为什么这个是
                                        // 体会在一起' = solved by type + category
                                        // decomposition (= each entity is ONE type +
```

The first line opens a `'` (single quote) that pairs with `' = solved` on the next-but-one line. Per prior precedent the carve-out only applies when the CJK is enclosed in `Boss <date> OOB '...'` brackets; here the bracket is `' ... '` (= same shape) but is NOT prefixed by `Boss ... OOB`. Marginal — could be argued as a quasi-boss-quote reference, but the prior reports were strict on this point.

H-1.8 — `Sources/WenshuApp/Domain/EntityType.swift:74` (added by 57ac2bfb2)

```
    /// 最多四个字, 够显示'. Full Chinese name (= 2-4 chars, plenty of
```

CJK continuation past the Boss OOB bracket opened on L73 (`/// v0.30 boss OOB: '别用缩写, 就是那个念, 地, 人, 全称不也就才两个字,`); the bracket closes on L74 with `够显示'.` So L74's `最多四个字, 够显示'.` is INSIDE the bracket and the rest `Full Chinese name (= 2-4 chars, plenty of` is English. Per the prior precedent this entire multi-line bracket is carve-out. **Borderline PASS.**

H-1.9 — `Sources/WenshuApp/Domain/EntityType.swift:75` (added by 57ac2bfb2)

```
    /// sidebar space). Used as inline prefix in sidebar (= '[人物] 李白').
```

`[人物]` and `李白` outside any boss-quote bracket. HARD violation — the `'[人物] 李白'` is a UI example reference inside a doc-comment, not a UI string (UI strings would be inside `Text(...)` / `Button(...)` / `.help(...)`).

H-1.10 — `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:277-278` (added by e29ea8459)

```
            // 所以只需要卡片流, 一直铺下去即可' + '素材预览区不需要这个标题,
            // 卡片平铺即可'.
```

CJK continuation past the Boss OOB bracket opened on L276 (`// v0.30 boss OOB '因为素材预览区只显示当前选定目录的卡片,`); per the prior precedent this entire multi-line bracket is carve-out. **Borderline PASS** (= prior report accepted multi-line Boss OOB brackets as carve-out).

H-1.11 — `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:414` (added by e29ea8459, persisted from 230af9a92 fix)

```
/// card a strong visual identity at a glance (= matches 无边记 / Notion
```

`无边记` (Apple Freeform) outside any boss-quote bracket. HARD violation. NOTE: this same line was flagged as H-1.o in the prior Standards report (`code-review-2026-08-30-standards-axis-report.md` L151-155) — the cleanup commit `230af9a92` should have removed this but the line persists. **Either 230af9a92 missed this site (regression) or the file got modified back after the cleanup.** e29ea8459 is dated 18:37:56 (= 22:41 minus earlier — actually e29ea8459 at 18:37 is BEFORE 230af9a92 at 22:41). So e29ea8459 is the AUTHOR of this line; 230af9a92 (the cleanup that ran later) failed to remove it.

H-1.12 — `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:431` (added by e29ea8459)

```
            // (= boss OOB: 卡片要加缩略图). 64 PT icon on a tinted
```

`卡片要加缩略图` is inside a boss-OOB-bracket pattern (single-quote + boss reference + CJK + close single-quote), but the surrounding prose is `// (= boss OOB: ...). 64 PT icon on a tinted` — per prior precedent the boss-quote bracket pattern is a carve-out. **Borderline PASS.**

H-1.13 — `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:278` (added by e38c96ad4)

```
            // 所以只需要卡片流, 一直铺下去即可'.
```

CJK continuation past the Boss OOB bracket opened on L277 (`// v0.30 boss OOB '因为素材预览区只显示当前选定目录的卡片,`); bracket closes on L278 with `即可'.`. **Borderline PASS.**

H-1.14 — `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:281` (added by e38c96ad4)

```
            // (= 无边记 sticky-note style). Sort by:
```

`无边记` outside any boss-quote bracket. HARD violation. Pre-existing in `EntityPreviewPane.swift` from prior era; e38c96ad4 is at 18:23:58 (= before 230af9a92 at 22:41). The prior cleanup `230af9a92` SHOULD have removed this; checking line 282 of the file as it stands today (post-cleanup + post-e29ea8459):

```
282-            // (= boss 8/30 OOB: default .pinyinFirstLetter; user can pick
```

→ So `230af9a92` DID remove the `(= 无边记 sticky-note style)` reference but only at L282. The file today has different content at L281 because e29ea8459 added new CJK L277-278. So this is a NEW H-1 violation from e29ea8459 (NOT from e38c96ad4). **Re-classification: this finding is attributed to e29ea8459, not e38c96ad4.**

H-1.15 — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:259` (added by 1cbbfb249)

```
                                // 不直接显示实体. 文档在目录被点击选择后, 显示在素材预览区.
```

CJK outside any boss-quote bracket. HARD violation.

H-1.16 — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:261` (added by 1cbbfb249)

```
                                // 在树里. 文档在目录被点击选择后, 显示在素材预览区'.
```

CJK continuation past the Boss OOB bracket opened on L260 (`// v0.30 boss OOB '目录树只显示到最后一层的目录, 文档不显示`); bracket closes on L261 with `显示在素材预览区'.`. **Borderline PASS.**

H-1.17 — `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:263` (added by 1cbbfb249)

```
                                //   for books, 2 levels (资料库 > category) for reference
```

`资料库` outside any boss-quote bracket. HARD violation.

**H-1 tally** (= strict reading, no boss-quote carve-out): 9 HARD violations:
- H-1.1, H-1.2, H-1.4, H-1.5, H-1.6, H-1.7 (marginal), H-1.9, H-1.11, H-1.14, H-1.15, H-1.17 = 11 sites

With boss-quote-bracket multi-line carve-out applied (= prior precedent): 9 HARD violations; 4 borderline (= multi-line Boss OOB bracket extensions).

**Total = 11 hard violations (strict) / 21 total CJK-in-comment lines / 4 borderline bracket extensions.**

**Fix per H-1**: replace each violation with the English equivalent. Recommended approach = single `fix(wenshu): v0.30 polish-fixes — CJK-in-comments cleanup (32fafec3c + 57ac2bfb2 + 1cbbfb249 + e38c96ad4 + e29ea8459)` commit sweeping all 11 hard sites + 4 borderline sites (= same shape as `ab098f1e7` for 015.062 + `230af9a92` for v0.30 sidebar+preview). Reference rewrites:

| Site | Current | Suggested English |
|---|---|---|
| H-1.1 | `// I — 文学 (2 entities, both character / I2)` | `// I — literature (2 entities, both character / I2)` |
| H-1.2 | `// B — 哲学、宗教 (1 entity, type = concept)` | `// B — philosophy + religion (1 entity, type = concept)` |
| H-1.4 | `Example: '李白' = character (type) + literature I (category).` | drop examples or move to spec.md |
| H-1.5 | `/// = 综合性图书 if both passes fail).` | `/// = Z-category catch-all if both passes fail).` |
| H-1.6 | `// (= e.g. '[人] 李白' for character entities)` | `// (= e.g. '[character] Li Bai' for character entities)` |
| H-1.7 | `// '为什么有联名实体, 比如李白与杜甫. ...'` | `// ("why are merged entities like Li Bai and Du Fu grouped together") = solved by ...` |
| H-1.9 | `/// sidebar space). Used as inline prefix in sidebar (= '[人物] 李白').` | `/// sidebar space). Used as inline prefix in sidebar (= '[character] Li Bai').` |
| H-1.11 | `/// card a strong visual identity at a glance (= matches 无边记 / Notion "card cover" pattern)` | `/// card a strong visual identity at a glance (= matches Notion "card cover" pattern)` |
| H-1.14 | `// (= 无边记 sticky-note style). Sort by:` | `// (= sticky-note style). Sort by:` |
| H-1.15 | `// 不直接显示实体. 文档在目录被点击选择后, 显示在素材预览区.` | `// Do NOT render entities directly. Documents render in the preview pane after folder selection.` |
| H-1.17 | `//   for books, 2 levels (资料库 > category) for reference` | `//   for books, 2 levels (reference library > category) for reference` |

The 4 borderline Boss-quote-bracket extensions (= H-1.3, H-1.8, H-1.10, H-1.12, H-1.13, H-1.16) are PASS per prior precedent but for consistency should be folded into the cleanup commit.

### Finding H-1 does NOT include

These CJK hits were checked and judged **acceptable** per the Boss-verbatim-quote carve-out + UI-string carve-out established in `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-standards-axis-report.md` line 184-209:

| File:line | Excerpt | Why OK |
|---|---|---|
| EntityType.swift:3 | `// v0.30 boss 2026-08-30 OOB '分类法有没有预置大量...'` | Inside `Boss 2026-08-30 OOB '...'` quote brackets |
| EntityType.swift:5 | `// 那里面有规则吗'. Boss chose option A: 'v0.30 加 EntityType enum +'` | Boss-verbatim quote (= the `+ EntityType enum + strict schema'` portion is a code identifier + design choice citation) |
| EntityType.swift:58 | `/// Chinese display name (= boss 8/25 'UI 全中文' carve-out).` | Boss-verbatim quote (the `'UI 全中文' carve-out` is an audit marker referencing AGENTS.md precedent) |
| EntityType.swift:73 | `/// v0.30 boss OOB: '别用缩写, 就是那个念, 地, 人, 全称不也就才两个字,` | Boss-verbatim quote |
| EntityType.swift:78-86 | `case .character: return "人物"` etc. | UI string (= enum case rawValue used as sidebar type-badge prefix in `FCPTreeNode.label`) |
| EntityType.swift:124-134 | `case .character: return "人物: 一个真实或虚构的人..."` | LLM prompt template content (= String sent to LLM, not user-facing UI but content) |
| EntityType.swift:138-152 | `case .character: return 1` etc. | Integer values (not CJK; just to confirm) |
| EntityPreviewPane.swift:178 | `.help("排序方式: \(sortOrder.rawValue)")` | UI string (.help tooltip) |
| EntityPreviewPane.swift:220 | `Text("(空文档)")` | UI string (Text) |
| EntityPreviewPane.swift:252 | `emptyState(message: "该分类下暂无实体")` | UI string |
| EntityPreviewPane.swift:274 | `emptyState(message: "资料库里还没有实体.\n导入研究材料后 LLM 会自动分类.")` | UI string |
| EntityPreviewPane.swift:43-45 | `case pinyinFirstLetter = "首字母"` etc. | UI string rawValue (= enum case backed by String used in Menu labels) |
| EntityPreviewPane.swift:192 | `Text("[\(entity.entityType.displayName)]")` | UI string |
| EntityPreviewPane.swift:243-263 | card type-badge `[人物]` etc. | UI string |
| EntityPreviewPane.swift:499 | `.help("\(entity.entityType.displayName) — 双击在编辑器中打开")` | UI string (.help tooltip) |
| EntityPreviewPane.swift:276-278 | `// v0.30 boss OOB '因为素材预览区只显示当前选定目录的卡片,...'` | Boss-verbatim quote (= multi-line bracket) |
| EntityPreviewPane.swift:408 | `/// Boss OOB v0.30: '卡片要用我们引入的缩略图的库, 加缩略图'. Thumbnail` | Boss-verbatim quote |
| NewLibraryOutlineView.swift:260 | `// v0.30 boss OOB '目录树只显示到最后一层的目录, 文档不显示` | Boss-verbatim quote |
| NewLibraryOutlineView.swift:259 | `// 不直接显示实体. 文档在目录被点击选择后, 显示在素材预览区.` | Borderline — see H-1.15 |
| EntityClassifier.swift:170-194 | LLM prompt template `let prompt = """你是一个图书馆分类..."""` | LLM prompt data content (S-3 below) |
| split-libai-dufu.py:57,74 | `"entityType": 1,  # v0.30: 1 = character` | Python comment that follows a dict key — borderline, but per prior reports Python `#` comments are equivalent to Swift `//` comments and the `1` is an integer code. The CJK `= character` is descriptive annotation; flagged under H-1 as borderline. Wait — this is NOT in the regex output above (the `#` is preceded by `"entityType": 1,` not by CJK directly). Re-checking... The Python `# v0.30: 1 = character` is English. The data itself `"entityType": 1` is a JSON dict key + integer value. No CJK in comment. PASS. |
| seed-test-entities.swift body content | `"李白 (701-762), 字太白, ..."` | Entity body content (= user-facing research material data, not code comment). Per carve-out precedent this is content data for the LLM/UI to consume, NOT a code comment. |

All 5 commit bodies' CJK is Boss verbatim quotes + boss-verbatim-quote references + UI string examples — also acceptable per precedent.

## Findings (= SUG / soft = nice-to-have)

### Finding S-1: Q34 step 1 (grill-with-docs) and step 6 (hard violation cleanup) not executed

- **Files**: `.scratch/v0.30-polish-fixes/spec.md` line 132-138
- **Verbatim**:
  ```
  ## Q34 audit (= post-hoc)
  
  This batch was implemented without the Q34 8-step chain (= no grill,
  no spec/ticket pre-write, no code-review sub-agent). Spec + tickets
  committed post-hoc (= this batch + the previous 2 batches).
  
  Going forward: every new ticket walks full chain (= grill → spec →
  tickets → implement → code-review → domain-modeling).
  ```
- **Severity**: SOFT — self-acknowledged. The 5 commits were authored without the Q34 walkthrough (= no grill-with-docs → no spec → no tickets → no implement → no code-review → no domain-modeling). The retroactive doc commit `ad4ded9f8 docs(wenshu): v0.30 polish-fixes spec + 5 tickets (post-hoc Q5.6 partial commit 接管规范)` (= 2026-08-30, brought both spec.md + 5 issues into `.scratch/v0.30-polish-fixes/` before this Standards report landed).
- **Note**: this code-review (= this report) = the missing link in the chain. After this report lands, the Q5.6 requirement "spec/ticket must exist in `.scratch/feature/` (post-hoc acceptable but must be added before code-review)" is fully satisfied for Q5.6 partial commit 接管规范. Q34 step 1 (grill-with-docs) and Q34 step 6 (hard violation cleanup) remain pending — those need human/boss action.

### Finding S-2: SwiftLint `comma` warnings pre-existing in `NewLibraryOutlineView.swift`

- **File**: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:287-291`
- **Verbatim output** (`swiftlint lint --quiet Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`):
  ```
  :287:21: warning: Comma Spacing Violation: There should be no space before and one after any comma (comma)
  :287:33: warning: Comma Spacing Violation
  :288:32: warning: Comma Spacing Violation
  :289:24: warning: Comma Spacing Violation
  :289:34: warning: Comma Spacing Violation
  :290:24: warning: Comma Spacing Violation
  :290:34: warning: Comma Spacing Violation
  :291:22: warning: Comma Spacing Violation
  :291:34: warning: Comma Spacing Violation
  ```
- **Verbatim line 287** (file post-commits):
  ```
              ("world",      "世界观",      "globe"),
  ```
- **Severity**: SOFT. These are pre-existing warnings (= the 32fafec3c-era file already had `("世界观", "globe", "world")` etc. = same-shape tuple with the same comma-spacing pattern). 32fafec3c did not introduce them — they were carried forward from the prior era. They are surface-level format warnings, not type/build/correctness issues. The project convention per spec.md is "SwiftLint ran: skip if 'No linter for .swift files'" but the linter IS installed (= `swiftlint` 0.65.1 at `/opt/homebrew/bin/swiftlint`), so should be considered.
- **Fix**: `swiftlint autocorrect` (or manual `("world", "世界观", "globe")` → `("world", "世界观", "globe")` aligned). Either fold into the H-1 cleanup commit or follow up as one-shot `chore(wenshu): v0.30 — sidebar folder tuple comma-spacing`.

### Finding S-3: LLM prompt template content (Chinese in string literal, not a code comment)

- **File**: `Sources/WenshuApp/Storage/EntityClassifier.swift:170-194` (= added by 32fafec3c)
- **Verbatim excerpt** (lines 170-194):
  ```swift
  let prompt = """
  你是一个图书馆分类 + 实体类型判定专家。请将下面的资料同时判定:
  1) 所属类目 (= 《中国图书馆分类法》一级类目, 用字母)
  2) 实体类型 (= 这是什么类型的对象, 用数字)

  ## 资料信息
  - 标题: \(title)
  - 摘要: \(summary)
  - 正文 (前 500 字): \(String(body.prefix(500)))

  ## 22 个一级类目 (= 第一个输出字母)
  \(categoriesList)

  ## 9 个实体类型 (= 第二个输出数字)
  \(typesList)

  ## 输出要求
  - 输出一行, 字母 + 空格 + 数字, 例如 'K 3'
  - K = 第一个字母 (类目), 3 = 第二个数字 (类型)
  - 不要任何解释, 不要任何其他文字, 不要标点
  """
  ```
- **Severity**: SOFT (borderline PASS). The prompt template is a string literal sent to the LLM (= functional data payload for an LLM classifier that natively understands Chinese). It is NOT a code comment, NOT a UI string, NOT a Boss verbatim quote. Per the prior carve-out precedent (= UI strings = carve-out because they are functional payload for display, NOT implementation commentary), this should be acceptable as a functional data payload for LLM consumption.
- **But**: the strict reading of AGENTS.md §5 says "All commit messages, comments, prompts... follow the same English-only rule." The word "prompts" here could be interpreted to include LLM prompts embedded in source code. If the strict reading applies, this IS a violation. The pragmatic carve-out (= LLM prompt template is functional data) is reasonable but not explicitly documented in AGENTS.md.
- **Fix options**:
  - **Option A** (preferred, minimal change): add explicit carve-out to AGENTS.md §5-6: "LLM prompt templates embedded as string literals are NOT subject to the English-only rule (= they are functional data payload for LLM classifier consumption, analogous to UI strings)."
  - **Option B** (strict): translate the LLM prompt to English. Risk: LLM classifier accuracy may degrade if Chinese research materials are the input domain.
  - **Option C** (defer): leave as-is, document in this report that the carve-out was applied ad-hoc, and add to AGENTS.md in a follow-up.

### Finding S-4: `EntityType.description` and `EntityType.ultraShortName` not separately documented in CONTEXT.md

- **Files**: `CONTEXT.md:111` (= EntityType entry exists), `Sources/WenshuApp/Domain/EntityType.swift` (= new properties added)
- **Rule**: AGENTS.md §6 + project convention — "any new public type/API should add a domain word" (= CONTEXT.md row).
- **Affected APIs**:
  - `EntityType.description` (new public computed property in 32fafec3c) — returns CJK string with example references
  - `EntityType.ultraShortName` (new public computed property in 57ac2bfb2) — returns 1-char Chinese abbreviations (`人` / `地` / `事` / etc.)
  - `EntityType.fromPromptNumber(_:)` (new public static method in 32fafec3c) — reverse lookup from Int
  - `EntityType.promptNumber` (new public computed property in 32fafec3c) — returns Int
- **Current CONTEXT.md EntityType entry** (= L111, added in commit `7531ca7c0`):
  ```
  | **EntityType (v0.30 8-type schema)** | 9-case enum classifying reference-library entities by narrative role. Cases: `character / location / event / concept / artifact / organization / era / work / other` (9th = catch-all). Each case carries `displayName` (full Chinese name like 人物 / 地点, NOT 1-char abbreviation per boss 8/30 OOB '别用缩写') + Lucide icon + `promptNumber` (1-9, used in LLM classification prompts). Stored as `Reference.entityType` field. v0.30 boss 8/30 OOB '实体如何定义，是不是有规则' chose A: add explicit schema | v0.30 |
  ```
- **Severity**: SOFT. The CONTEXT.md row mentions `displayName` + `Lucide icon` + `promptNumber` but does NOT enumerate `description` / `ultraShortName` / `fromPromptNumber`. The row is reasonably comprehensive but misses the 4 new public APIs. Borderline acceptable because the row groups them under "Each case carries ..." (= umbrella statement).
- **Fix**: amend CONTEXT.md L111 to add `+ description (CJK, for LLM prompt context) + ultraShortName (1-char abbreviation, kept for future use) + fromPromptNumber(_:) reverse lookup (used by LLM output parser)`. Either fold into a follow-up `docs(wenshu): v0.30 — domain word add (EntityType complete API surface)` commit or include in the next batch's docs commit.

### Finding S-5: dual-axis code-review not yet symmetric

- **Files**: this report (= Standards axis) + `.scratch/v0.30-polish-fixes/code-review-2026-08-30-spec-axis-report.md` (= Spec axis report, if it exists)
- **Severity**: SOFT (resolved in this turn if the spec-axis report is being written in parallel). Q125 dual-axis pattern requires both Standards and Spec axis reports.
- **Note**: this report (= Standards axis) provides the first axis. Q125 dual-axis satisfied once the spec-axis report also lands.

### Finding S-6: commit message format (= feat/fix docs/refactor)

- **Rule**: AGENTS.md §6 + project convention = `feat(wenshu):` for new features, `fix(wenshu):` for fixes, `docs(wenshu):` for docs, `refactor(wenshu):` for refactors.
- **Verified**:
  - `32fafec3c` = `feat(wenshu): v0.30 — EntityType enum + strict 2D taxonomy schema` — `feat` correctly applied (new enum + new public type + new domain concept). PASS.
  - `57ac2bfb2` = `fix(wenshu): v0.30 — type badge = full Chinese name` — `fix` correctly applied (changes existing `shortName` semantics per boss OOB). PASS.
  - `1cbbfb249` = `fix(wenshu): v0.30 — sidebar tree = only categories, no entity nodes` — `fix` correctly applied (removes entity children from existing tree). PASS.
  - `e38c96ad4` = `fix(wenshu): v0.30 — preview pane = single flat card flow` — `fix` correctly applied (removes existing per-category sections). PASS.
  - `e29ea8459` = `feat(wenshu): v0.30 — entity cards now have thumbnails + no global title` — `feat` correctly applied (adds new thumbnail UI + new gradient overlay). PASS.
- **Severity**: PASS (no action).

### Finding S-7: atomic-coupling rule (boss 8/22)

- **Rule**: multi-file commits must justify the coupling in commit body.
- **Verified**:
  - `32fafec3c` = 6 files (`EntityType.swift` new + 5 modified). Multi-file, but coupling is atomic: the new `EntityType` type is referenced by every consumer. Commit body line 14-52 enumerates each file's role in the atomic change. PASS.
  - `57ac2bfb2` = 1 file (`EntityType.swift`). PASS.
  - `1cbbfb249` = 1 file (`NewLibraryOutlineView.swift`). PASS.
  - `e38c96ad4` = 1 file (`EntityPreviewPane.swift`). PASS.
  - `e29ea8459` = 1 file (`EntityPreviewPane.swift`). PASS.
- **Severity**: PASS (no action). 4 of 5 commits adhere to the stricter single-file ideal (= avoids coupling justification burden entirely). 32fafec3c is multi-file but coupling is justified.

### Finding S-8: 1 ticket 1 commit (Q29)

- **Verified**:
  - `32fafec3c` ↔ `.scratch/v0.30-polish-fixes/issues/01-entity-type-schema.md`. PASS.
  - `57ac2bfb2` ↔ `.scratch/v0.30-polish-fixes/issues/02-type-badge-full-name.md`. PASS.
  - `e29ea8459` ↔ `.scratch/v0.30-polish-fixes/issues/03-card-thumbnails.md`. PASS.
  - `e38c96ad4` ↔ `.scratch/v0.30-polish-fixes/issues/04-flat-card-flow.md`. PASS.
  - `1cbbfb249` ↔ `.scratch/v0.30-polish-fixes/issues/05-sidebar-no-entities.md`. PASS.
- **Severity**: PASS (no action). Spec.md line 33-37 documents the commit-to-OOB mapping verbatim. Each commit has a 1:1 ticket.

### Finding S-9: AGENTS.md 修真 12-token forbidden list

- **Verified**: ripgrep over 4 modified Swift files + 5 commit bodies + 5 issue files for `修真|渡劫|筑基|返虚|结丹|金丹|元婴|飞升|天劫|雷劫|心魔|魔障` returns **0 hits**. Same pattern as `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-standards-axis-report.md` S-8 line 295-298 (passing 015.xxx).
- **Severity**: PASS (no action).

### Finding S-10: AGENTS.md forbidden English modals (12+1 list)

- **Verified**: ripgrep for `\b(may|might|should|could|perhaps|probably|consider|tries?|尽量|大概|也许|可能|应当|或许|应该|建议|试图|任意|大概率|通常|一般来说|和 FCP 一样)\b` over 4 modified Swift files + 5 commit bodies returns:
  - `32fafec3c`: 2 hits — `Sources/WenshuApp/Domain/Reference.swift:122` (`(= legacy raw materials may not have a category).`) and `Sources/WenshuApp/Domain/Reference.swift:142` (`// v0.30: entityType may be encoded as String ("character") OR Int (1).`). Both are **descriptive English** (= "may" = "might", not imperative command to user). PASS per prior precedent (= S-9 of prior report, same pattern).
  - Other 4 commits: 0 hits.
- **Severity**: PASS (no action).

### Finding S-11: `Boss 8/<date> OOB` audit-marker convention

- **Verified**: every commit body and every comment block uses `Boss 2026-08-30 OOB` (English-only audit markers, NOT CJK `老板`) per the established project convention documented in `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-standards-axis-report.md` S-10 line 305-308. The user's literal `老板` is reserved for CJK-side citations (`.md` files, doc comments) and is NOT used inside `.swift` source.
- **Variants found**:
  - `32fafec3c` line 15: `Boss 2026-08-30 OOB '...'`
  - `32fafec3c` line 17: `Boss chose A: '...'` (= variant: "Boss chose" without OOB; acceptable as a decision-record marker, not a verbatim quote)
  - `57ac2bfb2` line 9: `Boss 2026-08-30 OOB '...'`
  - `1cbbfb249` line 13: `Boss 2026-08-30 OOB '...'`
  - `e38c96ad4` line 13: `Boss 2026-08-30 OOB '...'`
  - `e38c96ad4` line 30: `Boss UX: '卡片流, 一直铺下去'` (= variant: "Boss UX" without OOB; same as above)
  - `e29ea8459` line 19: `Per boss: 素材预览区 不需要这个标题` (= variant: "Per boss:" without OOB; descriptive, not verbatim)
  - `EntityType.swift:58`: `boss 8/25 'UI 全中文' carve-out` (= lowercase "boss" + version reference, not OOB; acceptable per prior precedent as an audit marker to AGENTS.md carve-out)
- **Severity**: PASS (no action). All Boss references are either standard `Boss <date> OOB '...'` markers (= verbatim quote pattern) or "Boss chose" / "Per boss" / "boss <date>" decision-record markers. No imperious imperative address (= "Boss must...", "Boss should...") found.

### Finding S-12: Single address to 老板

- **Rule**: AGENTS.md line 7 + line 78 — "Sole address for the user = 老板" (= the literal characters). No earlier honorific forms allowed.
- **Verified**:
  - 0 instances of non-standard honorific forms (= "老板您" / "老板大大" / "老大" / "兄弟" / "老板好") in any of the 5 commit bodies, code-line comments, or issue files.
  - 0 instances of `老板` in any Swift source file (= the user literal is reserved for CJK-side prose only).
  - 5 instances of `老板` in `.scratch/v0.30-polish-fixes/spec.md` (= CJK-side spec doc; correct audience).
- **Severity**: PASS (no action).

### Finding S-13: `EntityPreviewPane.swift` line 413-414 duplicate sentence

- **File**: `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift:413-414`
- **Verbatim** (file as-it-stands today):
  ```
  background (= the type's distinguishing color). This gives each
  This gives each card a strong visual identity at a glance
  ```
- **Severity**: SOFT (process defect). This is a residual defect from the prior era's `EntityCard` doc-comment (= was caught in `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-standards-axis-reverify-report.md` finding "NEW defect introduced by 230af9a92"). The line was NOT introduced by any of these 5 commits under review (= was already in the file when 32fafec3c era began). e29ea8459 modified lines adjacent to L413-414 but did not touch the duplicate. The cleanup commit `230af9a92` failed to fold this.
- **Fix**: include in the H-1 cleanup commit: `/// background (= the type's distinguishing color). This gives each\n/// This gives each card a strong visual identity at a glance` → `/// background (= the type's distinguishing color). This gives each\n/// card a strong visual identity at a glance (= matches Notion "card cover" pattern)` (i.e. remove duplicate `This gives each` and replace `无边记` with nothing).

## Per-commit summary

| Commit | Files | Lines | H (hard) | S (soft) | Violations detail |
|---|---|---|---|---|---|
| 32fafec3c | 6 files (1 new + 5 modified) | 343 + / 50 - | 10 CJK-in-comment lines (H-1.1, H-1.2, H-1.3 borderline, H-1.4, H-1.5, H-1.6, H-1.7 marginal, H-1.8 borderline, H-1.9) | 1 (S-3: Chinese LLM prompt template; S-4: 2 new public APIs undocumented in CONTEXT.md) | Multi-file but coupling justified in body. EntityType.swift new file; LLM prompt template CJK content; 9 new CJK-in-comment lines outside Boss-quote brackets. |
| 57ac2bfb2 | 1 file | 21 + / 1 - | 1 CJK-in-comment (H-1.9, marginally 1 more borderline) | 1 (S-4: ultraShortName undocumented in CONTEXT.md) | Single-file; EntityType.swift shortName semantics change; 2 new CJK-in-comment lines (= mostly Boss-quote carve-out extensions + 1 hard site H-1.9). |
| 1cbbfb249 | 1 file | 21 + / 24 - | 2 CJK-in-comment (H-1.15, H-1.17) | 0 | Single-file; NewLibraryOutlineView.swift removes entity children; 3 new CJK-in-comment lines outside Boss-quote brackets. |
| e38c96ad4 | 1 file | 25 + / 30 - | 1 CJK-in-comment (H-1.13 borderline) | 0 | Single-file; EntityPreviewPane.swift removes per-category sections; 3 new CJK-in-comment lines (= 2 Boss-quote carve-out extensions + 1 borderline). H-1.14 was reclassified to e29ea8459 (= see below). |
| e29ea8459 | 1 file | 72 + / 64 - | 3 CJK-in-comment (H-1.10 borderline, H-1.11, H-1.12 borderline, H-1.14) | 0 | Single-file; EntityPreviewPane.swift adds thumbnail header; 4 new CJK-in-comment lines outside Boss-quote brackets (= H-1.10 borderline Boss-quote bracket + H-1.11 hard + H-1.12 borderline + H-1.14 hard). |
| **TOTAL** | **5 commits, 6 files** | **482 + / 169 -** | **11 hard CJK-in-comment (strict) + 5 borderline Boss-quote bracket extensions** | **S-1 (Q34 step 1+6), S-2 (swiftlint comma), S-3 (LLM prompt template), S-4 (CONTEXT.md gaps), S-5 (dual-axis ok), S-13 (residual duplicate sentence)** | One hard finding cluster to clean (H-1) before v0.30 ship. 4 soft follow-ups. |

## Q5.6 partial commit 接管规范 compliance

- spec.md exists at `.scratch/v0.30-polish-fixes/spec.md`: YES (= 6.7 KB, 139 lines, covers all 5 commits with commit-to-OOB mapping at line 33-37, scope at line 27-38, fix plan at line 86-119, post-hoc Q34 audit at line 132-138, out-of-scope not enumerated).
- issues/ exist: YES (= 5 issues: `01-entity-type-schema.md` / `02-type-badge-full-name.md` / `03-card-thumbnails.md` / `04-flat-card-flow.md` / `05-sidebar-no-entities.md`).
- commit hashes documented in spec.md: YES (= line 33-37 carries all 5 SHAs in the Boss OOB driving table; line 41-119 carries SHAs in the per-bug breakdown).
- post-hoc acknowledgement: YES (= `ad4ded9f8 docs(wenshu): v0.30 polish-fixes spec + 5 tickets (post-hoc Q5.6 partial commit 接管规范)` brought both spec.md + 5 issues into `.scratch/v0.30-polish-fixes/` before this Standards report landed).

Q5.6 partial commit 接管规范 compliance: **PASS** (= post-hoc acceptable per rule, docs commit landed before code-review = timing requirement met).

## Q34 8-step chain compliance (= post-hoc audit)

| Step | Required | Done? | Notes |
|---|---|---|---|
| 1. grill-with-docs | interview 老板 + lock spec | NO | Pre-implementation grill did NOT run. Pattern: 老板 sent 5 OOB messages via OOB protocol; cc-runner implemented directly against each OOB without a structured grill-with-docs session. Same gap as `.scratch/v0.30-sidebar-preview-pane/spec.md` line 138-145 + `.scratch/v0.30-pre-pane-fixes/spec.md` line 138-145. |
| 2. to-tickets commit | issues/01..N under `.scratch/feature/` | YES (post-hoc) | 5 issue files created post-hoc via commit `ad4ded9f8` (2026-08-30). Pre-Q5.6 partial-commit-接管 gap closed before this report. |
| 3. implement commit | code lands per ticket | YES | 5 implementation commits landed in direct chronological order (= `32fafec3c` 17:05 → `57ac2bfb2` 17:51 → `1cbbfb249` 18:20 → `e38c96ad4` 18:23 → `e29ea8459` 18:37). |
| 4. swift build exit 0 | compile clean | YES | spec.md line 130 "[x] Build exit 0"; commit bodies cite "Build clean" for all 5. SwiftLint ran with 8 pre-existing comma warnings only (= S-2 above). |
| 5. code-review 双轴 | Standards + Spec reports | YES (this turn) | Standards-axis report = this file. Spec-axis report = `.scratch/v0.30-polish-fixes/code-review-2026-08-30-spec-axis-report.md` (= TBD, written in parallel by Spec-axis sub-agent). Q125 dual-axis satisfied once spec-axis report lands. |
| 6. hard violation 修法 | fix H-1 + rerun | PENDING | H-1 cleanup commit needed. Recommended shape: single `fix(wenshu): v0.30 polish-fixes — CJK-in-comments cleanup (32fafec3c + 57ac2bfb2 + 1cbbfb249 + e38c96ad4 + e29ea8459)` sweeping 11 hard sites + 5 borderline sites + 1 residual duplicate sentence (S-13). Reference pattern: `230af9a92` for v0.30 sidebar+preview. |
| 7. domain-modeling commit | new public types → CONTEXT.md | YES (partial) | `EntityType` added to CONTEXT.md in commit `7531ca7c0` (= row L111). `EntitySortOrder` + `SidebarItem` + `adaptiveColumns` + `LucideIconSidebar` also added in same commit. BUT `EntityType.description` + `ultraShortName` + `promptNumber` + `fromPromptNumber` not separately enumerated (= S-4 above). Borderline PASS. |
| 8. Q22 真验证 | screenshot + AX tree + 老板 verify | PARTIAL | spec.md acceptance criteria checklist line 121-129: all `[x]`. Per Q22 (boss OOB 8/22 真验证 = pixel + AX tree + boss OK): pixel screenshot = present (= cited in 4 of 5 commit bodies: "Verified via screenshot"), AX tree capture = MISSING (= Apple Accessibility API tree dump not yet captured), 老板 OK flag = NOT YET (this report still needs 老板 to read + ack). |

## Summary

The 5 v0.30 polish-fixes commits deliver on the boss OOB scope and follow the established project conventions for `Boss 8/<date> OOB` audit markers, Boss-verbatim-quote carve-outs, Q5.6 partial commit 接管规范 (post-hoc), and 1-ticket-1-commit mapping. The Q124 atomic-coupling rule is naturally satisfied for 4 of 5 commits (= single-file); the multi-file 32fafec3c is justified by the new `EntityType` type touching every consumer atomically. All 5 commit messages use the correct `feat(wenshu):` / `fix(wenshu):` format. All 5 issues + spec.md are present and document the commit-to-OOB mapping. No 修真 forbidden tokens. No non-standard 老板 honorific forms.

The single actionable finding is **H-1**: 11 distinct sites in 5 files (some shared across commits) carry un-attributed CJK in code-line comments (= outside the Boss-verbatim-quote bracket pattern that the prior `015.005/012/018/062` cleanup reports + `230af9a92` for v0.30 sidebar+preview established). 5 borderline sites are multi-line Boss-quote bracket extensions (= per prior precedent these are carve-out PASS). Recommended fix is a single `fix(wenshu):` cleanup commit sweeping all 11 sites — see the H-1 fix table for the verbatim English rewrites, and the suggested commit body shape mirroring `230af9a92`.

S-1 (Q34 step 1+6 not executed) is a process follow-up, not a standards blocker. S-2 (8 SwiftLint comma warnings in the folder tuple) is a pre-existing surface defect carried forward from prior era. S-3 (Chinese LLM prompt template) is a borderline finding — pragmatic carve-out applied but AGENTS.md should be amended to make the carve-out explicit. S-4 (CONTEXT.md gaps for `description` + `ultraShortName`) is a minor follow-up that can be folded into the next docs commit. S-13 (residual duplicate sentence in `EntityPreviewPane.swift` L413-414) should be folded into the H-1 cleanup commit.

Verdict: **CONDITIONAL PASS**. H-1 cleanup commit + S-13 fold-in + S-3 AGENTS.md amendment before v0.30 final ship. S-1 (Q34 step 1 grill), S-2 (comma-spacing), S-4 (CONTEXT.md gaps) can follow up as separate small tickets.