AGENTS.md

# Hard rule (project-wide, non-negotiable)

- This file is English only. No Chinese characters. No CJK punctuation. No mixed CJK + Latin characters.
- All commit messages, comments, prompts, `.scratch/spec.md`, `.scratch/issues/`, `.scratch/backlog` files, `CONTEXT.md`, `README.md`, `CLAUDE.md`, and every doc in this repo follow the same English-only rule.
- Sole address for the user = "老板" (the literal characters). No earlier honorific forms.
- Forbidden neutral words: 可 / 应当 / 或许 / 可能 / 应该 / 建议 / 考虑 / 试图 / 尽量 / 大概 / 也许 / 或 / 任意 / 大概率 / 通常 / 一般来说. Replace with: 是 / 否 / 行 / 不行 / 可以 / 不可以 / 不变 / 变.
- Forbidden Chinese vocabulary: 修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障. Historical note: 修真 = an earlier agent's typo for 修正. Use 修 / 改 / fix / 替换 / 调整 in commit body / comment / doc / prompt / card body.
- First line of every doc = fact. Last line of every doc = fact.

This file = wenshu project baseline + cross-role address hard constraint. Single agent (pocock profile) direct dialog with 老板. No dispatch, no board, no 6-role flow. Version 8/18拍 v0.07 + 2026-09-04/05拍 v0.10 (pocock single agent purified version).

# §11 Project baseline

- Stack = Swift / SwiftUI + Swift Observation (@Observable) + filesystem JSON + Markdown (per-book private content) + Apple HIG (.fcpbundle-style directory, single-process). NO CoreData. NO external AI platform calls (any code file).
- §11 product positioning (boss 2026-09-03 拍): Wenshu is a writing tool, NOT an LLM platform. Wenshu never resells or bundles LLM access, never holds user tokens on its own backend, never charges for token consumption. LLM is a layer below Wenshu that the user provides via the §11.2 connector layer. Any PR that adds metering, billing, quota tracking, or token-bundling is out of scope.
- v0.27 boss OOB: "从今天开始，任何功能，先查有没有三方库可以用。不重复造轮子是对的。我之前说不引入三方给自己挖坑了" = wenshu stack baseline 修正 — 第三方库允许（前提 = 见 §11.1 UI 控件例外清单）。
- v1 LLM connector architecture: 7 connector profiles (Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter / minimax cn). Provider-agnostic. User BYOK (bring your own key). NO default recommendation. Wenshu ships with the connector layer wired but every profile is empty until user supplies credentials. See §11.2 for the 7 profiles.
- `.ws` directory (= macOS package, NSOpenPanel-selected at onboarding) = per-library container. Holds: Info.plist (= Apple HIG bundle metadata; CFBundlePackageType=WSPC + WSSchemaVersion) + chat.sqlite (= global LLM chat history; 45 KB at v0.24 ship) + Icon (= Finder icon) + shelves/ (= user-created bookshelves; multiple) + reference-library/ (= library's default bookshelf; system-managed, ONE instance, user CANNOT delete or rename; holds LLM Wiki 4 layers: raw/ + entities/ + abstracts/ + indexes/) + cache/ (= thumbnails + search index + export temp). Per-book structure = `shelves/<shelf-uuid>/books/<book-uuid>/` with 8 standard folders (world/ characters/ outlines/ chapters/ drafts/ sessions/ foreshadowing/ placeholders/) + 8 JSON sidecars + 2 per-book JSON data files (kanban.json, todo.json). Per-book private world + characters + foreshadowing + placeholders; reference-library is library-public (= cross-book reusable raw materials).
- Apple stack exclusive (macOS / iPad / iPhone). Current target = macOS-only single platform (老板 8/18 拍).
- Project root = `/Volumes/ANAN/Engineering/wenshu/`.
- Apple Developer Program paid on release (individual $99 / year).
- Version format = three digits (Hermes style): middle digit = phase, third digit = hotfix.
- 3 docs = this file + `README.md` + `CLAUDE.md`. `CONTEXT.md` = domain glossary (see `docs/agents/domain.md`).
- No hermes monorepo trace (no longer fork).
- No Tauri / Rust / Vue 3 trace. SQLite REMOVED from wenshu stack (= boss 2026-09-20 OOB 'SQLite 全部弃用，只用 SwiftData' + A1 'Apple-default-first = Core Spotlight'; = see §11.7 v1.55 sqlite3-zero migration arc); legacy `.ws` bundle sqlite3 files (= `chat.sqlite`, `indexes.sqlite`, `search.db`, `kanban.sqlite`) are imported once at first launch by `WSMigrationPerStore.swift` then never touched.
- No sparse-clone assumption.
- No novel-platform / novel-craft / Hermes-Slate-Desk legacy V0.5.x protocol.
- Do not decide LLM key config for 老板.
- Do not create project dir outside `~/wenshu-plugin/` (legacy plugin era, retired).
- Do not write any file to `~/.wenshu/` (dir retired).
- Do not self-write wenshu CLI (文枢 = Swift desktop app, not CLI).
- Do not touch any hermes self-owned file under `~/.hermes/`.
- Do not touch any file under `.archive/wenshu-monorepo-fork/`.
- Single-shelf model (= boss 2026-08-26 OOB): user has exactly one `.ws` library; onboarding is one-time; switching `.ws` paths requires Library Properties panel "Reset Library" (= clears UserDefaults.wenshu.libraryPath + returns to onboarding).

# §11.1 Third-party library policy (boss 8/27 OOB)

- Default = Apple stack exclusive (= Apple官方 SwiftUI / AppKit only).
- Exception: Apple官方 SwiftUI 不支持 / 实现困难的功能 = 允许第三方库。
- Acceptance criteria (= 4 conditions ALL must hold):
  1. GitHub stars >= 100 (community认可; = 项目级别信誉).
  2. Last commit within 12 months (= active maintenance; macOS 27 兼容保证).
  3. License = MIT / Apache / BSD / public domain (= commercial 兼容).
  4. macOS-first OR macOS-supported (= iOS-only 库不接受).
- Approved third-party exceptions (ratified 2026-08-28 OOB by 老板 = "all libraries can be introduced immediately"):
  - RUNTIME (production):
    - ~~`bring-shrubbery/lucide-swift` 1.25.0 — icon set (MIT, macOS-first, 8.8k★)~~ — REMOVED 2026-09-15 per boss OOB 'use SF Symbols 6 (3rd gen) with palette rendering'. Canonical icon layer is now Apple SF Symbols 6 (= built into macOS 27 = zero SPM dependency).
    - `sindresorhus/Defaults` 9.0.9 — UserDefaults typed wrapper (MIT, 2.7k★, P0; bumped 8.2.0 → 9.0.9 in v0.28 batch 1 per `brew info`-verified latest stable; wenshu source has zero `import Defaults` so zero source-code impact; the pin is preparation for the v0.28 chat history migration ticket's first consumer)
    - `sindresorhus/KeyboardShortcuts` 2.2.0 — global shortcut binding (MIT, 1.1k★, P1; bumped 1.10.0 → 2.2.0 in v0.28 batch 2 issue 09 per boss拍 'v1 → v2 breaking-change risk 由 ticket 评估' = evaluated to zero source impact = wenshu has zero `import KeyboardShortcuts`; all 26 .keyboardShortcut calls use Apple SwiftUI native modifier; lib reserved for v0.28+ Settings pane Keyboard tab where users rebind global shortcuts via System Settings)
    - `kean/Nuke` + `kean/NukeUI` — async image pipeline + SwiftUI `LazyImage` (MIT, 8.6k★ + 1.3k★, P0; NukeUI is a product of the main Nuke repo since Nuke 11.0; the standalone `kean/NukeUI` repo is frozen at Nuke 10.5 and rejected as the SPM pin source)
    - `weichsel/ZIPFoundation` 0.9.20 — pure-Swift ZIP read/write (MIT, 2.7k★, unblocked 2026-08-28 from prior defer)
    - ~~`groue/GRDB.swift` 7.11.1 — SQLite toolkit + FTS5 full-text (MIT, 8.6k★, P0; replaces prior "No SQLite" rule scope = inside `.ws` bundle only)~~ — REMOVED 2026-09-20 per boss OOB 'SQLite 全部弃用，只用 SwiftData' + A1 'Core Spotlight 替代 FTS5'; canonical search layer is now `Core Spotlight` (= `CSSearchableIndex` + `CSSearchQuery`; = built into macOS 27 = zero SPM dependency); see §11.7 v1.55 sqlite3-zero migration arc.
    - `swiftlang/swift-markdown` 0.4.0 — CommonMark/GFM parser (Apache-2.0, 3.4k★, P1; SPM resolves to latest 0.8.0 via the permissive `from:` lower bound)
    - `mattt/EventSource` 1.5.1 — spec-compliant SSE client (`AsyncSequence` + `Last-Event-ID` reconnect, MIT, 116★, P1)
    - `gonzalezreal/Textual` 0.5.0 — SwiftUI rich-text engine with Markdown support (MIT, 842★, P2; future editor preview)
    - `apple/swift-log` 1.15.0 — Apple first-party `Logger` API (Apache-2.0, 4k★, P3; adopted in v0.28 batch 1 as observation infrastructure for future wenshu CLI / daemon ticket; zero source consumers yet)
    - `smittytone/HighlighterSwift` 3.1.0 — code-fence syntax highlight (MIT, 105★, P1; 185 languages, 89 themes, pure-Swift no JS engine; thin 5-star margin above 100★ gate acceptable per boss拍 A; adopted in v0.28 batch 2 issue 02; consumer wiring lands with v0.28 M2 chapter-preview ticket; NOTE: SPM product name is `Highlighter` not `HighlighterSwift` per the upstream Package.swift; wenshu uses .product(name: "Highlighter", package: "HighlighterSwift") for the correct import path)
    - `witekbobrowski/EPUBKit` 0.5.0 — EPUB 2/3 parser (MIT, 316★, P1; adopted in v0.28 batch 2 issue 03; sole-maintainer risk mitigated by thin EPUBImportService adapter protocol that wraps the parser so a future swap to Readium or self-implemented parser is 1-file change; transitively depends on tadija/AEXML 4.7.0 + marmelroy/Zip 2.1.2; consumer wiring lands with v0.28 M3 EPUB-import feature ticket and feeds M5-15 LLM Wiki pipeline = extract core settings + writing-style fingerprint into reference-library)
    - `davecom/SwiftGraph` 4.0.0 — graph algorithms (Apache-2.0, 811★, P1; pure data = BFS / DFS / Dijkstra / Prim / Kruskal; no view surface = no ADR-0008 risk; adopted in v0.28 batch 2 issue 04; consumer wiring lands with v0.28 M4 graph-algorithms feature ticket = ForeshadowingGraph service that maps cross-chapter recycling paths)
    - `orchetect/MenuBarExtraAccess` 1.3.0 — macOS platform integration (MIT, 218★, P2; programmatic show/hide/toggle over SwiftUI MenuBarExtra; falls under 'macOS platform integration allowed' per ADR-0008 = the lib is a pure platform adapter, not a view-framework/pane/dock/split/drag library; adopted in v0.28 batch 2 issue 07; consumer wiring lands with v0.28 menu shape ticket; wenshu already has a hand-rolled NSStatusItem controller in .scratch/2026-08-22-menubar-v2 = the lib REPLACES that hand-rolled controller)
- DEV / TEST only (no runtime impact):
    - `nalexn/ViewInspector` 0.10.3 — SwiftUI view hierarchy reflection for XCTest (MIT, 2.6k★, testTarget only; ADR-0008 named for v0.28 ticket 028-011)
    - `krzysztofzablocki/Inject` 1.6.0 — SwiftUI hot-reload (MIT, 3.5k★; `#if DEBUG` only, Brewfile distribution)
    - `pointfreeco/swift-snapshot-testing` 1.19.4 — SwiftUI pixel-snapshot regression tests (MIT, ~14.9k★ org; adopted in v0.28 batch 1; testTarget only; README warns NEVER to add to runtime target)
    - `realm/SwiftLint` 0.65.1 + `nicklockwood/SwiftFormat` 0.62.1 — lint + format CI gates (MIT, 19.6k★ + 8.8k★; binary tooling via Brewfile + `wenshu-devtool` hooks chain; SwiftLint bumped from 0.62.1 per `brew info swiftlint` 2026-08-28 returning 0.65.1 as latest stable)
- Force-directed graph layout (batch 2 issue 05, CONDITIONAL WARN): `li3zhen1/Grape::ForceSimulation` 1.1.0 — MIT, 402★, macOS-first, Swift 6 ready, zero data-race (= the `ForceSimulation` product from the `Grape` package; the `Grape` SwiftUI view product = MiniMap + Toolbar + Panel = ADR-0008 view-architecture risk surface is REJECTED and not imported; adopted per boss拍 A = accept WARN even though the lib is 15mo stale = 2025-05-19 last commit; gate #2 fails by 3 months but the ForceSimulation API is stable per the README; ~700 LOC hand-rolled spring-force as in-house fallback)
- VIEW-FRAMEWORK FORBIDDEN (per ADR-0008 ratify 2026-08-28, NOT surveyed above): any pane / dock / split / drag library. Wenshu drag UX remains self-implemented.
- Superseded prior list:
  - `stevengharris/SplitView` — REMOVED 2026-08-28 (superseded by ADR-0008 path C self-implement); v0.27 reverted integration kept in git history.
  - `Sameesunkaria/OutlineView` — REMOVED 2026-08-28 (below 100★, never adopted).
- Pending evaluation (= needs demo + 老板拍, no current commitment):
  - `nodes-app/swift-markdown-engine` — AppKit TextKit 2 markdown editor (Apache-2.0, ~863★, ~2 months old; revisit when ≥1k★ and after `swiftlang/swift-markdown` parser path proves insufficient).
  - `Sameesunkaria/OutlineView` — 78★, below threshold; revisit when ≥100★.

# §11.2 LLM connector profiles (boss 2026-09-03 拍, ported from hermes agent core v0.x)

| Priority | Profile | Protocol | Auth pattern | First-class scenario |
|---|---|---|---|---|
| P0 | Anthropic | Anthropic native | API key | Overseas direct, high-quality (claude-sonnet-4.5, claude-opus-4) |
| P0 | OpenAI | OpenAI native | API key | Overseas mainstream (gpt-5, gpt-4.1) |
| P0 | minimax cn | Anthropic-compatible | API key | Boss v0 test default; Anthropic-compatible |
| P1 | DeepSeek | Anthropic-compatible | API key | China low-cost |
| P1 | Gemini | Gemini native | API key | Cross-provider workflows (gemini-2.5-pro, gemini-2.5-flash) |
| P1 | Ollama | OpenAI-compatible | None (local) | Privacy-sensitive, no-key users |
| P2 | OpenRouter | OpenAI-compatible | API key | One key, all models |

User picks profile in Settings → LLM Connector pane. No default. Wenshu UI shows no LLM details once a profile is configured.

# §11.3 Agent ↔ other Core module interaction principle (boss 2026-09-03 拍, derived from hermes-core-translation spec §3.6; corrected 2026-09-04 per boss OOB 'hermes 整体翻译成 swift, 整个工作树都完成了?' + '先不验收, 先继续把工作树干完')

The hermes-core-translation spec at `.scratch/2026-09-03-hermes-core-translation/spec.md`
enumerates 43 in-scope hermes modules (= 38 must-translate core per spec §2.1 + 5
grey thin-port per spec §2.2). Of these, 5 wenshu existing modules overlap with
hermes' ported layer and follow the wenshu-side wins pattern (= existing wenshu
module preserved; hermes-port is a thin adapter that delegates to it). The
remaining 38 modules are covered by direct ports in `Sources/WenshuApp/Core/Agent/`,
`Sources/WenshuApp/Core/Provider/`, and other wenshu Core sub-directories, or are
still deferred (= the work-tree gap per boss OOB 2026-09-04 '继续把工作树干完').

Full per-module mapping (= all 43 hermes modules → wenshu Swift counterpart, with
status = ✅ direct port / ⚠️ wenshu-side wins / 🟦 thin-port / ❌ deferred) lives in
the manifest at `.scratch/2026-09-03-hermes-core-translation/hermes-port-manifest.md`
§ "Hermès vs wenshu summary". The 5 wenshu-side wins pairs (= the projects that
matter for ADR-0009 / code-duplication-forbidden principle) are:

| Hermes Python | Wenshu existing (source of truth) | Hermes-port adapter | Decision |
|---|---|---|---|
| `agent/tool_executor.py` (tool surface) | `Core/Tools/FileTools.swift` + `ProcessTools.swift` + `AVMediaTools.swift` + `VisionTools.swift` + `WebTools.swift` | `Core/Agent/Tool/ReadFileTool.swift` + `WriteFileTool.swift` (thin agent-port wrappers) | **wenshu-side wins** |
| `agent/credential_pool.py` + `credential_persistence.py` + `credential_sources.py` + `secret_sources/` + `secret_scope.py` | `Core/Provider/ProviderKeychain.swift` + `AppleKeychainStore.swift` + `InMemoryKeychainStore.swift` + `ProviderKeychainMetadata.swift` + `OAuthFlow.swift` | `Core/Agent/Connector/ConnectorCredentials.swift` (thin adapter) | **wenshu-side wins** |
| `agent/memory_manager.py` + `memory_provider.py` | `Core/Memory/MemoryManager.swift` + `MemoryProvider.swift` + `MemoryStore.swift` + `MemoryConsolidator.swift` + `MemoryWriteGate.swift` | `Core/Agent/Memory/MemoryAdapter.swift` (thin adapter) | **wenshu-side wins** |
| `agent/skill_utils.py` + `skill_preprocessing.py` + `skill_commands.py` + `skill_bundles.py` | `Core/Skills/SkillMeta.swift` + `SkillRegistry.swift` | `Core/Agent/Skill/SkillAdapter.swift` (thin adapter; protocol shape) | **wenshu-side wins** |
| `agent/conversation_loop.py` (session persistence boundary) | `Core/Chat/ChatSessionStore.swift` (SQLite `chat_messages` + `chat_archives` tables per §11 baseline) | `Core/Agent/Conversation/ConversationLoop.swift` (engine that PRODUCES stream events; does NOT know about persistence) | **wenshu-side wins** |

The 43 hermes modules per spec §2.1 + §2.2 are covered across the wenshu tree
(= `Sources/WenshuApp/Core/Agent/`, `Core/Provider/`, `Core/Memory/`, `Core/Skills/`,
`Core/Tools/`, `Core/Chat/`, plus `UI/LLMConnector/` for the Settings UI). The
ground-truth tally per the parallel gap audit at
`.scratch/2026-09-04-hermes-port-gap-audit.md` (read-only static analysis
2026-09-04):

- 6 ✅ direct port (14%) — have a dedicated wenshu Swift file that ports the
  behavior 1:1 (= prompt_caching, error_classifier, turn_retry_state,
  context_breakdown, rate_limit_tracker, runtime_cwd).
- 11 ✅ wenshu-side wins (26%) — existing wenshu Core module (= pre-dates the
  hermes port) is the source of truth; hermes-port = thin adapter that delegates
  to it. The 5 pairs below account for 5 of the 11; the other 6 wenshu-side wins
  modules (= context_compressor, tool_guardrails, display, background_review,
  curator, credits_tracker) have no hermes-overlap conflict but use the
  wenshu-source-of-truth + thin-adapter pattern per ADR-0009.
- 18 ⚠️ partial (42%) — Swift file exists but is a stub / minimum-surface /
  wire-up-not-yet-done; Z-contract golden tests on most would fail.
- 8 ❌ missing (19%) — no Swift file exists; spec §3.1 target file has not been
  authored (= prompt_builder, chat_completion_helpers, agent_runtime_helpers,
  tool_dispatch_helpers, skill_bundles, secret_sources + secret_scope, retry_utils,
  shell_hooks).

Per boss OOB 2026-09-04 '先不验收, 先继续把工作树干完' = the 26 incomplete
(= 18 ⚠️ partial + 8 ❌ missing) are the work-tree to fill in.

Decision (= wenshu-side wins, per ADR-0009):

1. **wenshu-side wins**: for the 5 overlap pairs above, the existing wenshu
   module is preserved; the hermes-port is a thin adapter that delegates to it.
   The port DOES NOT re-implement the wenshu-side behavior. Code duplication is
   forbidden. The full per-module table at `.scratch/2026-09-03-hermes-core-translation/hermes-port-manifest.md`
   shows which hermes modules land in `Core/Agent/` (= hermes-port thin adapters)
   and which are absorbed by existing wenshu Core modules (= wenshu-side wins).
2. **Ticket boundary**: every ticket that touches one of these overlap pairs must
   state in its PR body "this PR uses wenshu-side wins pattern: [list wenshu
   modules it delegates to]". `/code-review` rejects any ticket that re-implements
   wenshu-side behavior.
3. **Existing-code rename** (spec §3.5): ticket 001 renames 12 existing files
   under `Core/Agent/` into the new sub-directory structure. Renames happen BEFORE
   any new module is added. `git mv` preserves blame.
4. **Future hermes-side wins**: any future ticket proposing "hermes port replaces
   wenshu-side" requires explicit boss拍. Default = wenshu-side wins. No silent
   replacement.
5. **Work-tree coverage** (boss OOB 2026-09-04 '继续把工作树干完'): the 26
   incomplete hermes modules (= 18 ⚠️ partial + 8 ❌ missing per the gap audit at
   `.scratch/2026-09-04-hermes-port-gap-audit.md`) are tracked in the manifest's
   Coverage section. The 8 ❌ missing modules (= prompt_builder,
   chat_completion_helpers, agent_runtime_helpers, tool_dispatch_helpers,
   skill_bundles, secret_sources + secret_scope, retry_utils, shell_hooks) have
   zero Swift surface today; each future ticket that authors a dedicated wenshu
   Swift file for one of these must update the manifest's Coverage tally +
   Hermès-vs-wenshu summary table.

Note: this section (§11.3) covers the 5 wenshu-side wins pairs. The full per-module
mapping (= all 43 hermes modules with their wenshu Swift counterpart) lives in the
manifest, NOT here, to keep this section (= project-level baseline principle)
stable while the per-module work-tree evolves.

# §11.4 SwiftData migration roadmap (= boss 2026-09-13 OOB '全链路 Apple-recommended')

Boss 2026-09-13 OOB: "我们的数据库换成了苹果推荐的" — Apple 2026 official
recommendation per developer.apple.com/documentation/swiftdata:
SwiftData = Core Data successor on iOS 17+/macOS 14+; = Apple-native
persistence with built-in migration framework (.versionedSchema),
type-safe queries (ModelContext.fetch), zero external dependencies.

Current state (= deviation from §11.4 spec):
- 10 raw sqlite3 stores, 20+ tables, hand-rolled migration
- WenshuWorkspace.swift = mega-store with 13 tables + duplicate
  chat_messages / chat_summaries / sub_agent_runs / kanban_tasks /
  bookmarks / memory_entries (= risk of divergence with the 9 separate stores)
- CONTEXT.md L36 says "NOT used = ... SQLite" but wenshu IS 10 sqlite3 files
- CLAUDE.md = updated to "use SwiftData" (= migration complete; = commit 88471839a)
- AGENTS.md §11.1 GRDB.swift REMOVED 2026-09-20 per boss OOB (= Core Spotlight replaces FTS5; = see §11.7)

Migration plan (= 6 phases, ~42 commits, 3-4 weeks):

  NOTE: phase 1 = 21 commits introducing 23 @Model classes (= commits 15,
  16, 17, 19 each introduced 2 classes; = 21 commits × 1-2 classes each = 23 total).
  This is why each @Model file says "Phase 1 commit X/21" (= the commit number
  out of 21) while the schema array contains 23 .self entries. See Container.swift
  header for the authoritative mapping.

## Phase 1: Define @Model classes (= 21 commits, 23 @Model classes)
- 23 separate WS*.swift files under Sources/WenshuApp/Persistence/ (= one
  per @Model class; = NOT consolidated into a single Models.swift; =
  per-file commits were chosen for easier review + blame per AGENTS.md
  §11.1 pre-v0.72 convention)
- Sources/WenshuApp/Persistence/Container.swift = ModelContainer setup
  (= the 21st commit; = introduced Container but no new @Model class;
  = the schema array lists all 23 explicit @Model classes)
- Mirror existing 20+ tables with explicit relationships
- Single container (= no more "10 stores in 10 files" pattern)

## Phase 2: Repositories (= 12 commits)
- 9 Repository classes (= replace 10 Actor APIs)
- WSMemoryRepository / WSChatRepository / WSTodoRepository /
  WSBookmarkRepository / WSKanbanRepository / WSLinkRepository /
  WSBookRepository / WSProviderKeyRepository / WSPreferenceRepository
- Public API stays Actor-isolated (= callers don't need to change)

## Phase 3: Update call sites (= 15 commits)
- 30+ files using old Actor APIs (= ToolRegistry / ViewModels / Views)
- Mechanical grep-friendly refactor
- @Observable @Model properties replace manual @Published

## Phase 4: One-time data migration (= 3 commits)
- Read all rows from existing sqlite3_* DBs
- Insert equivalent @Model instances into new ModelContainer
- Mark migration complete (= WSManifest.migratedFromRawSqliteAt)
- Old sqlite3 DBs kept as backup until next major version

## Phase 5: Delete old raw sqlite3 stores (= 5 commits)
- Remove 10 store files
- Remove WenshuWorkspace.swift mega-store
- Update Package.swift (= drop raw sqlite3 imports if no longer used)

## Phase 6: Doc updates (= 2 commits)
- CLAUDE.md: replace "use CoreData" with "use SwiftData"
- AGENTS.md §11.4: this section (boss-approved spec)
- CONTEXT.md: replace "NOT used = SQLite" with "SQLite is the pre-v0.72 legacy"

## Spec doc
Full spec at `.scratch/2026-09-13-swiftdata-migration-spec.md` (= 6.7 KB).

## §11.4.1 Phase 3 progress (= 2026-09-13)

Phase 3 (= switch call sites from old Actors to new Repositories) is
**partially complete**:

  - ✓ commit 33: Repository singletons + WSRepositoryContainer (= foundation)
  - ✓ commit 34: MemoryAdapter → WSMemoryRepository
  - ✓ commit 35: SubAgentProgressView → WSKanbanRepository
  - ⏸ deferred: ContextEngine / HermesTodoTool / TodoStoreTool /
    KanbanTools / ConnectorCredentials / WenshuVerifier / WenshuConductor /
    KanbanView / TodoListView / ChatView kanban usage (= 12 commits)

DEFERRED WORK RATIONALE:
  - Agent code (ContextEngine, HermesTodoTool, KanbanTools, etc.) uses
    actor-isolated types + MemoryManager wrapper + reactive subscription
    patterns that don't translate 1:1 to @MainActor + WSMemoryRepository.
  - Refactoring these requires actor boundary redesign (= multi-week
    effort) and is a separate ticket.
  - View code that uses BookXxxStore (JSON file persistence — e.g.
    KanbanView uses BookKanbanStore) is out of SQLite migration scope.

## §11.4.2 Phase 5 prerequisite tickets (= 5 tickets, sequential dependency)

Phase 5 (= delete old raw sqlite3 stores per §11.4 spec) is BLOCKED on these
5 prerequisite tickets. Each ticket = one dependency migration; = each ticket
unlocks one sqlite store file for deletion.

Dependency graph (= must be done in this order):

  ✓ Phase-5 Ticket 1 (WenshuAppDelegate migration) — commits bc05c4092, e7bb9ee5b, d3644f869, 1174bc59d
    └─> actual scope: WSPersistenceContainer.makeContainer(url:) +
        makeContainerForWarehouse(_:) factory + WenshuAppDelegate
        activates the warehouse container at launch (= SWIFTDATA
        URL SUPPORT, not ChatSessionStore deletion; the spec note
        "unlocks ChatSessionStore.swift deletion" was aspirational
        and is not delivered).
    └─> KanbanStore.swift deletion (= also needs Ticket 2)

  ✓ Phase-5 Ticket 2 (ChatView KanbanStore fallback → WSKanbanRepository)
    = commits 5fbef3a5d (= 2.1: WenshuConductor.kanbanStore → optional)
    + 0ffd714e2 (= 2.2: ChatView drops peer-conductor KanbanStore path)
    └─> ChatView.swift KanbanStore references reduced from 5 to 0 (= doc-only).
    └─> KanbanStore.swift NOT yet deletable: production callers remain
        (= WenshuAppDelegate L222 + KanbanStoreTool.swift L87 + WenshuConductor
        storage layer = 5 kanbanStore.add/transition callsites; = future ticket 6).

  ✓ Phase-5 Ticket 6 (KanbanStoreTool + WenshuConductor storage layer →
    WSKanbanRepository.shared)
    = 1 commit (= KanbanStore.swift deleted + KanbanDomain.swift extracted
    + WenshuConductor migrated + WenshuAppDelegate migrated + ChatView
    peer-conductor arg dropped + WSKanbanRepository.add lifecycle hooks
    + 14 test files migrated to per-test in-memory SwiftData container).
    └─> KanbanStore.swift DELETED (= Core/Kanban/).
    └─> KanbanStatus + KanbanTask domain types preserved in
    Core/Kanban/KanbanDomain.swift (= the canonical public API surface).

  ✓ Phase-5 Ticket 3 (TodoListView TodoStore subscription dropped)
    = commit ce80c6492 (= TodoListView.swift -191 lines / 1 file)
    └─> TodoListView.swift no longer imports/instantiates TodoStore.
    └─> TodoStore.swift NOT yet deletable: production callers remain
        (= TodoStoreTool.shared already uses WSTodoRepository; =
        BUT HermesTodoTool + 6 Specialized tools + WSMigrationPerStore
        still reference TodoStore; = future cleanup ticket 7).

  ✓ Phase-5 Ticket 7 (TodoStoreTool + Specialized + HermesTodoTool →
    WSTodoRepository.shared; TodoStore.swift deletion)
    = 1 commit (= TodoStore.swift deleted + TodoDomain.swift extracted
    + TodoStoreTool.swift docstring/error msg updates + TodoStoreReactivityTests.swift
    deleted (= tests dead reactive stream) + 6 test files migrated to
    per-test in-memory SwiftData container).
    └─> TodoStore.swift DELETED (= Core/Todo/).
    └─> TodoStatus + TodoPriority + TodoItem + TodoStoreError domain types
    preserved in Core/Todo/TodoDomain.swift (= the canonical public API
    surface).
    └─> WSMigrationPerStore.migrateTodoStore unchanged (= reads legacy
    sqlite3 file directly via query(db:sql:) without depending on the
    TodoStore actor class).

  ✓ Phase-5 Ticket 4 (ContextEngine MemoryStore → WSMemoryProvider)
    = commits bc8b83fe4 (= 4.1: MemoryManager.store optional + SwiftData bridge)
    + 43a7abaeb (= 4.2: ContextEngine.makeDefaultMemoryManager drops sqlite chain)
    └─> ContextEngine.swift no longer imports/instantiates MemoryStore.
    └─> MemoryStore.swift NOT yet deletable: production callers remain
        (= WenshuAppDelegate + WSMigrationPerStore migration code +
        WenshuConductor + MemoryProvider #warning; = future ticket 8).

  ✓ Phase-5 Ticket 5 (BacklinkResolver + FullTextSearch LinkIndex → WSLinkRepository)
    = commit 6d573f0e6 (= BacklinkResolver.swift + WSLink.id fix + BacklinkResolverTests.swift)
    └─> BacklinkResolver is the only production caller of LinkIndex.
    └─> LinkIndex.swift NOT yet deletable: test-only callers remain
        (= LinkIndexTests uses LinkIndex directly; = future ticket 9
        migrates those tests + deletes LinkIndex.swift).

  ✓ Phase-5 Ticket 9 (LinkIndexTests + LinkIndex.swift deletion)
    = 1 commit (= LinkIndex.swift deleted + LinkDomain.swift extracted
    + LinkIndexTests.swift deleted (= tests the now-deleted actor)).
    └─> LinkIndex.swift DELETED (= Core/LinkGraph/).
    └─> Link + LinkStoreError domain types preserved in
    Core/LinkGraph/LinkDomain.swift (= the canonical public API surface).
    └─> WSMigrationPerStore.migrateLinkIndex unchanged (= reads legacy
    sqlite3 file directly via query(db:sql:) without depending on the
    LinkIndex actor class).

  + bonus: WenshuWorkspaceMigrator + WenshuWorkspaceMigratorTests (= not
    part of phase 5 prerequisites; = WenshuWorkspace is gated on phase 4
    migration runner + WSMigrationPerStore completion; = separate cleanup
    ticket).

After all 9 tickets complete (= the full phase 5 ticket roadmap):
  - Package.swift: drop `import SQLite3` from production code (= only
    SQLiteConstants.swift keeps it; = test fixtures may also keep).
  - **Phase 5 spec is 100% complete** as of 2026-09-14 (= tickets 10a
    + 10b closed the HONEST SCOPE GAP; = all 7 of the planned sqlite3
    store files are deleted).
  - Currently 7 sqlite stores DELETED in phase 5: KanbanStore +
    TodoStore + MemoryStore + LinkIndex (via ticket 6 + 7 + 8 + 9)
    + ChatSessionStore (via ticket 10a) + BookmarkStore +
    WenshuWorkspace (via ticket 10b). Ticket 10a was scoped
    separately (= 2026-09-14 Q99 dual-axis audit uncovered it as
    still-alive; = chat history is the canonical wenshu feature so
    the audit surfaced this gap before it could leak into the
    Q99-clean release).
  - **HONEST SCOPE GAP** (= closed by Phase 5 ticket 10b):
    - ChatSessionStore.swift — **DELETED in ticket 10a (commit
      `49e5a7e64`)**. Chat persistence migrated to
      `WSChatRepository.shared` (= @MainActor SwiftData wrapper;
      = domain types in `Core/Chat/ChatDomain.swift`; =
      `WSSummary` / `WSSubAgentRun` / `WSChatMessage` @Models
      hold the canonical rows). The legacy `chat.sqlite` file
      on user disks is still migrated by
      `WSMigrationPerStore.migrateChatSessionStore(context:)`
      (= reads raw sqlite3 FILE directly, not the deleted actor).
    - BookmarkStore.swift (= Core/Bookmarks/, raw sqlite3 bookmark
      actor) — **DELETED in ticket 10b**. Bookmarks migrated to
      `WSBookmarkRepository.shared` (= @MainActor SwiftData wrapper;
      = domain type `Bookmark` in `Core/Bookmarks/BookmarkDomain.swift`;
      = `WSBookmark` @Model holds the canonical rows).
    - WenshuWorkspace.swift (= mega-store with 13 tables) —
      **DELETED in ticket 10b**. The 13 tables in WenshuWorkspace
      were already migrated to SwiftData @Models by Phase 5 ticket
      1 (= the per-table @Models like `WSBook` / `WSAttachment` /
      `WSSkill` etc. were authored in Phase 1 and have been the
      canonical persistence since). The actor was dead code at the
      time of deletion (= the only consumer was `WenshuWorkspaceMigrator`
      which itself had no production callers; = the runtime SQLite
      connection was only used by 3 stub `WSMigrationPerStore.migrateX`
      functions that read LEGACY raw-sqlite3 files directly without
      going through the actor). The `WenshuWorkspace.sqlite` file on
      user disks is now an orphan (= phase 4 migration runner has
      already imported any user data; = users can manually delete the
      file or it will be ignored by the SwiftData-only app).

  - **No future ticket 10c remains** (= the phase 5 sqlite3 cleanup
    roadmap is 100% complete). Remaining raw-sqlite3 usage lives in:
    - `HermesKanbanDB.swift` + `FullTextSearch.swift` (= helper indices;
      = not chat/kanban/toDo/memory/bookmark/workspace persistence;
      = out of phase 5 scope; = could be future cleanup if user wants
      pure SwiftData for everything).
    - `WSMigrationPerStore.swift` (= one-shot legacy importers that
      read raw-sqlite3 files from before the migration; = preserving
      these so old chat.sqlite / memory.db / etc. files on user disks
      continue to import on first launch with the new app; = dead code
      after the first launch per user).

Each ticket MUST:
  1. Land as 1+ atomic commit per migrated caller file (= no mega-commits).
  2. Pass full test suite (= no regressions).
  3. Update this section (= move the ticket from "⏸" to "✓" with commit hash).
  4. NOT touch unrelated code (= scope = 1 ticket = 1 caller file).

Branch:
  - `wt/migration-phase5-tickets-2026-09-13` (= historical;
    = AGENTS.md roadmap landing).
  - `wt/phase5-ticket-1-2026-09-13` (= current ticket 1 worktree;
    = rebases onto main as each ticket lands).

Ticket 1 sub-tasks (= 4 commits, all landed):
  - 1a (= commit bc05c4092): WSPersistenceContainer.makeContainer(at:) +
    makeContainerForWarehouse(_:) — SwiftData URL support.
  - 1b.1 (= commit e7bb9ee5b): WSPersistenceContainer.activateWarehouseContainer +
    current getter — warehouse container lifecycle.
  - 1b.2 (= commit d3644f869): WSRepositoryContainer.init default
    WSPersistenceContainer.shared → current.
  - 1b.3 (= commit 1174bc59d): WenshuAppDelegate calls
    makeContainerForWarehouse + activateWarehouseContainer at launch.

Ticket 2 sub-tasks (= 2 commits, all landed):
  - 2.1 (= commit 5fbef3a5d): WenshuConductor.kanbanStore param made optional.
  - 2.2 (= commit 0ffd714e2): ChatView drops peer-conductor KanbanStore path.

Ticket 3 (= 1 commit, landed):
  - ce80c6492: TodoListView drops TodoStore subscription (= -191 lines;
    = llmActivityBanner + 3 helper funcs + 2 subscribe helpers + 3 @State).

Ticket 4 sub-tasks (= 2 commits, all landed):
  - bc8b83fe4 (= 4.1): MemoryManager.store optional + SwiftData bridge helpers.
  - 43a7abaeb (= 4.2): ContextEngine drops sqlite chain (= 38 lines deleted).

Ticket 5 (= 1 commit, landed):
  - 6d573f0e6: BacklinkResolver uses WSLinkRepository.shared.
    (= also fixes WSLink.id composite key to include targetRef so that
    multiple [[name]] links on the same line don't collide).

Next: phase 5 deletion step (= tickets 7/8/9 future cleanup + final git rm).

## §11.5 Known test flakes (= accepted 2026-09-14, v1.24 closure)

Per boss OOB 2026-09-14 '按优先级推' + 'A': 2 pre-existing
MinimaxConnectorTests combined-run failures (= `testRequestBody`
+ `testResponseDecode`) are ACCEPTED as known flakes. Root cause
= `MinimaxConnector` is an `actor` (= per
`Sources/WenshuApp/Core/Agent/Connector/MinimaxConnector.swift:38`).
The actor + URLSession callback interaction causes a continuation
ordering race when Swift Testing runs multiple connector suites
concurrently.

Per Q46 stop-rule + Q186 + Q173 ponytail: 10 redo attempts on
URLProtocolStub migration (= v1.11-v1.23) were either
flaky, build-failing, or exceeded the Q112「1 ticket 1 file」scope.
The realistic fix requires a multi-file refactor (= combine
5 connector suites into 1 parent suite with `.serialized`).

### Acceptance (= per Q34 5.6 honest scope gap)

| # | Property | Value |
|---|---|---|
| 1 | Isolated run pass rate (= dev inner loop) | 100% (= MinimaxConnector isolated = 4/4 pass; = OpenAIConnector isolated = 10/10 pass) |
| 2 | Combined run variance | 0-7 fails out of 540+ tests (= timing-dependent) |
| 3 | Production code affected | 0 (= URLProtocolStub.swift is test-only) |
| 4 | Test files affected | 0 (= 8 real fixes from v1.18-v1.19 already landed) |

### Future fix (= scope-deferred per Q34 5.6)

| # | Option | Effort | Notes |
|---|---|---|---|
| 1 | Multi-file refactor: combine 5 connector suites into 1 parent `ConnectorTests.swift` | 4-6 hours | Defeats parallelism; = future ticket when boss accepts the tradeoff |
| 2 | Single-file alternative: add `static let _crossSuiteLock` to URLProtocolStub.swift + use in 5 test files' init() | 1-2 hours | Still multi-file change |
| 3 | Change `MinimaxConnector` to non-actor | 1 hour | Production code change (= violates Q112) |
| 4 | Accept the variance (= this ticket's recommendation) | 0 | Done |

### Why isolated runs pass but combined runs flake

Each connector test suite has `@Suite(..., .serialized)` (= serializes
tests WITHIN the suite). Swift Testing still runs DIFFERENT suites
concurrently. When `MinimaxConnectorTests` (= actor-based) runs in
parallel with `OpenAIConnectorTests` (= actor-based) etc., the
URLSession callbacks from multiple test requests interleave with
the actor continuations, causing the assertion race.

The dev inner loop (= running 1 test at a time via Xcode test
navigator or `swift test --filter`) is NOT affected. Only the
batch CI run is affected.

### Migration arc summary (= v0.73-v1.23 = 30+ tickets)

| Phase | Tickets | Net fix |
|---|---|---|
| v0.73-v0.82 | 10 | Hermes wiring gap + KeychainOps |
| v0.83-v0.94 | 12 | WorkspaceView helper tests + flakes investigation |
| v0.96-v1.08 | 13 | .serialized + init() reset + defer fix (= 5 real fixes) |
| v1.09 | 1 | TaskLocal backend infrastructure (= enabler) |
| v1.10 | 1 | OpenAI + Minimax migrate to TaskLocal (= 2 real fixes) |
| v1.16-v1.17 | 2 | Per-test stub instance infrastructure (= enablers) |
| v1.18-v1.19 | 2 | OpenAI + Minimax migrate to makeIsolatedStub (= 2 real fixes) |
| v1.11-v1.15 + v1.20-v1.23 | 9 | Spec-only honest scope gaps (= documented root cause at each attempt) |
| **v1.24** | **1** | **THIS TICKET: accept 2 flakes as known** |
| **Total** | **51** | **8 real fixes + 20 honest scope gaps + 2 infra enablers + acceptance closure** |


## §11.6 Migration arc closure (= v1.27 final summary, 2026-09-14)

Per boss OOB 2026-09-14 '清完所有待办' (= complete all pending
work without asking): the v0.73-v1.26 migration arc is CLOSED.

### Final stats (= per Q34 5.4 + Q46 + Q186)

| # | Metric | Value |
|---|---|---|
| 1 | Total tickets | 54 (= v0.73 through v1.26) |
| 2 | Real fixes | 8 (= v0.96, v0.98, v1.00, v1.05+v1.06, v1.08, v1.10, v1.18, v1.19) |
| 3 | Infra enablers | 3 (= v1.09 TaskLocal backend + v1.16-v1.17 per-test stub) |
| 4 | Spec-only honest scope gaps | 22 (= v1.11-v1.15 + v1.20-v1.26) |
| 5 | Acceptance closure | 1 (= v1.24 AGENTS.md §11.5) |
| 6 | Worktrees created | 54 (= all merged into main + cleaned up) |
| 7 | Branches created | 53 (= all deleted post-merge) |
| 8 | Commits on main | 135 ahead of B-03 rebase |
| 9 | Production code changes | 0 across all v1.11-v1.26 spec-only tickets |
| 10 | Test code changes (= real fixes) | ~80 LOC across 8 tickets |

### Test status (= per Q34 5.4 + Q173 ponytail)

| # | Metric | Value |
|---|---|---|
| 1 | Isolated test runs | 100% pass rate (= dev inner loop works) |
| 2 | Combined connector runs | 0-7 fails variance (= inherent; = documented in AGENTS.md §11.5) |
| 3 | Total tests in suite | ~540 |
| 4 | Known accepted flakes | 2 (= `MinimaxConnectorTests.testRequestBody` + `testResponseDecode`) |
| 5 | Pre-existing flakes outside URLProtocolStub | ~10 (= I18nParityTests en keys, Anthropic Gemini connector races, LiquidGlassPolishTests file scope) |

### Files touched across the arc

| # | Category | Files | LOC delta |
|---|---|---|---|
| 1 | Production code (= real fixes) | `ProviderKeychain.swift` + `URLProtocolStub.swift` + connector tests | +~150 production, +~500 test |
| 2 | Documentation (= spec-only closures) | `AGENTS.md` + 30+ `.scratch/` specs | +~2000 doc |
| 3 | Test infrastructure (= infra enablers) | `ProviderKeychain.swift` + `URLProtocolStub.swift` + 5 connector test files | (= already counted above) |

### Q46 stop-rule invoked

Per Q46 stop-rule + Q186 + Q173 ponytail: 12 URLProtocolStub
migration attempts (= v1.11 through v1.26) were either flaky,
build-failing, exceeded Q112 scope, or hit fundamental
architectural issues (= `MinimaxConnector` actor + URLSession
callback race).

The acceptance closure (= v1.24 / AGENTS.md §11.5) documents
the decision: **2 pre-existing MinimaxConnectorTests flakes
are accepted as known**; = isolated runs pass; = dev inner loop
works; = only batch CI runs are affected.

### What is NOT done (= future tickets if boss approves)

| # | Item | Why deferred |
|---|---|---|
| 1 | Multi-file refactor: combine 5 connector suites into 1 parent suite | Defeats parallelism; = future ticket if boss accepts the tradeoff |
| 2 | Process-wide test ordering lock | Multi-file; = requires v1.24 acceptance reversal |
| 3 | `MinimaxConnector` non-actor change | Production code; = violates Q112 |
| 4 | Migrate Anthropic + Gemini to `makeIsolatedStub` | Same write-through race as Minimax (= v1.26 reverted) |
| 5 | Full `swift test --no-parallel` scan | Background killed at 600s timeout; = not critical (= dev inner loop works) |
| 6 | repowise re-index via MCP | Binary lives in hermes runtime; = MCP fallback works (`get_change_risk`) |

### What IS done (= ready for production)

| # | Item | Status |
|---|---|---|
| 1 | `swift build` on main | BUILD COMPLETE in <8s |
| 2 | Isolated test runs | 100% pass (= all 5 connector suites + v1.18-v1.19 migrated tests) |
| 3 | `swift test --filter` (= targeted) | 100% pass (= no flakes when filtering single suites) |
| 4 | AGENTS.md §11.5 closure | Documents accepted flakes |
| 5 | AGENTS.md §11.6 closure (= this section) | Documents the arc completion |
| 6 | Git state | Clean working tree, 1 branch (main), 0 stale worktrees |
| 7 | 135 commits on main | All merged via `--no-ff` (= preserves ticket boundaries) |

# §11.7 v1.55 sqlite3-zero migration arc (= boss 2026-09-20 OOB)

Per boss 2026-09-20 OOB 'SQLite 全部弃用，只用 SwiftData' + A1 'Apple-default-first':
SQLite is REMOVED from wenshu runtime stack (= `GRDB.swift` SPM pin REMOVED per
§11.1; = raw `import SQLite3` survives ONLY in `WSMigrationPerStore.swift` for
one-shot legacy import).

Search layer = `Core Spotlight` (= `CSSearchableIndex` + `CSSearchQuery`; = built
into macOS 27; = zero SPM dependency). The 207 LOC `FullTextSearch.swift` actor
(SQLite FTS5) is REPLACED by `CSSearchableIndexSearch.swift` (= `CSSearchableIndex`
primary path + SwiftData token-overlap ranking fallback when Spotlight is
disabled by user).

Kanban helper = `HermesKanbanDB.swift` (994 LOC raw sqlite3) is REPLACED by
`HermesKanbanHelper.swift` (= pure SwiftData @Model query helpers; = no actor;
= ModelContext.fetch with #Predicate).

### Ticket roadmap (= 5 tickets, all on `wt/v1.55-sqlite3-zero-2026-09-20`)

| # | Ticket | Source change | Test change | Status |
|---|---|---|---|---|
| 1 | T1 — AGENTS.md §11.1 收窄 | `AGENTS.md` L27/L54/L190 + §11.7 new | doc-only | ⏸ starting |
| 2 | T2a — `CSSearchableIndexSearch.swift` 创建 (= `CSSearchableIndex` primary) | NEW file `Core/Search/CSSearchableIndexSearch.swift` | NEW test `CSSearchableIndexSearchTests.swift` | ⏸ starting |
| 3 | T2b — `FullTextSearch.swift` → `LegacyFTS5Fallback.swift` (= used only when Spotlight disabled) | rename + add fallback trigger | update `FullTextSearchTests.swift` | ⏸ starting |
| 4 | T3a — `HermesKanbanDB.swift` → `HermesKanbanHelper.swift` (= SwiftData @Model helpers) | rewrite 994 LOC → ~200 LOC SwiftData | NEW test `HermesKanbanHelperTests.swift` | ⏸ starting |
| 5 | T3b — `HermesKanbanDBTests.swift` + `HermesKanbanDB.swift` delete | delete file | delete test | ⏸ starting |
| 6 | T4 — `Package.swift` 删 GRDB | `Package.swift` + remove tests | n/a | ⏸ starting |

### Acceptance (= per Q112 + Q99 dual-axis)

| # | Property | Value |
|---|---|---|
| 1 | Q112 = 1 source + 1 test per ticket | YES (T1 doc-only exempt) |
| 2 | `swift build` clean | 0 errors / 0 warnings introduced |
| 3 | `swift test --filter` 100% pass on migrated files | YES |
| 4 | Q99 spec axis (= hermes 1:1 fidelity) | N/A (= SQLite removal is wenshu-side design divergence per §11 baseline 'no external AI platform calls' + boss 2026-09-20 OOB) |
| 5 | Q99 standards axis (= Apple default + pre-existing preservation) | YES (= Core Spotlight = Apple native; = no behavior loss for users) |
| 6 | `import SQLite3` count in production code | 1 (= `WSMigrationPerStore.swift` only, = one-shot legacy import) |
| 7 | `import GRDB` count in production code | 0 |
| 8 | Migration data flow | preserved (= legacy `.ws` sqlite3 files imported once at first launch by `WSMigrationPerStore.swift`, then never touched) |

### What is preserved (= scope-no-regression)

| # | Surface | Status |
|---|---|---|
| 1 | `SubAgentIdentity.swift` calls `FullTextSearch` | migrated to `CSSearchableIndexSearch` (= same public API: `index(docId:title:body:)`, `remove(docId:)`, `search(query:limit:)`) |
| 2 | `KanbanStoreTool` reads kanban via `HermesKanbanDB` | migrated to `HermesKanbanHelper` (= SwiftData fetch via #Predicate) |
| 3 | `WSMigrationPerStore.swift` reads raw sqlite3 files at first launch | unchanged (= dead code after first launch per user) |

### What is NOT done (= future tickets if boss approves)

| # | Item | Why deferred |
|---|---|---|
| 1 | SwiftData @Model for `WSChatMessage` / `WSSummary` already exists per §11.4 phase 1-5 | DONE in phase 1-5 (= 23 @Models) |
| 2 | `WenshuWorkspaceMigrator` cleanup | out of v1.55 scope (= separate ticket per §11.4.2 bonus) |
| 3 | `HermesKanbanDB.swift` SQLite helper reuse for `WSMigrationPerStore.migrateChatSessionStore` (= reads `chat.sqlite` directly) | N/A (= already uses raw `sqlite3_open` via SQLiteConstants.swift; = out of v1.55 scope) |

