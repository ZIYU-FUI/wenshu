# Hermes Agent Wiring Gap · v0.73

**Branch**: `wt/v0.73-hermes-wiring-gap-2026-09-14`
**Generated**: 2026-09-14
**Author**: pocock
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146

## Context

Boss 2026-09-14 OOB confirmation: "我们迁移了两回, 早期的一回漏接很普遍, 后来又迁移了一次, 你看是否有新文件替代".

## Two-pass migration timeline (= ground truth from `git log --grep`)

| Pass | Commit prefix | Date | Scope | Wiring pattern |
|---|---|---|---|---|
| Round 1 | `HERMES-PARTIAL-001` → `018` | 2026-08/09 | agent internals (= ConversationLoop, ToolExecutor, AsyncDelegation, AnthropicAdapter, OpenAI compat, etc.) | Partial: 1:1 port without ToolRegistry wire-up |
| Round 2 | `TICKET-HERMES-GAP-001` → `006` | 2026-09-04 | leakage backfill (= SkillBundles, SecretScope, ToolDispatchHelpers, ShellHookChain, SkillAdapter, PromptBuilder) | Partial: thin adapter over existing wenshu-side surface |
| Round 3 | `HERMES-INTERNAL-001` → `009` | 2026-09-04 | hermes-internal (= WebSearch, CodingContext, ReasonScrub, SSLGuard, CuratorBackup, IterationBudget, ManualCompressionFeedback, TitleGenerator, Redactor) | Stub-only; some wired into ConversationLoop internals |
| Round 4 | `HERMES-DISPATCH-001` → `004` | 2026-09-04 | connector layer (= AuthPool, FallbackChain, KeychainSelector, AutoRotation) | Wired through `ConnectorCredentials` + `AuxiliaryClient` |

## Post-Round-2 actual LLM tool surface (ground truth)

Per `rg "ToolRegistry\.shared\.register\(" Sources/WenshuApp` (= 12 callers):

```
book_manager        Core/Agent/Librarian/BookManagerTool.swift
kanban              Core/Agent/Tool/KanbanStoreTool.swift
ParagraphAI         Core/Agent/Tool/ParagraphAITool.swift
ReadFile            Core/Agent/Tool/ReadFileTool.swift
WriteFile           Core/Agent/Tool/WriteFileTool.swift
todo                Core/Agent/Tool/TodoStoreTool.swift
todo_hermes         Core/Agent/Todo/HermesTodoTool.swift    (= HERMES-PARTIAL Round 2)
av                  Core/Tools/AVMediaTools.swift
file                Core/Tools/FileTools.swift
process             Core/Tools/ProcessTools.swift
vision              Core/Tools/VisionTools.swift
web                 Core/Tools/WebTools.swift                (= URL fetch only, NOT the WebSearch port)
```

## Inventory diff (= the actual gap)

### A. Modules written but never wired into LLM tool surface (= 3 files, all Round 1/3 ports)

| Module | Source file | LOC | Hermès counterpart | Original round |
|---|---|---|---|---|
| `SkillBundles` | `Sources/WenshuApp/Core/Agent/Skill/SkillBundles.swift` | ~160 | `agent/skill_bundles.py` (438 LOC) | Round 2 (TICKET-HERMES-GAP-006) |
| `CronjobTools` | `Sources/WenshuApp/Core/Agent/Cron/CronjobTools.swift` | ~360 (= 1:1 port of 1,137 LOC hermes) | `tools/cronjob_tools.py` | Round 1 (HERMES-PARTIAL-010) |
| `WebSearch` | `Sources/WenshuApp/Core/Agent/Web/WebSearch.swift` | ~180 (= 1:1 port of 180 LOC hermes) | `web_search.py` + `web_search_provider.py` | Round 3 (HERMES-INTERNAL-001) |

### B. Modules written but undecided whether to wire (= 2 files)

| Module | Source file | LOC | Hermès counterpart | Decision needed |
|---|---|---|---|---|
| `AgentLifecycleTracker` | `Sources/WenshuApp/Core/Agent/Conversation/AgentLifecycleTracker.swift` | ~580 | `agent/agent_runtime_helpers.py` (subset) | Per boss 2026-09-04 OOB 'agent_init' may be auto-pilot only; check whether UI needs this surface |
| `ContextReferences` | `Sources/WenshuApp/Core/Agent/Conversation/ContextReferences.swift` | ~300 | `agent/context_references.py` (598 LOC) | Per HERMES-PARTIAL-014 commit msg: "ContextEngine bundle assembly + token state" is wired; the cross-file graph is not used anywhere in ContextEngine today |

### C. Modules confirmed wired (= avoid false positives from Round 1 inventory)

| Module | Why false-positive in pre-Round-2 audit | Round that wired it |
|---|---|---|
| `ToolDispatchHelpers` | Round 2 (TICKET-HERMES-GAP-??) | Round 2 |
| `ShellHookChain` | Round 2 (renamed + replaced per `1ce68c0ea HERMES-DISPATCH follow-up`) | Round 2 |
| `SkillAdapter` | 35 do_* hub commands | Round 2 (HERMES-PARTIAL-017) |
| `AuxiliaryClient` | Used by AnthropicStreaming SSECoalescer + OpenAIConnector | Round 1 (HERMES-PARTIAL-002) |
| `SecretScope` | Embedded inside `ProviderKeychain` (= EnvVar + Keychain source) | Round 2 (TICKET-HERMES-GAP-005) |
| `ModelMetadata` | Used by `ProviderProfileExt` (`WenshuModelCatalog.defaultModelsForProvider`) | Round 1 (HERMES-PARTIAL-015) |

## Acceptance criteria (= Q34 5.4 + boss 9/4 OOB "工作树干完")

For each of the 5 modules in §A + §B, this spec answers:

1. Should the module be wired into LLM tool surface (= `ToolRegistry.shared.register`)?
   Or kept as internal-only (= Round 1 hermes-port-missing pattern is acceptable)?
2. If wired: which Tool class wraps it (= 1 file 1 commit per Q112 / Q124)?
3. If NOT wired: is the Swift file worth keeping (= dead code or doc-referenced)?

### Per-module decision matrix

| Module | Wire decision | Rationale | Owner ticket |
|---|---|---|---|
| `SkillBundles` | **Wire** (= scope of v0.73) | Boss uses `/bundle` for slash-command aliasing in hermes; wenshu SkillKeywordRegistryBootstrap exists but lacks bundle resolution; without wiring, `/bundle` is a silent stub | issue 001 |
| `CronjobTools` | **Defer** (= out of scope) | Per boss 9/4 OOB 'A': cron = wenshu-side wins (= LaunchAgent, not hermes's cross-process claim/lock); the LLM-side cron dispatcher is over-engineering for v0.73 since wenshu cron runs at OS level | issue 002 (= keep file, mark as deferred, NOT deleted) |
| `WebSearch` | **Defer** (= spec re-check 2026-09-14) | Boss 9/4 OOB 'A' approved multi-provider rotation; however hermes-port shipped actor shell without any provider implementations (= EXAProvider/TAVILYProvider/BRAVEProvider/PARALLELProvider/SEARXNGProvider = zero hits in Sources/). Adding the providers is a separate 5-ticket scope; = v0.74+ | issue 003 (revised) |
| `AgentLifecycleTracker` | **Defer + spec the surface** | Sub-agent heartbeat belongs to the WenshuConductor / SubAgentProgressView UI layer; today the UI lives in `SubAgentProgressView.swift` which reads a different in-memory state (= refactor risk); needs separate spec | issue 004 (= design-doc only, no code) |
| `ContextReferences` | **Defer** | `ContextEngine.swift` does NOT use `ContextReferences` (= per HERMES-PARTIAL-013 + 014 commit chain); the cross-session graph is over-implementation for wenshu's single-shelf model (= §11 baseline) | issue 005 (= keep file, mark as deferred, NOT deleted) |

### Out-of-scope (explicit)

- Deleting the 5 Swift files (= NO deletion tickets; = files remain as documented future work).
- Re-running the Round 2/3/4 wiring (= those commits are immutable; = spec acknowledges them as ground truth).
- Adding new hermes modules beyond the existing 43 (= per spec §2.1 + §2.2 scope).

## Cross-references

- `AGENTS.md` §11.3 (wenshu-side wins pattern + thin adapter discipline)
- `AGENTS.md` §11.2 (7-connector BYOK architecture; cronjob = macOS LaunchAgent per boss 9/4)
- `.scratch/2026-09-03-hermes-core-translation/spec.md` §3.1 (43 hermes modules enumerated)
- `.scratch/2026-09-03-hermes-core-translation/hermes-port-manifest.md` (coverage tally)
- `.scratch/2026-09-04-hermes-port-gap-audit.md` (parallel gap audit at 2026-09-04)
- `Sources/WenshuApp/Core/Agent/Tool/ToolRegistry.swift` L34 (canonical `ToolRegistry.shared.register(...)` site)
- `Sources/WenshuApp/Core/Agent/Conversation/WenshuConductor.swift` L636 + L658 + L689 (MIGRATE-TOOLREGISTRY-002 + default-tool-names ordering)

## Validation

For each "Wire" module in §Acceptance:

1. `swift build` = BUILD COMPLETE
2. `swift build --target WenshuAppTests` = BUILD COMPLETE
3. Unit tests for new Tool class = at least 1 positive + 1 negative case
4. Hermes-port golden parity test = updated to reference the new Tool wrapper
5. Code-review 双轴 = Standards axis (vs `ToolRegistry` pattern + Apple HIG) + Spec axis (vs this spec.md acceptance criteria)

## Files in this spec scope

- `.scratch/v0.73-hermes-agent-wiring-gap/spec.md` (this file)
- `.scratch/v0.73-hermes-agent-wiring-gap/issues/001-wire-skillbundles.md`
- `.scratch/v0.73-hermes-agent-wiring-gap/issues/002-defer-cronjobtools.md`
- `.scratch/v0.73-hermes-agent-wiring-gap/issues/003-wire-websearch.md`
- `.scratch/v0.73-hermes-agent-wiring-gap/issues/004-spec-agent-lifecycle.md`
- `.scratch/v0.73-hermes-agent-wiring-gap/issues/005-defer-context-references.md`