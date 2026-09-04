# Standards Axis Report — v0.30 batch3 (4 commits)

> Date: 2026-08-30
> Sub-agent: Standards axis (AGENTS.md §5-6 hard rules + boss-protocol carve-outs)
> Commits reviewed: 291487322, 09c6521e2, bf86a0b2b, a8bebb858
> Branch: wt/multi-agent-dispatch
> Reviewer tools: ripgrep (CJK + pollution scan), git show/diff/blame, `swiftlint` 0.65.1, `swift build`, python `Tools/wenshu-devtool/pollution_watchdog.py`
> Carve-out precedent: `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-standards-axis-report.md` (= established Boss-verbatim-quote + UI-string + audit-marker `Boss 8/<date> OOB` patterns)

## Verdict: CONDITIONAL PASS

`CONDITIONAL PASS` (= 1 hard violation cluster + 4 soft findings). The 4 commits are shippable: they implement the boss OOB scope, the build is clean, all CJK in commit bodies is `Boss <date> OOB '...'` or functional data (= established carve-outs), no `修真`/pollution tokens in the diffs, SwiftLint shows only the pre-existing 8 comma-spacing warnings carried forward from c5ed76169 (not introduced by any batch3 commit). However, four real issues need cleanup before the v0.30 final cut:

1. **H-1 (highest priority, blocker for v0.30 ship)**: `Scripts/split-help-docs.py` (new file, 636 lines, 100% of bf86a0b2b's volume) contains 5+ code-line comment lines with un-attributed CJK outside the Boss-verbatim-quote bracket pattern. Not a build blocker (script runs idempotently, content correct) but a HARD rule violation against AGENTS.md §5-6.
2. **S-1 (process)**: `EntityPreviewPane` is a new public SwiftUI `View` struct (= new public type surface) added in 291487322 with no CONTEXT.md domain-word row. Self-flagged in spec.md as out-of-scope; consistent with prior polish-fixes report's S-4 finding.
3. **S-2 (process)**: Q34 step 1 (grill-with-docs) was NOT executed. Spec.md line 95-101 self-acknowledges this. Same pattern as the prior 3 batches' Q34 gaps; closing this gap requires human/boss action outside the code-review sub-agent's authority.
4. **S-3 (process)**: `swift build` exit 0 verified; SwiftLint shows only 8 pre-existing `comma` warnings in `NewLibraryOutlineView.swift:287-291` (= 09c6521e2 area) — same pre-existing pattern documented in the prior standards reports; not a regression from batch3.

The remaining 7 rules pass cleanly.

## Findings (= FAIL / H = hard violation)

### Finding H-1: un-attributed CJK in code-line comments of `Scripts/split-help-docs.py`

- **Commit**: bf86a0b2b
- **Files**: `Scripts/split-help-docs.py` (= new file, 636 lines)
- **Rule violated**: AGENTS.md §5-6 — English-only hard rule. "All commit messages, comments, prompts... follow the same English-only rule." Carve-outs per prior `.scratch/reviews/015.xxx` + `.scratch/v0.30-*/code-review-*-standards-axis-report.md`: Boss verbatim quotes, audit markers (= `Boss 8/<date> OOB`), user-facing UI strings (= Text/Button labels), LLM prompt template content, entity-body content. **Code-line comments describing implementation must be English.**
- **Severity**: HARD. The `.swift` files were already cleaned up by `230af9a92` (= batch1's H-1 cleanup commit). The Python dev script introduced by bf86a0b2b adds 5+ new CJK code-line comment hits. The prior project precedent for `Scripts/*.py` is established (= `Scripts/split-libai-dufu.py` from v0.29 carries the same pattern), but the prior standards reports explicitly exclude Scripts/*.py from the strict Swift-source carve-out analysis (= see `.scratch/v0.30-polish-fixes/code-review-2026-08-30-standards-axis-report.md` S-3). However, per AGENTS.md §5-6 strict reading, code-line comments in **any** tracked source file (including Scripts/*.py) must be English-only.

**Verbatim code excerpts:**

H-1.a — `Scripts/split-help-docs.py:41`

```
# ============================================================
# 1. 角色: Split 六个Agent.md → 6 separate files
# ============================================================
```

`(角色 / 六个Agent.md / →)` are CJK characters and CJK punctuation inside a code-line comment without being enclosed in `Boss 8/<date> OOB '...'` quote-bracket form. Per precedent reports (`015.062-*-standards.md` line 18-22, `v0.30-sidebar-preview-pane/code-review-2026-08-30-standards-axis-report.md` H-1.h) the carve-out applies only to CJK inside `Boss 8/<date> OOB '...'` brackets; here the CJK appears outside the boss-quote phrase structure.

H-1.b — `Scripts/split-help-docs.py:46-47`

```
# Also update entities.json to reflect the split
# (No entity changes needed — these are book-level help docs, not entities)
```

Line 46 is English. Line 47 is English. **No violation here** — included only to show the contrast with line 41 above.

H-1.c — `Scripts/split-help-docs.py:261`

```
# Track that the parent file 六个Agent.md should be deleted
```

`(六个Agent.md)` is a literal disk-filename string in a code-line comment. While the filename is a legitimate disk reference (correct filename to delete), the COMMENT (not the string being deleted) contains CJK. The filename could be referenced via the path variable (`shelf_root / "characters" / "六个Agent.md"`) outside the comment.

H-1.d — `Scripts/split-help-docs.py:275-291`

```
# ============================================================
# 2. 小说正文: Split 功能模块说明.md → 8 separate files
# ============================================================

print("\n=== 2. 小说正文: 功能模块说明 → 8 files ===")

# We split into:
# 1. 项目管理区 (Sidebar)
# 2. 素材预览区 (Project Preview)
# 3. 编辑器 (Editor)
# 4. 工具区 (Specialized Tools)
# 5. 聊天区 (Chat)
# 6. 动态区 (Dynamic)
# 7. 资料库 (Reference Library)
# 8. 标题栏 + 状态栏 (Title + Status bar)
# 9. 交互约定 (Keyboard shortcuts)
# Total = 9 (the 8 zones + 1 keyboard reference)
```

This is the most flagrant violation: 11 consecutive code-line comment lines carrying the raw Chinese module names. The L281-291 list redundantly re-states the module names that are ALREADY enumerated inside the `module_files = [...]` array structure below (= comment is a documentation-style repeat of the data). Translating the comment names to English equivalents is mechanical.

H-1.e — `Scripts/split-help-docs.py:617`

```
# Track that the parent file 功能模块说明.md should be deleted
```

Same pattern as H-1.c (`功能模块说明.md` = disk filename in code-line comment, not in a boss-quote bracket).

H-1.f — `Scripts/split-help-docs.py:630-635`

```
print()
print("=" * 70)
print("Summary:")
print(f"  角色: 1 file → {len(agent_files)} files (= 1 file per agent)")
print(f"  小说正文: 1 file → {len(module_files)} files (= 1 file per function module)")
print(f"  Total: 2 → {len(agent_files) + len(module_files)} files (= 6 + 9 = 15 new files)")
print("=" * 70)
```

These `print()` statements carry CJK in terminal output. Strict reading of AGENTS.md §5-6 (English-only in code) flags these as code-source violations (the print() argument is a Python source string literal). However, the project convention precedent for `Scripts/*.py` accepts this pattern (cf. `Scripts/split-libai-dufu.py` L36 `print("ERROR: 旧 '李白与杜甫' entity not found. Aborting.")`, L163 `print("v0.29 split 李白与杜甫 → 李白 + 杜甫 (both subcategory=I2)")` — same CJK-in-print() pattern from v0.29). Recommend flagging as H-1 borderline, not separate finding.

**Total: 5 distinct code-line comment CJK hits + 3 CJK-in-print() hits + 1 mixed-comment-block (H-1.d = 11 lines), all introduced by bf86a0b2b.**

**Fix per H-1** (suggested English rewrites):

| Line | Current | Suggested English |
|---|---|---|
| L41 | `# 1. 角色: Split 六个Agent.md → 6 separate files` | `# 1. Characters: split 6-agents.md -> 6 separate files` |
| L44 | `print("\n=== 1. 角色: 六个Agent → 6 files ===")` | `print("\n=== 1. Characters: 6-agents -> 6 files ===")` |
| L261 | `# Track that the parent file 六个Agent.md should be deleted` | `# Track that the parent file (= "characters/6-agents.md") should be deleted` |
| L270 | `print(f"  ✗ DELETED: characters/六个Agent.md (split into 6 files)")` | `print(f"  ✗ DELETED: characters/6-agents.md (split into 6 files)")` |
| L272 | `print(f"\n  Created {len(agent_files)} files in 角色/")` | `print(f"\n  Created {len(agent_files)} files in characters/")` |
| L275 | `# 2. 小说正文: Split 功能模块说明.md → 8 separate files` | `# 2. Chapters: split function-modules.md -> 8 separate files` |
| L279 | `print("\n=== 2. 小说正文: 功能模块说明 → 8 files ===")` | `print("\n=== 2. Chapters: function-modules -> 8 files ===")` |
| L281-291 | 11 CJK module-name comments | rename to English module names: Sidebar / Preview / Editor / Tools / Chat / Dynamic / Reference / ChromeStatusBar / KeyboardShortcuts (= same as the `filename` keys below, no information loss) |
| L617 | `# Track that the parent file 功能模块说明.md should be deleted` | `# Track that the parent file (= "chapters/function-modules.md") should be deleted` |
| L626 | `print(f"  ✗ DELETED: chapters/功能模块说明.md (split into {len(module_files)} files)")` | `print(f"  ✗ DELETED: chapters/function-modules.md (split into {len(module_files)} files)")` |
| L628 | `print(f"\n  Created {len(module_files)} files in 小说正文/")` | `print(f"\n  Created {len(module_files)} files in chapters/")` |
| L633 | `print(f"  角色: 1 file → {len(agent_files)} files (= 1 file per agent)")` | `print(f"  characters: 1 file -> {len(agent_files)} files (= 1 file per agent)")` |
| L634 | `print(f"  小说正文: 1 file → {len(module_files)} files (= 1 file per function module)")` | `print(f"  chapters: 1 file -> {len(module_files)} files (= 1 file per function module)")` |

Note: the `.md` content data being WRITTEN to the user-facing help-doc files (= the `f"""..."""` blocks at L51-258 and L293-614) contains massive CJK. That CJK is the **content of user-facing documentation files** (= help-doc markdown that the user reads in their library), not code-line comments. It is the SAME carve-out as the LLM prompt template content (Finding S-3 of prior polish-fixes report, line 278-310) and the entity-body content (line 233 of prior report). **NOT a violation** — only the COMMENTS and `print()` statements around them need cleanup.

A single `fix(wenshu): v0.30 — bf86a0b2b CJK cleanup (Scripts/split-help-docs.py comments + print +144 sites)` commit sweeping these 13+ sites is the right shape (= same pattern as `230af9a92` cleanup for the Swift files).

### Finding H-1 does NOT include

These CJK hits in the same file (bf86a0b2b) were checked and judged **acceptable** per the established carve-outs:

| File:line | Excerpt | Why OK |
|---|---|---|
| Scripts/split-help-docs.py:2-12 (module docstring) | `Boss OOB '角色一个文件拆成六个吧...'` | Boss-verbatim quote (= inside the docstring = documentation, sits at top of the file). Module docstrings are documentation, not code-line comments — different surface from inline `#` comments. PASS per audit-marker convention. |
| Scripts/split-help-docs.py:51-258 (agent_files list content) | `f"""# 主 Agent (Conductor)\n你是直接对话的那个 (= 文枢打开后的主聊天窗口)。它读你当前选中的章节和设定, 帮你:...` | Content DATA written to user-facing .md files. Same carve-out as LLM prompt template content + entity-body content. PASS. |
| Scripts/split-help-docs.py:136 (`## v0.30 增强 (= 老板新拍)`) | INSIDE f-string content block (= written to .md) | Content data, not code comment. PASS. |
| Scripts/split-help-docs.py:293-614 (module_files list content) | Massive CJK .md content | Same as above — user-facing documentation data. PASS. |
| Scripts/split-help-docs.py:402 (`跨章节的伏笔追踪。老板 OOB v0.30+ = 自动扫描你正文里的"伏笔"标记。`) | INSIDE f-string content block | Same content-data carve-out. The `老板 OOB` here is a literal reference in the .md content, NOT the commit-message-side audit marker. PASS. |
| Sources/WenshuApp/Storage/LibraryMigrator.swift:587-594 (NEW comment block) | `// v0.30 boss OOB: '角色一个文件拆成六个吧, 正常以后也是一个角色一个文档'. The single 六个Agent.md is replaced by 6 per-agent files...` | CJK is inside `Boss OOB '...'` quote brackets (PASS), plus `六个Agent.md` is a literal disk-filename reference (identifier context, not prose comment). |
| Sources/WenshuApp/Storage/LibraryMigrator.swift:635-640 (NEW comment block) | `// v0.30 boss OOB: '功能模块也是, 一个功能模块拆成一个文档'. The single 功能模块说明.md is replaced by 9 per-module files...` | Same as above. |
| Sources/WenshuApp/Storage/LibraryMigrator.swift:596, 641 (let charactersFile/chapterFile) | `.appendingPathComponent("六个Agent.md")` / `.appendingPathComponent("功能模块说明.md")` | Disk-filename literal in code (legitimate CJK identifier reference). |
| Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift (09c6521e2 stdFolders tuple) | `("世界观", "globe", "world")` etc. | UI-string tuple literals displayed in the sidebar UI. Per precedent `v0.30-polish-fixes/code-review-2026-08-30-standards-axis-report.md` S-2 these are accepted as UI-string content. |

All 4 commit bodies' CJK is `Boss 2026-08-30 OOB '...'` verbatim quotes — acceptable per established audit-marker precedent.

## Findings (= SUG / soft = nice-to-have)

### Finding S-1: `EntityPreviewPane` new public type not added to CONTEXT.md

- **File**: `Sources/WenshuApp/Views/Workspace/EntityPreviewPane.swift` (= new file from 291487322)
- **Files affected**: `CONTEXT.md` (= should add row), the new file itself
- **Rule**: AGENTS.md §6 + project Q34 step 7 = "domain-modeling commit (= add new domain words to CONTEXT.md)"
- **Affected types**: `EntityPreviewPane` (new public SwiftUI `View` struct, 291487322). Pattern follows prior polish-fixes report's Finding S-4 (`EntityType.description` + `ultraShortName` not documented in CONTEXT.md, line 312-326).
- **Severity**: SOFT. CONTEXT.md currently documents 6 v0.30-era domain words added in commit `7531ca7c0`: `EntityCategory`, `EntityType`, `SidebarItem`, `EntitySortOrder`, `adaptiveColumns(width:)`, `LucideIconSidebar`. None of them are SwiftUI views (= all are enums / functions / helpers). `EntityPreviewPane` IS a new architectural concept (= the entity-card-flow render component for the material management zone) — same level of architectural significance as `SidebarItem` (= composite enum for sidebar List selection). Borderline-PASS because EntityPreviewPane is the implementation detail of an already-known domain concept (preview pane), but per the strict prior precedent (S-4 of polish-fixes report) any new public TYPE should get a CONTEXT.md row.
- **Fix**: one `docs(wenshu): v0.30 — domain word add (EntityPreviewPane)` commit touching `CONTEXT.md` only. Suggested row:

  | Symbol | Description | Phase |
  |---|---|---|
  | `EntityPreviewPane (v0.30 entity card flow)` | Public SwiftUI View rendering entity cards in the material management zone (= projectPreview). 3 modes: single-entity detail / category-scoped grid / overview grid. Uses `LazyVGrid` with `adaptiveColumns(width:)` for responsive 2-col → 1-col layout. Card content: type icon thumbnail + `[type]` badge + category chip + title + summary. Double-click handler wired for Ticket 3 (= future editor-zone wiring). | v0.30 |

  Optional: batch with `twoColumnBreakpoint (private constant = N/A)`, `EntityCard (private struct = N/A)`, `pinyinFirstLetter(_:) private helper`.

### Finding S-2: SwiftLint `comma` warnings pre-existing in `NewLibraryOutlineView.swift`

- **File**: `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:287-291`
- **Rule**: SwiftLint `comma` rule (`.swiftlint.yml` defaults)
- **Verbatim output** (`swiftlint lint Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`):
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
- **Verbatim line 287-291** (file post-batch3):
  ```
  ("world",      "世界观",      "globe"),
  ("characters", "角色",        "user-round"),
  ("outlines",   "章节大纲",    "list-tree"),
  ("chapters",   "小说正文",    "book-text"),
  ("drafts",     "小说草稿",    "file-pen-line"),
  ```
- **Severity**: SOFT. The 8 comma warnings are in `standardFolderNames` (= `[(name: String, displayName: String, icon: String)]`), which is the CURRENT (post-c5ed76169 batch1) file state. The `09c6521e2` commit DID touch a similar tuple structure (`standardFolders: [(name, icon, directoryName)]`) but that tuple was subsequently refactored to the current `standardFolderNames` by the later c5ed76169 commit. The 8 warnings pre-date the batch3 commits; they are the same 8 warnings documented in the prior standards report (see `v0.30-sidebar-preview-pane/code-review-2026-08-30-standards-axis-report.md` S-2 line 221-242). Not introduced by any of the 4 batch3 commits.
- **Fix**: `swiftlint autocorrect` (or manual realignment). Fold into the H-1 cleanup commit or follow up as one-shot `chore(wenshu): v0.30 — sidebar folder tuple comma-spacing`.

### Finding S-3: Q34 step 1 (grill-with-docs) not executed — self-acknowledged post-hoc

- **File**: `.scratch/v0.30-batch3/spec.md` line 95-101
- **Verbatim**:
  ```
  ## Q34 audit (= post-hoc)

  This batch was implemented without the Q34 8-step chain (= no grill, no
  spec/ticket pre-write, no code-review sub-agent). Spec + tickets committed
  post-hoc (= this batch + the previous 3 batches).

  Going forward: every new ticket walks full chain.
  ```
- **Severity**: SOFT — self-acknowledged. The 4 commits were authored without the Q34 walkthrough (= no grill-with-docs → no spec → no tickets → no implement → no code-review → no domain-modeling). The retroactive doc commit `fe01fb59b docs(wenshu): v0.30 batch3 spec + 4 tickets (post-hoc Q5.6 partial commit 接管规范)` (= 2026-08-30 22:50:56 +0800, brought both spec.md + 4 issues into `.scratch/v0.30-batch3/` before this Standards report landed) brings the chain back into compliance per Q5.6 partial commit 接管规范 (post-hoc acceptable if added before code-review).
- **Note**: this code-review (= this report) = the missing link in the chain. After this report lands, the Q5.6 requirement "spec/ticket must exist in `.scratch/feature/` (post-hoc acceptable but must be added before code-review)" is fully satisfied. Q34 step 1 (grill-with-docs) + step 6 (hard violation cleanup = fix H-1) remain pending — those need human/boss action.

### Finding S-4: dual-axis code-review not yet symmetric

- **Files**: this report (= Standards axis) + `.scratch/v0.30-batch3/code-review-2026-08-30-spec-axis-report.md` (Spec axis report = 8.7 KB, already exists)
- **Severity**: SOFT (resolved in this turn). The companion spec-axis report already exists at 8.7 KB. This Standards-axis report (= this file) provides the second axis. Q125 dual-axis pattern satisfied.

### Finding S-5: commit message format (= feat/fix docs/refactor)

- **Rule**: AGENTS.md §6 + project convention = `feat(wenshu):` for new features, `fix(wenshu):` for fixes, `docs(wenshu):` for docs, `refactor(wenshu):` for refactors.
- **Verified**:
  - `291487322` = `feat(wenshu): v0.30 — EntityPreviewPane (card flow in material management zone)` — `feat` correctly applied (NEW SwiftUI View + new binding chain + new ENC type surface). PASS.
  - `09c6521e2` = `fix(wenshu): v0.30 — sidebar folder count badge (= show .md count per folder)` — `fix` correctly applied (changes `count: nil` → `count: docCount` = bug fix). PASS.
  - `bf86a0b2b` = `feat(wenshu): v0.30 — split help-doc files (角色 1→6, 功能模块 1→9)` — `feat` correctly applied (NEW script + new split file structure + removed old merged file write path). PASS.
  - `a8bebb858` = `fix(wenshu): v0.30 — sidebar tree row trailing padding 18 PT (= count badge breathing room)` — `fix` correctly applied (adds `.padding(.trailing, 18)` = bug fix for cramped badge). PASS.
- **Severity**: PASS (no action).

### Finding S-6: atomic-coupling rule (boss 8/22)

- **Rule**: multi-file commits must justify the coupling in commit body.
- **Verified**:
  - `291487322` = 5 files (1 NEW `EntityPreviewPane.swift` + 4 modified: `App.swift`, `RegisteredPanes.swift`, `NewLibraryOutlineView.swift`, `WorkspaceView.swift`). Commit body enumerates all 5 modifications with explicit reason for each (= end-to-end binding chain from sidebar tap to preview pane render). The cohesion is one logical unit: the preview pane + the bindings + default-init wiring. PASS.
  - `09c6521e2` = 3 files (`BookStore.swift` + `WenshuLibrary.swift` + `NewLibraryOutlineView.swift`). Commit body enumerates all 3 modifications with reason. Atomic unit = folder count badge feature (helper + thin wrapper + consumer). PASS.
  - `bf86a0b2b` = 2 files (1 NEW `Scripts/split-help-docs.py` + 1 modified `LibraryMigrator.swift`). Commit body justifies: NEW script provides data, migrator removes old auto-merge code. Tight coupling. PASS.
  - `a8bebb858` = 1 file (`NewLibraryOutlineView.swift`). Single-file = no coupling required. PASS.
- **Severity**: PASS (no action). 4 commits all satisfy the boss 8/22 rule.

### Finding S-7: 1 ticket 1 commit (Q29)

- **Verified**:
  - `291487322` ↔ `.scratch/v0.30-batch3/issues/01-entity-preview-pane.md`. PASS.
  - `09c6521e2` ↔ `.scratch/v0.30-batch3/issues/02-folder-count-badge.md`. PASS.
  - `bf86a0b2b` ↔ `.scratch/v0.30-batch3/issues/03-split-help-docs.md`. PASS.
  - `a8bebb858` ↔ `.scratch/v0.30-batch3/issues/04-sidebar-18pt-padding.md`. PASS.
- **Severity**: PASS (no action). Spec.md line 26-32 documents the commit-to-OOB mapping verbatim (= `291487322` / `09c6521e2` / `bf86a0b2b` / `a8bebb858` in the Boss OOB driving table).

### Finding S-8: AGENTS.md 修真 12-token forbidden list

- **Verified**: ripgrep over the 6 modified/created files + 4 commit bodies for `修真|渡劫|筑基|返虚|结丹|金丹|元婴|飞升|天劫|雷劫|心魔|魔障` returns 0 hits. Same pattern as `.scratch/v0.30-polish-fixes/code-review-2026-08-30-standards-axis-report.md` S-7 line. `python3 Tools/wenshu-devtool/pollution_watchdog.py .` shows all 24 hits are in PRE-EXISTING files (`v0.28-free-layout/code-review-v028-001-standards.md`, `v0.28-integration-batch-1/standards-axis-review.md`, `v0.30-polish-fixes/code-review-...-standards.md`, `v0.30-sidebar-preview-pane/code-review-...-standards.md`, `.swiftlint.yml`) — NONE are in files modified or added by the 4 batch3 commits.
- **Severity**: PASS (no action).

### Finding S-9: AGENTS.md forbidden English modals (12+1 list)

- **Verified**: ripgrep for `\b(may|might|should|could|perhaps|probably|consider|tries?|尽量|大概|也许|可能|应当|或许|应该|建议|试图|任意|大概率|通常|一般来说|和 FCP 一样)\b` over the 6 modified/created files returns 3 hits:
  - `Scripts/split-help-docs.py:261` (`# Track that the parent file 六个Agent.md should be deleted`) — **descriptive English** (= "should" = "the proper action is to delete", describes the code below).
  - `Scripts/split-help-docs.py:617` (`# Track that the parent file 功能模块说明.md should be deleted`) — same pattern.
  - `Sources/WenshuApp/Storage/LibraryMigrator.swift:592` (`// exists, we delete it (= the split script should be re-run`) — descriptive English (= describes the script's purpose, not an imperative command).
  - `Sources/WenshuApp/Storage/LibraryMigrator.swift:639` (`// (= the split script should be run to migrate content).`) — descriptive English.
  - All 4 hits = **descriptive English** (= "should" = "the right action is", not imperative command to user). PASS per prior precedent (S-10 of polish-fixes report line 371-376: "Both are **descriptive English** (= 'may' = 'might', not imperative command to user). PASS per prior precedent (= S-9 of prior report, same pattern)").
- **Severity**: PASS (no action).

### Finding S-10: `Boss 8/<date> OOB` audit-marker convention (Rule 9 inverse)

- **Verified**: every commit body uses `Boss 2026-08-30 OOB '...'` (English-only audit markers, NOT CJK `老板`) per the established project convention documented in `.scratch/reviews/015.018-...standards.md` line 23 and `.scratch/v0.30-sidebar-preview-pane/code-review-2026-08-30-standards-axis-report.md` S-10 line 305-308. The user's literal `老板` is reserved for CJK-side citations (= `.md` files, doc comments — in this batch, the `Scripts/split-help-docs.py` `.md` content blocks at L136 and L402 carry `老板新拍` / `老板 OOB v0.30+` as content data being written to user .md files, which is content data not commit-message prose) and is NOT used inside commit bodies. The CJK `老板` references at `Scripts/split-help-docs.py:136` and `:402` are inside `f"""..."""` triple-quoted content blocks (= content DATA written to user .md files), so they're carve-out content, not commit-message prose. This matches the audit-marker carve-out pattern (S-3 content-data, S-4 prompt-template precedent, polish-fixes report S-3 line 278-310).
- **Severity**: PASS (no action).

## Per-commit summary

| Commit | Files | Lines | H (hard) | S (soft) | Violations detail |
|---|---|---|---|---|---|
| 291487322 | 5 files (1 new + 4 modified) | 409 + / 10 - | 0 hard violations in commit's diff (EntityPreviewPane.swift is born clean because `230af9a92` cleanup already ran) | 1 (S-1: EntityPreviewPane public type not in CONTEXT.md) | EntityPreviewPane.swift new file: all new code-line comments either English-only or Boss-quote-bracketed CJK. The `L10: card-flow grid (= 无边记-style sticky-note layout)` violation was introduced by this commit but ALREADY CLEANED in `230af9a92 fix(wenshu): v0.30 — H-1 CJK-in-comments cleanup` (= the title literal in this commit's state is `Notion-like sticky-note layout`). All CJK pass per established carve-outs. |
| 09c6521e2 | 3 files | 77 + / 8 - | 0 | 1 (S-2 pre-existing comma warnings carried forward) | BookStore.swift + WenshuLibrary.swift: all ENGLISH comments + Boss-quote-bracketed CJK. NewLibraryOutlineView.swift: changes a 2-element tuple to 3-element tuple, all CJK in tuple literals are UI strings. Clean. |
| bf86a0b2b | 2 files (1 new + 1 modified) | 653 + / 135 - | **1 cluster: H-1, 13+ sites in `Scripts/split-help-docs.py` code-line comments + 3 print() statements** | 0 | New file `Scripts/split-help-docs.py` (636 lines): massive CJK in code-line comments at L41, L261, L275, L281-291, L617 + CJK in print() statements at L270, L272, L279, L626, L628, L633-635. All COMMIT-DIFF CJK outside Boss-quote brackets = hard violation. LibraryMigrator.swift modification: REMOVES 152 lines of CJK string literals (positive net), adds 12 lines of Boss-quote-bracketed CJK comments + filename references (acceptable). |
| a8bebb858 | 1 file | 10 + / 0 - | 0 | 0 | NewLibraryOutlineView.swift: 2 NEW comment blocks, both have all CJK inside `Boss OOB '...'` quote brackets (= PASS per audit-marker convention). No regression. |
| **TOTAL** | **4 commits, 11 files (2 new + 9 modified)** | **1149 + / 153 -** | **H-1 cluster (= 13+ sites in bf86a0b2b's `Scripts/split-help-docs.py`)** | **S-1 (EntityPreviewPane CONTEXT.md), S-2 (8 swiftlint comma pre-existing), S-3 (Q34 step 1 post-hoc self-ack), S-4 (dual-axis ok)** | One hard finding (H-1) to clean before v0.30 ship. One soft follow-up (S-1) for Q34 step 7. |

## Q5.6 partial commit 接管规范 compliance

- spec.md exists at `.scratch/v0.30-batch3/spec.md`: YES (= 4.5 KB, 101 lines, covers all 4 commits with commit-to-OOB mapping at line 26-32, scope at line 33-60, fix plan at line 61-85, post-hoc Q34 audit at line 95-101, acceptance criteria line 87-93).
- issues/ exist: YES (= 4 issues: `01-entity-preview-pane.md`, `02-folder-count-badge.md`, `03-split-help-docs.md`, `04-sidebar-18pt-padding.md`).
- commit hashes documented in spec.md: YES (= line 26-32 carries `291487322` / `09c6521e2` / `bf86a0b2b` / `a8bebb858` in the Boss OOB driving table).
- post-hoc acknowledgement: YES (= `docs(wenshu): v0.30 batch3 spec + 4 tickets (post-hoc Q5.6 partial commit 接管规范)` commit at `fe01fb59b`, 2026-08-30 22:50:56 +0800, brought both spec.md + 4 issues into `.scratch/v0.30-batch3/` before this Standards report landed).
- **Q5.6 partial commit 接管规范 compliance: PASS** (= post-hoc acceptable per rule, docs commit landed before code-review = timing requirement met).

## Q34 8-step chain compliance (= post-hoc audit)

| Step | Required | Done? | Notes |
|---|---|---|---|
| 1. grill-with-docs | interview 老板 + lock spec | NO | Pre-implementation grill did NOT run. Pattern: 老板 sent 4 OOB messages via OOB protocol; cc-runner implemented directly against each OOB without a structured grill-with-docs session. Same gap as `.scratch/v0.30-sidebar-preview-pane/spec.md` line 138-145 + `.scratch/v0.30-pre-pane-fixes/spec.md` line 138-145 + `.scratch/v0.30-polish-fixes/spec.md` line 132-138. |
| 2. to-tickets commit | issues/01..N under `.scratch/feature/` | YES (post-hoc) | 4 issue files created post-hoc via commit `fe01fb59b` (2026-08-30 22:50:56). Pre-Q5.6 partial-commit-接管 gap closed before this report. |
| 3. implement commit | code lands per ticket | YES | 4 implementation commits landed in chronological order (`09c6521e2` 17:24 → `291487322` 18:06 → `bf86a0b2b` 18:17 → `a8bebb858` 18:30). |
| 4. swift build exit 0 | compile clean | YES | `swift build 2>&1 | tail -10` → "Build complete! (3.69秒)" exit 0. |
| 5. code-review 双轴 | Standards + Spec reports | YES (this turn) | Spec-axis report = `.scratch/v0.30-batch3/code-review-2026-08-30-spec-axis-report.md` (8.7 KB, already exists). Standards-axis report = this file. Q125 dual-axis satisfied. |
| 6. hard violation 修法 | fix H-1 + rerun | PENDING | H-1 cleanup commit needed. Recommended shape: single `fix(wenshu): v0.30 — bf86a0b2b CJK cleanup (Scripts/split-help-docs.py comments + print +144 sites)` or similar. Sweep 13+ sites per H-1 fix table. Reference pattern: `230af9a92` for batch1 cleanup + `53c802c42` for batch1 residual. |
| 7. domain-modeling commit | `EntityPreviewPane` → CONTEXT.md | PENDING | `docs(wenshu): v0.30 — domain word add (EntityPreviewPane)` (= docs commit touching only `CONTEXT.md`). Self-flagged in this report as S-1. |
| 8. Q22 真验证 | screenshot + AX tree + 老板 verify | PARTIAL | spec.md line 92-93 "Screenshot verified: ✓". Per Q22 (boss OOB 8/22 真验证 = pixel + AX tree + boss OK): pixel screenshot = present (per spec.md), AX tree capture = MISSING (= Apple Accessibility API tree dump not yet captured), 老板 OK flag = NOT YET (this report still needs 老板 to read + ack). Plus the Spec-axis report's CONDITIONAL on 291487322 (sidebar-category click activation not visually verified at runtime, = step 8 click hit-area smoke test pending). |

## Summary

The 4 v0.30 batch3 commits deliver on the boss OOB scope and follow the established project conventions for `Boss 8/<date> OOB` audit markers, Boss-verbatim-quote carve-outs, UI-string carve-outs, content-data carve-outs (= the .md help-doc content inside `Scripts/split-help-docs.py` `f"""..."""` blocks). All 4 commit bodies + 4 issue files + spec.md = the full Q5.6 chain (post-hoc). The Q124 atomic-coupling rule is satisfied (all 4 commits justify their file scope in body prose). The Q29 1-ticket-1-commit and Q34 step mapping are documented in spec.md line 26-32.

The single hard finding is **H-1**: 13+ sites in `Scripts/split-help-docs.py` carry un-attributed CJK in code-line comments and print() statements (= outside the Boss-verbatim-quote bracket pattern that the prior 015.005/012/018/062 cleanup reports established). All 13+ sites were introduced by bf86a0b2b. Recommended fix is a single `fix(wenshu):` cleanup commit sweeping the 13 sites — see the H-1 fix table for the verbatim English rewrites. Note that the massive CJK content INSIDE the `f"""..."""` triple-quoted blocks (= the actual `.md` file body content being written to disk) is acceptable per the established content-data carve-out precedent (= polish-fixes report S-3).

S-1 (CONTEXT.md domain word add for `EntityPreviewPane`) is a process follow-up, not a standards blocker. S-2 (8 SwiftLint comma warnings at `NewLibraryOutlineView.swift:287-291`) is a pre-existing surface defect carried forward from c5ed76169 batch1 — the 09c6521e2 commit did not introduce these warnings (the `standardFolders` tuple it modified was a different variable that was later refactored by c5ed76169 into the current `standardFolderNames` structure). S-3 (post-hoc Q34 step 1 self-acknowledged) is a documented process gap pending human/boss action.

Verdict: **CONDITIONAL PASS**. H-1 cleanup commit + S-1 domain-modeling commit before v0.30 final ship.
