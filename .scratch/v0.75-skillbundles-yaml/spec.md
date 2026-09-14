# v0.75 SkillBundles YAML Discovery · Spec

**Branch**: `wt/v0.75-skillbundles-yaml-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "正常推进" + "跑到问题清单清完"

## Context

v0.73 spec §Acceptance row "SkillBundles" deferred YAML discovery as future work (= see `Sources/WenshuApp/Core/Agent/Skill/SkillBundles.swift` doc comment line 17: "Future tickets can add YAML discovery on top of `register(_:)` without changing the public surface").

v0.74 shipped `WebSearch.shared` + 5 providers + `WebSearchTool` (= 6 commits, 12 files).
v0.75 = the SkillBundles YAML discovery continuation.

## Scope (= 2 tickets, 1 file 1 commit each per Q112)

| # | Ticket | File(s) | LOC estimate | Dependency |
|---|---|---|---|---|
| 1 | `001-skillbundles-yaml-discovery` | `Sources/WenshuApp/Core/Agent/Skill/SkillBundlesYAMLDiscovery.swift` (= parser + directory scanner) + `Tests/WenshuAppTests/Core/Agent/SkillBundlesYAMLDiscoveryTests.swift` | ~290 LOC + ~180 LOC tests | None (= standalone) |
| 2 | `002-skillbundles-bootstrap-on-launch` | `Sources/WenshuApp/App/WenshuAppDelegate.swift` (= invoke discover() at launch) | ~10 LOC | Ticket 1 |

Out of scope (= explicit):

- Bundle YAML schema extensions (= nested objects, multi-line strings)
  (= = over-engineering for the v0.74 schema; = matches hermes YAML subset)
- Bundle hot-reload watcher (= FSEvent-based; = separate ticket, future work)
- Bundle editing UI (= separate ticket, future work)
- SkillBundles wire to existing SkillRegistry surface (= stays decoupled per
  AGENTS.md §11.3 wenshu-side wins pattern; SkillBundles is its own thin
  adapter over the actor)

## Per-ticket acceptance criteria

### Ticket 001 — YAML discovery module

- New file: `Sources/WenshuApp/Core/Agent/Skill/SkillBundlesYAMLDiscovery.swift`
- Public API:
  - `SkillBundlesYAMLDiscovery.discover(into:from:) -> Int` (= main entry)
  - `SkillBundlesYAMLDiscovery.defaultDirectory() -> URL`
  - `SkillBundlesYAMLDiscovery.parseYAML(at:) -> SkillBundleYAML`
  - `SkillBundlesYAMLDiscovery.parseYAMLString(_:sourceFile:) -> SkillBundleYAML`
  - `SkillBundlesYAMLDiscoveryError` enum (= 4 cases: directoryNotFound / missingField / duplicateID / malformedYAML)
- Directory resolution order:
  1. `$WENSHU_BUNDLES_DIR` env var override
  2. `~/Library/Application Support/wenshu/skill-bundles/`
  3. `~/.wenshu/skill-bundles/`
- YAML schema (= matches hermes subset):
  ```
  id: alpha
  name: Alpha Bundle
  skill_ids:
    - skill-a
    - skill-b
  dependencies:
    - core-libs
  ```
- First-launch UX: missing directory = return 0 (= no error, no bundles registered)
- Per Q34: log + continue on malformed file (= don't crash)
- Per AGENTS.md §11.1: NO third-party YAML library (= Foundation only)

### Ticket 002 — Bootstrap on app launch

- `WenshuAppDelegate.applicationDidFinishLaunching` calls `SkillBundlesYAMLDiscovery.discover(into: SkillBundles.shared)` after `SkillKeywordRegistryBootstrap` (= matches the existing bootstrap pattern)
- Failure-tolerant (= wrap in `do/catch` so a malformed YAML never blocks app launch)
- Documented in delegate header

## Cross-references

- `Sources/WenshuApp/Core/Agent/Skill/SkillBundles.swift` (= the actor this ticket adds discovery on top of)
- `Sources/WenshuApp/Core/Skills/SkillKeywordRegistryBootstrap.swift` (= existing bootstrap pattern reference)
- `Sources/WenshuApp/App/WenshuAppDelegate.swift` (= bootstrap call site)
- `AGENTS.md §11.3` (= wenshu-side wins pattern: thin adapter)
- `AGENTS.md §11.1` (= no third-party deps; Foundation only)

## Validation (= per Q34 step 4)

For each ticket:

1. `swift build` = BUILD COMPLETE
2. `swift build --target WenshuAppTests` = BUILD COMPLETE (= zero regressions)
3. New unit tests for Ticket 001 (= 11 cases: parsing + discovery + malformed recovery)
4. Manual smoke (= launch app, place a YAML file in the directory, verify registration)
5. Code-review 双轴 = Standards + Spec per Q146

## Final scope after v0.73 + v0.74 + v0.75 (= honest tally per Q239)

| Module | v0.73 | v0.74 | v0.75 |
|---|---|---|---|
| `SkillBundles` | Wired | Wired | **Wired + YAML discovery** |
| `CronjobTools` | Deferred | Deferred | Deferred (= per §11.2) |
| `WebSearch` | Deferred (no providers) | Wired | Wired |
| `AgentLifecycleTracker` | Deferred + design doc | Wired (Option B) | Wired |
| `ContextReferences` | Deferred | Deferred | Deferred (= per §11 single-shelf model) |

= 3 wired + 2 deferred (= same as v0.74; = v0.75 only adds YAML discovery on top of SkillBundles).

## Out-of-scope (= explicit, again)

- FSEvent hot-reload (= separate ticket, future work)
- Bundle editing UI (= separate ticket, future work)
- WebSearch provider key wiring via ProviderKeychain (= v0.76 scope; needs user-supplied API keys)