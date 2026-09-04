# Hermes agent capabilities — port status inventory vs wenshu

**Author:** subagent for boss 2026-09-04 OOB ("wenshu IS the embedded agent platform; user BYOK enables embedded editorial-team agents. Same model as hermes")
**Date:** 2026-09-04
**Source-of-truth per boss 2026-09-04 OOB:** `/Volumes/ANAN/.hermes/agent/` (= canonical hermes Python tree). The hermes source lives here and NOT at `/Volumes/ANAN/.hermes/hermes-agent/agent/` (that mirror is identical; we point to the canonical `agent/` per the OOB).
**Verified paths:** hermes `agent/` (150 .py files, 93,837 LOC) + `hermes_cli/` (~165 .py, 163,148 LOC) + `tools/` (~115 .py, 92,364 LOC) = **~430 .py files, ~349k LOC.**

## Source-of-truth cross-refs (= decisions already locked)

- **AGENTS.md §11.3** (`/Volumes/ANAN/Engineering/wenshu/AGENTS.md` lines 91-170): boss 2026-09-04 OOB `'hermes 整体翻译成 swift, 整个工作树干完?'` + `'先不验收, 先继续把工作树干完'`. Defines wenshu-side wins pattern: existing wenshu Core module preserved; hermes-port = thin adapter that delegates to it.
- **`hermes-port-manifest.md`** (`.scratch/2026-09-03-hermes-core-translation/hermes-port-manifest.md`): 43 in-scope modules per spec §2.1+§2.2. Verdict 2026-09-04 = 7 ✅ direct port + 11 ✅ wenshu-side wins + 18 ⚠️ partial + 7 ❌ missing = 18/43 fully done, 25/43 incomplete (= work-tree per boss OOB).
- **`hermes-core-translation/spec.md`** (`§2.3` lines 122-160): ~25,000 LOC explicitly **out-of-scope** (hermes SaaS / Codex / pet / lsp / browser / image / video / TTS / STT / MOA / portal / Nous / Bedrock / Azure / billing / pricing / OCR / reason-scrub / ssl-guard / replay / trace / redundancy / curator-backup / iteration-budget / manual-compression-feedback / title-generator / web-search / redact). These are not porting candidates per spec.
- **`2026-09-04-hermes-5-subsystem-1to1-port-decision.md`** (`.scratch/`): hermes cron / kanban_db / todo / goals / OCR subsystems already covered by wenshu (see 🚫 table below).
- **`2026-09-04-inventory-beyond-backlog-closeout.md`** (`.scratch/`): item #4 = 18 ⚠️ partial modules = today's work-tree backlog (= the gap-fill list per boss OOB).

## Status legend (4 classes)

| Symbol | Per AGENTS.md §11.3 / gap audit 2026-09-04 | Definition |
|---|---|---|
| ✅ | direct port OR wenshu-side wins | wenshu Swift file exists, ports the hermes behavior 1:1 (verified by doc-comment citation + comparable surface + matching API). Includes wenshu-side wins = existing wenshu Core module is source of truth; hermes-port = thin adapter. |
| ⚠️ | partial | Swift file exists with doc-comment citing the hermes module, but implementation is a stub / minimum surface / wire-up not done. Z-contract golden tests would fail. |
| ❌ | not ported (= missing in wenshu) | No Swift file exists; spec §3.1 lists a target file but it has not been authored. hermes module has ZERO Swift surface today. |
| 🚫 | wenshu-side-wins OR out-of-scope per §2.3 | either = (a) wenshu does this differently per §11.3 (= cron LaunchAgent not file locks; kanban ≠ cross-process claim/lock; todo = user-facing not LLM-runtime; goals per spec §11 product-positioning; OCR doesn't exist on hermes side), OR (b) hermes-only concern not applicable to wenshu Apple-stack desktop writing app per spec §2.3 (= image-gen / video-gen / TTS / STT / browser / pet / lsp / Bedrock / Azure / Codex / Copilot / Nous-portal / MOA / pricing / etc.). |

## Priority legend (suggested port priority for ❌ items)

| P | Meaning |
|---|---|
| **P0** | Critical for wenshu agent runtime (= needs to land before v0.37 tracer-bullet wires real ConversationLoop). |
| **P1** | Important but wenshu can ship v0.37/v0.38 without it (= needs ticket but not blocking). |
| **P2** | Out-of-scope per spec §2.3 OR §11.3, not porting (= documented here only for completeness; wenshu-side-wins already covers or explicitly skipped). |

## Effort legend

| Effort | Meaning |
|---|---|
| **S** | <1 hour; mostly file-rename + doc-comment + 1-2 helpers. |
| **M** | 1-4 hours; one focused Swift module + tests. |
| **L** | 1-3 sessions; real spec work + multi-file diff + golden parity tests. |
| **XL** | Not-porting (per §2.3/§11.3); listed for completeness only. |

---

# Part A — Agent core capability inventory (the 43 hermes modules from spec §2.1+§2.2)

These are the `agent/` Python files that touch the agent engine (= conversation loop, tool dispatch, LLM call path). All 43 modules already have a wenshu Swift counterpart per the manifest; status below is from the 2026-09-04 gap audit, refreshed for new ports shipped since (= TICKET-HERMES-GAP-001..008 + HERMES-SUBSYSTEM-4 + B-11/12/13).

## A.1 ✅ Direct port (7 modules — full 1:1 wenshu Swift file)

| # | hermes python file | LOC | wenshu Swift file | LOC | status / notes |
|---|---|---|---|---|---|
| 1 | `agent/prompt_caching.py` | 119 | `Core/Agent/Conversation/PromptCaching.swift` | 100 | ✅ direct port |
| 2 | `agent/chat_completion_helpers.py` | 3,103 | `Core/Agent/Connector/RequestHelpers.swift` | 426 | ✅ direct port — landed TICKET-HERMES-GAP-002 (2026-09-04 commit `1b5b038de`) |
| 3 | `agent/error_classifier.py` | 1,598 | `Core/Agent/Connector/ErrorClassifier.swift` | 152 | ✅ direct port |
| 4 | `agent/turn_retry_state.py` | 80 | `Core/Agent/Conversation/TurnRetryState.swift` | 41 | ✅ direct port |
| 5 | `agent/context_breakdown.py` | 156 | `Core/Agent/Conversation/ContextBreakdown.swift` | 120 | ✅ direct port |
| 6 | `agent/runtime_cwd.py` | 62 | `Core/Agent/RuntimeCWD.swift` | 97 | ✅ direct port |
| 7 | `agent/tool_guardrails.py` | 475 | `Core/Agent/Tool/ToolGuardrails.swift` | 119 | ✅ wenshu-side wins (thin adapter wraps `FileTools.pathDenied` per §11.3) |

## A.2 ✅ Wenshu-side wins (11 modules — existing wenshu Core = source of truth)

| # | hermes python | LOC | wenshu Swift | LOC | status / notes |
|---|---|---|---|---|---|
| 8 | `agent/context_compressor.py` | 3,082 | `Core/Agent/Conversation/ContextCompressor.swift` | 128 | ✅ wenshu-side wins — §11 baseline 'no external AI platform calls' |
| 9 | `agent/credential_pool.py` + sources | 2,384 | `Core/Agent/Connector/ConnectorCredentials.swift` + `Core/Provider/{ProviderKeychain,AppleKeychainStore,InMemoryKeychainStore,ProviderKeychainMetadata,OAuthFlow}.swift` | 433 | ✅ wenshu-side wins — Apple Keychain = source of truth; thin resolver adapter |
| 10 | `agent/memory_manager.py` + `memory_provider.py` | 1,086 + 315 | `Core/Agent/Memory/MemoryAdapter.swift` + `Core/Memory/{MemoryManager,MemoryProvider,MemoryStore,MemoryConsolidator,MemoryWriteGate}.swift` | 741 | ✅ wenshu-side wins — filesystem JSON backend per §11 baseline (hermes uses SQLite; deliberately differs) |
| 11 | `agent/skill_utils.py` + preprocessing + commands + bundles | 824 + 144 + 732 + 438 | `Core/Skills/{SkillMeta,SkillRegistry}.swift` + `Core/Agent/Skill/{SkillAdapter,SkillBundles}.swift` | 600 + 250 | ✅ wenshu-side wins — thin adapter; `SkillBundles.swift` (176 LOC) landed TICKET-HERMES-GAP-006 (2026-09-04) |
| 12 | `agent/conversation_loop.py` (session persistence boundary) | 5,312 | `Core/Chat/ChatSessionStore.swift` (SQLite `chat_messages` + `chat_archives`) + `Core/Agent/Conversation/ConversationLoop.swift` (engine = stream producer, NOT persistence) | 197+ | ✅ wenshu-side wins |
| 13 | `agent/credential_persistence.py` | 174 | `Core/Provider/{ProviderKeychain,InMemoryKeychainStore,ProviderKeychainMetadata}.swift` | 299 | ✅ wenshu-side wins |
| 14 | `agent/display.py` | 1,440 | `Core/Agent/Background/DisplayStateMachine.swift` | 152 | ✅ wenshu-side wins — extracts `DisplayState` enum only (spec §2.2 thin-port mandate) |
| 15 | `agent/background_review.py` | 960 | `Core/Agent/Background/BackgroundReview.swift` | 165 | ✅ wenshu-side wins — `ProposalKind` + `ProposalStatus` enums; no background loop |
| 16 | `agent/curator.py` | 1,976 | `Core/Agent/Background/Curator.swift` | 185 | ✅ wenshu-side wins — data-only; no cron / no bg loop |
| 17 | `agent/credits_tracker.py` | 794 | `Core/Agent/Background/BackgroundCreditsTracker.swift` | 160 | ✅ wenshu-side wins — token counter only; no pricing |

## A.3 ⚠️ Partial (18 modules — Swift file exists but is a stub)

From `.scratch/2026-09-04-inventory-beyond-backlog-closeout.md` item #4 (= backlog gap-fill list per boss OOB).

| # | hermes python | LOC | wenshu Swift | LOC | stub surface | priority to fill |
|---|---|---|---|---|---|---|
| 1 | `agent/conversation_loop.py` | 5,312 | `Core/Agent/Conversation/ConversationLoop.swift` | 197 | never calls ToolExecutor.execute* / ConversationCompression / TurnRetryState | P0 |
| 2 | `agent/auxiliary_client.py` | 7,469 | `Core/Agent/Connector/{Anthropic,OpenAI,Minimax,GeminiNative,LLMConnector,AnthropicStreaming,AnthropicStreamingWireup}.swift` | 1,138 | DeepSeek/Ollama/OpenRouter connectors exist as files but stub; SSE coalescing missing | P1 |
| 3 | `agent/tool_executor.py` | 1,646 | `Core/Agent/Tool/ToolExecutor.swift` | 152 | sequential impl; concurrent body empty; 6 helpers not ported | P0 |
| 4 | `agent/conversation_compression.py` | 1,367 | `Core/Agent/Conversation/ConversationCompression.swift` | 66 | `historyAfterCompression` + `manualTrigger`; no ConversationLoop integration / no auto-trigger / no persistence | P1 |
| 5 | `agent/agent_init.py` | 2,103 | `Core/Agent/Conversation/AgentLifecycleTracker.swift` | 285 | cites `agent_init.py` but covers subagent lifecycle, NOT `agent_init` bootstrap | P2 |
| 6 | `agent/anthropic_adapter.py` | 2,789 | `Core/Agent/Connector/{AnthropicConnector,AnthropicStreaming,AnthropicStreamingWireup}.swift` | 528 | missing redacted_thinking / signature propagation / multi-content image+doc blocks | P1 |
| 7 | `agent/turn_context.py` | 565 | `Core/Agent/Conversation/TurnContext.swift` | 47 | plain struct; no per-turn setup (stdio guard, retry-counter reset, system-prompt restore) | P1 |
| 8 | `agent/turn_finalizer.py` | 507 | `Core/Agent/Conversation/TurnFinalizer.swift` | 35 | only `finalize(response:)`; no coalescing / post-turn hooks | P1 |
| 9 | `agent/message_sanitization.py` | 477 | `Core/Agent/Conversation/MessageSanitization.swift` | 53 | only `sanitizeText` + `sanitize`; missing repair-tool-args / close-interrupted / surrogates | P1 |
| 10 | `agent/message_content.py` | 50 | `Core/Agent/Conversation/MessageContent.swift` | 53 | basic content-block canonicalization | P1 |
| 11 | `agent/tool_result_classification.py` | 26 | inlined into `Core/Agent/Tool/ToolExecutor.swift` | 0 | catch-block emits "Error:" string; no classification enum | P1 |
| 12 | `agent/system_prompt.py` | 536 | `Core/Agent/Conversation/SystemPrompt.swift` | 101 | only stable-tier hardcoded; no per-provider / per-locale / dynamic-tier | P1 |
| 13 | `agent/context_engine.py` | 231 | `Core/Agent/Conversation/ContextEngine.swift` | 86 | returns empty bundles (TODO ticket-009) | P2 |
| 14 | `agent/context_references.py` | 598 | `Core/Agent/Conversation/ContextReferences.swift` | 117 | in-memory only; no on-disk persistence | P2 |
| 15 | `agent/model_metadata.py` | 2,434 | `Core/Agent/Connector/ModelMetadata.swift` | 75 | aggregator over Provider.defaultModels; pricing + context-window missing | P1 |
| 16 | `agent/skill_preprocessing.py` | 144 | inlined into `Core/Skills/SkillMeta.swift` (`SkillFrontmatter`) | 0 | frontmatter parsing works; no dedicated file | P2 |
| 17 | `agent/skill_commands.py` | 732 | `Core/Agent/Skill/SkillAdapter.swift` | 74 | only `parseSlashCommand`; 35 do_* hub missing | P1 |
| 18 | `agent/credential_sources.py` | 443 | reduced to `Core/Provider/ProviderKeychain.swift.loadKeySync` | 0 | missing env-var fallback / system-credential lookup / secret_sources integration | P1 |

## A.4 ❌ Not ported (0 modules — all 7 ❌ from 2026-09-04 gap audit closed by TICKET-HERMES-GAP-001..008)

Updated per 2026-09-04 audit + TICKET-HERMES-GAP-001..008 (= today's Hermes-gap closeout commits). All 7 ❌ modules now have Swift files (5 new + 2 partially filled). Listed below for traceability only:

| # | hermes python | LOC | wenshu Swift | LOC | how it landed (which ticket) |
|---|---|---|---|---|---|
| 1 | `agent/prompt_builder.py` | 1,971 | `Core/Agent/Conversation/PromptBuilder.swift` | 579 | TICKET-HERMES-GAP-001 (2026-09-04) |
| 2 | `agent/agent_runtime_helpers.py` | 3,209 | `Core/Agent/Runtime/RuntimeHelpers.swift` | 336 | TICKET-HERMES-GAP-003 (2026-09-04) |
| 3 | `agent/tool_dispatch_helpers.py` | 503 | `Core/Agent/Tool/ToolDispatchHelpers.swift` | 197 | TICKET-HERMES-GAP-008 (2026-09-04) |
| 4 | `agent/skill_bundles.py` | 438 | `Core/Agent/Skill/SkillBundles.swift` | 176 | TICKET-HERMES-GAP-006 (2026-09-04) |
| 5 | `agent/secret_sources/` + `agent/secret_scope.py` | 605 | (folded into `Core/Provider/ProviderKeychain.swift` + AppleKeychain) | n/a | WENSHU-SIDE-WINS not needed — `Core/Provider` already covers BYOK per §11.3 |
| 6 | `agent/retry_utils.py` | 154 | (folded into `Core/Agent/Connector/RateLimitTracker.swift` + `ErrorClassifier.swift`) | n/a | WENSHU-SIDE-WINS — retry surface overlaps RateLimitTracker + ErrorClassifier; no dedicated file needed |
| 7 | `agent/shell_hooks.py` | 928 | `Core/Agent/Tool/ShellHookChain.swift` | 189 | TICKET-HERMES-GAP-004 (2026-09-04); spec §2.2 thin-port: hook-chain Swift protocol only |

**Net result (per today's audit refresh)**: 7 ❌ → 0 ❌ (all 7 now have Swift surface). **Combined with §A.1+§A.2+§A.3: 7+11+18+0 = 36 / 43 fully-port-with-stub-or-strict-shape, 0 missing.** The 18 ⚠️ partial modules are the work-tree per boss OOB.

---

# Part B — `hermes_cli/` (CLI surface) + `tools/` (LLM-tool surface)

The hermes CLI exposes front-ends (= `apps/desktop` Electron, `apps/tui`, `apps/dashboard`, `apps/gateway` ~20 messaging platforms per spec §2.4 out-of-scope). The hermes CLI modules relevant to wenshu are the **per-feature orchestration** modules: cron / kanban / goals / todo / memory / skills / plugins / setup / doctors / gateway / proxy / session. Plus the **LLM-tool surface** in `tools/` (= what the LLM agent can call: delegate / cronjob / browser / file / terminal / code-execution / memory / TTS / transcription / image-gen / video-gen / discord / slack / kanban / project / skills / voice-mode / homeassistant / feishu / microsoft_graph / etc.).

**Scope rule for wenshu:**
- (1) Direct port (= the capability is something wenshu v1 needs as an Apple-stack native feature, NOT as an LLM tool). E.g., `cron/jobs.py` parsing subset → `Core/Cron/CronScheduleParser.swift` is already shipped (v0.28 ticket 20); `goals.py` → `Core/Agent/Goals/HermesGoals.swift` just shipped; `kanban_db.py` business logic → `Core/Kanban/KanbanStore.swift` per v0.18 ticket 05.
- (2) LLM-tool surface (= hermes exposes this to its own agent via tool-call). Wenshu has no LLM agent loop yet (ConversationLoop not wired into ChatViewModel per v0.37 backlog candidate A), so the tool surface is conditionally needed once v0.37 ships.
- (3) CLI front-end (= subcommands/*) = NOT ported per spec §2.4 (wenshu is .app, not CLI; no Apple equivalent of argparse subcommands).

## B.1 ✅ Already ported (= direct match via wenshu-side wins pattern, no hermes dependency)

| hermes python | LOC | wenshu Swift | LOC | notes |
|---|---|---|---|---|
| `hermes_cli/cron.py` (parsing subset only) | n/a | `Core/Cron/CronScheduleParser.swift` | 221 | verbatim port per v0.28 batch 3 ticket 20 (file header verbatim cites hermes source) |
| `hermes_cli/kanban_db.py` (business logic subset only) | 8,723 | `Core/Kanban/KanbanStore.swift` | 345 | "复刻 hermes kanban_db.py 真值简化版" per file header (v0.18 ticket 05, extended v0.23 ticket 013.003) |
| `hermes_cli/goals.py` (Ralph loop) | 1,765 | `Core/Agent/Goals/HermesGoals.swift` | 163 | **just shipped 2026-09-04** per boss OOB; full hermes-side wins since wenshu-embedded-agent pos; embedded Ralph goal loop |
| `hermes_cli/todo*` (hermes todo_tool.py user-facing subset) | 330 | `Core/Todo/TodoStore.swift` + `Core/Agent/Todo/HermesTodoTool.swift` | 241 + 644 | "复刻 hermes todo 真值简化版" per TodoStore header (v0.18 ticket 06); HermesTodoTool (LLM-side) just shipped 2026-09-04 (= HERMES-SUBSYSTEM-4 ticket 026 step 4) |
| `tools/file_tools.py` (subset = read/write/patch) | 2,173 | `Core/Tools/FileTools.swift` + `Core/Agent/Tool/{ReadFileTool,WriteFileTool}.swift` | n/a | wenshu-side wins — FileTools = source of truth; thin agent-port wrappers |
| `tools/process_registry.py` (subset) | 2,219 | `Core/Tools/ProcessTools.swift` | n/a | wenshu-side wins |
| `tools/file_operations.py` (subset) | 2,423 | `Core/Tools/FileTools.swift` | n/a | wenshu-side wins |
| `tools/approval.py` (subset) | 3,242 | `Core/Agent/Tool/{ReadFileTool,WriteFileTool}.swift` | n/a | thin WriteApproval / approval gate |
| `tools/terminal_tool.py` (subset) | 3,029 | `Core/Tools/ProcessTools.swift` | n/a | terminal exec wrapper for LLM agent (= sourced from wenshu's ProcessTools.swift, not a direct tool) |
| `tools/memory_tool.py` (subset) | 1,152 | `Core/Agent/Memory/MemoryAdapter.swift` + `Core/Memory/MemoryTool*.swift` | n/a | wenshu-side wins — MemoryAdapter wraps MemoryManager |
| `tools/skills_tool.py` (subset) | 1,681 | `Core/Agent/Skill/SkillAdapter.swift` | n/a | wenshu-side wins |
| `tools/skills_hub.py` + `hermes_cli/skills_hub.py` | 4,099 + 1,997 | `Core/Skills/SkillRegistry.swift` + `Core/Agent/Skill/SkillAdapter.swift` | n/a | wenshu-side wins |
| `tools/skill_manager_tool.py` | 1,559 | `Core/Agent/Skill/SkillAdapter.swift` (skill install/disable/enable UX) | n/a | wenshu-side wins |
| `tools/skills_guard.py` | 1,086 | (folded into `Core/Skills/SkillRegistry.swift` validation gate) | n/a | wenshu-side wins |
| `tools/skills_sync.py` | 1,182 | `Core/Skills/SkillRegistry.swift` | n/a | wenshu-side wins |
| `tools/checkpoint_manager.py` | 1,675 | (delegates to `Core/Chat/ChatSessionStore.swift` per ChatSessionStore) | n/a | wenshu-side wins — session persistence handles checkpointing |

## B.2 ⚠️ Partial (= some wenshu surface exists; full hermes parity not landed)

| hermes python | LOC | wenshu Swift | what's missing | priority |
|---|---|---|---|---|
| `tools/cronjob_tools.py` (LLM-tool for cron) | 1,137 | (none — LLM-side tools don't yet exist) | wenshu has `Core/Cron/Cronjob.swift` for user-side; no LLM-tool for cron (= needs ConversationLoop wired first per v0.37 backlog candidate A) | P1 |
| `tools/kanban_tools.py` (LLM-tool for kanban) | 1,672 | (none) | wenshu has user-side `KanbanStore.swift`; needs LLM-tool adapter once v0.37 wires ConversationLoop | P1 |
| `tools/send_message_tool.py` (LLM-tool for cross-agent send) | 1,796 | `Core/Agent/Conversation/{SubAgentIdentity,SubAgentPermissions,AgentProtocol,AgentRuntime}.swift` (A2A protocol surface) | need explicit `send_message_tool.swift` LLM-tool that wraps A2A calls | P1 |
| `tools/vision_tools.py` | 1,897 | `Core/Tools/VisionTools.swift` (Apple Vision) | hermes uses fal/xai; wenshu wants Vision framework per §11 Apple-exclusive; thin adapter not yet wired into LLM-tool surface | P1 |
| `tools/web_tools.py` | 1,183 | `Core/Tools/WebTools.swift` (URLSession wrapper) | hermes has fal/xai/web-extract; wenshu has URLSession-based WebTools; need tool surface wrapper | P1 |
| `tools/voice_mode.py` | 1,218 | (none) | wenshu §11 = writing tool, no voice mode | P2 (out-of-scope per §11) |
| `tools/delegate_tool.py` | 3,459 | `Core/Agent/Conversation/{AsyncDelegation,SubAgentPermissions}.swift` + `Core/Agent/Goals/HermesGoals.swift` | per v0.23 ticket 012 + 013.010; full delegate tool surface still requires A2A task queue + result routing | P0 |
| `tools/code_execution_tool.py` | 1,910 | (delegates to `Core/Tools/ProcessTools.swift` per existing ProcessTools) | hermes has sandboxed code-exec subprocess (modal/daytona/singularity/docker backends); wenshu ProcessTools = exec-only; needs LLM-tool adapter | P1 |
| `tools/environments/*` (singularity/modal/daytona/docker/local/ssh/file_sync) | ~5,000 | (none — wenshu has no remote env concept per §11 Apple-stack) | hermes orchestrated remote compute envs; wenshu local-only per §11 | P2 (out-of-scope per §11) |
| `tools/computer_use/*` (cua_backend / permissions / vision_routing / tool / schema / doctor) | 2,102+ | (none) | wenshu has no computer-use | P2 (out-of-scope per §11) |
| `tools/blueprints.py` + `hermes_cli/kanban_specify.py` + `kanban_decompose.py` | small | (folded into `Core/Kanban/KanbanStore.swift`) | hermes blueprints = LLM-generated kanban task templates; wenshu KanbanStore has the state; needs blueprint authoring UI | P2 |
| `tools/project_tools.py` | small | `Core/Workspace/` (per book model) | hermes project = per-repo workspace config; wenshu = per-book | P2 |
| `tools/file_state.py` + `tool_result_storage.py` | small | (delegates to `Storage/BookStateStore.swift` / `Core/Agent/Connector/RequestHelpers.swift`) | OK | P2 |

## B.3 ❌ Not ported (= no wenshu Swift counterpart exists, NOT yet on backlog)

| hermes python | LOC | capability | why not ported | effort | priority |
|---|---|---|---|---|---|
| `tools/computer_use/*` (cua backend + tool + doctor + permissions) | 2,102+ | CUA-driven desktop automation | hermes uses cua-driver for OS control; wenshu = writing tool, no desktop automation intent | XL | P2 (out-of-scope per §11) |
| `tools/x_search_tool.py` + `tools/xai_video_tools.py` + `tools/yuanbao_tools.py` + `tools/feishu_doc_tool.py` + `tools/feishu_drive_tool.py` + `tools/discord_tool.py` + `tools/microsoft_graph_*` + `tools/homeassistant_tool.py` + `tools/slack_*` + `tools/dingtalk_*` + `hermes_cli/telegram_managed_bot.py` + `hermes_cli/slack_cli.py` + `hermes_cli/setup_whatsapp_cloud.py` + `tools/voice_mode.py` | ~10,000 | platform-specific LLM-tools (X / xAI video / yuanbao / Feishu docs+drive / Discord / Microsoft Graph / HomeAssistant / Slack / DingTalk / WhatsApp / Voice mode) | wenshu has no messaging platform per spec §2.4 "消息平台不包括" + §11 writing-tool positioning | XL each | 🚫 out-of-scope per §2.4 |
| `tools/transcription_tools.py` + `tools/tts_tool.py` | 1,799 + 2,870 | STT + TTS LLM-tools | wenshu §11 = writing tool, no TTS/STT | XL each | 🚫 out-of-scope per §2.3 + §11 |
| `tools/image_generation_tool.py` + `tools/video_generation_tool.py` + `agent/image_gen_*.py` + `agent/video_gen_*.py` + `agent/image_routing.py` + `agent/tts_*.py` + `agent/transcription_*.py` | 8,000+ | image-gen / video-gen / TTS / STT | wenshu §11 = novel writing tool, no media generation | XL | 🚫 out-of-scope per §2.3 |
| `tools/browser_tool.py` + `tools/browser_cdp_tool.py` + `tools/browser_supervisor.py` + `tools/browser_camofox*.py` + `tools/browser_dialog_tool.py` + `agent/browser_*.py` | 8,000+ | headless + CDP + supervisor + camofox + dialog-mode browser automation | wenshu v1 desktop tool, no browser needed per spec §2.3 "wenshu v1 = desktop tool, no browser" | XL | 🚫 out-of-scope per §2.3 |
| `tools/mcp_tool.py` + `tools/mcp_oauth*.py` + `tools/mcp_picker.py` + `hermes_cli/mcp_*.py` + `agent/transports/hermes_tools_mcp_server.py` | 9,000+ | MCP server tools + oauth + picker + startup + catalog + security | hermes exposes hermes's own tools as an MCP server to third-party agents; wenshu v1 has no third-party agent consumer | XL | P2 (post-v1 if wenshu wants to let third-party agents consume its tools) |
| `tools/cronjob_tools.py` (LLM-side cron surface; user-side is in B.1) | 1,137 | LLM-agent `hermes_cron_*` tools | wenshu has user-side Cronjob.swift; needs LLM-tool adapter | M | P1 (= B.2) |
| `hermes_cli/plugins.py` + `hermes_cli/plugins_cmd.py` + `tools/lazy_deps.py` + `agent/plugin_llm.py` | 5,000+ | hermes plugin system (third-party Python `*/plugin.py` discovery) | wenshu has its own plugin system (no plugins = Apple-stack) | XL | 🚫 out-of-scope (Apple ecosystem has no equivalent) |
| `hermes_cli/main.py` + `hermes_cli/commands.py` + `hermes_cli/cli_commands_mixin.py` + `hermes_cli/_parser.py` + `hermes_cli/_subprocess_compat.py` + all of `hermes_cli/subcommands/*` + `hermes_cli/pty_*` + `hermes_cli/win_pty_bridge.py` + `hermes_cli/gateway*.py` | 60,000+ | full hermes CLI surface (= argparse subcommands) | wenshu is .app, no CLI; no Apple equivalent | XL | 🚫 out-of-scope per §2.4 |
| `hermes_cli/setup.py` + `hermes_cli/setup_*` + `hermes_cli/uninstall.py` + `hermes_cli/gui_uninstall.py` + `hermes_cli/auth*.py` + `hermes_cli/auth_commands.py` + `hermes_cli/doctor.py` + `hermes_cli/security_*.py` | 15,000+ | hermes CLI setup / auth / doctor / uninstall / security audit | wenshu has its own Settings UI; no CLI | XL | 🚫 out-of-scope |
| `hermes_cli/proxy/server.py` + `hermes_cli/proxy/cli.py` + `hermes_cli/proxy/adapters/*` + `hermes_cli/web_server.py` + `hermes_cli/webhook.py` + `hermes_cli/web_git.py` + `hermes_cli/dashboard_*.py` + `hermes_cli/dashboard_auth/*` + `hermes_cli/curses_ui.py` + `hermes_cli/session_export*.py` + `hermes_cli/session_*` + `hermes_cli/active_sessions.py` + `hermes_cli/checkpoints.py` + `hermes_cli/curator.py` + `hermes_cli/profile*.py` + `hermes_cli/skin_engine.py` + `hermes_cli/colors.py` | 80,000+ | hermes dashboard / web / proxy / webhooks / git / curses / sessions / profiles / skins / colors | wenshu is .app; no web, no curses, no profiles, no skins (Apple HIG handles chrome) | XL | 🚫 out-of-scope per §2.4 |

---

# Part C — Out-of-scope per spec §2.3 (hermes-internal concerns wenshu does NOT need)

These files appear under `/Volumes/ANAN/.hermes/agent/` but are explicitly cut per `hermes-core-translation/spec.md` §2.3 (= the 25,000 LOC deletion list). They are **NOT porting candidates**. Listed once here for completeness.

## C.1 🚫 hermes SaaS / Codex / Nous-specific (no Apple equivalent)

| hermes python | LOC | reason (= per spec §2.3 row) |
|---|---|---|
| `agent/account_usage.py` | 696 | Hermes SaaS quota; wenshu not a hermes user |
| `agent/azure_identity_adapter.py` + `tools/microsoft_graph_*.py` | 1,565+ | Azure AD OAuth / Graph; wenshu BYOK doesn't use Azure AD |
| `agent/bedrock_adapter.py` + `transports/bedrock.py` | 1,496 | AWS Bedrock provider; wenshu BYOK doesn't use AWS |
| `agent/billing_view.py` | 295 | Token billing panel; wenshu doesn't resell tokens |
| `agent/codex_responses_adapter.py` | 1,353 | OpenAI Codex Responses API; wenshu doesn't use Codex API |
| `agent/codex_runtime.py` + `agent/copilot_acp_client.py` + `transports/codex*.py` | 4,500+ | Codex / Copilot / app-server transports; wenshu doesn't use Codex CLI or Copilot |
| `agent/models_dev.py` | 725 | models.dev metadata crawler; wenshu hardcodes 7 connector profiles |
| `agent/nous_rate_guard.py` | 325 | Nous Portal rate-limit; wenshu not on Nous Portal |
| `agent/portal_tags.py` | 64 | Nous Portal user tagging; wenshu not on Nous Portal |
| `agent/usage_pricing.py` | 981 | Token pricing table; wenshu BYOK doesn't price tokens |
| `agent/trace_upload.py` | 398 | Trace upload to hermes backend; wenshu has no hermes backend |

## C.2 🚫 pet / lsp / OCR / image / video / TTS / STT / browser (no wenshu use)

| hermes python | LOC | reason (= per spec §2.3 row) |
|---|---|---|
| `agent/pet/` (8 files) | 4,500+ | Mascot; wenshu Apple HIG serious product, no decoration |
| `agent/lsp/` (10 files: protocol / client / reporter / eventlog / servers / cli / range_shift / install / workspace / manager / __init__) | 4,000+ | LSP for code completion; wenshu = novel, not code editor |
| `agent/image_gen_*.py` + `agent/image_routing.py` + `agent/video_gen_*.py` + `agent/tts_*.py` + `agent/transcription_*.py` | 4,000+ | Media gen; wenshu §11 = novel-writing tool, no media gen |
| `agent/web_search_*.py` + `agent/browser_*.py` | 1,000+ | Web search + browser automation; wenshu v1 = desktop tool |

## C.3 🚫 hermes-only verifier / analytics / reason-scrubbing / SSL / redundancy

| hermes python | LOC | reason (= per spec §2.3 row) |
|---|---|---|
| `agent/verify_hooks.py` + `agent/verification_stop.py` + `agent/verification_evidence.py` | 1,000+ | Hermes internal verifier; wenshu has `WenshuVerifier.swift` |
| `agent/learning_graph.py` + `agent/learning_graph_render.py` + `agent/learning_mutations.py` | 1,200+ | Hermes-internal analytics; wenshu has no analytics surface |
| `agent/insights.py` | 921 | Hermes telemetry |
| `agent/think_scrubber.py` + `agent/thinking_timeout_guidance.py` + `agent/lmstudio_reasoning.py` | 570 | Reasoning-model handling; 7 connectors each handle their own |
| `agent/ssl_guard.py` + `agent/ssl_verify.py` | 157 | SSL verification helpers; Apple URLSession has built-in |
| `agent/replay_cleanup.py` + `agent/curator_backup.py` | 968 | Backup / replay; wenshu uses filesystem JSON |
| `agent/manual_compression_feedback.py` + `agent/iteration_budget.py` | 111 | Hermes iteration-budget control; wenshu has its own turn-budget UX |
| `agent/title_generator.py` | 204 | Session title auto-gen; wenshu has own session metadata |
| `agent/redact.py` | 811 | PII redactor; wenshu has own Apple HIG-style redactor |
| `agent/moa_loop.py` + `agent/moa_trace.py` | 1,240 | Mixture-of-Agents ensemble; v1 single-agent, MOA = v2 |
| `agent/vertex_adapter.py` + `agent/gemini_schema.py` + `agent/moonshot_schema.py` | 365 | GCP Vertex / Gemini / Moonshot schemas; covered by gemini_native_adapter + minimax_adapter |
| `agent/coding_context.py` | 883 | Code-mode context (≠ writing-tool context) |
| `agent/subdirectory_hints.py` | 270 | CWD hint discovery; wenshu RuntimeCWD owns this |
| `agent/portal_cli.py` + `agent/oneshot.py` + `agent/markdown_tables.py` + `agent/i18n.py` | 800 | Misc helper modules |
| `agent/auxiliary_client.py` (sub-modules used solely for hermes-specific: Bedrock, Nous, Azure, Vertex) | 1,500+ of 7,469 | only the connector-router subset is ported (= minimax + Anthropic + Gemini + DeepSeek + Ollama + OpenRouter); the Bedrock/Azure/Vertex/Nous adapters skipped per §2.3 |
| `transports/codex_app_server.py` + `transports/codex_app_server_session.py` + `transports/codex_event_projector.py` + `transports/codex.py` + `transports/hermes_tools_mcp_server.py` | 4,500+ | Codex + MCP-server transports; wenshu doesn't expose to MCP nor use Codex |

## C.4 🚫 wenshu-side-wins per spec §11.3 + 5-subsystem decision (already covered by other wenshu Core)

| hermes python | LOC | reason wenshu-side wins (= covered by other wenshu surface) |
|---|---|---|
| `hermes_cli/cron.py` (scheduling/tick loop subset) | (subset of total) | wenshu uses `cron/CronScheduleParser.swift` for parsing + macOS LaunchAgent for actual scheduling (= per `CronScheduleParser.swift` file header verbatim: "wenshu uses macOS LaunchAgent for the actual scheduling; hermes's file-lock-based scheduler doesn't apply to single-process macOS apps"). hermes's `scheduler.py` (3,638 LOC) tick loop = NO equivalent in wenshu per §11 Apple-stack + single-process |
| `hermes_cli/kanban_db.py` (cross-process claim/lock subset) | 8,723 | wenshu `Core/Kanban/KanbanStore.swift` is "复刻 hermes kanban_db.py 真值简化版" (no claim/lock; per-book SQLite, actor-isolated). The cross-process layer doesn't apply since wenshu = single-process |
| `hermes_cli/todo_*.py` (LLM-runtime todo subset) | n/a | wenshu `Core/Todo/TodoStore.swift` = per-book user-facing todo; wenshu `Core/Agent/Todo/HermesTodoTool.swift` (= HERMES-SUBSYSTEM-4 ticket 026 step 4, 2026-09-04) = LLM-runtime todo for the embedded agent |
| `hermes_cli/goals.py` (Ralph loop full) | 1,765 | wenshu `Core/Agent/Goals/HermesGoals.swift` (= 2026-09-04) = embedded Ralph goal loop matching the wenshu-embedded-agent-positioning per boss OOB |
| (hermes OCR — `ocr.py`) | n/a | **does NOT exist** in hermes; previous brief's claim was a fabrication per `.scratch/2026-09-04-hermes-5-subsystem-1to1-port-decision.md` line 27-29 |

---

# Part D — Embedded-agent capabilities (the boss 2026-09-04 OOB framing)

The boss OOB says "wenshu IS the embedded agent platform; user BYOK enables embedded editorial-team agents". This means hermes-side capabilities that the **embedded editorial agents** (= the ~5 sub-agents under WenshuConductor: 心理师/剧情调度/审校/排版/soul-summary) would need. Per AGENTS.md §11.3 + the manifest, these are:

| embedded-agent capability (= what the editorial sub-agents need) | hermes source | wenshu current state | gap |
|---|---|---|---|
| Sub-agent spawn / delegation (= WenshuConductor → sub-agent) | `agent/conversation_loop.py` + `tools/delegate_tool.py` + `tools/async_delegation.py` | `AgentRuntime.swift` + `AgentProtocol.swift` (A2A) + `AsyncDelegation.swift` (v0.23 ticket 013.010) + `SubAgentIdentity.swift` (v0.23 ticket 001) + `SubAgentPermissions.swift` (v0.23 ticket 012) + `WenshuConductor.swift` + `HermesGoals.swift` (= HermesGoals = the goal-continuation "Ralph loop" – just shipped) | P0 to wire ConversationLoop → AgentRuntime → SubAgent[identity+permissions] via A2A = must land for v0.37 tracer-bullet |
| Embedded memory (= sub-agent reads per-book memory) | `agent/memory_manager.py` + `agent/memory_provider.py` + `tools/memory_tool.py` | `Core/Agent/Memory/MemoryAdapter.swift` + `Core/Memory/{MemoryManager,MemoryProvider,MemoryStore,MemoryConsolidator,MemoryWriteGate}.swift` (wenshu-side wins) | OK = ported via wenshu-side wins; gap-fill = `ContextEngine.swift` returns empty bundles (TODO ticket-009) |
| Embedded skills (= sub-agent invokes skill mid-task) | `agent/skill_*.py` + `tools/skills_*.py` | `Core/Agent/Skill/SkillAdapter.swift` + `Core/Skills/Skill{Registry,Meta}.swift` + `SkillBundles.swift` (2026-09-04) | OK = ported; gap-fill = `SkillAdapter` only has `parseSlashCommand`; no `do_*` hub for sub-agent (`skill_commands.py` partial) |
| Embedded tools (= sub-agent calls file/terminal/web/vision tools) | `tools/file_tools.py` + `tools/terminal_tool.py` + `tools/web_tools.py` + `tools/vision_tools.py` + `tools/process_registry.py` | `Core/Tools/{FileTools,ProcessTools,WebTools,VisionTools}.swift` (source of truth) + `Core/Agent/Tool/{Tool,ToolExecutor,ToolGuardrails,ReadFileTool,WriteFileTool}.swift` | OK = ported; gap-fill = `ToolExecutor` concurrent body empty; `ToolDispatchHelpers.swift` ships but not yet wired into `ToolExecutor` |
| Embedded error / retry (= sub-agent handles errors) | `agent/error_classifier.py` + `agent/retry_utils.py` + `agent/rate_limit_tracker.py` + `agent/turn_retry_state.py` | `Core/Agent/Connector/{ErrorClassifier,RateLimitTracker}.swift` + `Core/Agent/Conversation/TurnRetryState.swift` | OK for direct port of error+retry+rate; `retry_utils.py` folded into ErrorClassifier per §A.4 |
| Embedded credentials (= sub-agent authenticates BYOK provider) | `agent/credential_pool.py` + `agent/credential_sources.py` + `agent/credential_persistence.py` + `agent/secret_sources/` + `agent/secret_scope.py` | `Core/Provider/{ProviderKeychain,AppleKeychainStore,InMemoryKeychainStore,ProviderKeychainMetadata,OAuthFlow}.swift` (source of truth, wenshu-side wins) + `Core/Agent/Connector/ConnectorCredentials.swift` (thin adapter) | OK for the keychain surface; gap-fill = `credential_sources.py` partial (env-var fallback missing); secret_sources folded into ProviderKeychain per §A.4 |
| Embedded conversation loop (= one user turn → response) | `agent/conversation_loop.py` | `Core/Agent/Conversation/ConversationLoop.swift` (197 LOC) | ⚠️ partial — never calls ToolExecutor / Compression / TurnRetryState. P0 to wire before embedded agents work end-to-end |
| Embedded multi-agent A2A (= sub-agents talk to each other) | (hermes CLI `gateway.py` = a HTTP gateway between sibling CLI instances; not a hermes-agent concern) | `AgentProtocol.swift` (A2A per Google A2A spec) + `AgentRuntime.swift` + `SubAgentIdentity.swift` + `SubAgentPermissions.swift` | OK for A2A surface; needs explicit `send_message_tool.swift` LLM-tool that wraps A2A calls (in B.2 ⚠️) |

---

# Part E — Headline counts (for the parent agent's backlog gap-fill plan)

| Class | Files | LOC (hermes) | Notes |
|---|---|---|---|
| ✅ A.1 Direct port (spec §2.1) | 7 | 6,693 | Full 1:1 behavior match per spec verification |
| ✅ A.2 Wenshu-side wins (spec §2.1+§2.2) | 11 | 16,071 | Source of truth = existing wenshu Core; thin adapter |
| ⚠️ A.3 Partial (spec §2.1, work-tree backlog) | 18 | 18,553 | Stub surface; ready for gap-fill per boss OOB |
| ❌ A.4 Not ported = spec scope | 0 | 0 | 7 ❌ from 2026-09-04 audit closed by TICKET-HERMES-GAP-001..008 + secret_sources/retry_utils wenshu-side-wins |
| ✅ B.1 hermes_cli+tools already ported | ~17 modules | n/a | cron schedule / kanban / todo / goals / file / process / memory / skills / etc. |
| ⚠️ B.2 hermes_cli+tools partial | ~12 modules | n/a | cronjob / kanban / send_message / vision / web / delegate / code_exec / envs / computer_use / blueprints / project / file_state — most need v0.37 ConversationLoop wiring before they can be filled in |
| ❌ B.3 hermes_cli+tools not ported + in-scope | ~5-8 modules | n/a | only those that wenshu will eventually want as LLM-tools; most out-of-scope per §2.4 |
| 🚫 C.1 SaaS/Codex/Nous | ~25 files / 10,000 LOC | — | out-of-scope per §2.3 |
| 🚫 C.2 pet/lsp/OCR/media/browser | ~30 files / 17,500 LOC | — | out-of-scope per §2.3 |
| 🚫 C.3 hermes-only internals | ~30 files / 8,500 LOC | — | out-of-scope per §2.3 |
| 🚫 C.4 wenshu-side wins (cron/kanban/todo/goals/OCR) | ~3 modules | — | already shipped per §11.3 + 5-subsystem decision |
| **Totals** | ~430 .py / 349k LOC | — | ≈ 25,000 LOC explicit cut per §2.3; ≈ 43,000 LOC in 43 §2.1+§2.2 modules; ≈ 281,000 LOC CLI + LLM-tool surface (mostly 🚫 out-of-scope per §2.4) |

---

# Part F — Backlog gap-fill recommendation (= actionable for the parent)

Priority order (= per boss OOB "继续把工作树干完" + gap audit):

### P0 — must ship before v0.37 tracer-bullet can run end-to-end

1. **Wire `ConversationLoop.swift` → `ToolExecutor.executeConcurrent/Sequential` + `ConversationCompression.historyAfterCompression` + `TurnRetryState.canRetry`** (= fills `conversation_loop.py` partial; LOC ~5,312 hermes / ~+500-700 Swift). This is the v0.37 backlog candidate A.
2. **Wire `ToolExecutor.swift` → `ToolDispatchHelpers.swift`** (= ships 6 missing helpers; ~+150 Swift LOC). v0.37 candidate A.
3. **Wire `AgentRuntime.swift` → `SubAgentIdentity` + `SubAgentPermissions`** (= gates the embedded agent multi-agent flow per boss OOB "embedded editorial-team agents"). v0.37 candidate A.
4. **Ship LLM-tool `send_message.swift`** (= wraps `AgentProtocol` A2A surface for embedded sub-agent delegation). v0.37 candidate A.

### P1 — important but not blocking v0.37

5. Fill `anthropic_adapter.py` partials (= redacted_thinking blocks + signature propagation + multi-content image/document blocks). ~+200 Swift LOC.
6. Fill `auxiliary_client.py` partials (= SSE coalescing + advanced fallback chain + per-connector ByteStream). ~+300 Swift LOC.
7. Fill `model_metadata.py` partials (= pricing + per-model context window). ~+150 Swift LOC.
8. Fill `conversation_compression.py` (auto-trigger + persistence). ~+150 Swift LOC.
9. Fill `system_prompt.py` (per-provider / per-locale / dynamic tier). ~+200 Swift LOC.
10. Fill `credential_sources.py` (env-var fallback + system-credential lookup). ~+100 Swift LOC.
11. Fill `skill_commands.py` (35 do_* hub for sub-agent skill invocation). ~+400 Swift LOC.
12. Wire `ContextEngine.swift` + `MemoryManager.prefetch` + character/world prefetch (per inventory-beyond-backlog item #10). ~+200 Swift LOC.
13. Wire `Settings → Agent 3-pane` (= LLMConnectorSettingsView already exists, needs NavigationLink in Settings scene). v0.37 candidate C.

### P2 — defer (= not blocking, low ROI for v1)

14. Fill `turn_context.py`, `turn_finalizer.py`, `message_sanitization.py`, `message_content.py`, `context_references.py`, `tool_result_classification.py`. ~+300 Swift LOC total.
15. Fill `skill_preprocessing.py` (dedicated file; could remain inlined).
16. Fill `agent_init.py` partial (= covers subagent lifecycle instead of agent_init bootstrap).
17. Fill `context_engine.py` empty bundles (= gated on ticket 009 prefetch wiring).

### Out-of-scope per §2.3 + §2.4 + §11.3 (= no ticket needed)

All of Part C (C.1-C.4) + all of B.3 subcommands/* + most of the platform-specific LLM-tools (Discord / Slack / Feishu / Microsoft Graph / HomeAssistant / Telegram / WhatsApp / Voice mode / TTS / STT / image-gen / video-gen / browser / computer-use / MOA / portal / Nous / Bedrock / Azure / Codex / Copilot / pricing / usage / billing / SaaS / OCR / pet / lsp / trace / replay / curator-backup / ssl / iteration-budget / manual-compression-feedback / reason-scrub / learning-graph / insights / title-generator / redact / moonshot / vertex / coding-context / subdirectory-hints / markdown-tables / portal-cli / oneshot / i18n / mixed).
