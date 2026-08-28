# Wenshu v0.28 six-module capability-gap audit + library survey

**Date:** 2026-08-28 · **Branch:** `wt/multi-agent-dispatch`
**Author:** wenshu pocock single-agent · **Trigger:** Boss 2026-08-28 OOB — "用你昨天拷问后的结论去找, 还有 swift 库, UI 库, 工程管理库, 都算"

## Destination

Find every third-party library (= Swift framework / UI enhancement / engineering management tool) that closes a real capability gap in wenshu's six modules. Each recommendation must be evaluated against:

1. AGENTS.md §11.1 four-condition gate: GitHub stars >= 100 / last commit within 12 months / license = MIT-Apache-BSD-public-domain / macOS-first OR macOS-supported
2. ADR-0008 view-framework FORBIDDEN carve-out (= no pane / dock / split / drag libraries — wenshu drag UX remains self-implemented)
3. Per-library risk assessment (= bus factor / upstream drift / breaking-change risk vs wenshu's stable v0.27 / Swift 6.4 baseline)

## Anchor (from boss 拷问 on 2026-08-27)

Wenshu = Apple-stack-exclusive macOS-only long-form fictional-novel AI authoring platform. v1 LLM = minimax cn (Anthropic-compatible protocol). Stack = Swift 6.4 + SwiftUI (Observation) + AppKit + filesystem JSON + Apple HIG (.fcpbundle-style directory, single-process). NO CoreData. NO external AI platform calls in code files. Per-feature wiring of each library is deferred to v0.28+ feature tickets (= bookshelf card thumbnails, chat history migration, Settings pane, .ws export/import, FTS5 migration, chapter preview, .ws streaming, editor preview).

## Six modules (boss-defined on 2026-08-27)

| # | Module | Core view / store path |
|---|---|---|
| M1 | Workspace Shell | `Sources/WenshuApp/App.swift` + `State/Workspace{State,Store}.swift` + `Views/Workspace/` + drag splitters (`NativeSplitter` per ADR-0007) |
| M2 | Book Reader & Editor | `Core/Composer/` + `Core/WordCount/` + `Views/Chat/ChatView.swift` + chapter/draft folders in .ws |
| M3 | Project / Manuscript Manager | `Storage/FileSystem*.swift` + `State/BookStore.swift` + `Core/{Kanban,Todo,Search,Templates,Bases,QuickSwitcher,Bookmarks}/` |
| M4 | Foreshadowing & Plot Web | `Core/Graph/` + `Core/LinkGraph/` + `Core/Canvas/` + `Domain/CrossRefInject.swift` + foreshadowing folder |
| M5 | Character & World Codex | `Domain/{Character,World,EntityIngestion,SmartQuery*,CrossRefInject}.swift` + `Storage/FileSystem{Character,World,Reference}Store.swift` |
| M6 | Settings & Library | `Views/{Settings,Onboarding,Library}/` + `Core/{Provider,Agent,Memory,Skills,Cron,Backup,Tools}/` + `State/WenshuLibrary.swift` |

## Three audit dimensions (boss OOB)

1. **Swift 框架** — language-level / runtime / parser / DB / network libraries that fill capability gaps (= swift-markdown, GRDB, Nuke, ZIPFoundation, EventSource, Defaults, KeyboardShortcuts, KeychainAccess, etc.)
2. **UI 增强** — SwiftUI primitive libraries that ship small leaf views without claiming pane / split / dock (= Textual, Highlightr, MarkdownUI, swiftui-messaging-ui, fuzzy-match pickers, etc.)
3. **工程管理** — dev / test / CI / lint / hot-reload / observability tools that improve the build pipeline (= ViewInspector, Inject, SwiftLint, SwiftFormat, SwiftLintPlugin, os.Logger, etc.)

## Method

Fan out 6 sub-agents in parallel (1 per module). Each sub-agent:

1. Reads this spec + `.scratch/2026-08-28-six-module-audit/modules/inventory.json` (the gap list)
2. For each gap, runs web_search + `git ls-remote --tags` + SPI lookup + (when in budget) `gh api` for the candidate
3. Evaluates against the AGENTS.md §11.1 four-condition gate + ADR-0008 carve-out
4. Writes a per-module report to `.scratch/2026-08-28-six-module-audit/modules/M{N}-*.md`
5. Returns a compact summary: top-N recommendations + 1-line risk note per recommendation

After sub-agent batch completes, this orchestrator:

1. Cross-cuts results against the three dimensions (Swift framework / UI enhancement / engineering management)
2. Writes the consolidated verdict to `.scratch/2026-08-28-six-module-audit/verdict/consolidated-verdict.md`
3. Identifies any library that bridges multiple modules (= de-dupe)
4. Proposes the final adopt-list (= library name + version pin + module + dimension + trigger condition per AGENTS.md §11.1 protocol)
5. Posts 1 final summary back as the response

## Acceptance criteria

- All 6 modules covered by sub-agent reports (= no module gap left)
- Each per-module report carries the AGENTS.md §11.1 evaluation per library (PASS / FAIL / WARN)
- ADR-0008 view-framework FORBIDDEN carve-out applied (= no pane / dock / split / drag library approved)
- Cross-cut report identifies any library that bridges >= 2 modules (= de-dupe recommendation)
- Final adopt-list is commit-ready (= name + version pin + module + dimension + trigger condition)

## Constraints

- Sub-agents are READ-ONLY (= no edits to `Package.swift`, `AGENTS.md`, `CONTEXT.md`, or any source file)
- All writes go into `.scratch/2026-08-28-six-module-audit/` (= scratch directory, not tracked)
- Boss decision required before any adopted library lands in `Package.swift` (per AGENTS.md §11.1 = every third-party SDK requires owner-grill approval before adding)

## Out of scope (deferred to future survey waves)

- Per-feature wiring of each recommended library (= lands with the feature ticket that consumes it)
- ADR-0008 §"Does NOT apply to" listed libraries (already approved)
- v0.28 free-layout ticket 028-001+ series (separate spec at `.scratch/2026-08-28-v0-28-free-layout/`)
- Bonsplit (rejected 2026-08-27 per ADR-0008 path C self-implement)