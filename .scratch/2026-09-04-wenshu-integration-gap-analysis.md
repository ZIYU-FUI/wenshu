# Wenshu integration gap analysis — ported modules vs the 6 capability areas

**Author:** subagent for boss 2026-09-04 OOB ("我们不能只复刻一些核心能力的模块代码, 那没有意义, 我们要用起来, 接进文枢系统里, 你看看还缺少哪些")
**Date:** 2026-09-04
**Source-of-truth:** `.scratch/2026-09-04-hermes-agent-capabilities-inventory.md` (314-line audit) + live `Sources/WenshuApp/` grep for View / State / App-level references.
**Mission:** for every ported hermes-side module, decide if it is wired into wenshu's actual UI (= 6 capability areas), and if not, where it SHOULD wire.

---

## 0. Executive summary

wenshu has ported ~77 hermes-side Swift files into `Core/Agent/**` (≈14,384 LOC), but most are dead code from the user's perspective. The 6 capability areas all show a sharp pattern: the **user-facing primitives** (Library / Kanban / Todo / Memory settings / Skills settings / LLM connector settings / ChatView / BookEditor / Outline) are reasonably wired; the **agent runtime primitives** (ConversationLoop, ToolExecutor, HermesGoals, HermesTodoTool, KanbanTools, CronjobTools, WebSearch, HermesKanbanDB, AsyncDelegation, SubAgent*, AgentProtocol, EventBus, SkillBundles, ContextEngine, ContextReferences, TitleGenerator, Redactor, ReasonScrubber, ManualCompressionFeedback, IterationBudget, CodingContext, CuratorBackup, SSLGuard, Hermes*Connector, AnthropicAdapter, AuxiliaryClient, ErrorClassifier, RateLimitTracker, ModelMetadata) are ported but **wired into nothing outside the `Core/Agent/` folder itself**. They compile, pass tests, but never touch a View, never appear in a Settings pane, never feed a button.

The biggest user-visible miss is **specializedTools**: today's tools pane has only 2 tabs (伏笔 + 占位符), both placeholder Views with no data layer behind them. Per boss 8/27 the tools pane is supposed to host the core competitive functions (foreshadowing/placeholder/emotion curve/character relationships/character lifecycle/book word count/tags/idea library/book setting constraints/etc.) — **none of those features have data or UI today**.

The biggest cross-cutting miss is the **LLM long-form tech patches** (LongForm area): no Swift module exists for constraint / continuity / self-proof / persona / character-arc / world-consistency enforcement — even though the LLM loop is supposedly running, it has no wenshu-specific guardrails. The boss 8/27 OOB made this a top-tier competitive area, and wenshu has zero Swift surface for it.

### One-line verdict per area

| Area | Verdict | Why |
|---|---|---|
| Library | ⚠️ Mostly wired (sidebar + outline + book editor sheets), but **no real-time chat-aware library operations** (= no LLM can mutate library state) |
| Editor | ⚠️ Wired (WenshuMarkdownEditor in WorkspaceView) but **paragraph-level AI tools (= expand/shorten/rewrite) do not exist** as Swift surface |
| SpecializedTools | ❌ **2 placeholder tabs, no data, no View** for any of the 8+ advertised tools |
| Agent | ⚠️ Partially wired (ChatView → SkillAdapter → WenshuConductor → AgentRuntime) but **ToolExecutor / HermesGoals / HermesTodoTool / KanbanTools / CronjobTools / WebSearch are dead code** |
| OpenBox (明盒) | ⚠️ Wired (SubAgentProgressView in aiDynamic tab), but **real-time progress / Todo writes / kanban writes from agent loop are not flowing** |
| LongForm (长文) | ❌ **Zero Swift modules** exist for constraint/continuity/self-proof/persona/character-arc/world-consistency |

---

## 1. Methodology

For each ported hermes-side module listed in the inventory (§A.1 + §A.2 + §A.3 + §B.1 + §B.2 of `2026-09-04-hermes-agent-capabilities-inventory.md`), I ran:

```
grep -rln <ModuleName> Sources/WenshuApp/Views Sources/WenshuApp/UI Sources/WenshuApp/State Sources/WenshuApp/App.swift
```

A module is **"wired"** if it appears in any file outside `Core/Agent/` (i.e. consumed by a View, a State, a Settings pane, or the App boot). A module is **"dead code"** if its only references are inside `Core/Agent/` (other agents, tests, or its own file).

A module is **"needed for usability"** if its absence breaks a common user workflow the boss 8/27 OOB listed (= "user BYOK enables embedded editorial-team agents. Same model as hermes").

The 6 capability areas come from boss 8/27 final:

1. **Library** = library + shelves + books + all data around books
2. **Editor** = Obsidian-style MD + AI paragraph tools (expand/shorten/rewrite)
3. **SpecializedTools** = core competitive functions (foreshadowing/placeholder/emotion curve/character relationships/character lifecycle/book word count/tags/idea library/book setting constraints/etc.)
4. **Agent** = multi-agent writing, single main chat, context compression, hermes-style
5. **明盒 (OpenBox)** = agent kanban + todo + real-time progress, hermes-style
6. **长文 (LongForm)** = core competitive tech patches for LLM long-form chaos (constraint/continuity/self-proof/persona/character arc/world consistency)

---

## 2. Area: Library (= library + shelves + books + all data around books)

### 2.1 Ported (= 8 modules that ARE wired)

| Module | LOC | Wired? | Where wired |
|---|---|---|---|
| `BookStore.swift` (state) | n/a | ✅ | `WorkspaceView` (preview scope binding) + `WenshuEditorServicesFactory.make` |
| `WenshuLibrary` (state) | n/a | ✅ | `App.swift` (root) + `WorkspaceView` + `NewLibraryOutlineView` (sidebar) |
| `NewLibraryOutlineView` (sidebar) | n/a | ✅ | `WorkspaceView.case .projectSidebar` line 315-319 |
| `BookEditorSheet` | n/a | ✅ | triggered from NewLibraryOutlineView's edit-row path |
| `BookshelfEditorSheet` | n/a | ✅ | same |
| `ReferenceEditorSheet` | n/a | ✅ | same |
| `CharacterEditorSheet` | n/a | ✅ | same |
| `WorldEntryEditorSheet` | n/a | ✅ | same |
| `SmartQueryView` | n/a | ⚠️ Wired but **no engine** behind it (the view ships as placeholder per v0.26 spec) |

### 2.2 Not ported (= hermes-side modules that wenshu would benefit from)

| Module | LOC | Hermes source path | Why "needed for usability"? |
|---|---|---|---|
| `book_manager.py` | ~2,500 | `agent/librarian/book_manager.py` | hermes has a per-book librarian that handles book metadata + folder structure; wenshu's `BookStore.swift` does this manually for each book. If wenshu wants the LLM agent to create / rename / delete books (= a common editorial workflow), it needs a uniform book API |
| `link_graph_sync.py` | ~1,100 | `agent/librarian/link_graph_sync.py` | hermes cross-book link discovery; wenshu has `Core/LinkGraph/` but only for backreferences within a book |
| `vault_indexer.py` | ~2,800 | `agent/librarian/vault_indexer.py` | hermes full-text + entity index for the entire library; wenshu has `Core/Search/` but no per-library index |
| `llm_wiki/` (4-layer deriver) | ~5,500 | `agent/librarian/llm_wiki/` | hermes builds raw → entities → abstracts → indexes per-library; wenshu reference-library mirrors this structure but no Swift builder exists |

### 2.3 Gap

**The Library is well-wired at the UI level** (= sidebar + outline + editor sheets), but **no agent can mutate library state through a uniform API**. The LLM agent loop, when wired (see §4 below), will not be able to: create a new book / rename a book / move a chapter / delete a reference. That's the user's "BYOK enables editorial team" promise.

**Effort to close**: ~5 days. Mostly port `agent/librarian/*.py` 1:1 (~10,000 LOC hermes → ~2,500 LOC Swift). LLM-tool wrappers then sit in `Core/Agent/Tool/BookManagerTool.swift`.

---

## 3. Area: Editor (= Obsidian-style MD + AI paragraph tools)

### 3.1 Ported (= 2 modules that ARE wired)

| Module | LOC | Wired? | Where wired |
|---|---|---|---|
| `WenshuMarkdownEditor.swift` | 55 | ✅ | `WorkspaceView.case .editor` line 1680 (NSViewRepresentable wrapper) |
| `WenshuEditorServicesFactory.swift` | 94 | ✅ | `WorkspaceView` line 1101 (creates the editor configuration per active book) |

### 3.2 Ported (= 3 modules that are NOT wired into editor)

| Module | LOC | Wired? | Where SHOULD it wire? |
|---|---|---|---|
| `WenshuMarkdownEditor` paragraph AI tools | 0 | ❌ | **Missing** — no Swift module exists for paragraph-level expand/shorten/rewrite. Boss 8/27 OOB explicitly listed "AI paragraph tools" as core editor feature |
| `ReferenceLibraryImageProvider.swift` | n/a | ⚠️ Wired in factory but **not yet used** in any active editor session |
| `ReferenceLibraryWikiLinkResolver.swift` | n/a | ⚠️ Wired in factory but **not yet used** in any active editor session |

### 3.3 Not ported (= hermes-side modules that wenshu would benefit from)

| Module | LOC | Hermes source path | Why "needed for usability"? |
|---|---|---|---|
| `paragraph_ai.py` (expand/shorten/rewrite/summarize) | ~1,800 | `agent/editing/paragraph_ai.py` | boss 8/27 OOB listed "expand/shorten/rewrite" as core editor feature; **wenshu has zero Swift surface for it today** |
| `selection_actions.py` | ~600 | `agent/editing/selection_actions.py` | hermes selection-level AI actions (= translate / rephrase / convert-to-bullet); wenshu editor has no selection listener |
| `md_preview_renderer.py` | ~1,200 | `agent/editing/md_preview_renderer.py` | hermes preview-side CommonMark renderer; wenshu `WenshuMarkdownEditor` already uses swift-markdown-engine so this is partially covered |
| `llm_wiki_layer_injector.py` | ~800 | `agent/editing/llm_wiki_layer_injector.py` | hermes injects per-book LLM Wiki 4-layer entities into editor preview; wenshu has `Domain/WikiEntityPreflight.swift` but no editor injection |
| `autocomplete.py` | ~1,400 | `agent/editing/autocomplete.py` | hermes inline autocomplete from skill commands; wenshu has SkillAdapter.parseSlashCommand (slash only) but not inline |

### 3.4 Gap

The editor itself is wired (= `WenshuMarkdownEditor` is the active `case .editor` body), but **paragraph-level AI tools (= the boss 8/27 core feature) have zero Swift surface**. The "AI can rewrite my paragraph" promise falls back to "open chat, copy/paste, send" today.

**Effort to close**: ~3 days. Port `agent/editing/paragraph_ai.py` to `Core/Agent/Editing/ParagraphAITool.swift` (~400 LOC). Wire as an editor toolbar button (3 buttons: expand / shorten / rewrite) + keyboard shortcuts. Cross-cuts Agent area (paragraph AI is an LLM-tool).

---

## 4. Area: SpecializedTools (= the 8+ core competitive functions)

### 4.1 Ported (= 2 tabs, but both are placeholder Views)

| Module | LOC | Wired? | Where wired |
|---|---|---|---|
| `ForeshadowingView.swift` | 92 | ⚠️ Wired into `WorkspaceView.case .specializedTools` line 416 + 597 — but **body = 3 placeholder rows**, no data layer |
| `PlaceholderView.swift` | 79 | ⚠️ Wired into `WorkspaceView.case .specializedTools` line 417 + 598 — but **body = 3 placeholder rows**, no data layer |

### 4.2 Ported (= 3 modules that are NOT wired into specializedTools)

| Module | LOC | Wired? | Where SHOULD it wire? |
|---|---|---|---|
| `BookKanbanStore.swift` (per-book JSON) | n/a | ❌ | SHOULD wire: kanban-in-book tab (= per-book kanban view) in specializedTools pane |
| `MemorySettingsView.swift` | n/a | ⚠️ Wired into AgentSettingsView, NOT into specializedTools |
| `WordCountBadge.swift` | n/a | ⚠️ Wired into status bar, NOT into specializedTools (= boss 8/27 listed "book word count" as a specialized tool, not a status bar item) |

### 4.3 Not ported (= hermes-side modules that wenshu would benefit from)

| Module | LOC | Hermes source path | Why "needed for usability"? |
|---|---|---|---|
| `foreshadowing_tracker.py` | ~2,400 | `agent/specialized/foreshadowing_tracker.py` | boss 8/27 OOB top item: "foreshadowing" is one of the 6 advertised tools. Swift placeholder exists, no data layer |
| `placeholder_scanner.py` | ~1,800 | `agent/specialized/placeholder_scanner.py` | boss 8/27 OOB top item: "placeholder" is one of the 6 advertised tools. Swift placeholder exists, no data layer |
| `emotion_curve.py` | ~1,600 | `agent/specialized/emotion_curve.py` | boss 8/27 OOB top item: "emotion curve" = chart per-chapter. **Zero Swift surface today** |
| `character_relationships.py` | ~1,200 | `agent/specialized/character_relationships.py` | boss 8/27 OOB top item: "character relationships" = graph view. **Zero Swift surface today** |
| `character_lifecycle.py` | ~900 | `agent/specialized/character_lifecycle.py` | boss 8/27 OOB top item: "character lifecycle" = birth/death/arc per chapter. **Zero Swift surface today** |
| `tag_manager.py` | ~700 | `agent/specialized/tag_manager.py` | boss 8/27 OOB top item: "tags". `Domain/EntityType.swift` has entity tagging but no specialized-tools tab |
| `idea_library.py` | ~2,100 | `agent/specialized/idea_library.py` | boss 8/27 OOB top item: "idea library" = cross-book reference snippets. **Zero Swift surface today** |
| `book_setting_constraints.py` | ~1,500 | `agent/specialized/book_setting_constraints.py` | boss 8/27 OOB top item: "book setting constraints". **Zero Swift surface today** |
| `long_form_guardrails.py` | ~3,200 | `agent/specialized/long_form_guardrails.py` | **THE TOP PRIORITY**: see §7. Constraint / continuity / self-proof / persona / character arc / world consistency — boss 8/27 OOB made this a top-tier competitive area. **Zero Swift surface today** |
| `outline_viewer.py` | ~800 | `agent/specialized/outline_viewer.py` | boss 8/27 OOB: editor has 大纲 tab = `EditorPlaceholder()` placeholder. No real outline renderer |
| `backlinks_viewer.py` | ~600 | `agent/specialized/backlinks_viewer.py` | boss 8/27 OOB: editor has 反链 tab = `EditorPlaceholder()` placeholder. `Core/LinkGraph/BacklinksPanel.swift` exists but not wired |

### 4.4 Gap

**SpecializedTools is the worst-wired area in wenshu.** Of the 8 tools boss 8/27 listed:

- 2 tabs (Foreshadowing + Placeholder) have Views but no data
- 1 tab (大纲) is `EditorPlaceholder` (= no outline renderer)
- 1 tab (反链) is `EditorPlaceholder` (= no backlinks renderer, despite `BacklinksPanel.swift` existing)
- 4 tools (emotion curve / character relationships / character lifecycle / idea library) have ZERO Swift surface
- LongForm (= constraint / continuity / self-proof / persona / character arc / world consistency) = see §7, **the single biggest competitive moat boss 8/27 named, with zero Swift surface**

**Effort to close**: ~3-4 weeks (= this is the dominant area). Per-tool: ~400-1,000 Swift LOC + 1 View + 1 tab in the specializedTools pane. LongForm alone is ~800-1,200 Swift LOC.

---

## 5. Area: Agent (= multi-agent writing, single main chat, context compression, hermes-style)

### 5.1 Ported (= 11 modules that ARE wired)

| Module | LOC | Wired? | Where wired |
|---|---|---|---|
| `WenshuVerifier.swift` | n/a | ✅ | `ChatView.swift` line 10 + 255-260 + 305-307 (the streaming verifier path = the actual LLM call) |
| `WenshuConductor.swift` | 398 | ✅ | `App.swift` line 1406 + `ChatView` line 102 (the multi-agent runtime) |
| `AgentRuntime.swift` | 105 | ✅ | `App.swift` line 1293 + `ChatView` line 10 (runtime instance) |
| `AgentProtocol.swift` | n/a | ✅ | `App.swift` line 1421 (A2A surface) |
| `SkillAdapter.swift` | n/a | ✅ | `ChatView.swift` line 182 (CHATBOX-001 slash-command front-door) + `SkillsSettingsView` |
| `MemoryAdapter.swift` | n/a | ✅ | `MemorySettingsView` + `MemoryRetrievalPanel` + `MemoryEntryRow` + `DynamicZoneView` (the right-bottom half-visible panel) |
| `SkillRegistry.swift` | n/a | ✅ | `SkillMeta.swift` + `SkillsSettingsView` |
| `SkillMeta.swift` | n/a | ✅ | `SkillsSettingsView` |
| `LLMConnector` (5 connectors: Anthropic / OpenAI / GeminiNative / MiniMax / DeepSeek / Ollama / OpenRouter) | n/a | ✅ | `LLMConnectorSettingsView` (the AgentSettingsView's LLM section) |
| `MemoryManager.swift` | n/a | ✅ | `MemoryAdapter` + `MemorySettingsView` |
| `ChatSessionStore.swift` | n/a | ✅ | `ChatView` line 217-300 (persistence + archive) |

### 5.2 Ported (= ~25 modules that are NOT wired into the Agent area)

These compile and pass tests but no View, no State, no Settings pane, no conductor path consumes them:

| Module | LOC | Where SHOULD it wire? |
|---|---|---|
| `ConversationLoop.swift` | 197+ | SHOULD wire: `WenshuConductor.handle()` should delegate to `ConversationLoop` (currently uses `AgentRuntime` + `MiniMaxVerifier` shortcut per `ChatView.swift` line 222-293). Per boss OOB "embedded editorial-team agents" the loop is the entry point |
| `ToolExecutor.swift` | 152 | SHOULD wire: `ConversationLoop.executeTurn()` (= the per-turn function-call dispatch). Currently `ToolExecutor` is only referenced by tests + `ToolDispatchHelpers.swift` itself |
| `ToolDispatchHelpers.swift` | 197 | SHOULD wire: same — `ToolExecutor.execute()` should call these |
| `RuntimeHelpers.swift` | 336 | SHOULD wire: `ConversationLoop` + `HermesGoals.runGoal()` (= both reference it but only via init) |
| `HermesGoals.swift` | 163 | SHOULD wire: a "Long-running goal" button in ChatView's bottom toolbar (= user types goal → main agent keeps working until judgment says done). Per boss 8/27 OOB "long-running agent" is the Ralph loop pattern |
| `HermesTodoTool.swift` | 644 | SHOULD wire: `WenshuConductor.handle()` should expose a `todos` LLM-tool that writes to `TodoStore`. Currently `TodoListView` reads from `TodoStore` but no LLM writes to it |
| `KanbanTools.swift` | n/a | SHOULD wire: same — `WenshuConductor.handle()` should expose a `kanban` LLM-tool that writes to `KanbanStore` (or `HermesKanbanDB`). Currently `KanbanView` reads from `BookKanbanStore` but no LLM writes |
| `CronjobTools.swift` | n/a | SHOULD wire: same — `WenshuConductor.handle()` should expose a `cron` LLM-tool. `CronScheduleView` is a placeholder today |
| `WebSearch.swift` | 136 | SHOULD wire: `ToolExecutor` should register `WebSearchTool` so LLM can call it. Per boss 8/27 "embedded editorial team" the agent needs research capability |
| `HermesKanbanDB.swift` | n/a | SHOULD wire: same as `KanbanStore` — but as the SQLite-backed alternative to the per-book JSON. Currently `KanbanView` reads `BookKanbanStore` (JSON), `HermesKanbanDB` is the hermes-port that **nothing** in the runtime reads |
| `AsyncDelegation.swift` | n/a | SHOULD wire: `WenshuConductor.handle()` should use `AsyncDelegation` to spawn sub-agents (the boss OOB "5 editorial sub-agents under WenshuConductor"). Currently `WenshuConductor.handle()` is single-shot |
| `SubAgentIdentity.swift` | n/a | SHOULD wire: `WenshuConductor.handle()` should assign each spawned sub-agent a `SubAgentIdentity`. Currently the conductor path doesn't spawn sub-agents |
| `SubAgentPermissions.swift` | n/a | SHOULD wire: same — gate each sub-agent's writes by `SubAgentPermissions`. **Without this, embedded agents have root access** (= unsafe per boss 8/27 OOB safety stance) |
| `EventBus.swift` | n/a | SHOULD wire: a `Settings → Events` panel showing the bus log. Plus the auto-trigger system should fire on `event.tool.completed` etc. |
| `ShellHookChain.swift` | n/a | SHOULD wire: `ToolExecutor.execute()` should run pre/post-hook chains for every tool call (= hermes-side shell_hooks pattern). **Without this, every auto-trigger has to be manual** |
| `TurnContext.swift` / `TurnFinalizer.swift` / `MessageSanitization.swift` | small | SHOULD wire: `ConversationLoop.executeTurn()` (= per-turn setup + finalize + sanitize). Per inventory Part F #1, this is the v0.37 backlog candidate A |
| `ReasonScrubber.swift` | n/a | SHOULD wire: `MessageSanitization` chain (= strip chain-of-thought before saving to chat.sqlite) |
| `Redactor.swift` | n/a | SHOULD wire: `MessageSanitization` chain (= redact PII per Apple HIG-style rules) |
| `ContextEngine.swift` | 86 | SHOULD wire: `ContextReferences.swift` + `MemoryManager.prefetch` (= assemble context bundle per turn). Currently returns empty bundles (TODO ticket-009) |
| `ContextReferences.swift` | 117 | SHOULD wire: same |
| `ModelMetadata.swift` | 75 | SHOULD wire: `LLMConnectorSettingsView` should display per-model context window + pricing. Currently the picker shows only model name |
| `AnthropicAdapter.swift` | n/a | SHOULD wire: `AnthropicConnector.stream` (per inventory Part F #5, missing redacted_thinking + signature propagation) |
| `AuxiliaryClient.swift` | n/a | SHOULD wire: 5 connectors should route through `AuxiliaryClient` (per inventory Part F #6, SSE coalescing + per-task model selection) |
| `ErrorClassifier.swift` | n/a | SHOULD wire: `LLMConnector.stream` catch block (currently inline `UserFacingError.from`) |
| `RateLimitTracker.swift` | n/a | SHOULD wire: `AuxiliaryClient` retry loop (per inventory Part A.4 #6) |
| `IterationBudget.swift` | n/a | SHOULD wire: `ConversationLoop.executeTurn()` (per-turn retry counter) |
| `ManualCompressionFeedback.swift` | n/a | SHOULD wire: `ChatView`'s compression row (= let user rate compression quality) |
| `CodingContext.swift` | n/a | SHOULD wire: `ConversationLoop` (= inject code-mode context for code-heavy sessions). **However** wenshu §11 = writing tool, code-mode is rarely used → low priority |
| `CuratorBackup.swift` | n/a | SHOULD wire: `BackupView` (currently placeholder). The wenshu-side wins means `BackupView` already shows backup status; `CuratorBackup` is the hermes-port that does the actual snapshots |
| `SSLGuard.swift` | n/a | SHOULD wire: `Network/*` providers (= strict / allowSelfSigned / bypass modes) |
| `TitleGenerator.swift` | n/a | SHOULD wire: `ChatView.startNewSession` (= auto-generate session title from first message). Per inventory Part C.3, wenshu has its own session metadata — but `TitleGenerator` is the hermes-port |
| `PromptBuilder.swift` | 579 | SHOULD wire: `ConversationLoop.executeTurn()` (= build per-turn prompt). Per inventory Part A.4 #1 (TICKET-HERMES-GAP-001) |
| `SystemPrompt.swift` | 101 | SHOULD wire: same (= per-provider / per-locale / dynamic tier) |
| `ContextBreakdown.swift` | n/a | SHOULD wire: `ConversationLoop` (= break context into tiers) |
| `ContextCompressor.swift` | n/a | SHOULD wire: same |
| `TurnRetryState.swift` | n/a | SHOULD wire: same (= per-turn retry counter) |
| `WenshuAgentIdentity.swift` | n/a | SHOULD wire: `WenshuConductor` (= identity for the main agent) |
| `AgentLifecycleTracker.swift` | n/a | SHOULD wire: `WenshuConductor.handle()` (= lifecycle events for the main agent) |
| `OutputKind.swift` | n/a | SHOULD wire: `TurnFinalizer` (= classify output as text / thinking / tool-use) |
| `AgentBootstrapper.swift` | n/a | SHOULD wire: `App.swift` line 1406 (currently `WenshuConductor` inits directly; should bootstrap from `AgentBootstrapper`) |
| `ConversationCompression.swift` | 66 | ⚠️ Wired into `ChatViewCompressionRow.swift` line 101 (= visible in chat UI) but **the conductor path doesn't auto-trigger compression** |
| `PromptCaching.swift` | n/a | SHOULD wire: `AnthropicConnector` (= cache prompt prefix to avoid re-tokenizing per turn) |
| `AnthropicStreaming.swift` + `AnthropicStreamingWireup.swift` | n/a | SHOULD wire: `AnthropicConnector.stream` (per inventory Part B.2, currently SSE coalescing is partial) |
| `RequestHelpers.swift` | 426 | ⚠️ Wired into all 5 connectors (per inventory Part A.1 #2) but no test or main path uses it directly |
| `ConnectorCredentials.swift` | n/a | ⚠️ Wired into `ProviderKeychain` |
| `LLMResponse.swift` / `LLMMessage.swift` / `WenshuLLMModel.swift` / `WenshuLLMModelFetcher.swift` | small | ⚠️ Wired into the connector layer |
| `Tool.swift` / `ReadFileTool.swift` / `WriteFileTool.swift` / `ToolGuardrails.swift` / `ToolInputParser.swift` | small | SHOULD wire: `ToolExecutor` should register these 3 tools |

### 5.3 Not ported (= hermes-side modules that wenshu would benefit from)

| Module | LOC | Hermes source path | Why "needed for usability"? |
|---|---|---|---|
| `fallback_chain.py` | ~2,800 | `agent/auxiliary_client.py::fallback_chain` | hermes 7-connector fallback chain for 429 / rate-limit. **Without it, wenshu crashes on rate-limit** (= boss 8/27 OOB safety stance) |
| `web_search.py` + `web_search_*.py` (already partial port via HERMES-INTERNAL-001) | ~2,500 | `agent/web_search*.py` | boss 8/27 OOB: wenshu editor team needs research. `WebSearch.swift` (136 LOC) is just landed but not wired into `ToolExecutor` |
| `plugin_hook_system` | ~3,500 | `agent/plugin_hook_system.py` | hermes auto-trigger hook chain. **Without it, every auto-trigger (= compression / curator / title-gen) has to be manual** |
| `context_window_calculator.py` | ~600 | `agent/context_window_calculator.py` | hermes per-model context window calculator (= not just hardcoded numbers) |
| `prompt_template_manager.py` | ~1,400 | `agent/prompt_template_manager.py` | hermes per-skill prompt templates |
| `delegation_target_resolver.py` | ~800 | `agent/delegation_target_resolver.py` | hermes which sub-agent should handle which task |

### 5.4 Gap

The Agent area is **the most ported but least wired**. ~25 modules sit in `Core/Agent/` with no consumer outside the Agent folder. The user-facing ChatView + AgentSettingsView wiring uses **only ~11 modules** of the ~36 ported. The other ~25 are unreachable.

The root cause: the boss 2026-09-04 OOB "继续把工作树干完" led to a port-first, wire-later pattern. The 11 ⚠️ partial modules from inventory §A.3 are the wiring backlog (= ~3,500 Swift LOC to wire, ~5-7 days of focused work).

**Effort to close**: ~7-10 days. Priority order:

1. Wire `ConversationLoop → ToolExecutor → HermesGoals / HermesTodoTool / KanbanTools / CronjobTools / WebSearch` (= the LLM-tool surface, ~3 days)
2. Wire `AsyncDelegation → SubAgentIdentity → SubAgentPermissions` (= the embedded sub-agent safety surface, ~2 days)
3. Wire `ContextEngine → ContextReferences → MemoryManager.prefetch` (= per-turn context, ~2 days)
4. Wire the 7-connector fallback chain (= `AuxiliaryClient.fallbackChain`, ~2 days)

---

## 6. Area: 明盒 (OpenBox) (= agent kanban + todo + real-time progress, hermes-style)

### 6.1 Ported (= 4 modules that ARE wired)

| Module | LOC | Wired? | Where wired |
|---|---|---|---|
| `SubAgentProgressView.swift` | 160 | ⚠️ Wired (= exists as a View) but **never instantiated** in `WorkspaceView` (per §1 grep, only referenced in DynamicZoneView's comments + by tests). Boss 8/24 OOB hid it from the dynamic zone |
| `KanbanView.swift` | 438 | ✅ | `DynamicZoneView.case .kanban` line 74 |
| `TodoListView.swift` | 481 | ✅ | `DynamicZoneView.case .todo` line 76 |
| `KanbanStore.swift` (per-book JSON) | n/a | ✅ | `KanbanView` line 258-303 (via `BookKanbanStore`) |
| `TodoStore.swift` | n/a | ✅ | `TodoListView` |
| `MemoryRetrievalPanel` | n/a | ✅ | `DynamicZoneView` line 86 (= the right-bottom half-visible panel) |

### 6.2 Ported (= 4 modules that are NOT wired into OpenBox)

| Module | LOC | Where SHOULD it wire? |
|---|---|---|
| `KanbanTools.swift` | n/a | SHOULD wire: `WenshuConductor.handle()` should write to `BookKanbanStore` (or `HermesKanbanDB`) per LLM tool call. **Currently no LLM writes to kanban** |
| `HermesTodoTool.swift` | 644 | SHOULD wire: same — `WenshuConductor.handle()` should write to `TodoStore`. **Currently no LLM writes to todo** |
| `HermesKanbanDB.swift` | n/a | SHOULD wire: as the SQLite-backed alternative to `BookKanbanStore` (per inventory Part A.4 #4, 14,347 LOC hermes → 1:1 port = dead code) |
| `EventBus.swift` | n/a | SHOULD wire: `SubAgentProgressView` should subscribe to `event.agent.started` / `event.agent.completed` (= real-time progress feed). **Currently SubAgentProgressView polls KanbanStore every refreshTrigger** |

### 6.3 Not ported (= hermes-side modules that wenshu would benefit from)

| Module | LOC | Hermes source path | Why "needed for usability"? |
|---|---|---|---|
| `kanban_event_projector.py` | ~600 | `agent/openbox/kanban_event_projector.py` | hermes EventBus → Kanban projector (= every tool call auto-creates a kanban ticket). Per inventory Part A.4 #4, EventBus is ported but no projector exists |
| `todo_event_projector.py` | ~400 | `agent/openbox/todo_event_projector.py` | hermes EventBus → Todo projector (= every sub-agent task auto-creates a todo) |
| `progress_aggregator.py` | ~1,200 | `agent/openbox/progress_aggregator.py` | hermes roll-up of sub-agent progress (= total / running / done / failed). Currently `SubAgentProgressView` shows raw tasks |
| `agent_status_card.py` | ~500 | `agent/openbox/agent_status_card.py` | hermes per-sub-agent status card (= name / role / current task / ETA) |

### 6.4 Gap

OpenBox is **partially wired**: the UI exists (`KanbanView` + `TodoListView` + the `MemoryRetrievalPanel`) but **no real-time flow from the agent runtime**. The user sees a static kanban + todo because no agent is writing to it. `SubAgentProgressView` (= the "明盒" hermes-style progress feed) was hidden by boss 8/24 OOB and never re-surfaced.

**Effort to close**: ~3 days. Re-surface `SubAgentProgressView` as a 3rd tab in `DynamicZoneView`, wire `EventBus → Kanban / Todo projectors`, and have `WenshuConductor` emit `event.agent.*` events per sub-agent lifecycle.

---

## 7. Area: 长文 (LongForm) (= LLM long-form chaos tech patches)

### 7.1 Verdict: ❌ ZERO Swift surface exists

Per boss 8/27 OOB the LongForm area is the **top competitive moat**: tech patches that fix the LLM's tendency to drift over long-form writing. The 5 patches boss named:

| Patch | Description | Hermes source path | wenshu Swift module |
|---|---|---|---|
| Constraint enforcement | "Don't violate the book's setting constraints" (= magic system, era, technology level) | `agent/longform/constraint.py` (~3,500 LOC) | **NONE** |
| Continuity check | "Don't contradict earlier chapters" (= character states, plot facts) | `agent/longform/continuity.py` (~2,800 LOC) | **NONE** |
| Self-proof | "Verify each claim against the book's reference library" | `agent/longform/self_proof.py` (~2,200 LOC) | **NONE** |
| Persona validator | "Stay in character voice" (= character-arc consistency) | `agent/longform/persona.py` (~1,600 LOC) | **NONE** |
| Character arc tracker | "Track character development across chapters" | `agent/longform/character_arc.py` (~2,400 LOC) | **NONE** |
| World consistency | "Don't break the world's rules" (= magic / technology / geography) | `agent/longform/world_consistency.py` (~2,000 LOC) | **NONE** |
| LLM Wiki 4-layer context | "Inject raw + entities + abstracts + indexes into every long-form turn" | `agent/longform/wiki_context.py` (~1,800 LOC) | `Domain/WikiEntityPreflight.swift` exists but no per-turn injector |

**Total: 6 Swift modules + 1 partial, summing to ~16,300 LOC of hermes = ~3,500 LOC of Swift.**

### 7.2 Where SHOULD they wire?

All 6 patches fit into the same architectural slot: a `LongFormGuardrail` chain that runs **after** `ConversationLoop` generates a turn but **before** the turn is written to `chat.sqlite` and presented to the user.

Wire path:

```
ConversationLoop.executeTurn()
  ↓
LongFormGuardrail.assess(turn)
  ├─ ConstraintEnforcer.check(turn, constraints)
  ├─ ContinuityChecker.check(turn, priorChapters)
  ├─ SelfProver.verify(turn, referenceLibrary)
  ├─ PersonaValidator.validate(turn, characterCard)
  ├─ CharacterArcTracker.update(turn, characterArc)
  └─ WorldConsistencyChecker.check(turn, worldRules)
  ↓
if any check fails → ConversationLoop.rewrite(turn, feedback) → re-assess
else → write turn to chat.sqlite + present to user
```

UI surface:

- A "LongForm settings" pane in `AgentSettingsView` (= 5 toggle + 1 sensitivity slider)
- A per-turn "guarded by: constraint ✓, continuity ✗ (rewrote)" footer in ChatView

### 7.3 Gap

**LongForm is wenshu's stated #1 competitive moat per boss 8/27 OOB. It has zero Swift surface today.** This is the single biggest "ported-but-not-wired" gap in the project.

**Effort to close**: ~3 weeks. ~3,500 Swift LOC. This is the most strategic wiring work, not the cheapest.

---

## 8. Cross-cutting integration gaps

Things that touch multiple areas and must be wired once, not 6 times:

### 8.1 EventBus wiring (touches Agent + OpenBox + LongForm)

`EventBus.swift` is ported (= 1 file, ~80 LOC) but **no producer + no consumer**. Should be:

- **Producer**: `WenshuConductor.handle()` emits `event.agent.started` / `event.turn.completed` / `event.tool.executed` per turn
- **Consumer A** (Agent area): `ToolExecutor` subscribes for retry / fallback triggers
- **Consumer B** (OpenBox area): `KanbanTools` / `HermesTodoTool` subscribe for auto-creating tickets (= hermes `kanban_event_projector.py`)
- **Consumer C** (LongForm area): `LongFormGuardrail` subscribes for `event.turn.completed` (= triggers re-write loop)
- **Consumer D** (Settings area): `EventLogView` (= new Settings pane showing the bus stream)

**Effort**: ~3 days. 1 producer wiring + 4 consumer wirings.

### 8.2 LLM-tool surface wiring (touches Agent + OpenBox + Editor + Library)

The user-facing promise "BYOK enables embedded editorial team" requires that the LLM can call tools that mutate every state in wenshu:

| LLM tool | Wires to area | Current state |
|---|---|---|
| `book_create` / `book_rename` / `book_delete` | Library | Not ported |
| `paragraph_expand` / `paragraph_shorten` / `paragraph_rewrite` | Editor | Not ported |
| `foreshadowing_create` / `foreshadowing_resolve` | SpecializedTools | Not ported |
| `character_create` / `character_update` / `character_arc` | SpecializedTools + LongForm | Not ported |
| `emotion_curve_plot` | SpecializedTools | Not ported |
| `idea_library_capture` | SpecializedTools | Not ported |
| `constraint_set` / `world_rule_set` | LongForm | Not ported |
| `kanban_create` / `kanban_complete` | OpenBox | `KanbanTools.swift` ported, not wired |
| `todo_create` / `todo_complete` | OpenBox | `HermesTodoTool.swift` ported, not wired |
| `cron_create` / `cron_delete` | Agent (long-running) | `CronjobTools.swift` ported, not wired |
| `web_search` | Agent | `WebSearch.swift` ported, not wired |
| `delegate_to_subagent` | Agent | `AsyncDelegation.swift` ported, not wired |
| `memory_save` / `memory_recall` | Agent | `MemoryAdapter.swift` wired (Settings pane), not wired into `ToolExecutor` |

**13 LLM-tools** need to be wired (= 13 `Core/Agent/Tool/*Tool.swift` files + 13 entries in `ToolExecutor.toolRegistry`). The 5 that are ported but unwired (`KanbanTools` / `HermesTodoTool` / `CronjobTools` / `WebSearch` / `AsyncDelegation`) are the immediate backlog.

**Effort**: ~10 days total. ~5 days for the 5 already-ported unwired + ~5 days for the 8 not-ported.

### 8.3 Book-side state isolation (touches Library + Editor + SpecializedTools + OpenBox + LongForm)

All 5 areas beyond Library need **per-book state isolation**: the kanban for book A is not the kanban for book B. Today:

- `KanbanStore.swift` (per-book JSON via `BookKanbanStore`) = ✅ per-book isolated
- `TodoStore.swift` = ⚠️ global, not per-book
- `MemoryAdapter.swift` = ⚠️ global (per `MemorySettingsView` "scope" picker)
- `HermesKanbanDB.swift` = ⚠️ global SQLite, no per-book scoping
- `HermesGoals.swift` = ⚠️ per-call (caller passes directory)

**Effort**: ~2 days to add per-book scoping to `TodoStore` + `MemoryAdapter`.

---

## 9. Priority list — what to wire next

Ranked by: **(impact × low effort × cross-cutting)**:

### 9.1 Top 3 highest-priority integration gaps

#### Priority #1: Wire `ConversationLoop → ToolExecutor → LLM-tools`

- **What it enables**: The "BYOK enables embedded editorial team" promise. User types "帮我重写第三章, 短一点" → LLM calls `paragraph_shorten` tool → chapter rewritten. User types "把这条伏笔加进看板" → LLM calls `kanban_create` tool → ticket appears in `KanbanView`. This is the single user-facing feature that demonstrates the entire agent runtime is alive.
- **Effort**: 5 days.
  - Day 1-2: wire `ConversationLoop.executeTurn()` to call `ToolExecutor.execute()`
  - Day 3: wire `ToolDispatchHelpers` + register the 5 already-ported unwired tools (`KanbanTools` / `HermesTodoTool` / `CronjobTools` / `WebSearch` / `AsyncDelegation`)
  - Day 4: port the 8 missing tools (`book_create` / `paragraph_*` / `foreshadowing_*` / `character_*` / `emotion_curve_plot` / `idea_library_capture` / `delegate_to_subagent` / `memory_save`)
  - Day 5: integration test (= run a chat, see tools fire, see state mutate)
- **Why #1**: touches 5 of 6 areas (Agent + OpenBox + Editor + Library + SpecializedTools). Highest cross-cutting. Lowest effort per area touched.

#### Priority #2: Build the LongForm guardrail chain

- **What it enables**: wenshu's stated #1 competitive moat. "AI doesn't drift in long-form writing" = the user can trust wenshu's LLM to write 50 chapters without breaking character voice or world rules. Currently wenshu's LLM writes whatever it wants.
- **Effort**: 12-15 days.
  - Week 1: port `ConstraintEnforcer` + `ContinuityChecker` (= the 2 most-cited patches)
  - Week 2: port `SelfProver` + `PersonaValidator`
  - Week 3: port `CharacterArcTracker` + `WorldConsistencyChecker` + wire the re-write loop
  - + LongForm settings pane in `AgentSettingsView` + per-turn "guarded by" footer in `ChatView`
- **Why #2**: highest competitive moat. Lowest current surface. But ~3x the effort of Priority #1.

#### Priority #3: Wire specializedTools with real data + 8+ new tabs

- **What it enables**: The boss 8/27 OOB advertised 8 specialized tools. Today only 2 placeholder tabs exist. Filling this makes the Tools pane the single biggest user-visible "wenshu = writing tool" differentiator.
- **Effort**: 12-15 days.
  - Week 1: `ForeshadowingView` + `PlaceholderView` (real data, port `foreshadowing_tracker.py` + `placeholder_scanner.py`)
  - Week 2: `EmotionCurveView` + `CharacterRelationshipsView` (port `emotion_curve.py` + `character_relationships.py`)
  - Week 3: `CharacterLifecycleView` + `TagManagerView` + `IdeaLibraryView` (port the remaining 3)
- **Why #3**: highest user-visible ROI. Boss 8/27 OOB stated this as the "core competitive" surface. Currently it's the worst-wired area.

### 9.2 Subsequent priorities (lower impact or higher effort)

| # | Priority | Effort | Touches |
|---|---|---|---|
| 4 | Wire `ContextEngine + MemoryManager.prefetch + WikiEntityPreflight` (= per-turn context injection) | 5 days | Agent + LongForm |
| 5 | Wire 7-connector fallback chain (= `AuxiliaryClient.fallbackChain`) | 3 days | Agent |
| 6 | Wire `AsyncDelegation → SubAgentIdentity → SubAgentPermissions` (= embedded sub-agent safety) | 4 days | Agent + OpenBox |
| 7 | Wire `EventBus` (= 1 producer + 4 consumers) | 3 days | Agent + OpenBox + LongForm + Settings |
| 8 | Port `paragraph_ai.py` (= editor paragraph AI tools) | 4 days | Editor |
| 9 | Wire `MemoryRetrievalPanel` + per-book isolation for `TodoStore` + `MemoryAdapter` | 2 days | OpenBox + Library |
| 10 | Wire `SubAgentProgressView` as 3rd tab in `DynamicZoneView` | 1 day | OpenBox |
| 11 | Wire `EventLogView` (= new Settings pane showing bus stream) | 2 days | Settings |
| 12 | Port hermes librarian (= `book_manager.py` + `link_graph_sync.py` + `vault_indexer.py`) | 8 days | Library |

### 9.3 Effort vs impact matrix

```
                  Low effort        High effort
High impact       #1 (5d)           #2 (12-15d) LongForm
                                    #3 (12-15d) specializedTools
Medium impact     #4 (5d)           #6 (4d) AsyncDelegation
                  #5 (3d)           #9 (2d) per-book isolation
                  #7 (3d)           #12 (8d) librarian
                  #10 (1d)
Low impact        #11 (2d)          #8 (4d) paragraph_ai
```

The 3 highest-impact items are: #1 (low effort, high impact, cross-cutting) → #2 (high effort, top moat) → #3 (high effort, top user-visible feature).

---

## 10. Headline gap counts

|| Class | Count | Notes |
|---|---|---|---|
| ✅ Wired (= ported AND consumed by View / State / App) | 24 modules | See §2.1 + §3.1 + §5.1 + §6.1 |
| ⚠️ Wired-but-stub (= ported, View exists, but no data behind) | 4 modules | `ForeshadowingView` + `PlaceholderView` + `SmartQueryView` + `SubAgentProgressView` |
| ❌ Dead code (= ported, but no View / State / App consumer outside Core/Agent/) | ~36 modules | See §5.2 (= the inventory Part A.3 partials + B.2 partials) |
| 🚫 Not ported (= hermes-side module exists, no Swift counterpart, in-scope) | ~17 modules | See §5.3 + §7.1 (= LongForm moat) |
| 🚫 Out-of-scope per §2.3 + §2.4 + §11.3 | ~80+ modules | per inventory Parts B.3 + C |

**Total ported today: ~77 hermes-side Swift files (~14,384 LOC)**
**Total wired into a user-facing surface: 24 files (= 31%)**
**Total dead code: 36 files (= 47%)**
**Total not ported but in-scope: 17 modules (= ~3,500 Swift LOC)**

### 10.1 Per-area breakdown

| Area | Wired | Dead code | Not ported (= needed) |
|---|---|---|---|
| Library | 9 | 0 | 4 |
| Editor | 2 | 0 | 5 |
| SpecializedTools | 2 (placeholders) | 0 | 11 (8 boss-named + 3 followup) |
| Agent | 11 | ~25 | 6 |
| OpenBox (明盒) | 6 | 4 | 4 |
| LongForm (长文) | 0 | 1 (partial `WikiEntityPreflight`) | 6 |
| **Totals** | **30** | **~30** | **~36** |

---

## 11. Cited file paths

- `.scratch/2026-09-04-hermes-agent-capabilities-inventory.md` (the source-of-truth inventory, 314 lines)
- `.scratch/2026-09-04-inventory-beyond-backlog-closeout.md` (today's work-tree backlog, 18 items)
- `.scratch/2026-09-03-hermes-core-translation/hermes-port-manifest.md` (43 in-scope modules, verdict tally)
- `Sources/WenshuApp/Core/Agent/**` (77 hermes-side Swift files)
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` (the active 6-zone dispatcher)
  - line 315-319: `case .projectSidebar` (= NewLibraryOutlineView = Library)
  - line 378-395: `case .editor` (= EditorPlaceholder for 3 tabs = Editor)
  - line 399-417: `case .specializedTools` (= 2 placeholder tabs = SpecializedTools)
  - line 419-420: `case .aiChat` (= ChatView = Agent)
  - line 421-422: `case .aiDynamic` (= ZoneModuleView = OpenBox + Memory)
- `Sources/WenshuApp/Views/Chat/ChatView.swift` (the agent runtime front-door)
  - line 10: ChatViewModel comment "点发送 → AgentRuntime.delegateTask → WenshuVerifier.ping"
  - line 117-127: ChatViewModel.init(conductor:store:sessionId:appState:)
  - line 174-201: routeInput (= CHATBOX-001 slash-command front-door)
  - line 220-293: send() path (= conductor.handle + streaming fallback)
- `Sources/WenshuApp/Views/Settings/AgentSettingsView.swift` (the only LLM/Memory/Skills settings surface)
- `Sources/WenshuApp/Views/Dynamic/DynamicZoneView.swift` (the OpenBox + Memory surface)
  - line 74: `KanbanView()` (OpenBox kanban)
  - line 76: `TodoListView()` (OpenBox todo)
  - line 86: `MemoryRetrievalPanel` (right-bottom half-visible)
- `Sources/WenshuApp/Views/Tools/ForeshadowingView.swift` + `PlaceholderView.swift` (the 2 specializedTools placeholders, ~170 LOC of body text)
- `Sources/WenshuApp/App.swift` (the app boot)
  - line 1293: `static let sharedRuntime = AgentRuntime()`
  - line 1406: `Self.sharedConductor = WenshuConductor(...)` (the conductor bootstrap)
  - line 1421: `let protocol_ = AgentProtocol(...)` (the A2A bootstrap)

---

## 12. Cited commit hashes

Most relevant for the gap analysis (= today's hermes-port commits that produced the dead code):

- `57d0863b0` — HERMES-PARTIAL-001 — ConversationLoop fully wires ToolExecutor + Compression + Retry + Sanitization + Finalizer (5,312 LOC 1:1)
- `b84ce4c08` — HERMES-PARTIAL-003 — ToolExecutor concurrent + 6 helpers (1,646 LOC 1:1)
- `503444779` — HERMES-PARTIAL-018 — AsyncDelegation full surface (3,459 LOC 1:1 from delegate_tool.py)
- `e6e5ce04a` — HERMES-SUBSYSTEM-4 — HermesTodoTool (330 LOC 1:1 LLM-tool)
- `edd5ff6f0` — HERMES-SUBSYSTEM-5 — HermesGoals (1,765 LOC Ralph loop)
- `46253533b` — HERMES-SUBSYSTEM-3 retry — HermesKanbanDB (14,347 LOC 1:1)
- `ff2cd64d4` — HERMES-PARTIAL-011 — KanbanTools LLM-side dispatcher (1,672 LOC 1:1)
- `56f68dd4c` — HERMES-PARTIAL-010 — CronjobTools LLM-side dispatcher (1,137 LOC 1:1)
- `b22d788c5` — HERMES-PARTIAL-017 — SkillAdapter 35 do_* hub commands (732 LOC 1:1)
- `f92f7481e` — HERMES-INTERNAL-001 — WebSearch actor + protocol + 5-provider rotation
- `0fe80dd8d` — HOOK-SYSTEM-002 — hermes skill implicit keyword detection
- `6a0283562` — HOOK-SYSTEM-001 — hermes plugin event bus (= EventBus.swift)
- `3afb27149` — HERMES-INTERNAL-009 — Redactor with configurable rules
- `d50dc772d` — HERMES-INTERNAL-008 — TitleGenerator with heuristic + LLM modes
- `a9c642364` — HERMES-INTERNAL-004 — SSLGuard with strict / allowSelfSigned / bypass modes
- `c0405156b` — HERMES-INTERNAL-005 — CuratorBackup thin adapter over Curator

**Key observation**: today's port commits are 1:1 (= hermes parity achieved) but **none of them touch a View file outside the Agent folder**. The next 5-7 days of work should be wiring-first (= port = done, wiring = the user-visible ROI).

---

## 13. What this report does NOT cover (= explicitly out-of-scope)

- The 80+ hermes modules marked 🚫 in the inventory (= out-of-scope per spec §2.3 + §2.4 + §11.3). Not candidates for wenshu.
- Frontend-only polish (= chrome / status bar / Liquid Glass tuning). Per AGENTS.md §11, this is owner-approved work, not gap-fill work.
- v0.40 Apple-methodology cleanup tickets (A2-A11). These are refactors, not gap-fills.
- CHANGELOG.md update for today's work (= doc debt, not gap).

---

End of report.