# v0.80 Item 6 + Item 8 strict · Blocked + Spec

**Branch**: `wt/v0.80-keychain-and-repowise-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "清单改完了吗"

## Context

Boss 2026-09-14 OOB asked "清单改完了吗" (= "did you finish the checklist?"). My honest answer: **no, 3 items still open**:

- **Item 6**: repowise update (= MCP tool; = requires boss's MCP environment)
- **Item 8 strict**: ProviderKeychain wire (= v0.76 used UserDefaults; = the strict reading of item 8 was "use AppleKeychain")
- **Item 10**: WorkspaceView / NavigationSplitShell / PreviewPane tests (= design doc only; = real test work deferred to v0.78+)

This spec addresses item 6 + item 8 strict. Item 10 is unchanged.

## Item 6 = BLOCKED

`repowise` is a private MCP server (= configured via `.mcp.json`). It's not on PyPI
(= `pip3 install repowise` fails). The local Python environment doesn't have
access to the MCP server.

To trigger a repowise re-index, the boss's MCP-enabled environment is required
(= the MCP server runs in Hermes runtime, not in this shell). Per Q46
(boss 2026-08-21 "≥3 redo commits must stop + list real cause + await boss拍"):
I cannot complete item 6 without boss-environment.

**Action**: write this spec + document the blocker. Boss can re-run repowise update
from their MCP-enabled terminal.

## Item 8 strict = AppleKeychain migration for WebSearch API keys

v0.76 used UserDefaults for web search API keys (= `wenshu.search.exa_api_key`).
This is the **dev path** — works for testing but doesn't meet AGENTS.md §11
which mandates `AppleKeychain` for API keys.

This ticket = migrate the keys to AppleKeychain via the existing
`ProviderKeychain` shim (= v0.74 spec: API keys via ProviderKeychain).

### Implementation

1. Add `ProviderKeychain.saveSearchAPIKey(provider: String, key: String)` method
   (= wraps the existing `ProviderKeychain.saveMetadata(...)` with the right key namespace)
2. Add `ProviderKeychain.loadSearchAPIKey(provider: String) -> String?`
3. Update `WebSearchConfigurator.configuredEngine()` to read from ProviderKeychain
   instead of UserDefaults (= replace `userDefaults.string(forKey:)` with
   `ProviderKeychain.loadSearchAPIKey(for: provider)`)
4. Migrate UserDefaults → AppleKeychain on first launch (= if `wenshu.search.<key>`
   exists in UserDefaults, move it to AppleKeychain and delete the UserDefaults entry)
5. Update `searchAPIKeysEnabled()` accordingly
6. Update tests to use ProviderKeychain test backend (= `InMemoryKeychainStore`
   from the existing `Core/Provider/AppleKeychainStore.swift` test surface)

### Acceptance

- [ ] `swift build` = BUILD COMPLETE
- [ ] `swift build --target WenshuAppTests` = BUILD COMPLETE
- [ ] All v0.76 WebSearchConfigurator tests still pass (= 6 cases)
- [ ] New tests for ProviderKeychain search key methods (= 4 cases)
- [ ] UserDefaults migration runs on first launch (= logged)
- [ ] Manual smoke: existing `wenshu.search.*` UserDefaults keys migrate to
      AppleKeychain on next launch; = new keys go directly to AppleKeychain
- [ ] Code-review 双轴 = Standards + Spec per Q146

## Item 10 = unchanged (= deferred to v0.78+ per v0.77 spec)

## Cross-references

- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (= existing keychain shim)
- `Sources/WenshuApp/Core/Provider/AppleKeychainStore.swift` (= Apple HIG keychain wrapper)
- `Sources/WenshuApp/Core/Agent/Web/WebSearchConfigurator.swift` (= the v0.76 module to update)
- `AGENTS.md §11` (= "API keys via AppleKeychain for production")

## Final tally after v0.73 + v0.74 + v0.75 + v0.76 + v0.77 + v0.78 + v0.79 + v0.80

| Module | Status |
|---|---|
| `SkillBundles` | Wired + YAML discovery |
| `CronjobTools` | Deferred (= per §11.2) |
| `WebSearch` | Wired + providers + UserDefaults config (v0.80 = Keychain migration) |
| `AgentLifecycleTracker` | Wired (Option B) |
| `ContextReferences` | Deferred (= per §11 single-shelf model) |

| Checklist item | Status |
|---|---|
| 1. v0.73 dead code grep | ✅ |
| 2. v0.73 hermes-port inventory | ✅ |
| 3. v0.73 wire SkillBundles | ✅ |
| 4. v0.74 wire WebSearch + providers | ✅ |
| 5. v0.74 wire AgentLifecycleTracker | ✅ |
| 6. repowise update | ❌ **BLOCKED on boss MCP environment** |
| 7. v0.75 SkillBundles YAML discovery | ✅ |
| 8. WebSearch ProviderKeychain | ⚠️ **partial**: v0.76 used UserDefaults; v0.80 (this ticket) migrates to Keychain |
| 9. SQLite3 audit | ✅ |
| 10. WorkspaceView tests | ⚠️ **design doc only** (= v0.78+ real test work) |
| 11. LibraryMigrator shotgun surgery | ✅ (= historical artifact, no action needed) |