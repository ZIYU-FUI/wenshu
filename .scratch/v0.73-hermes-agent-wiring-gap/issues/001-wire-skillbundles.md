# Issue 001 · Wire SkillBundles into ToolRegistry

**Ticket**: 001-wire-skillbundles
**Scope**: 1 file (= new SkillBundlesTool.swift) + 1 file (= registration site update)
**Methodology**: Q112 (1 ticket 1 commit 1 file) + Q34 step 4 (drive `/tdd` internally)

## Problem

`Sources/WenshuApp/Core/Agent/Skill/SkillBundles.swift` (= 1:1 port of hermes `skill_bundles.py` 438 LOC, shipped in TICKET-HERMES-GAP-006) defines the canonical `SkillBundles` actor + `SkillBundle` struct + `SkillBundlesError`. **No Tool wrapper exists** (= grep `ToolRegistry.shared.register` returns zero callers referencing `SkillBundles`).

The LLM cannot:
- List available bundles (= hermes `/bundle list` equivalent)
- Resolve a bundle's transitive skill dependencies
- Invoke `/bundle <name>` from the chat surface

## Decision (per spec.md §Acceptance)

**Wire.** Boss uses `/bundle` for slash-command aliasing in hermes; wenshu's `SkillKeywordRegistryBootstrap.swift` already has keyword matching but lacks bundle resolution.

## Plan

### 1. New file: `Sources/WenshuApp/Core/Agent/Tool/SkillBundlesTool.swift`

Mirrors the `KanbanStoreTool` / `BookManagerTool` pattern:

- `class SkillBundlesTool`
- `@Tool`-equivalent schema (= 4 actions: list / resolve / register / unregister)
- `ToolRegistrySchema` with `name: "skill_bundles"`, `toolset: "agent"`
- `Task { await ToolRegistry.shared.register(...) }` at file bottom (= self-registration per ToolRegistry.swift L34 pattern)
- `WenshuConductor.defaultToolNames` += `"skill_bundles"` (per WenshuConductor.swift L658 ordering convention)

### 2. Update file: `Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift`

Add `"skill_bundles"` to `defaultToolNames` array at L658 (= deterministic ordering).

## TDD plan

1. **Red**: write `Tests/WenshuAppTests/Core/Agent/Tool/SkillBundlesToolTests.swift` with 4 cases:
   - `testSkillBundlesList` (= list returns empty when no bundles registered)
   - `testSkillBundlesResolve` (= transitive deps resolve in dependency order)
   - `testSkillBundlesRegister` (= register then list = 1)
   - `testSkillBundlesCycle` (= dependency cycle → `SkillBundlesError.cycle`)
2. **Green**: implement `SkillBundlesTool` until all 4 tests pass.
3. **Refactor**: extract `SkillBundlesTool.Actions` enum + `SkillBundlesTool.Result` struct.

## Files changed (atomic per Q112)

- `Sources/WenshuApp/Core/Agent/Tool/SkillBundlesTool.swift` (new, ~200 LOC)
- `Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift` (+1 line in `defaultToolNames`)

## Commit message template

```
feat(wenshu): wire SkillBundles into ToolRegistry (= 1:1 hermes /bundle)

- New SkillBundlesTool (= 4 actions: list / resolve / register / unregister)
- Self-registers via ToolRegistry.shared.register at module import
- WenshuConductor.defaultToolNames += "skill_bundles"
- 4 unit tests added (list / resolve / register / cycle)

Refs: .scratch/v0.73-hermes-agent-wiring-gap/spec.md §Acceptance
Ticket: 001-wire-skillbundles
```

## Acceptance (per Q34 step 4 + spec §Validation)

- [ ] `swift build` = BUILD COMPLETE
- [ ] `swift build --target WenshuAppTests` = BUILD COMPLETE
- [ ] All 4 unit tests pass
- [ ] `WenshuConductor.defaultToolNames.count` = 13 (= was 12)
- [ ] `ToolRegistry.shared.listTools()` includes `skill_bundles`
- [ ] Code-review 双轴 = Standards pass + Spec pass

## Out-of-scope

- Hermes-port golden parity test update (= separate ticket, deferred to v0.73 batch 2)
- `WenshuConductor.swift` schema enum update (= separate ticket, deferred)
- Wenshu-side bundle YAML discovery (= future ticket; = uses existing SkillRegistry surface per AGENTS.md §11.3)