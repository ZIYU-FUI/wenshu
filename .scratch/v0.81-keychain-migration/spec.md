# v0.81 WebSearch API Keychain Migration · Spec

**Branch**: `wt/v0.81-keychain-migration-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "继续"

## Context

v0.73-v0.80 wired hermes ports into LLM tool surface. v0.76 used
UserDefaults for web-search API keys (= dev path; = the AGENTS.md §11
mandate to use AppleKeychain was deferred per v0.80 spec).

v0.81 = migrate WebSearch API keys from UserDefaults to AppleKeychain,
add the missing test surface, and ship the production-ready path.

## Scope (= 2 tickets, 1 file 1 commit each per Q112)

| # | Ticket | File(s) | LOC | Dependency |
|---|---|---|---|---|
| 1 | `001-search-api-keychain` | `Sources/WenshuApp/Core/Provider/SearchAPIKeychain.swift` (= Apple Keychain backend for search keys) + tests | ~280 LOC + ~210 LOC tests | None (= standalone) |
| 2 | `002-websearch-configurator-migrate` | `Sources/WenshuApp/Core/Agent/Web/WebSearchConfigurator.swift` (= UserDefaults → Keychain migration) | ~30 LOC change | Ticket 1 |

Out of scope (= explicit):

- SEARXNG endpoint URL config (= needs separate config key, future ticket)
- Apple Developer Program paid enrollment (= B-10 phase B, future)
- UI for API key entry (= v0.82+ scope; = LLMConnector Settings pane)

## Per-ticket acceptance criteria

### Ticket 001 — SearchAPIKeychain module

- New file: `Sources/WenshuApp/Core/Provider/SearchAPIKeychain.swift`
- Public API:
  - `protocol SearchAPIKeychainStoring` (= saveKey / loadKey / deleteKey / listConfiguredProviders)
  - `final class AppleSearchKeychainStore: SearchAPIKeychainStoring` (= production Apple Keychain via Security framework)
  - `final class InMemorySearchKeychainStore: SearchAPIKeychainStoring` (= test backend)
  - `enum SearchAPIKeychain` (= backwards-compat shim with `backend` + `setBackendForTesting`)
- Service identifier: `"wenshu.search"` (= separate namespace from LLM keys = "wenshu.providers")
- Per AGENTS.md §11: API keys via AppleKeychain in production
- Per AGENTS.md §11.1: NO third-party deps (= Foundation + Security only)

### Ticket 002 — WebSearchConfigurator migration

- `WebSearchConfigurator.configuredEngine()` reads from `SearchAPIKeychain.loadKey(for:)`
- `WebSearchConfigurator.searchAPIKeysEnabled()` reads from `SearchAPIKeychain.listConfiguredProviders()`
- First-launch migration: if `wenshu.search.<key_name>` exists in
  UserDefaults (= legacy v0.76 dev path), move it to SearchAPIKeychain
  and delete the UserDefaults entry
- Old `WebSearchConfiguratorTests` (= UserDefaults-based) = deleted (= replaced by `SearchAPIKeychainTests`)

## Cross-references

- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= existing keychain pattern)
- `Sources/WenshuApp/Core/Agent/Web/WebSearchConfigurator.swift` (= the v0.76 module to update)
- `Sources/WenshuApp/Core/Agent/Web/WebSearch.swift` (= the WebSearch actor)
- `AGENTS.md §11` (= API keys via AppleKeychain for production)

## Validation (= per Q34 step 4)

For each ticket:

1. `swift build` = BUILD COMPLETE
2. `swift build --target WenshuAppTests` = BUILD COMPLETE (= zero regressions)
3. New unit tests for Ticket 001 (= 10 cases: save/load/delete/list + empty-key + setBackendForTesting + UserDefaults migration + SEARXNG exclusion + enabled set)
4. Existing v0.76 WebSearchConfiguratorTests = deleted (= signature changed; = replaced by SearchAPIKeychainTests)
5. Code-review 双轴 = Standards + Spec per Q146

## Final scope after v0.73 + v0.74 + v0.75 + v0.76 + v0.77 + v0.78 + v0.79 + v0.80 + v0.81

| Module | Status |
|---|---|
| `SkillBundles` | Wired + YAML discovery + AppleKeychain (LLM-style) |
| `CronjobTools` | Deferred (= per §11.2) |
| `WebSearch` | Wired + 5 providers + UserDefaults→AppleKeychain migration |
| `AgentLifecycleTracker` | Wired (Option B) |
| `ContextReferences` | Deferred (= per §11 single-shelf model) |

**Item 8 strict from v0.80 = ✅ DONE**: AppleKeychain migration lands.

## Out-of-scope (= explicit)

- SEARXNG endpoint URL config (= future ticket)
- UI for API key entry (= LLMConnector Settings pane)
- Migrating FullTextSearch (= different surface, separate ticket)
- Adding more providers (= current 5 are complete)