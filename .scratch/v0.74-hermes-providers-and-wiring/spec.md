# v0.74 Hermes Agent Wiring Completion · Spec

**Branch**: `wt/v0.74-hermes-providers-and-wiring-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "正常推进"

## Context

v0.73 hermes wiring gap audit (= `.scratch/v0.73-hermes-agent-wiring-gap/spec.md`)
landed in worktree `wt/v0.73-hermes-wiring-gap-2026-09-14` (= 9 commits, 14 files,
1,175 insertions). It shipped:

- 1 wire (= `SkillBundlesTool` + 12 tests + WenshuConductor registration)
- 3 doc-only defer headers (= CronjobTools + ContextReferences + WebSearch)
- 1 design doc (= `AgentLifecycleTrackerDesign.md`)

v0.74 = the **wiring completion** scope: actually wire the things v0.73 deferred
because of missing implementations (= WebSearch providers + SkillBundles YAML
discovery) and the wiring path v0.73's design doc recommended (= Option B =
parallel call site in AsyncDelegation for AgentLifecycleTracker).

## Scope (= 4 tickets, 1 file 1 commit each per Q112)

| # | Ticket | File(s) | LOC estimate | Dependency |
|---|---|---|---|---|
| 1 | `001-websearch-providers-stub` | `Sources/WenshuApp/Core/Agent/Web/Providers/EXAProvider.swift` (= + 4 siblings) | ~5 files / ~50 LOC each | None (= standalone) |
| 2 | `002-websearch-default-providers` | `Sources/WenshuApp/Core/Agent/Web/WebSearch.swift` (= add `.shared` singleton with empty provider list) | ~30 LOC | Ticket 1 |
| 3 | `003-websearch-tool-wire` | `Sources/WenshuApp/Core/Agent/Tool/WebSearchTool.swift` (= wire Tool wrapper now that providers exist) | ~200 LOC | Ticket 2 |
| 4 | `004-asyncdelegation-tracker-call` | `Sources/WenshuApp/Core/Agent/Conversation/AsyncDelegation.swift` (= add `tracker.registerSpawn(...)` + `markCompleted(...)` calls per Option B in `AgentLifecycleTrackerDesign.md`) | ~40 LOC | None (= standalone; uses existing `AgentLifecycleTracker`) |

Out of scope (= explicit):

- SkillBundles YAML discovery (= v0.75+ scope; = touches disk I/O path;
  needs separate spec)
- Wiring SkillBundles + WebSearch into `WenshuConductor.defaultToolNames`
  (= trivial follow-up after Ticket 3 lands; = can ship in the same PR)
- AgentLifecycleTracker Option A (= refactor SubAgentProgressView;
  = separate spec, separate risk)
- Refactor / cleanup of the existing `CronjobTools` (= stay deferred per §11.2)

## Per-ticket acceptance criteria

### Ticket 001 — WebSearch provider stubs (= 5 files)

For each provider (`EXAProvider` / `TAVILYProvider` / `BRAVEProvider` /
`PARALLELProvider` / `SEARXNGProvider`):

- One file per provider (= follows Q112)
- Conforms to `WebSearchProvider` protocol (= `name: String` + `search(query: String, limit: Int) async throws -> [WebSearchResult]`)
- Each provider reads its API key from `ProviderKeychain` (= AGENTS.md §11 — no plaintext secrets)
- Each provider sends 1 HTTPS request via URLSession (= AGENTS.md §11.1 — no third-party SDKs)
- Provider returns `[WebSearchResult]` (= empty array is allowed; = triggers rotation per WebSearch actor design)
- Provider error type = `WebSearchError.providerFailure(name: String, underlying: String)`
- File header documents: (a) the hermes counterpart (= `web_search_provider.py`), (b) the API endpoint URL, (c) the API key name (= e.g. `exa_api_key` for EXA)
- File body stub returns `[WebSearchResult]()` (= empty success) when the API key is missing (= "config not yet set" — prevents throw-on-startup, lets the wenshu dev experience test the rotation path)

### Ticket 002 — `WebSearch.shared` singleton with default empty provider list

- Add `public static let shared: WebSearch = WebSearch(providers: [])` (= matches the `SkillBundles.shared` pattern from v0.73)
- `init(providers:)` already exists; = no breaking change
- Doc comment explains: empty provider list = `search(...)` throws `WebSearchError.noProvidersConfigured` (= matches existing behavior in `WebSearch.search`)
- This is the smallest change that lets `WebSearchTool` instantiate without config

### Ticket 003 — `WebSearchTool` wire

Mirrors `SkillBundlesTool` (= v0.73 ticket 001 = ground truth pattern):

- New file: `Sources/WenshuApp/Core/Agent/Tool/WebSearchTool.swift`
- 2 actions: `search(query, limit, providers?)` / `research(query, limit)`
- `ToolRegistrySchema` with `name: "web_search"`, `toolset: "research"`
- `Task { await ToolRegistry.shared.register(...) }` at file bottom
- JSON envelope convention = matches `SkillBundlesTool`
- Defaults to `WebSearch.shared` (= the empty-provider singleton)
- Allows `providers` field override (= future ticket to wire real provider list from UserDefaults / config)
- Tests: 4 cases (= search success / search all-fail / research success / missing-query)

### Ticket 004 — `AsyncDelegation` parallel call site (= AgentLifecycleTracker Option B)

Per `AgentLifecycleTrackerDesign.md` Option B recommendation:

- `AsyncDelegation` calls `AgentLifecycleTracker.shared.registerSpawn(...)` at dispatch time
- `AsyncDelegation` calls `AgentLifecycleTracker.shared.markCompleted(...)` at result collection
- `AsyncDelegation` calls `AgentLifecycleTracker.shared.markFailed(...)` on error path
- `AsyncDelegation` calls `AgentLifecycleTracker.shared.cancel(...)` on cancellation
- Existing call sites for `WSKanbanRepository.shared.add(...)` (= the user-visible progress source) are unchanged (= UI keeps reading from SwiftData; = tracker is parallel source of truth)
- No new tests (= AgentLifecycleTrackerTests covers the tracker; = AsyncDelegation behavior is unchanged from UI perspective)

## Cross-references

- `.scratch/v0.73-hermes-agent-wiring-gap/spec.md` (= upstream audit)
- `Sources/WenshuApp/Core/Agent/Web/WebSearch.swift` (= protocol + actor)
- `Sources/WenshuApp/Core/Agent/Conversation/AgentLifecycleTracker.swift` (= tracker to wire)
- `Sources/WenshuApp/Core/Agent/Conversation/AgentLifecycleTrackerDesign.md` (= Option B recommendation)
- `Sources/WenshuApp/Core/Agent/Conversation/AsyncDelegation.swift` (= wire target for ticket 004)
- `Sources/WenshuApp/Core/Agent/Tool/SkillBundlesTool.swift` (= the v0.73 pattern reference for ticket 003)
- `AGENTS.md §11.1` (= no third-party SDKs for HTTP)
- `AGENTS.md §11` (= API keys via AppleKeychain / ProviderKeychain; no plaintext)

## Validation (= per Q34 step 4)

For each ticket:

1. `swift build` = BUILD COMPLETE
2. `swift build --target WenshuAppTests` = BUILD COMPLETE (= zero regressions)
3. New unit tests for Ticket 001 + 003 (= providers + tool)
4. Code-review 双轴 = Standards + Spec per Q146

## Final scope after v0.74 (= honest tally per Q239)

After v0.74 ships (= 4 tickets), the v0.73 inventory's 5 modules have:

| Module | v0.73 status | v0.74 status |
|---|---|---|
| `SkillBundles` | Wired | Wired |
| `CronjobTools` | Deferred | Deferred (= per §11.2) |
| `WebSearch` | Deferred (no providers) | **Wired** (= providers + tool) |
| `AgentLifecycleTracker` | Deferred + design doc | **Wired (Option B)** (= parallel call site) |
| `ContextReferences` | Deferred | Deferred (= per §11 single-shelf model) |

= 3 wired + 2 deferred (= matches the v0.73 spec's "wire 1 + defer 2 + design 1" decision; = v0.74 finishes the deferred-but-actionable items).

## Out-of-scope (= explicit, again)

- Disk I/O for SkillBundles (= v0.75)
- `WenshuConductor.defaultToolNames` += `web_search` (= trivial follow-up, can ship in same PR as Ticket 003 but not a separate ticket)
- `AgentLifecycleTracker` SwiftData persistence (= separate ticket, separate spec)
- `SubAgentProgressView` refactor (= Option A from the design doc; = separate spec)