# ADR-0009: wenshu-side wins (= hermes port is thin adapter, NOT replacement)

> Status: accepted
> Date: 2026-09-03
> Decision-maker(s): 老板 (Q19 of grilling round 3, 拍板)

## Context

Pre-v0.35, wenshu had 2,182 LOC of agent code (= 13 files under `Sources/WenshuApp/Core/Agent/`) covering: WenshuVerifier (L282-339 = `send(request:outputKind:extraSystemPrompt:)` 58-LOC send + Min-Max-Anthropic native wire), WenshuAgentIdentity, AgentProtocol, AgentRuntime, AgentLifecycleTracker, AsyncDelegation, OutputKind, SubAgentIdentity, SubAgentPermissions, WenshuLLMModel, WenshuLLMModelFetcher, WenshuVerifierKeyNote, WenshuConductor.

The v0.35 hermes-core-translation project (= boss Q1 拍 = "hermes 核心 agent 相关的所有") ports hermes' agent core (= 93,837 LOC Python, 116 files) to Swift, as the agent layer for wenshu. Five wenshu existing modules overlap with hermes ported layer:

- `Core/Tools/FileTools.swift` + `ProcessTools.swift` + `AVMediaTools.swift` ↔ `Core/Agent/Tool/ReadFileTool.swift` + `WriteFileTool.swift`
- `Core/Provider/ProviderKeychain.swift` ↔ `Core/Agent/Connector/ConnectorCredentials.swift`
- `Core/Memory/MemoryManager.swift` + `MemoryProvider.swift` + `MemoryConsolidator.swift` ↔ `Core/Agent/Memory/MemoryManager.swift` + `MemoryProvider.swift` + `MemoryStore.swift`
- `Core/Skills/SkillMeta.swift` + `SkillRegistry.swift` ↔ `Core/Agent/Skill/SkillUtils.swift` + `SkillPreprocessing.swift` + `SkillCommands.swift` + `SkillBundles.swift`
- `Core/Chat/ChatSessionStore.swift` ↔ `Core/Agent/Conversation/ConversationLoop.swift`

The fundamental question: **when hermes port and wenshu existing module overlap, who wins**?

## Decision

**wenshu-side wins** (= ADR-0009). The existing wenshu module is preserved; the hermes port is a thin adapter (= delegation pattern) that delegates to the wenshu module. The port DOES NOT re-implement the wenshu-side behavior. Code duplication is forbidden.

Three constraints flowing from this decision:

1. **Ticket boundary**: Every ticket that touches one of the overlap pairs (= see Context section) MUST state in its PR body: "this PR uses wenshu-side wins pattern: [list wenshu modules it delegates to]". `/code-review` rejects any ticket that re-implements wenshu-side behavior.

2. **Existing-code rename** (per spec §3.5): ticket 001 renames 12 existing files under `Core/Agent/` into the new sub-directory structure (`Conversation/` + `Connector/` + `Tool/` + `Memory/` + `Skills/`). Renames happen BEFORE any new module is added. `git mv` preserves blame.

3. **Future hermes-side wins requires explicit 老板拍**: Any future ticket proposing "hermes port replaces wenshu-side" requires explicit boss拍. Default = wenshu-side wins. No silent replacement.

Five concrete examples (from spec §3.6):

- **ConnectorCredentials ↔ ProviderKeychain**: `ConnectorCredentials` is a thin adapter over `ProviderKeychainStoring` (= existing `Core/Provider/ProviderKeychain.swift`). Reuses `AppleKeychainStore.loadKeySync(for:)` directly. No duplicate `kSecClassGenericPassword` setup.
- **ReadFileTool / WriteFileTool ↔ FileTools**: `ReadFileTool` / `WriteFileTool` thin async wrappers over `Core/Tools/FileTools.swift` (= existing sync read/write atomic). Boss Q14 拍 "thin wrapper" pattern.
- **MemoryAdapter ↔ MemoryManager**: `MemoryAdapter` thin adapter over `Core/Memory/MemoryManager.swift` (= existing actor with `prefetch/sync/write gate`). Reuses `MemoryWriteGate` + `MemoryConsolidator` (= ticket 013.001 / 013.005).
- **SkillAdapter ↔ SkillRegistry**: `SkillAdapter` thin adapter over `Core/Skills/SkillRegistry.swift` (= existing actor with list/load/invoke). Reuses `SkillTrustLevel` + `SkillQuarantine` (= ticket 013.008).
- **ContextEngine ↔ Core/Memory**: `ContextEngine` thin facade over `Core/Memory/*`. Delegates prefetch + sync to existing actor.

## Consequences

**Easier**:
- Code reuse (= 9,500 LOC wenshu Core preserved, no duplicate write)
- Bug surface smaller (= one implementation, not two)
- MemoryManager / SkillRegistry / FileTools have been battle-tested in v0.18-v0.34 (= 4 years of in-the-wild fixes)
- Test stability (= wenshu Core tests continue to pass; hermes port tests run on top)
- Boss's "boss 拍 vs agent re-implementation" friction = minimized (= hermes port doesn't pretend to replace)

**Harder**:
- Architectural split (= hermes port assumes wenshu Core = stable API; if Core changes, port must re-delegate)
- Naming inconsistency (= hermes Python names vs wenshu Swift names = bridge; e.g. `MemoryConsolidator` ↔ hermes `MemoryStore`)
- Documentation overhead (= must document wenshu-side wins per ticket)

**Locked in**:
- wenshu Core modules are the canonical implementation (= `Core/Provider`, `Core/Tools`, `Core/Memory`, `Core/Skills`, `Core/Chat`)
- `Core/Agent/` (= the hermes port) is a thin adapter layer (= cannot modify wenshu Core from inside Core/Agent)
- Future "hermes port replaces wenshu-side" proposals require explicit boss拍

## Alternatives considered

1. **hermes-side wins** (= hermes port is the canonical implementation, wenshu Core = thin adapter): Rejected. Boss Q19 explicit "我决策落盘" = "adapter / 加东西, 不 delegate / 替换". Code duplication prohibited.
2. **No overlap (= keep both hermes port and wenshu Core as parallel implementations)**: Rejected. Code duplication prohibited (= boss Q19). Maintenance burden too high (= two memory systems, two skill registries = drift inevitable).
3. **Replace wenshu Core entirely with hermes port**: Rejected. v0.18-v0.34 wenshu Core has 4 years of in-the-wild fixes (= boss拍 decisions, edge cases). Wholesale replacement would lose battle-tested behavior.
4. **Hybrid (= hermes port where wenshu has no implementation, wenshu-side where both exist)**: Accepted as default (= this ADR).

## Cross-references

- AGENTS.md §11.3 agent ↔ other Core module interaction principle
- spec.md §3.5 / §3.6 (= 12-file rename plan + 5 actor interface true-values)
- tickets 001 sub-step 6 (= ReadFileTool + WriteFileTool wenshu-side wins example) + 006 (= ConnectorCredentials wenshu-side wins) + 009 (= MemoryAdapter wenshu-side wins) + 010 (= SkillAdapter wenshu-side wins)
- ADR-0008 (7-connector BYOK, depends on wenshu-side wins for ConnectorCredentials)
- ADR-0012 (Scope B)