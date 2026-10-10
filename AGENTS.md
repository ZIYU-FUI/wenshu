AGENTS.md

# Hard rule (project-wide, non-negotiable)

- This file is English only. No Chinese characters. No CJK punctuation. No mixed CJK + Latin characters.
- All commit messages, comments, prompts, `.scratch/spec.md`, `.scratch/issues/`, `.scratch/backlog` files, `CONTEXT.md`, `README.md`, `CLAUDE.md`, and every doc in this repo follow the same English-only rule.
- Sole address for the user = "老板" (the literal characters). No earlier honorific forms.
- Forbidden neutral words: 可 / 应当 / 或许 / 可能 / 应该 / 建议 / 考虑 / 试图 / 尽量 / 大概 / 也许 / 或 / 任意 / 大概率 / 通常 / 一般来说. Replace with: 是 / 否 / 行 / 不行 / 可以 / 不可以 / 不变 / 变.
- Forbidden Chinese vocabulary: 修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障. Historical note: 修真 = an earlier agent's typo for 修正. Use 修 / 改 / fix / 替换 / 调整 in commit body / comment / doc / prompt / card body.
- First line of every doc = fact. Last line of every doc = fact.
- **Comment policy (= 老板 2026-09-24, expanded 2026-09-24)**: code comments capture engineering intent only. Forbidden content (= the dev-narrative kinds real human devs would laugh at):
  - Boss / 老板 / boss拍 / 老板拍 / 老板 directives (`boss OOB YYYY-MM-DD '...'` / `Per boss OOB ...`)
  - Ticket IDs (`CHATBOX-NNN`, `HERMES-PARTIAL-NNN`, `Ticket 3`, `Ticket 001`)
  - Q-numbers (`Q34 5.2`, `Q173 ponytail`, `Q112`)
  - Version narratives (`v1.38 extracted (= ticket 1 of N)`, `v1.0.0-m1-shell boss OOB`)
  - Phase numbering (`Phase 3 of 5-phase`)
  - Refactor history (`replaces X (166 LOC)`, `Extracted from X.swift (= ...)`)
  - Follow-up chains (= this continues the v1.34/v1.38/v1.39 arc)
  - Any phrase that describes *how this file came to be* (= ticket lineage). What stays: engineering facts.
- Allowed comment kinds: `///` public API doc-comments, `// MARK: -` section headers, technical "why this exists" rationale, `// FIXME` / `// TODO` (SwiftLint tracked), file header = file path + module name + last-meaningful-version only.
- OOB references in code: only `(see OOB.md #YYYY-MM-DD)` — never the directive text inline.
- OOB is archived separately in `OOB.md` (wenshu repo root, dev-time only).

This file = wenshu project baseline + cross-role address hard constraint. Single agent (pocock profile) direct dialog with 老板. No dispatch, no board, no 6-role flow. Version 8/18拍 v0.07 + 2026-09-04/05拍 v0.10 (pocock single agent purified version).

# Split layout (= boss 2026-10-02 OOB 'AGENTS / CLAUDE 两个大文件，需要治理吗' + option C)

This file contains the **head + Hard rule + §11 Project baseline + §11.1 + §11.2 + §11.3** (= the cross-cutting rules every wenshu work touches). The remaining §11.X sections are split across two companion files (= to keep each file within the Hermes context-file 20K-char cap; = the previous single-file layout was 245,067 chars = 12× cap = Hermes head/tail truncation dropped §11.5 / §11.6 / §11.10 / §11.11 / §11.13 entirely; = commit `724a6c2de` on 2026-10-02 closed the split).

- `AGENTS-§11-rules.md` — current ACTIVE rules (= the rules any wenshu view / model / tool file must obey today). Contains §11.4 (SwiftData migration roadmap) + §11.5 (known test flakes = acceptance baseline) + §11.7 (sqlite3-zero migration) + §11.7d + §11.7e + §11.8 (stale-helper migration) + §11.12 (Pocock engineering standards skill set) + §11.14 (v2.4 agent-behavior closed-enum product philosophy) + §11.15 (v2.5 keyless web search) + §11.16 (v2.6 facet model).
- `AGENTS-§11-history.md` — CLOSED arc records (= the canonical reference for arcs that already shipped; = future amendments land at the bottom of `AGENTS.md` as a new §11.X section, then move to history when fully closed). Contains §11.6 + §11.9 + §11.10 + §11.11 + §11.13 + §11.17-§11.30.

When in doubt about which file owns a §11.X reference: ACTIVE rules affecting current code belong in `AGENTS-§11-rules.md`; CLOSED arc records (anything with "closure" / "arc closure" in the section title) belong in `AGENTS-§11-history.md`.

# §11 Project baseline

- Stack = Swift / SwiftUI + Swift Observation (@Observable) + filesystem JSON + Markdown (per-book private content) + Apple HIG (.fcpbundle-style directory, single-process). NO CoreData. NO external AI platform calls (any code file).
- §11 product positioning (boss 2026-09-03 拍): Wenshu is a writing tool, NOT an LLM platform. Wenshu never resells or bundles LLM access, never holds user tokens on its own backend, never charges for token consumption. LLM is a layer below Wenshu that the user provides via the §11.2 connector layer. Any PR that adds metering, billing, quota tracking, or token-bundling is out of scope.
- wenshu stack baseline 修正 — 第三方库允许（前提 = 见 §11.1 UI 控件例外清单）。
- v1 LLM connector architecture: 14 first-class + custom provider profiles (Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter / minimax / minimax cn / Nous / OpenAI Codex / GitHub Copilot / Copilot ACP / xAI OAuth / StepFun + a `custom` Provider entry for BYOK endpoints). Provider-agnostic. User BYOK (bring your own key). NO default recommendation. Wenshu ships with the connector layer wired but every profile is empty until user supplies credentials. See §11.2 for the canonical list (= `Sources/WenshuApp/Core/Provider/Provider.swift` Provider.all).
- `.ws` directory (= macOS package, NSOpenPanel-selected at onboarding) = per-library container. Holds: Info.plist (= Apple HIG bundle metadata; CFBundlePackageType=WSPC + WSSchemaVersion) + chat.sqlite (= global LLM chat history; 45 KB at v0.24 ship) + Icon (= Finder icon) + shelves/ (= user-created bookshelves; multiple) + reference-library/ (= library's default bookshelf; system-managed, ONE instance, user CANNOT delete or rename; holds LLM Wiki 4 layers: raw/ + entities/ + abstracts/ + indexes/) + cache/ (= thumbnails + search index + export temp). Per-book structure = `shelves/<shelf-uuid>/books/<book-uuid>/` with 8 standard folders (world/ characters/ outlines/ chapters/ drafts/ sessions/ foreshadowing/ placeholders/) + 8 JSON sidecars + 2 per-book JSON data files (kanban.json, todo.json). Per-book private world + characters + foreshadowing + placeholders; reference-library is library-public (= cross-book reusable raw materials).
- Apple stack exclusive (macOS / iPad / iPhone). Current target = macOS-only single platform (老板 8/18 拍).
- Project root = `/Volumes/ANAN/Engineering/wenshu/`.
- Apple Developer Program paid on release (individual $99 / year).
- Version format = three digits (Hermes style): middle digit = phase, third digit = hotfix.
- 3 docs = this file + `README.md` + `CLAUDE.md`. `CONTEXT.md` = domain glossary (see `docs/agents/domain.md`).
- No hermes monorepo trace (no longer fork).
- No Tauri / Rust / Vue 3 trace. SQLite REMOVED from wenshu stack (= boss 2026-09-20 OOB (see OOB.md) + A1 'Apple-default-first = Core Spotlight'; = runtime layer fully replaced in §11.7 v1.55 sqlite3-zero arc; = one-shot legacy importer deleted in §11.7d v1.55d closure on 2026-09-21 per boss OOB (see OOB.md)); legacy `.ws` bundle sqlite files (= `chat.sqlite`, `indexes.sqlite`, `search.db`, `kanban.sqlite`) are now orphaned (= no production code reads them; = see §11.7d for full removal record).
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
    - ~~`bring-shrubbery/lucide-swift` 1.25.0 — icon set (MIT, macOS-first, 8.8k★)~~ — REMOVED 2026-09-15 per boss OOB (see OOB.md). Canonical icon layer is now Apple SF Symbols 6 (= built into macOS 27 = zero SPM dependency).
    - `sindresorhus/Defaults` 9.0.9 — UserDefaults typed wrapper (MIT, 2.7k★, P0; bumped 8.2.0 → 9.0.9 in v0.28 batch 1 per `brew info`-verified latest stable; wenshu source has zero `import Defaults` so zero source-code impact; the pin is preparation for the v0.28 chat history migration ticket's first consumer)
    - `sindresorhus/KeyboardShortcuts` 2.2.0 — global shortcut binding (MIT, 1.1k★, P1; bumped 1.10.0 → 2.2.0 in v0.28 batch 2 issue 09 per boss拍 (see OOB.md) = evaluated to zero source impact = wenshu has zero `import KeyboardShortcuts`; all 26 .keyboardShortcut calls use Apple SwiftUI native modifier; lib reserved for v0.28+ Settings pane Keyboard tab where users rebind global shortcuts via System Settings)
    - `kean/Nuke` + `kean/NukeUI` — async image pipeline + SwiftUI `LazyImage` (MIT, 8.6k★ + 1.3k★, P0; NukeUI is a product of the main Nuke repo since Nuke 11.0; the standalone `kean/NukeUI` repo is frozen at Nuke 10.5 and rejected as the SPM pin source)
    - `weichsel/ZIPFoundation` 0.9.20 — pure-Swift ZIP read/write (MIT, 2.7k★, unblocked 2026-08-28 from prior defer)
    - ~~`groue/GRDB.swift` 7.11.1 — SQLite toolkit + FTS5 full-text (MIT, 8.6k★, P0; replaces prior "No SQLite" rule scope = inside `.ws` bundle only)~~ — REMOVED 2026-09-20 per boss OOB (see OOB.md) + A1 'Core Spotlight 替代 FTS5'; canonical search layer is now `Core Spotlight` (= `CSSearchableIndex` + `CSSearchQuery`; = built into macOS 27 = zero SPM dependency); see §11.7 v1.55 sqlite3-zero migration arc.
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

# §11.3 Agent ↔ other Core module interaction principle (boss 2026-09-03 拍, derived from hermes-core-translation spec §3.6; corrected 2026-09-04 per boss OOB (see OOB.md) + '先不验收, 先继续把工作树干完')

The hermes-core-translation spec at `.scratch/2026-09-03-hermes-core-translation/spec.md`
enumerates 43 in-scope hermes modules (= 38 must-translate core per spec §2.1 + 5
grey thin-port per spec §2.2). Of these, 5 wenshu existing modules overlap with
hermes' ported layer and follow the wenshu-side wins pattern (= existing wenshu
module preserved; hermes-port is a thin adapter that delegates to it). The
remaining 38 modules are covered by direct ports in `Sources/WenshuApp/Core/Agent/`,
`Sources/WenshuApp/Core/Provider/`, and other wenshu Core sub-directories, or are
still deferred (= the work-tree gap per boss OOB 2026-09-04 (see OOB.md #2026-09-04)).

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

Per boss OOB 2026-09-04 (see OOB.md #2026-09-04) = the 26 incomplete
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
5. **Work-tree coverage** (boss OOB 2026-09-04 (see OOB.md #2026-09-04)): the 26
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

