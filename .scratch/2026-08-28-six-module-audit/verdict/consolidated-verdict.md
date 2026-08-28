# Wenshu six-module capability-gap audit + library adopt-list — consolidated verdict

**Date:** 2026-08-28 · **Branch:** `wt/multi-agent-dispatch`
**Trigger:** Boss 2026-08-28 OOB "用你昨天拷问后的结论去找, 还有 swift 库, UI 库, 工程管理库, 都算" + revised "agent 相关的, 不用调研, 就直接本地拿 hermes 源码复刻"

## Destination

Find every third-party library (= Swift framework / UI enhancement / engineering management tool) that closes a real capability gap in wenshu's six modules. Each recommendation must pass AGENTS.md §11.1 four-condition gate (stars≥100, last commit ≤12mo, MIT/Apache/BSD/PD, macOS-first OR macOS-supported) + avoid the ADR-0008 view-framework FORBIDDEN carve-out (no pane / dock / split / drag libs). Agent-side capabilities (M5 entity extraction + smart-query + cross-ref + LLM Wiki pipeline; M6 Provider/Agent/Memory/Skills/Cron/Backup) ship via verbatim port from local hermes-agent source, NOT via third-party survey.

## Six modules (boss-defined on 2026-08-27)

| # | Module | Coverage today | Adopt-list from survey | Port from hermes |
|---|---|---|---|---|
| M1 | Workspace Shell | LayoutShellView + WorkspaceView + WorkspaceState/Store + NativeSplitter (self-implemented per ADR-0008) | `pointfreeco/swift-snapshot-testing` 1.19.4 (NEW, P2 testTarget) | none |
| M2 | Book Reader & Editor | swift-markdown parser + Textual preview | `smittytone/HighlighterSwift` 3.1.0 (NEW, P1 UI enhancement) | none |
| M3 | Project / Manuscript Manager | FileSystem*Store + BookStore + Kanban + Todo + Search + Templates + Bases + QuickSwitcher + Bookmarks | `witekbobrowski/EPUBKit` 0.5.0 (NEW, P1 Swift framework) | none |
| M4 | Foreshadowing & Plot Web | Core/Graph + Core/LinkGraph + Core/Canvas | `davecom/SwiftGraph` 4.0.0 (NEW, P1 Swift framework) | none |
| M5 | Character & World Codex | Domain/{Character,World,EntityIngestion,SmartQuery*,CrossRefInject} + FileSystem{Character,World,Reference}Store | none (boss OOB: hermes 源码复刻 only) | 4 verbatim port plans (~1,500 LOC): entity extraction + smart-query + cross-ref + LLM Wiki 4-layer pipeline |
| M6 | Settings & Library | Settings tabs + Provider/Agent/Memory/Skill/Cron/Backup + Library lifecycle | `KeyboardShortcuts` (bump 1.10.0 → 2.2.0) + `apple/swift-log` 1.5.4 + `orchetect/MenuBarExtraAccess` (NEW, P1-P3 mixed) | ~5,000-6,300 LOC across ~25-30 new files (Provider / Agent identity / MemoryManager REPLACES existing / Skills hub / Cron scheduler / Backup ZIP engine) |

## Three-dimension cross-cut (per AGENTS.md §11.1)

### Swift 框架 (parser / DB / network / runtime / storage)

| Library | Pin | Module(s) | Trigger |
|---|---|---|---|
| `witekbobrowski/EPUBKit` | 0.5.0 | M3 Project Manager | EPUB import ticket |
| `davecom/SwiftGraph` | 4.0.0 | M4 Foreshadowing & Plot Web | graph algorithms ticket (BFS/DFS/Dijkstra/Prim) |
| `li3zhen1/Grape::ForceSimulation` *(CONDITIONAL)* | 1.1.0 | M4 Foreshadowing & Plot Web | force-directed layout ticket (BOSS re-check on WARN = 15mo stale) |
| `apple/swift-log` | 1.5.4 | M6 Settings & Library | observability ticket |

### UI 增强 (SwiftUI leaf primitives, NO pane / dock / split / drag)

| Library | Pin | Module(s) | Trigger |
|---|---|---|---|
| `smittytone/HighlighterSwift` | 3.1.0 | M2 Book Reader & Editor | code-fence syntax highlight in Textual preview + chat fence replies |

### 工程管理 (dev / test / CI / lint / hot-reload / observability)

| Library | Pin | Module(s) | Trigger |
|---|---|---|---|
| `pointfreeco/swift-snapshot-testing` | 1.19.4 | M1 Workspace Shell | ticket 028-011 (drag-lost regression suite) |
| `orchetect/MenuBarExtraAccess` | 1.3.0 | M6 Settings & Library | menu bar extra show/hide toggle when v0.28+ menu shape lands |

## Already-adopted library version bumps (no new dep, just pin update)

| Library | Old pin | New pin | Reason |
|---|---|---|---|
| `sindresorhus/Defaults` | 8.2.0 | **9.0.8** (Mar 26 2026) | §11.1 1.5-yr gap; bump when v0.28 chat history migration lands |
| `realm/SwiftLint` | n/a | **0.62.1** (Oct 13 2025) | approved in §11.1; version pin in Brewfile |
| `nicklockwood/SwiftFormat` | n/a | **0.62.1** (Jul 7 2026) | approved in §11.1; version pin in Brewfile |
| `sindresorhus/KeyboardShortcuts` | 1.10.0 | **2.2.0** | §11.1 P1 stale; bump when v0.28 Settings pane lands |

## Total adopt-list delta (this audit)

| Count | Library |
|---|---|
| **6 NEW deps** | `witekbobrowski/EPUBKit`, `davecom/SwiftGraph`, `(CONDITIONAL) li3zhen1/Grape::ForceSimulation`, `apple/swift-log`, `smittytone/HighlighterSwift`, `pointfreeco/swift-snapshot-testing`, `orchetect/MenuBarExtraAccess` (7 if Grape approved, 6 if rejected) |
| **4 version bumps** | Defaults, SwiftLint, SwiftFormat, KeyboardShortcuts |
| **0 Package.swift changes for M5/M6 agent-side** | all agent capabilities land via verbatim port from hermes (~6,500-7,800 LOC Swift across ~30 new files + 7 file extensions) |

## ADR-0008 view-framework FORBIDDEN carve-out — applied per candidate

Every candidate library was checked against ADR-0008 §"Applies to" (= any library claiming pane / dock / split / drag / Tab-bar / MiniMap / Toolbar / custom Layout protocol ownership). All 6 NEW candidates are leaf-level (parser / DB / algorithm / image / log / UI primitive / test). ZERO recommendations require the carve-out.

The most-at-risk library was `bonsplit` (rejected — pane + tab bar + drag-lost cmux #2289 evidence per ADR-0008 path C self-implement) and `exyte/Grid` (rejected — grid container = SwiftUI view extension targeting view architecture, even though library itself isn't pane/split/dock).

## Risks (open questions for boss)

1. **`witekbobrowski/EPUBKit` bus factor = 1** — sole maintainer, 5 months since last release. Mitigation: thin adapter protocol `EPUBImportService` so a future swap to Readium or self-implemented parser (ZIPFoundation + AEXML) is a 1-file change.
2. **`li3zhen1/Grape::ForceSimulation` 15-month stale** — fails gate #2 by 3 months. Mitigation: WARN, conditional on boss re-check. Alternative = hand-rolled `GraphBuilder.layout(...)` 130-LOC spring-force ships today.
3. **`smittytone/HighlighterSwift` stars = 105** — exactly at the 100★ gate floor. Margin = 5★. Mitigation: if `swift-markdown-engine` adoption happens first (it transitively pulls HighlighterSwift), we get the maintenance signal for free.
4. **M5/M6 hermes 复刻 scope** — ~6,500-7,800 LOC across ~30 new files is a substantial v0.28+ effort. Recommend splitting into 4-5 v0.28 tickets (entity extraction / smart query / cross-ref / LLM Wiki pipeline; Provider / Agent identity / Memory / Skills / Cron / Backup) rather than one mega-commit.
5. **Hermes surface drops** (per boss "数据不出本机" + "用户不可通过聊天改系统" + "single-user / local-only" rules): ~10,500 LOC of hermes Python dropped for cloud memory providers, OAuth, external credential backends, plugin system, cron LLM tool, OTLP, cross-process file locking. These drops are intentional per boss OOB, NOT technical gaps.

## Cross-module bridges (= de-dupe)

- `kean/Nuke` 13.2.0 — already adopted, used by M1 (Workspace drag preview), M2 (book cover in chat), M3 (bookshelf cards), M5 (portrait in codex). Single dep with multi-module consumers → no new Package.swift row.
- `groue/GRDB.swift` 7.11.1 — currently zero consumers in source despite Package.swift row. Once M3 migrates `FullTextSearch.swift` to GRDB, this dep becomes load-bearing for M3 (search) and unlocks future M6 (chat.sqlite, backup diff) + M2 (chapter revisions). Single dep with future-multiple-consumer.

## Method / data caveats

- **Network rate-limited from sandbox** — direct SPI / GitHub pages returned `Blocked: URL targets a private or internal network address.` All sub-agents used `git ls-remote --tags` + `web_search` snippet extraction for star / license / last-commit metadata. UNVERIFIED numbers flagged inline.
- **All 6 sub-agents READ-ONLY** on `Package.swift` / `AGENTS.md` / `CONTEXT.md` / `Sources/`. Zero edits per spec.
- **All writes confined to `.scratch/2026-08-28-six-module-audit/modules/`** — no tracked file changes from this audit.

## Files

- `spec.md` — destination + method + acceptance criteria
- `modules/inventory.json` — six-module existing / needs_survey inventory
- `modules/M1-workspace-shell.md` — 30.6 KB · 20 candidates · PASS=6 WARN=2 FAIL=12
- `modules/M2-book-reader-editor.md` — 26 KB · 18 candidates
- `modules/M3-project-manager.md` — 12 KB · 5 gaps evaluated
- `modules/M4-foreshadowing-plot-web.md` — 215 lines · 9 candidates
- `modules/M5-character-world-codex.md` — 31 KB · hermes verbatim-port plan (4 capabilities)
- `modules/M6-settings-library.md` — 65 KB · hermes verbatim-port plan (7 capabilities) + non-agent survey (6 surfaces)

## Acceptance criteria

- [x] All 6 modules covered by per-module reports
- [x] AGENTS.md §11.1 four-condition gate applied per library
- [x] ADR-0008 view-framework FORBIDDEN carve-out applied (zero candidates qualify)
- [x] Cross-cut identifies bridges (`Nuke` 4-module consumer, `GRDB` future-multiple-consumer)
- [x] Final adopt-list is commit-ready (name + version pin + module + dimension + trigger condition)

## Out of scope (deferred to feature work)

- Per-feature wiring of each recommended library (= lands with the ticket that consumes it)
- ADR-0008 §"Does NOT apply to" listed libraries (already approved in earlier audit waves)
- Bonsplit (rejected 2026-08-27 per ADR-0008 path C; v0.28 self-implements WorkspaceView)
- v0.28 free-layout ticket 028-001+ series (separate spec at `.scratch/2026-08-28-v0-28-free-layout/`)