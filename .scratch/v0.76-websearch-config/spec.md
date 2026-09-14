# v0.76 WebSearch UserDefaults Configuration · Spec

**Branch**: `wt/v0.76-websearch-config-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "跑到问题清单清完"

## Context

v0.74 shipped 5 web search provider classes (= EXA / TAVILY / BRAVE / PARALLEL / SEARXNG) but they're all stubbed (= return [] when no API key).

v0.76 = the "wire the providers to user-configurable API keys" ticket. This is the production-UX layer that lets users actually configure their search API keys.

## Scope (= 2 tickets, 1 file 1 commit each per Q112)

| # | Ticket | File(s) | LOC | Dependency |
|---|---|---|---|---|
| 1 | `001-websearch-configurator` | `Sources/WenshuApp/Core/Agent/Web/WebSearchConfigurator.swift` (= UserDefaults → provider list builder) + tests | ~120 LOC + ~150 LOC tests | None (= standalone) |
| 2 | `002-websearch-tool-engine-injection` | `Sources/WenshuApp/Core/Agent/Tool/WebSearchTool.swift` (= inject configured engine from WenshuAppDelegate) | ~20 LOC | Ticket 1 |

Out of scope (= explicit):

- AppleKeychain migration (= v0.77+ scope; = need user-driven credential UI)
- SEARXNG endpoint URL config (= v0.77+ scope; = needs separate config key)
- UI for API key entry (= v0.77+ scope; = needs Settings pane; = touches LLMConnector pane + UI tests)

## Per-ticket acceptance criteria

### Ticket 001 — WebSearchConfigurator module

- New file: `Sources/WenshuApp/Core/Agent/Web/WebSearchConfigurator.swift`
- Public API:
  - `WebSearchConfigurator.supportedProviders: [String]` (= ["exa", "tavily", "brave", "parallel", "searxng"])
  - `WebSearchConfigurator.searchAPIKeyName(for: String) -> String?`
  - `WebSearchConfigurator.configuredEngine(userDefaults: UserDefaults) -> WebSearch`
  - `WebSearchConfigurator.searchAPIKeysEnabled(userDefaults: UserDefaults) -> Set<String>`
- UserDefaults key format: `wenshu.search.<key_name>` (= e.g. `wenshu.search.exa_api_key`)
- Empty / unset keys = provider skipped (= matches the v0.74 stub behavior)
- SEARXNG excluded (= requires endpoint URL, not API key; = future ticket)
- Per AGENTS.md §11.1: NO third-party deps

### Ticket 002 — WebSearchTool engine injection

- `WebSearchTool.init(engine:)` already exists (= the v0.74 ticket 003 design)
- New `WebSearchTool.configured()` factory method (= returns the Tool with the configured engine from UserDefaults)
- WenshuAppDelegate doesn't change for v0.76 (= the bootstrap already in v0.74 ticket 003 uses `WebSearch.shared`; = a v0.77 ticket will swap this for `WebSearchTool.configured()`)

## Cross-references

- `Sources/WenshuApp/Core/Agent/Web/WebSearch.swift` (= the actor this ticket feeds)
- `Sources/WenshuApp/Core/Agent/Web/Providers/*.swift` (= the 5 provider classes from v0.74)
- `Sources/WenshuApp/Core/Agent/Tool/WebSearchTool.swift` (= the LLM-facing wrapper)
- `AGENTS.md §11` (= API keys via AppleKeychain for production; = UserDefaults is the dev placeholder)

## Validation (= per Q34 step 4)

For each ticket:

1. `swift build` = BUILD COMPLETE
2. `swift build --target WenshuAppTests` = BUILD COMPLETE
3. New unit tests for Ticket 001 (= 6 cases: key name mapping / empty engine / single provider / multiple providers / enabled set / empty-string filtering)
4. Code-review 双轴 = Standards + Spec per Q146

## Final scope after v0.73 + v0.74 + v0.75 + v0.76 (= honest tally)

| Module | v0.73 | v0.74 | v0.75 | v0.76 |
|---|---|---|---|---|
| `SkillBundles` | Wired | Wired | Wired + YAML discovery | Wired |
| `CronjobTools` | Deferred | Deferred | Deferred | Deferred |
| `WebSearch` | Deferred (no providers) | Wired | Wired | **Wired + configured** |
| `AgentLifecycleTracker` | Deferred + design doc | Wired (Option B) | Wired | Wired |
| `ContextReferences` | Deferred | Deferred | Deferred | Deferred |

= 3 wired + 2 deferred. v0.76 adds the "configured engine" path on top of WebSearch wiring.

## Out-of-scope (= explicit, again)

- AppleKeychain migration (= v0.77+; = needs Settings UI)
- SEARXNG endpoint URL (= v0.77+; = separate config key)
- UI for API key entry (= v0.77+; = LLMConnector Settings pane)