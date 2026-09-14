# Issue 003 · Wire WebSearch into ToolRegistry (= 5-provider rotation)

**Ticket**: 003-wire-websearch
**Scope**: 1 file (= new WebSearchTool.swift) + 1 file (= registration site update)
**Methodology**: Q112 (1 ticket 1 commit 1 file) + Q34 step 4 (drive `/tdd` internally)

## Problem

`Sources/WenshuApp/Core/Agent/Web/WebSearch.swift` (= 1:1 port of hermes `web_search.py` + `web_search_provider.py`, shipped in HERMES-INTERNAL-001) defines:

- 5 search providers: EXA / TAVILY / BRAVE / PARALLEL / SEARXNG
- Auto-rotation on failure (= tries every provider in order)
- `ResearchReport` type (= query + sources + summary; = convenience aggregator)
- Firecrawl scraper-only backend

**No Tool wrapper exists.** Today's LLM-side `web` tool (= `Core/Tools/WebTools.swift`) is fetch-only (= single URL → markdown; = no search, no rotation, no research).

## Decision (per spec.md §Acceptance)

**Wire, scope-limited.** Boss 2026-09-04 OOB 'A' approved the multi-provider rotation; today the LLM cannot search. The `web` Tool stays as-is (= URL fetch); we ADD `web_search` as a separate Tool to avoid breaking existing call paths.

## Plan

### 1. New file: `Sources/WenshuApp/Core/Agent/Tool/WebSearchTool.swift`

- `class WebSearchTool`
- 2 actions: `search(query, limit, providers?)` / `research(query, depth)`
- `ToolRegistrySchema` with `name: "web_search"`, `toolset: "research"`
- `Task { await ToolRegistry.shared.register(...) }` at file bottom
- **Per Q42**: uses existing `WebSearch.shared.search(...)` (= hermes-port surface), NO duplicate provider logic
- **Per AGENTS.md §11.1**: NO third-party SDKs; URLSession only (= already the case per WebSearch.swift hard rule)
- **Per AGENTS.md §11**: API keys come from `ProviderKeychain` (= or `SecretScope`); NO plaintext

### 2. Update file: `Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift`

Add `"web_search"` to `defaultToolNames` array (= deterministic ordering; = insert at position 9 per existing research toolset).

## TDD plan

1. **Red**: write `Tests/WenshuAppTests/Core/Agent/Tool/WebSearchToolTests.swift` with 4 cases:
   - `testWebSearchSearch` (= single provider returns results)
   - `testWebSearchRotation` (= first provider fails → second succeeds; = use stub provider)
   - `testWebSearchResearch` (= research pipeline returns `ResearchReport`)
   - `testWebSearchAllFail` (= all 5 providers fail → typed error)
2. **Green**: implement `WebSearchTool` until all 4 tests pass.
3. **Refactor**: extract `WebSearchTool.Actions` enum.

## Files changed

- `Sources/WenshuApp/Core/Agent/Tool/WebSearchTool.swift` (new, ~180 LOC)
- `Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift` (+1 line in `defaultToolNames`)

## Commit message template

```
feat(wenshu): wire WebSearch into ToolRegistry (= 5-provider rotation + research)

- New WebSearchTool (= 2 actions: search / research)
- Reuses hermes-port WebSearch.shared actor (= NO duplicate provider logic per AGENTS.md §11.3)
- 5-provider rotation + ResearchReport convenience aggregator
- Self-registers via ToolRegistry.shared.register
- WenshuConductor.defaultToolNames += "web_search"
- 4 unit tests added (search / rotation / research / all-fail)

Refs: .scratch/v0.73-hermes-agent-wiring-gap/spec.md §Acceptance
Ticket: 003-wire-websearch
```

## Acceptance

- [ ] `swift build` = BUILD COMPLETE
- [ ] `swift build --target WenshuAppTests` = BUILD COMPLETE
- [ ] All 4 unit tests pass
- [ ] `ToolRegistry.shared.listTools()` includes `web_search` (= NEW, alongside `web` Tool)
- [ ] NO duplicate provider logic (= grep `WebSearchTool.swift` for `EXAProvider\|TAVILYProvider\|BRAVEProvider\|PARALLELProvider\|SEARXNGProvider` = zero hits; = delegate to `WebSearch.shared`)
- [ ] Code-review 双轴 = Standards pass + Spec pass

## Out-of-scope

- Hermes-port golden parity test update (= separate ticket)
- Wenshu-side provider YAML config (= future ticket; = wenshu-devtool concern)
- `WebTools.swift` (= URL fetch) — kept as-is (= separate concern from search)