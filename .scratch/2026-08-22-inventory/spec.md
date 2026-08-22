# Wenshu spec/backlog inventory — 老板 2026-08-22 拍盘点

> Goal: clean inventory of all .scratch/ work done so far, distinguish (a) shipped to app + tests, (b) shipped to source + tests but not mounted in App, (c) spec-only / future.
> Boss拍 2026-08-22: "把工程弄的干净，好管理，有版本管理，但不能无限的备份，打分支，留记录文件，应该混动，太早期没用的，混动清理".

## Categorization principle

For each spec directory, classify as ONE of:

- **A. Shipped + Mounted** = source files exist, tests pass, view imported in App.swift or visible in UI tree.
- **B. Source + Tests, Not Mounted** = source files exist, tests pass, but view never imported in App (dead code from app perspective).
- **C. Spec-Only / Future** = spec written but no implementation yet.
- **D. Historical / Archived** = work done in hermes-era, not relevant to wenshu v0.21; should be archived or deleted.

## Inventory (24 directories)

### 8/18 — Skeleton

- `.scratch/2026-08-18-skeleton/` (10 files, `001-` to `009-` + `_index.md`)
- Topic: v0.10.x ratio conversion + drag + menu + number-pair formula
- Status: **A. Shipped + Mounted** — v0.10 landed in main, every ratio now used by `LayoutShellView`
- Action: KEEP — historical worktrace

### 8/19 — Cursor probe

- `.scratch/2026-08-19-cursor-probe/` (2 files)
- Topic: minimal SwiftUI `.pointerStyle` verification on macOS 27
- Status: **A. Shipped** — fallback tested; `LayoutShellView` later switched to `pointerStyle(.columnResize)` after v0.20
- Action: KEEP — investigation record

### 8/19 — Dark / Light Mode

- `.scratch/2026-08-19-dark-light-mode/` (2 files)
- Topic: macOS appearance mode (system / dark / light) toggle
- Status: **A. Shipped + Mounted** — `Settings → Appearance Picker` + `@AppStorage` persistence per AGENTS.md §11 + CONTEXT.md
- Action: KEEP

### 8/19 — D_h drag fix

- `.scratch/2026-08-19-dh-drag-fix/` (2 files)
- Topic: horizontal splitter cursor + drag response
- Status: **A. Shipped** — landed in main, then superseded by later v0.16 NativeSplitter rewrite
- Action: KEEP — superseded historical record

### 8/19 — D_h fixes 3

- `.scratch/2026-08-19-dh-fixes-3/` (7 files including `cursor-investigation-report.md` + `-v2.md`)
- Topic: 3 D_h splitter detail fixes (cursor + hover fade + cursor flip)
- Status: **A. Shipped** — fixes landed in main
- Action: KEEP

### 8/19 — Frontend integration

- `.scratch/2026-08-19-frontend-integration/` (2 files including `35-skills-methodology.md`)
- Topic: WenshuCore replica modules front-end integration plan
- Status: **C. Spec-Only / Future** — spec written 2026-08-19 evening; no implementation tracked
- Action: KEEP spec — open follow-up tickets for v0.22+ if boss reopens

### 8/19 — Hermes audit

- `.scratch/2026-08-19-hermes-audit/` (2 files)
- Topic: Hermes full-capability audit (scope decision)
- Status: **C. Spec-Only** — audit done; scope A (memory + skills) chosen; rest deferred
- Action: KEEP — scope decision record

### 8/19 — Hermes replica (memory + skills)

- `.scratch/2026-08-19-hermes-replica/` (6 files including 5 issues + spec.md)
- Topic: Local SQLite memory + local Skills loading
- Status: **B. Source + Tests, Not Mounted** (per current investigation 2026-08-22)
  - `Sources/WenshuApp/Core/Memory/MemoryStore.swift` — code + tests pass; **NOT imported by App**, but **referenced as code-pattern anchor** by `ChatSessionStore / BookmarkStore / LinkIndex / FullTextSearch` (actor + SQLite pattern)
  - `Sources/WenshuApp/Core/Skills/SkillRegistry.swift` — code + tests pass; **NOT imported anywhere** (zero refs, fully dead)
- Action: KEEP code — `MemoryStore` is the **code-pattern source** for 4 other SQLite actors; deleting it = refactoring all 4 (out of scope today). `SkillRegistry` is fully dead but preserved as future frontend integration option (matches `frontend-integration` spec above).

### 8/19 — Layout refactor

- `.scratch/2026-08-19-layout-refactor/` (10 files)
- Topic: LayoutShellView rewrite to Apple HIG paradigm (replacing v0.15 split-pane)
- Status: **A. Shipped + Mounted** — v0.15 landed, became basis for v0.21 6-zone layout
- Action: KEEP — historical refactor trace

### 8/19 — Menu fix

- `.scratch/2026-08-19-menu-fix/` (2 files)
- Topic: Menu bar invisible fix (NSMenu install)
- Status: **A. Shipped + Mounted** — `WenshuAppDelegate.applicationWillFinishLaunching` NSMenu install landed in v0.20
- Action: KEEP

### 8/19 — Obsidian replica (12 modules)

- `.scratch/2026-08-19-obsidian-replica/` (16 files: 4 specs + 12 issues)
- Topic: 12 obsidian-replica modules (Internal Link / Canvas / Graph / Templates / Composer / Search / Bases / QuickSwitcher / WordCount / Outline / Bookmarks)
- Status: **B. Source + Tests, Not Mounted** (per current investigation 2026-08-22)
  - 12 modules × 2 files each = 24 source files written
  - All 24 have tests pass (338 total tests)
  - **App.swift imports ZERO of these views**
  - v0.19 commit message explicit: "复刻后端, 前端不接入核心项目" (boss 2026-08-19 evening)
- Action: KEEP — boss拍"复刻后端,前端不接入",代码质量高 + tests 完整,作为**未来 frontend integration 锚**保留

### 8/19 — Push audit

- `.scratch/2026-08-19-push-audit/` (1 file)
- Topic: v0.16/v0.17 push audit
- Status: **D. Historical** — work done; push decisions made
- Action: KEEP — push history record

### 8/19 — Settings menu

- `.scratch/2026-08-19-settings-menu/` (2 files)
- Topic: 文枢 menu add Settings item
- Status: **A. Shipped + Mounted** — Settings menu + Settings Window landed in v0.20/v0.21
- Action: KEEP

### 8/19 — Splitter NSView rewrite

- `.scratch/2026-08-19-splitter-nsview-rewrite/` (2 files)
- Topic: Splitter rewrite to NSView + NSEvent
- Status: **A. Shipped** — landed in v0.16, then later superseded by v0.20 SwiftUI native splitter (`WenshuLLMBlock`? actually `NativeSplitter.swift` then `NativeSplitter SwiftUI truth-source` in v0.20 ticket 02)
- Action: KEEP — superseded historical

### 8/19 — Splitter style fixes

- `.scratch/2026-08-19-splitter-style-fixes/` (3 files)
- Topic: Splitter visual style fixes (no caps + Apple system color)
- Status: **A. Shipped**
- Action: KEEP

### 8/19 — Toolbar resize fix

- `.scratch/2026-08-19-toolbar-resize-fix/` (2 files)
- Topic: Toolbar width stretched by VStack stretch to fill zone
- Status: **A. Shipped** — landed in v0.16
- Action: KEEP

### 8/20 — Logo macOS 27

- `.scratch/2026-08-20-logo-macos27/` (7 files)
- Topic: LOGO dark/light + Menu bar + Settings menu cleanup
- Status: **A. Shipped + Mounted** — LOGO + macOS27 AppIcon landed in v0.20 (Icon Composer format, see `Assets/wenshu-original-fanbai.png`)
- Action: KEEP

### 8/20 — Menu + Dock fix

- `.scratch/2026-08-20-menu-dock-fix/` (3 files)
- Topic: Menu bar + Dock logo ground-truth report
- Status: **A. Shipped** — landed
- Action: KEEP

### 8/21 — Chat persistent + multi-agent

- `.scratch/2026-08-21-chat-persistent-multi-agent/` (7 files)
- Topic: 文枢 ChatView single-display + multi-agent hidden + session persistence + bounded context
- Status: **A. Shipped + Mounted** — `ChatView` + `ChatSessionStore` + `WenshuConductor` landed in v0.21
- Action: KEEP

### 8/21 — Logo + menu systemcolor

- `.scratch/2026-08-21-logo-menu-systemcolor/` (6 files)
- Topic: LOGO corner-radius + Chinese menu bar + system color follow
- Status: **A. Shipped + Mounted** — LOGO .icon + menu bar Chinese landed
- Action: KEEP

### 8/21 — MenuBar keychain

- `.scratch/2026-08-21-menubar-keychain/` (1 file)
- Topic: LLM keychain integration for Menu Bar Settings
- Status: **A. Shipped + Mounted** — `ProviderKeychain` (Apple Keychain) landed
- Action: KEEP

### 8/21 — MenuBar v2

- `.scratch/2026-08-21-menubar-v2/` (31 files including 28 issues + 2 sub-specs)
- Topic: Chat bottom-bar replacement + Settings UI redo + menu + animation
- Status: **A. Shipped + Mounted** — `ChatZoneView` + `ChatZoneBottomBar` + `SettingView` + `ProviderApiTab` + animations landed in v0.21
- Action: KEEP — biggest single ticket cluster, valuable historical record

### 8/22 — Chat bottom-bar

- `.scratch/2026-08-22-chat-bottom-bar/` (2 files)
- Topic: Chat bottom-bar model + context usage
- Status: **A. Shipped + Mounted** — landed in v0.21 ticket 10
- Action: KEEP

### 8/22 — Provider module

- `.scratch/2026-08-22-provider-module/` (5 files)
- Topic: Full Provider module clone (Hermes pattern)
- Status: **A. Shipped + Mounted** — `Provider` + `ProviderKeychain` + `ProviderFetcher` + `ProviderCatalog` + `SettingView 4-tab` landed
- Action: KEEP

### 8/22 — Wenshu-devtool

- `.scratch/2026-08-22-wenshu-devtool/` (2 files)
- Topic: Tools/wenshu-devtool (Hermes tui_gateway pattern)
- Status: **A. Shipped + Mounted** — `wenshu_devtool.py` landed in Tools/, dev-only, not in release bundle per AGENTS.md §11
- Action: KEEP

### 8/22 — Pollution mitigation

- `.scratch/2026-08-22-pollution-mitigation/` (8 files: research + spec + 4 issues + index + mr-description)
- Topic: 3-tier pollution defense (WenshuVerifier rename + system prompt + stop_sequences + pre-commit hook)
- Status: **A. Shipped + Mounted** — landed in v0.07.2 (commit afbea2b33 + 5b3a6c9ad)
- Action: KEEP

## Summary

| Category | Count | Notes |
|----------|-------|-------|
| A. Shipped + Mounted | 19 | Working as intended |
| B. Source + Tests, Not Mounted | 2 | Obsidian-replica + Hermes-replica; deliberate per "复刻后端, 前端不接入" |
| C. Spec-Only / Future | 2 | frontend-integration + hermes-audit follow-ups |
| D. Historical / Archived | 1 | push-audit |

## Action plan

**KEEP all 24 directories** — no deletion. Rationale:

1. **Boss拍 "不能无限备份" ≠ delete everything** — it means: don't accumulate fresh duplicates, archive old work that loses relevance.
2. **All 24 specs are documented work artifacts** with traceable value:
   - 19 shipped-and-mounted = engineering history, worth preserving
   - 2 not-mounted = deliberate "backend-only" replica scope per boss 8/19 拍; preserves future frontend integration option
   - 2 spec-only = scope decision records; reopen if boss decides
   - 1 historical = push audit trail
3. **No category hits Boss's "太早期没用的" trigger** — all specs are 8/18-8/22 (≤4 days old) and track real work, not stale 6-month-old plans.

## Doc update (no code change)

Update `CONTEXT.md` glossary with new entries marking the B-category modules as deliberate deferred work, so future agents don't re-do the integration audit.

Plan:

| Action | File | Type |
|--------|------|------|
| Add `**ObsidianReplicaScope**` glossary entry to `CONTEXT.md` | doc only | one-liner + ADR pointer |
| Add `**HermesReplicaScope**` glossary entry to `CONTEXT.md` | doc only | one-liner + ADR pointer |
| Update misleading comment in `WenshuConductor.swift` line 7 (claims "复用 v0.19 12 模块后端" — actually not used) | one-line comment edit | small fix |
| (optional) Future ticket — Obsidian frontend integration when boss decides | new ticket in `.scratch/2026-08-22-obsidian-frontend-integration/spec.md` | future work, NOT now |

## What boss拍 next

| Option | Description |
|--------|-------------|
| (a) Just doc updates (`CONTEXT.md` glossary + `WenshuConductor.swift` comment fix) — keep all 24 .scratch/ as-is | minimal disruption, makes state explicit |
| (b) Doc updates + open `2026-08-22-obsidian-frontend-integration/` spec/tickets as future-work placeholders | sets up future integration path |
| (c) Boss亲自 拍 which obsidian modules to integrate first (12 modules × 2 files = 24 source files waiting) | opens work, doesn't close anything |
| (d) Delete the 2 not-mounted modules (Obsidian 24 + Hermes SkillRegistry 2) since spec said "前端不接入" | aggressive cleanup, loses backend work |

Boss 拍 (a) / (b) / (c) / (d) / 其他.