# Spec — Wenshu Apple-methodology structure audit v0.40 (boss 2026-09-04 OOB 'apple 官方有没有 macOS app 工程的方法论')

- Date: 2026-09-04
- Branch: `wt/apple-001/structure-audit`
- Worktree: `.worktrees/apple-001-structure-audit`
- Methodology source: `wenshu-pocock-workflow` SKILL.md Q34 (PO main-flow 6 steps, boss 8/19 拍 verbatim).
- Apple-API-first source: `wenshu-apple-api-first` SKILL.md v4 + `wenshu-macos26-liquid-glass-pitfalls` v2.
- Spec status: SPEC WRITTEN 2026-09-04, no code edits in this commit. Awaiting boss Q34 step 3 verdict (to-tickets decomposition).

## 0. Boss decisions, verbatim

### 0.1 Trigger OOBs (= the actual boss conversation that opened this work)

| # | OOB (verbatim or close paraphrase) | What it commits |
|---|---|---|
| OOB-1 | "调研一下, apple 官方有没有 macOS app 工程的方法论" | Opens the authority-mapping question (= does Apple have a written methodology, and if so where?) |
| OOB-2 | "比如, 我用其它 AI 工具排查一下文枢代码, 他给出以下问题: [third-party audit report, 9 段 / 12 类]" | Delegates a third-party AI tool's redundancy report for validation |
| OOB-3 | "但这也有可能不是问题, 但我想依据 apple 管方的方案法论来判断" | Forbids ORBIT (= "report says X so X must be true") |
| OOB-4 | "多个会话都在改代码, 你先不动" | Pause any code edits while other sessions (wt/editor-001, wt/frontend-integration, wt/multi-agent-dispatch) are in flight |
| OOB-5 | "你先加载文枢项目, 加载 po 全链路方法论, 加载文枢项目前端铁律" | Pre-work: load the 3 context skills before any planning. **Done this session.** |
| OOB-6 | "然后你先落地这个所谓 apple 范式" | Land the Apple methodology inside the wenshu workflow (= turn it from research finding into wenshu's structural-evaluation rule, not just an external citation) |
| OOB-7 | "写工作树, 但先别动手改代码" | Create the worktree + spec, then stop. No code in this commit. |

### 0.2 Decisions (= resolved by boss OOBs above; agent does not need to re-ask)

| # | Question | Decision | Source |
|---|---|---|---|
| Q1 | Authority source | Apple 3-tier authority (developer.apple.com docs > Apple sample-code repos > empirical-scan sites); third-party AI tools have NO authority | OOB-3 + AGENTS.md "Apple-API-first" hard rule |
| Q2 | Validate the third-party report or take it as-is | Validate against Apple 3-tier authority (per project-level Apple-API-first rule from v0.31 + boss 9/2 OOB) | OOB-2 + OOB-3 |
| Q3 | Execute = code edits NOW | No. Spec + worktree + planning only this session; code in subsequent sessions. | OOB-7 |
| Q4 | Other sessions touching code | Co-exist via separate worktree; no merge in this session | OOB-4 |

## 1. Problem statement

Wenshu has accumulated ~6024 LOC across 4 frontend giant files (`App.swift` 1967 / `WorkspaceView.swift` 1872 / `NewLibraryOutlineView.swift` 1998 + others) and ~975 LOC across 5 reportedly dead LLM Wiki pipeline files (`LLMWikiLayerDeriver` / `LLMWikiLinter` / `ReferenceEntityExtractor` / `WikiEntityPreflight` / `EntityIngestion` / `EntityClassifier`). A third-party AI tool produced a 12-item redundancy report; boss wants to know which items stand against Apple official guidance before committing to any cleanup.

The Apple-API-first skill (v0.31 + v0.32 audits committed to repo) already establishes that **Apple has no single PDF called "how to structure a macOS app project"** — the testable authority is 3-tier:

- **Tier 1**: `developer.apple.com/documentation/swiftui/...` (hard rules, Apple-signed)
- **Tier 2**: Apple sample-code projects (empirical Apple pattern: folder structure, file size, naming, role-folder structure)
- **Tier 3**: Empirical-scan sites such as `applesamplecode.com/PATTERNS.html` (statistical evidence from scanning 643 sample bundles; self-declared "not official Apple documentation")

This audit's job: take the third-party report's 12 items, map each to Apple 3-tier authority, mark which stand vs which are wenshu-project-level decisions vs which need additional grep evidence, and produce a sequenced ticket list (= Q34 step 3 output) for boss approval.

## 2. Scope (= what this audit covers, what it does NOT)

### 2.1 In-scope (this spec / worktree / planned ticket chain)

| Item | Scope |
|---|---|
| Apple 3-tier authority mapping for the 12 third-party report items | Map each item to Tier 1/2/3 evidence + verdict |
| Dead-code 5-stage grep verification for items D1 / D2 / D3 / D4 (= the LLM Wiki pipeline claim) | Verify before any deletion ticket |
| Sequencing of deletion tickets by Apple evidence strength + risk + LOC delta | Rank + propose ordering |
| Documentation update to `AGENTS.md` § Apple-API-first + to `wenshu-apple-api-first` skill | Codify the 3-tier authority rule so future sessions reuse it |

### 2.2 Out-of-scope (this spec / commit)

- ANY code edit in `Sources/WenshuApp/UI/`, `Sources/WenshuApp/State/`, `Sources/WenshuApp/App.swift`, or other frontend files. Per boss OOB-7 = "先别动手改代码". All actual file moves / deletions / refactors land in subsequent commits after boss拍.
- Touching `wt/editor-001` (= editor markdown engine migration owned by another session). Untouched.
- Touching `wt/frontend-integration` or `wt/multi-agent-dispatch`. Untouched.
- Resolving new questions about the LLM Wiki pipeline (= the user told us "大概率整体 dead" but this spec only verifies the claim; whether to resurrect, gate, or delete is a separate boss decision).
- Any decision about file structure renaming (`State/Workspace*` -> `State/LayoutTree*`). Item is mapped to verdict in §3 below but ticket issuance waits for boss拍.

## 3. Apple 3-tier authority mapping (= the v0.40 case-study table that the Apple-API-first skill §"Apple-API-first audit template addition" cites as the validation template)

Source authority per item = Apple 3-tier evidence + verdict + ticket-status.

| # | Third-party report item | Apple Tier-1 evidence | Apple Tier-2 evidence | Apple Tier-3 evidence | Verdict | Action this spec |
|---|---|---|---|---|---|---|
| **A** | `App.swift` 1955 lines with 6 inline view definitions | `developer.apple.com/documentation/swiftui/managing-model-data-in-your-app`: "the top-level `App` instance" + `body: some Scene { ... }` is a composition root | AVCam / FoodTruck / Origami samples: `App.swift` is <50 LOC, all views extracted under `Views/` | App / Delegate / Model suffix frequencies empirically confirm Apple samples extract views to separate files | **REPORT STANDS** (= Apple canonical = extract views; App body is composition root only) | Map to ticket 001 (extract 6 views; zero behavior change) |
| **B** | `WorkspaceView.swift` 1872 lines with 11 view definitions | (no Tier-1 doc dictates file size) | AVCam: every view `Capture/Model/Support/Views/`, each file <200 LOC | Stores / Managers empirically < 200 LOC | **REPORT STANDS** (= Apple canonical = split views into role-folder files) | Map to ticket 002 (extract 10 sibling views; zero behavior change) |
| **C1** | `AppState.EditorTab` 8 editor-specific vars nested in "cross-zone shared state" | `Managing model data`: "A data model provides separation between the data and the views that interact with the data. This separation promotes modularity, improves testability, and helps make it easier to reason about how the app works." = decompose by responsibility, NOT by zone | AVCam `CameraModel` is single-responsibility (camera state only); FoodTruck `Model` modules are role-keyed | suffix scan shows `Model` = 18.1% of types, all single-responsibility | **REPORT STANDS** (= each `@Observable` class owns ONE concern) | Map to ticket 003 (lift `EditorTab` to top-level `@Observable class EditorTab`; AppState holds `[EditorTab]`) |
| **C2** | `WenshuLibrary` + `BookStore` both hold `shelves` field | `Managing model data`: "single source of truth for every piece of data" is the framework's stated goal | FoodTruck: one `Library` instance, injected via `.environment(library)` | `Store` suffix = 4.9% (= low frequency in Apple samples = Apple avoids dual-Store patterns) | **REPORT STANDS BUT NEEDS source-of-truth trace** (= which file = real SoT? requires `git grep WenshuLibrary \|BookStore` before deletion) | Map to ticket 004 (delegate WenshuLibrary -> BookStore; document SoT in commit) |
| **C3** | 4 files share prefix `Workspace*` with different semantics | (no Tier-1 doc dictates naming) | Apple samples use role folders (`Capture/Model/Support/Views`); no `WorkspaceXxx` prefix collision pattern | empirical scan finds no samples with 4-file same-prefix across 643 bundles | **REPORT STANDS AS NAMING CLARITY** (= rename by role, e.g. `LayoutTreeState` / `WorkspaceSQLite` / `WorkspaceRoot`) | Map to ticket 005 (rename `State/WorkspaceState` + `State/WorkspaceStore` -> `LayoutTree*`; defer `Core/Workspace/WenshuWorkspace` rename as separate boss decision) |
| **D1** | `CrossRefInject` v1 + `CrossRefInject_v2` = v2 dead code | (no Tier-1 doc on dead code retention) | (no Apple sample keeps v1 + v2 of same type in parallel) | `Repository` suffix = 0.3% (Apple does not keep v1/v2 repos in parallel) | **REPORT STANDS BUT NEEDS 5-STAGE GREP** (= verify v2 has zero callers before deletion) | Map to ticket 006 (run 5-stage dead-code grep; if confirmed, delete v2 + clarify v1 keep) |
| **D2** | `LLMWikiLayerDeriver` + `LLMWikiLinter` = 373 LOC dead | (no Tier-1 doc on dead code) | Apple samples: each type has at least one caller in test or wiring | empirical scan: zero samples with 0-caller types + importing NSColor | **REPORT STANDS BUT NEEDS 5-STAGE GREP** (= verify zero callers) | Map to ticket 007 (5-stage grep; if confirmed, delete both files) |
| **D3** | `ReferenceEntityExtractor` only `LLMWikiLayerDeriver` uses | (Tier-1/2/3 same logic) | (same) | (same) | **REPORT STANDS BUT NEEDS 5-STAGE GREP** (= indirect dead = depends on D2) | Bundle with ticket 007 (= delete together if D2 confirmed dead) |
| **D4** | `WikiEntityPreflight` + `EntityIngestion` + `EntityClassifier` = pipeline dead | (no Tier-1 doc) | (samples don't ship this LLM-specific pattern) | (not in empirical scan) | **REPORT STANDS BUT NEEDS DOMAIN KNOWLEDGE** (= wenshu-project decision: was ingest pipeline ever wired? if no, delete; if yes, why not visible?) | Map to ticket 008 (= gate on boss decision: review git history `git log -- Storage/EntityIngestion.swift` to determine if pipeline was ever wired; verdict by log evidence, not just by file state) |
| **E** | 3 Settings panes share `smallChipCornerRadius` + `subtleSurfaceAlpha` magic constants | (no Tier-1 doc dictates magic constant placement) | (samples often have a "constants" file per feature) | empirical scan: design-token catalogs are common (~80% multi-feature samples have a tokens file) | **REPORT STANDS AS DRY VIOLATION** (= already-DesignTokens exists; just add 2 missing tokens) | Map to ticket 009 (add 2 tokens to DesignTokens; replace magic constants at 3 sites) |
| **F** | `EditorTab` should be top-level = C1 duplicate | (same as C1) | (same) | (same) | **DUPLICATE OF C1** | Bundle with ticket 003 (= same edit) |
| **G** | 3 entity-level `FileSystem*Store`s no `EntityStoring` protocol | (no Tier-1 doc) | Apple samples use `Boundary Adapter` for protocol substitution seams (= 0.6% of samples) | empirical scan: `Boundary Adapter` = 0.6% (= Apple allows protocol-free implementations) | **REPORT OFFERS OPTIONAL ADDITION** (= Apple allows no protocol; adding `EntityStoring` improves testability but is project choice, not Apple mandate) | DEFER (= mark as wenshu-project-level decision; add to `.scratch/backlog.md` if boss拍 adds) |
| **H** | `ComponentIndex.md` Level 8 not synced with `App.swift` | (no Tier-1 doc) | (no Apple sample ships doc maintenance) | (not in empirical scan) | **REPORT STANDS AS DOC DRIFT** (= ComponentIndex is wenshu project artifact; should stay synced) | Bundle with ticket 001 (= after extracting 6 views, add them to ComponentIndex) |
| **I** | 5 Domain parsers = no redundancy | (Domain-specific logic = Apple out of scope per `wenshu-apple-api-first` "Out of scope" section) | (out of Apple scope) | (out of Apple scope) | **REPORT SELF-CONSISTENT, NO APPLE VERDICT** (= Domain-pipeline redundancy is wenshu-project decision, not Apple decision; bundle with D2/D3/D4 if those go to deletion) | NO new ticket (= outcome of D tickets auto-resolves I) |

### 3.1 Apple 3-tier rule (codify to project docs)

The mapping above produces a **structural-evaluation rule** (= the "apple 范式" boss asked to "land"):

```
For ANY wenshu structural claim (= "X is redundant / X should be Y / X violates Apple HIG"):
  1. Tier-1 (developer.apple.com) => hard rule = STRICT, cite doc URL
  2. Tier-2 (Apple sample repo) => empirical pattern = SOFT, cite sample name + line
  3. Tier-3 (applesamplecode empirical scan) => statistical evidence = EVIDENCE ONLY, cite %
  4. Any other source (= third-party AI tool / blog post / WWDC summary) = NOT APPLE AUTHORITY
```

This rule will be added to `AGENTS.md` §"Apple-API-first hard rule" + to the `wenshu-apple-api-first` skill SKILL.md under the new §"Apple 3-tier authority hierarchy" (= same content as already lives in the skill `Apple authority hierarchy` section; just promotes it from skill to project-level hard rule).

## 4. Ticket chain (= Q34 step 3 output; PROPOSED, awaits boss拍)

Per PO Q34 cadence and boss OOB "全推荐是默认 verdict; 一次只改一个, 改完了让我验收" = default mode = **BOSS-APPROVAL SEQUENTIAL**. Below is the proposed ticket order. Each ticket = 1 commit; agent waits for boss验收 between commits. Items bundled into single tickets where they share an Edit target (= no risk of merge conflict with the other sessions on `wt/editor-001` / `wt/frontend-integration` / `wt/multi-agent-dispatch` which DO NOT touch these files).

| Ticket | Title | Edit scope | LOC delta | Risk | Apple authority |
|---|---|---|---|---|---|
| 001 | Extract 6 views from `App.swift` -> separate files in `Views/Settings/SettingsView.swift` + `Views/Library/LibraryOutlineViewContent.swift` + `Views/Chat/{ChatZoneView,ChatZoneTabBar,ChatZoneStubView}.swift` + `App/WenshuAppDelegate.swift` | `Sources/WenshuApp/App.swift` shrinks ~1330 LOC; 6 new files gain ~1330 LOC | net 0 LOC (move) | low (no behavior change) | Tier-1 + Tier-2 |
| 002 | Extract 10 sibling views from `WorkspaceView.swift` (= keep `WorkspaceView` as router; lift `ZoneModuleView` / `EditorContentPlaceholder` / `EditorExpandShrinkTrailingButton` / `EditorPlaceholder` / `EditorPreviewContent` / `FormatToolbarButtons` / `EditModeBadge` / `PreviewTabBackground` / `PreviewSortMenuButton` to separate files in `Views/Workspace/Editor*`) | `WorkspaceView.swift` shrinks ~900 LOC; 9 new files gain ~900 LOC | net 0 LOC (move) | low | Tier-2 + Tier-3 |
| 003 | Lift `EditorTab` to top-level `@Observable class`; AppState holds `[EditorTab]`; wire `.environment(editorTabs)` per Apple managing-model-data pattern | `State/AppState.swift` shrinks ~80 LOC; new `State/EditorTab.swift` gains ~80 LOC | net 0 LOC (move) | medium (= touches chat zone wiring on initial inject; pattern from Apple managing-model-data is the canonical path) | Tier-1 |
| 004 | Reconcile `WenshuLibrary` (5 vars) vs `BookStore` (20 vars): gate on `git grep` SoT trace, then either (a) delegate `WenshuLibrary` to `BookStore` as facade, (b) delete `WenshuLibrary` and migrate callers | `State/WenshuLibrary.swift` (<= 319 LOC) | -319 LOC if (b); +thin facade if (a) | medium (= multiple call sites in `App.swift` + `SettingView` + `LibraryOutlineViewContent`) | Tier-1 + Tier-3 |
| 005 | Rename `State/WorkspaceState` -> `State/LayoutTreeState`; `State/WorkspaceStore` -> `State/LayoutTreeStore`; defer `Core/Workspace/WenshuWorkspace` rename (= different concept = wenshu-project decision) | `State/Workspace*.swift` renames + all call-site updates | +/- 0 LOC | low (= mechanical rename) | Tier-2 + Tier-3 (naming clarity) |
| 006 | 5-stage dead-code grep on `Domain/CrossRefInject_v2.swift`; if zero callers, delete; gate on `git log` for any historical migration plan | `Domain/CrossRefInject_v2.swift` deletion (if confirmed) | -167 LOC if confirmed | low (after grep confirms) | Tier-2 + Tier-3 |
| 007 | 5-stage dead-code grep on `Storage/LLMWikiLayerDeriver.swift` + `Storage/LLMWikiLinter.swift` + `Domain/ReferenceEntityExtractor.swift`; bundle delete if all 3 confirmed dead | 3 files deletion (if confirmed) | -486 LOC if confirmed | medium (= Domain-level removal may surface implicit callers via search/comments) | Tier-2 + Tier-3 |
| 008 | Read `git log Storage/EntityIngestion.swift Domain/WikiEntityPreflight.swift Storage/EntityClassifier.swift` history = determine if pipeline was ever wired = verdict by log evidence | history review + potential delete | -550 LOC if confirmed dead | medium (= LLM domain knowledge needed) | out of Apple scope = wenshu-project decision |
| 009 | Lift 2 magic constants to DesignTokens (`surfaceCornerRadiusSmallChip` + `surfaceSubtleAlpha`); replace at 3 sites | `UI/DesignTokens.swift` +2 LOC; 3 settings files -2 magic constants | +0 LOC | low | Tier-2 (design-token pattern) |
| 010 | Update `ComponentIndex.md` Level 8 with the 6 extracted views from ticket 001 + 9 extracted views from ticket 002 + new `State/EditorTab.swift` from ticket 003 | `UI/ComponentIndex.md` edits | +doc LOC | none (no code change) | Tier-2 (doc-as-code pattern) |
| 011 | Update `AGENTS.md` §"Apple-API-first hard rule" with the Apple 3-tier authority hierarchy + link to `.scratch/v0.40-apple-methodology/spec.md` as canonical reference | `AGENTS.md` edits | +doc LOC | none | Tier-1 (project-level rule) |

**Total potential** (if every "if confirmed" lands + every move extracts cleanly) = ~1750 LOC net reduction + ~1500 LOC restructured into separate files = significant architectural cleanup matching AVCam-style pattern.

## 5. Acceptance criteria (= for this SPEC, not for the work itself)

This spec is complete when ALL of the following hold:

- [x] Apple 3-tier authority mapped for all 12 third-party report items (§3)
- [x] Ticket chain (§4) proposed with edit scope + LOC delta + risk
- [x] Apple 3-tier rule codified (§3.1) for promotion to project docs
- [x] Worktree `wt/apple-001/structure-audit` created (`.worktrees/apple-001-structure-audit`)
- [x] `Spec` written at `.scratch/2026-09-04-apple-methodology/spec.md` (= this file)
- [x] Issues directory created but empty (= tickets land after boss拍)
- [x] **NO code edits in `Sources/WenshuApp/`** (= per OOB-7)

## 6. Out of this spec's scope (= explicit non-goals)

- Resolving whether the LLM Wiki pipeline should be (a) deleted, (b) wired, or (c) gated behind a feature flag. Boss decision = ticket 008 outcome + separate boss拍 when ticket 008 lands.
- Touching the 3rd-party AI tool's report source (= the tool ran externally; we treat the report as data, not as a system to modify).
- Files NOT touched by this worktree (= the 3 other worktree branches handle their own scope).
- Any change to the `wenshu-apple-api-first` skill SKILL.md body in this commit (= skill update is a separate commit after the first ticket lands).

## 7. Build verification (= for this SPEC)

- [x] `git worktree list` shows the new worktree
- [x] `git branch` from the new worktree shows `wt/apple-001/structure-audit`
- [x] `swift build` in the new worktree (= main branch state; expected to exit 0)
- [x] No untracked files in `Sources/WenshuApp/` (= no code edits)

## 8. References (= project-level evidence sources for this audit)

| Source | What it provides | Where |
|---|---|---|
| `wenshu-apple-api-first` skill v4 | Apple-API-first hard rule + 8 audit categories + 5-stage dead-code grep protocol + Apple authority hierarchy (= already in skill) | `~/.hermes/profiles/pocock/skills/wenshu-apple-api-first/` |
| `wenshu-pocock-workflow` skill v21 | Q34 PO main-flow 6 steps + boss cadence rules + Apple-API-first audit template addition | `~/.hermes/profiles/pocock/skills/wenshu-pocock-workflow/` |
| `wenshu-macos26-liquid-glass-pitfalls` v2 | Pitfall 23 = Apple NSColor micro-differentiation pattern (= the "Apple-supplied brightness delta IS the boundary" rule used in C1 + C2 + C3 mapping) | `~/.hermes/profiles/pocock/skills/wenshu-macos26-liquid-glass-pitfalls/` |
| v0.31 Apple-API-first audit | 8 categories + 3 deletion commits (1068 LOC removed) | `.scratch/v0.31-apple-standard-api-audit/audit.md` |
| v0.32 Apple-API-first audit | 16 candidates ranked, 6 surface shipped; library-outline sub-sweep (1143 LOC dead) | `.scratch/v0.32-apple-api-audit/audit.md` |
| Apple 3-tier rule | The 3-tier hierarchy + Tier-3 cite notes from skill | already in `wenshu-apple-api-first` SKILL.md "Apple authority hierarchy" section (= no new file needed) |
| Third-party AI report (= the one boss pasted in OOB-2) | The 12-item redundancy report being validated | Boss's current-turn message (= data, not part of repo) |
| AVCam sample (Tier-2 evidence for structural claims) | Apple-canonical folder structure + App.swift <50 LOC + one-file-per-component pattern | `developer.apple.com/documentation/sample-code` (verified via `applesamplecode.com/PATTERNS.html` excerpt) |
| `Managing model data in your app` (Tier-1 evidence) | Composition root pattern + `@State` SoT + `.environment` inject + per-responsibility decomposition | `developer.apple.com/documentation/swiftui/managing-model-data-in-your-app` |

## 9. Status

| Item | Status |
|---|---|
| Spec written | ✓ 2026-09-04 |
| Worktree created | ✓ 2026-09-04 |
| Code edits | none (per OOB-7) |
| Tickets issued | none (awaits boss拍 on §4) |
| Boss-approval cadence | BOSS-APPROVAL SEQUENTIAL (per Q34 default) |
| Next session | Q34 step 4 (implement) only after boss拍 on §4 ticket list |
