# v0.40 architecture refactor — boss decision spec (boss 2026-09-05 OOB '好继续')

## Goal

Pick the next architectural refactor (= beyond the integration plan = 22 tickets ship done). This spec lists 4 candidate refactors; boss拍 which one to ship.

## Why now

- Integration plan (= 22 wire-up tickets) shipped today (= 2026-09-04 to 2026-09-05).
- HermesTodoStore lock-recursion bug fixed today (= FIX-TODO-LOCK-001).
- ~130 commits today, build clean, ~85+ tests pass.
- v0.40 (= current target per AGENTS.md) is the next milestone.
- Remaining work per wayfinder-plan `.scratch/2026-09-04-wenshu-integration-plan.md`:
  - v0.40 architecture refactor (Q1-Q8 boss decisions per .scratch/2026-09-04-apple-methodology/apple-self-check.md)
  - macOS 27 Liquid Glass polish (AGENTS.md §11 老板拍 chrome 优化)

## 4 candidate refactors (= boss拍 which 1)

### Option A — `Sources/WenshuApp/Core/Agent/Conversation/ConversationLoop.swift` refactor

**What**: ConversationLoop.swift is 5312 LOC after HERMES-PARTIAL-001 (= today). It mixes:
- System prompt assembly
- Context compression
- LLM call dispatch
- Tool execution
- Response parsing
- Progress emission

Refactor into 5 focused actor-per-concern modules:
- `PromptAssemblyActor`
- `ContextCompressionActor`
- `LLMDispatchActor`
- `ToolExecutionActor` (= wraps the existing ToolExecutor)
- `ResponseFinalizationActor`

`ConversationLoop` becomes the orchestrator that wires them.

**Effort**: M (= 3-4 days)

**Risk**: Medium (= public API changes; consumers like `WenshuConductor` need updates)

**Value**: High (= enables future per-concern unit testing + parallel progress tracking + context-isolated caching)

### Option B — `Sources/WenshuApp/Core/Provider/` unification

**What**: 7 connector profiles (Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter / minimax cn) ship today. They each implement `LLMConnector` but with duplicated request/response marshaling.

Refactor: extract shared `RequestHelpers` + `ResponseHelpers` (= already partly done by GAP-002 / commit `114a00c39`). Migrate all 7 profiles to use the helpers consistently. Add a generic streaming-event base class.

**Effort**: M (= 2-3 days)

**Risk**: Low (= public surface stays identical; just internal cleanup)

**Value**: Medium (= easier to add 8th profile + reduces drift over time)

### Option C — `Sources/WenshuApp/Core/Tools/` unification

**What**: ~12 LLM tools exist today (= FileTool / ProcessTool / VisionTool / WebTool / ParagraphAITool / TodoStoreTool / KanbanStoreTool / BookManagerTool / etc.). Each implements `Tool` protocol.

Refactor: extract a `ToolRegistry` actor (= single source of truth for tool name → tool instance lookup). Add a unified error envelope (= `ToolError` struct). Add tool metadata (= `ToolMetadata` struct with name / description / input schema).

**Effort**: M (= 2-3 days)

**Risk**: Low (= public surface stays identical)

**Value**: High (= enables dynamic tool discovery for the LLM + tool metadata introspection for CommandPalette UI)

### Option D — `Sources/WenshuApp/Core/Storage/` unification

**What**: ~6 storage backends today (= BookStore / KanbanStore / TodoStore / MemoryStore / ChatSessionStore / ForeshadowingTracker sidecar / etc.). They each use SQLite via GRDB but with inconsistent schema / migration / indexing.

Refactor: extract a `PersistenceActor` base class (= handles schema / migration / WAL / backup). Migrate all 6 stores to use it. Add a unified `PersistenceDirectory` resolution (= from `appState.libraryPath`).

**Effort**: L (= 4-5 days)

**Risk**: High (= data migration risk; must preserve existing user data)

**Value**: High (= enables per-library backup + cross-store queries + future encryption layer)

## Recommended

**Option C — ToolRegistry unification** (medium effort, low risk, high value).

Why C over the others:
- A is risky (public API changes; can wait)
- B is medium (cleanup; less urgent)
- **C enables the dynamic tool discovery for LLM + tool metadata for CommandPalette** = directly improves user-visible UX (= commands in CommandPalette show real tool descriptions from metadata)
- D is high effort (data migration) + boss拍 only when needed

## Out of scope for this spec

- v0.40 Liquid Glass polish (= separate ticket; AGENTS.md §11)
- v0.40 macOS 27 HIG alignment (= separate ticket)
- B-10 phase B (= AppleKeychainStore flip; separate ticket)

## Hard rules (= applies to whichever boss拍)

- English-only in all files.
- DO NOT touch AGENTS.md / CLAUDE.md / README.md / CHANGELOG.md.
- DO NOT introduce any new third-party dependency (= Apple stack exclusive per §11.1).
- The refactor MUST preserve all existing public surface (= `public` methods / properties / actor declarations unchanged from consumer's perspective).
- All existing tests MUST continue to pass after the refactor.

## Frontend verification dependency

None (= internal refactor; no UI changes).

*First line = fact. Last line = fact.*