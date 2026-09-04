# Spec — Hermes core agent translation into Wenshu (老板 2026-09-03 拍 'hermes core 用 swift 翻译, 文枢独立 agent')

- Date: 2026-09-03
- Boss OOB 2026-09-03 verbatim: '如果把 hermes 核心的, 除了几个前端, 其它的所有代码用 swift 翻译一遍, 在文枢的 agent 部分, 完全复刻整套 hermes, 做得到吗'
- Boss follow-up OOB (after Q&A round 1): '项目级的不依赖, 文枢不能依赖用户先安装 hermes 才能使用我们的 APP, 但如果我们的 APP, agent 部分可以直接复用 hermes 的原码也可以。我只是不知道 python 和我们的 APP 是否可以混用'
- Boss follow-up OOB (after Q&A round 2): '没有任何推荐, 用户自己决定, 和 hermes 一样, 我们提供的是写小说的工具。不是 LLM 提供商' + '文枢不提供这个服务, 文枢只卖工具'
- Boss verdict on all 12 questions: 全按推荐 (boss accepted every recommendation in the 12-question grill round 2026-09-03)
- Methodology source: wenshu `.scratch/2026-08-19-frontend-integration/35-skills-methodology.md` (po main flow 6 steps, boss 8/19 拍 must keep verbatim). Current spec is the output of step 3 (to-spec) with all 12 grill decisions locked.
- Spec status: spec approved by boss 2026-09-03, ready for step 4 (to-tickets).
- Implementation status: not started. Tracer-bullet ticket = issue 001 of this spec.
- Source repo: `/Volumes/ANAN/.hermes/agent/` (hermes source tree). Verified identical to `/Volumes/ANAN/.hermes/hermes-agent/agent/` mirror at 2026-09-03.
- Wenshu repo: `/Volumes/ANAN/Engineering/wenshu/`
- Worktree: `wt/multi-agent-dispatch` (current active branch, v0.34 ship sequence is in flight; this spec ships in same worktree as v0.34+, ticket 001 tracer-bullet = first commit of v0.35+ agent translation layer).

## 0. Boss decisions, verbatim from 3-round grill (2026-09-03)

| # | Question | Boss verdict | Rationale |
|---|---|---|---|
| Q1 | Scope of "复刻" | Scope B = Scope A + grey modules (thin port) | Boss: '核心 agent 相关的所有, 几个前端 + 消息平台不包括, 其它在我看来的全都需要. 如果有你觉的文枢用不到的, 你可以罗列, 告诉我这是做什么的, 我来判断是不是真的非必要' |
| Q2 | Project-level hermes dependency | Project-level NOT dependent; single-process .app; Python NOT embedded | Boss: '项目级的不依赖, 文枢不能依赖用户先安装 hermes 才能使用我们的 APP. 但 agent 部分可以直接复用 hermes 的原码也可以' |
| Q3 | LLM port architecture | 7 connectors, provider-agnostic, NO default recommendation, user BYOK | Boss: '没有任何推荐, 用户自己决定, 和 hermes 一样, 我们提供的是写小说的工具. 不是 LLM 提供商' |
| Q4 | Business model | BYOK only, tool-only, no token reselling, no managed mode | Boss: '文枢不提供这个服务, 文枢只卖工具' |
| Q5 | Final port scope (Q1 pushback) | Scope B (= A + grey thin-port) | Boss accepted after seeing the 25,000 LOC cuttable list + 5,000 LOC grey optional list |
| Q6 | Python/Swift mixing | Path 1 = Pure Swift translation | Boss accepted after seeing hermes core has no PyTorch/numpy/heavy C-extension (only asyncio + httpx + stdlib) |
| Q7 | §11 baseline wording rewrite | Rewrite + §11.2 7-connector-profile section | Boss accepted verbatim rewrite of 'v1 LLM provider supports minimax cn only' line |
| Q8 | §11 product-positioning addition | Add 'tool-only' principle at §11 top | Boss accepted to lock out future 'managed mode' PRs |
| Q9 | Branch strategy | Single wt + tracer-bullet + edge tickets (strategy 3) | Boss accepted because aligned with §11 '1 ticket 1 commit' + /to-tickets blocking-edge model |
| Q10 | First tracer-bullet scope | TB-B = conversation_loop + tool_executor + 1 connector (minimax) + 2 stub tools | Boss accepted; 6 weeks, end-to-end runs |
| Q11 | Port style | Direct port + Swift idiom correction + `// SWIFT-PORT:` comment prefix | Boss accepted; long-term = upstream sync friendly |
| Q12 | Verification | Z contract test per ticket (golden file) + X e2e dual-track every 5 tickets | Boss accepted; rejects Y (single-track e2e) because misses protocol-layer drift |

### 0.1 Truth-survey findings (boss Q21 = truth-survey mode 2026-09-03)

After grill completion, boss requested deep fact-finding on (A) hermes Python target, (B) wenshu existing spec §7 / ChatView / WenshuVerifier, (C) wenshu §11 baseline. Findings:

| Source | Finding | Spec impact |
|---|---|---|
| **A** hermes `conversation_loop.py` L523-L546 | `run_conversation(agent, user_message, system_message=None, conversation_history=None, task_id=None, stream_callback=None, persist_user_message=None, persist_user_timestamp=None, moa_config=None)` returns `Dict[str, Any]` | §3.4 documents exact Swift signature for ticket 001 |
| **A** hermes `tool_executor.py` L306 / L965 | `execute_tool_calls_concurrent` and `execute_tool_calls_sequential` both take `(agent, assistant_message, messages, effective_task_id, api_call_count=0)` and mutate messages list in place | §3.4 documents these helpers map to actor-isolated Swift functions with `// SWIFT-PORT:` comments |
| **A** hermes `anthropic_adapter.py` L1689-1694 / L1750-1751 / L1880-1881 / L1898 | cache_control marker on tools + content parts + assistant blocks (= 4 wire-format hook points) | §3.3 + ticket 002 confirmed; each Swift implementation maps to a specific hermes Python line range |
| **B** wenshu `WenshuVerifier.swift` L279-L337 | `send(request:outputKind:extraSystemPrompt:) async throws -> WenshuLLMResponse` already exists (= v0.34 ship). URLSession.shared.data(non-streaming) + SSEClient.swift(streaming). 7 public types. | §3.4 ticket 001 rewires `WenshuVerifier.send()` to delegate to `LLMConnector.send()` instead of building URLRequest directly |
| **B** wenshu `ChatView.swift` L941 | `ChatMessageView` exists (= tool_use rendering surface for ticket 001's 🟨 tier) | §6.4 UI mapping confirmed |
| **C** wenshu `AGENTS.md` §11 L14-L36 (= 22 line baseline block) | Stack / v1 LLM provider / .ws directory / Apple stack / version format / etc. all must be preserved; L17 "v1 LLM provider supports minimax cn only" is the SOLE line that gets rewritten (= §7.1) | §7 documents exact 4-edit diff (L17 rewrite + product-positioning insertion + §11.2 new + §11.3 new) |
| **C** wenshu `AGENTS.md` §11.1 L37-L75 | third-party lib policy UNCHANGED (= already ratified 2026-08-28) | §11.1 not touched by ticket 011 |

These findings make spec §3.4-§3.6 deterministic (= no more guessing during ticket implementation). They also confirm scope estimate (~24,000 Swift LOC + ~3,000 docs lines) is realistic.

## 1. Problem statement

Hermes ships an agent core that wenshu's v1 LLM-driven writing UX depends on. Today wenshu's agent layer (`Sources/WenshuApp/Core/Agent/`, 2,182 LOC across 13 files) is a thin wrapper around a single Anthropic-compatible call to minimax cn (per AGENTS.md §11 baseline, 2026-08-14 owner decision). The wrapper lacks the proven agent runtime pieces that hermes ships: byte-stable prompt caching, conversation loop with tool dispatch, context compression, multi-provider credential pool, multi-platform tool dispatch.

Wenshu's target customer segment will not necessarily use hermes; some will bring their own LLM key. The product must therefore:

(a) ship as a self-contained .app that does not require the user to install hermes,
(b) expose a connector layer where the user picks any of 7 mainstream LLM providers,
(c) never position wenshu as an LLM platform, never resell tokens, never hold user keys on a wenshu backend.

Direct port of hermes core agent into Swift, in-process, satisfies all three constraints while inheriting hermes' design wins (cache-stable system prompt, alternation-safe message loop, tool dispatch, context compression).

## 2. Scope (Scope B = A + grey thin-port)

### 2.1 In-scope: must-translate core (~30 modules, ~60,000 Python LOC → ~55,000 Swift)

These modules are the agent engine. Every one of them touches the conversation loop, tool dispatch, or LLM call path. None can be skipped without losing the "hermes-grade agent" target.

| # | Source | LOC | Role |
|---|---|---|---|
| 1 | `agent/conversation_loop.py` | 5,312 | Agent main loop = one user turn through model call / tool dispatch / retries / fallbacks / compression / post-turn hooks |
| 2 | `agent/auxiliary_client.py` | 7,469 | Multi-provider adapter (Anthropic + OpenAI-compatible), token metering, stream coalescing |
| 3 | `agent/tool_executor.py` | 1,646 | Single tool-call dispatch + result classification |
| 4 | `agent/prompt_builder.py` | 1,971 | Composes the final system-prompt blocks; stable tier + dynamic tier |
| 5 | `agent/prompt_caching.py` | 119 | Pure functions for `apply_anthropic_cache_control` (4-breakpoint layout) |
| 6 | `agent/context_compressor.py` | 3,082 | Token-budget aware context compression; rolling summary |
| 7 | `agent/conversation_compression.py` | 1,367 | Long-conversation compaction (manual + auto triggers) |
| 8 | `agent/chat_completion_helpers.py` | 3,103 | Anthropic + OpenAI request/response marshaling |
| 9 | `agent/agent_runtime_helpers.py` | 3,209 | Runtime state dict, flags, credentials resolution |
| 10 | `agent/agent_init.py` | 2,103 | AIAgent bootstrap, config wiring |
| 11 | `agent/anthropic_adapter.py` | 2,789 | Anthropic native wire format (cache_control marker, content parts, tool_result, redacted_thinking) |
| 12 | `agent/credential_pool.py` | 2,384 | BYOK credential pool, key rotation, OAuth + API key split |
| 13 | `agent/error_classifier.py` | 1,598 | Provider error → user-actionable taxonomy |
| 14 | `agent/turn_context.py` | ~700 | Per-turn state bundle |
| 15 | `agent/turn_finalizer.py` | ~600 | Turn-end normalization (text + tool_use coalescing) |
| 16 | `agent/turn_retry_state.py` | ~400 | Retry budget per turn |
| 17 | `agent/message_sanitization.py` | ~300 | Strip control chars, normalize whitespace |
| 18 | `agent/message_content.py` | ~400 | Content-block canonicalization |
| 19 | `agent/tool_guardrails.py` | ~500 | Pre-tool safety check (path scope, secret scan) |
| 20 | `agent/tool_dispatch_helpers.py` | ~600 | Tool dispatch pre/post hooks |
| 21 | `agent/tool_result_classification.py` | ~400 | Tool result → user-visible / background / error classification |
| 22 | `agent/system_prompt.py` | 536 | Byte-stable system prompt tier (cache-stable prefix) |
| 23 | `agent/context_engine.py` | 924 | Context aggregator (world / character / chapter / foreshadow) |
| 24 | `agent/context_breakdown.py` | ~300 | Token count breakdown |
| 25 | `agent/context_references.py` | ~500 | Cross-turn reference resolver |
| 26 | `agent/model_metadata.py` | 2,434 | Per-provider model catalog (capabilities, context window, pricing) |
| 27 | `agent/memory_manager.py` | 1,086 | Memory storage + retrieval |
| 28 | `agent/memory_provider.py` | ~400 | Memory backend (filesystem JSON in wenshu; SQLite in hermes) |
| 29 | `agent/skill_utils.py` | ~700 | Skill load + dispatch |
| 30 | `agent/skill_preprocessing.py` | ~400 | Skill pre-compile (frontmatter parse) |
| 31 | `agent/skill_commands.py` | ~500 | Skill slash-command surface |
| 32 | `agent/skill_bundles.py` | ~300 | Skill bundle discovery |
| 33 | `agent/secret_sources/` + `agent/secret_scope.py` | ~600 | Secret scope resolution (BYOK + system + env) |
| 34 | `agent/rate_limit_tracker.py` | ~300 | Provider rate-limit backoff |
| 35 | `agent/credential_persistence.py` | ~400 | Credential persistence across sessions |
| 36 | `agent/credential_sources.py` | ~300 | Credential source resolution |
| 37 | `agent/retry_utils.py` | ~300 | Generic retry helper |
| 38 | `agent/runtime_cwd.py` | ~200 | Runtime cwd resolution per book |

Total: ~58,000 Swift LOC target.

### 2.2 In-scope: grey thin-port (~5 modules, ~5,000 Python LOC → ~3,000 Swift)

These are "thin" because we translate only the state-machine interface, not the full TUI/cron infra.

| Source | LOC | Thin-port behavior |
|---|---|---|
| `agent/display.py` | 1,440 | Extract turn status enum + streaming chunk observer; no TUI rendering |
| `agent/shell_hooks.py` | 928 | Extract hook-chain Swift protocol; user scripts optional, default off |
| `agent/background_review.py` | 960 | Review state enum only; wenshu reviews are user-triggered, no background loop |
| `agent/curator.py` | 1,976 | State-machine interface for memory/skill curation; no cron, no background loop |
| `agent/credits_tracker.py` | ~400 | Token counter only; no pricing, no quota |

Total: ~3,000 Swift LOC.

### 2.3 Out-of-scope: explicitly NOT translated (~25,000 Python LOC)

These modules are hermes SaaS / Codex-specific / pet / lsp / browser. Wenshu has no use for them. Boss Q1 acceptance = "你罗列后我可以判断非必要" — all 25,000 LOC are non-essential for wenshu.

| Source | LOC | Reason for cut |
|---|---|---|
| `account_usage.py` | 671 | Hermes SaaS quota; wenshu is not a hermes user |
| `azure_identity_adapter.py` | 706 | Azure AD OAuth; wenshu BYOK doesn't use Azure AD |
| `bedrock_adapter.py` | 1,342 | AWS Bedrock provider; wenshu BYOK doesn't use AWS |
| `billing_view.py` | 301 | Token billing panel; wenshu doesn't resell tokens |
| `codex_responses_adapter.py` | 1,353 | OpenAI Codex Responses API; wenshu doesn't use Codex API |
| `codex_runtime.py` | 1,273 | Codex CLI subprocess; wenshu doesn't use Codex CLI |
| `copilot_acp_client.py` | 857 | GitHub Copilot ACP client; wenshu doesn't use Copilot |
| `image_gen_provider.py` / `image_gen_registry.py` / `image_routing.py` | ~1,500 | Image generation; wenshu §11 = novel-writing tool, no image gen in v1 |
| `video_gen_provider.py` / `video_gen_registry.py` | ~800 | Video generation; same reason |
| `transcription_provider.py` / `transcription_registry.py` | ~600 | STT; wenshu §11 = writing tool, no STT |
| `tts_provider.py` / `tts_registry.py` | ~600 | TTS; same reason |
| `pet/` | ~3,000 | Mascot; wenshu Apple HIG serious product, no decoration |
| `lsp/` (client + servers) | ~2,000 | LSP for code completion; wenshu = novel, not code editor |
| `learning_graph*.py` (3 files) | ~1,500 | Hermes-internal analytics graph; wenshu has no analytics surface |
| `usage_pricing.py` | 981 | Token pricing table; wenshu BYOK doesn't price tokens |
| `portal_tags.py` | 200 | Nous Portal user tagging; wenshu not on Nous Portal |
| `nous_rate_guard.py` | 200 | Nous Portal rate-limit; same |
| `models_dev.py` | ~500 | models.dev metadata crawler; wenshu hardcodes 7 connector profiles |
| `trace_upload.py` | ~300 | Trace upload to hermes backend; wenshu has no hermes backend |
| `moa_loop.py` / `moa_trace.py` | ~1,300 | Mixture-of-Agents ensemble; v1 single-agent, MOA = v2 |
| `verify_hooks.py` / `verification_stop.py` / `verification_evidence.py` | ~600 | Hermes internal verifier; wenshu already has WenshuVerifier.swift |
| `curator_backup.py` | ~300 | Curator backup script; wenshu uses filesystem JSON backup |
| `replay_cleanup.py` | ~300 | Session replay cleanup; wenshu uses own session store |
| `ssl_guard.py` / `ssl_verify.py` | ~400 | SSL verification helpers; Apple URLSession has built-in |
| `manual_compression_feedback.py` / `iteration_budget.py` | ~500 | Hermes iteration-budget control; wenshu has its own turn-budget UX |
| `think_scrubber.py` / `thinking_timeout_guidance.py` / `lmstudio_reasoning.py` | ~500 | Reasoning-model handling; 7 connectors each handle their own |
| `title_generator.py` | ~400 | Session title auto-gen; wenshu has own session metadata |
| `web_search_provider.py` / `web_search_registry.py` / `browser_provider.py` / `browser_registry.py` | ~3,000 | Web search + browser automation; wenshu v1 = desktop tool, no browser |
| `redact.py` | ~500 | PII redactor; wenshu has own Apple HIG-style redactor |

Total cut: ~25,000 Python LOC.

### 2.4 Out-of-scope: hermes front-ends and messaging (boss Q1 verbatim)

- `apps/desktop/` (Electron Hermes.app) — wenshu uses SwiftUI, no Electron port
- `apps/tui/` (Ink TUI) — wenshu uses SwiftUI, no TUI port
- `apps/dashboard/` (web dashboard) — wenshu uses SwiftUI, no web port
- `apps/gateway/` (Telegram / Discord / Slack / WhatsApp / iMessage / Signal / Matrix / Teams / Email / ~20 more) — boss Q1: '消息平台不包括'
- `transports/codex_app_server_session.py` — Codex-specific transport, out of scope

## 3. Architecture

### 3.1 Wenshu-side module layout (target after this spec lands)

```
Sources/WenshuApp/Core/Agent/
├── Agent/                          (= existing, becomes the public façade)
│   ├── AgentRuntime.swift
│   ├── AgentProtocol.swift
│   ├── AgentLifecycleTracker.swift
│   ├── AgentIdentity.swift
│   ├── AgentPermissions.swift
│   ├── AsyncDelegation.swift
│   ├── OutputKind.swift
│   ├── SubAgentIdentity.swift
│   └── WenshuAgentIdentity.swift
├── Conversation/                   (NEW — port of hermes agent core)
│   ├── ConversationLoop.swift             (= port of conversation_loop.py 5312 LOC → ~4,000 Swift)
│   ├── TurnContext.swift                  (= turn_context.py)
│   ├── TurnFinalizer.swift                (= turn_finalizer.py)
│   ├── TurnRetryState.swift               (= turn_retry_state.py)
│   ├── MessageSanitization.swift          (= message_sanitization.py)
│   ├── MessageContent.swift               (= message_content.py)
│   ├── PromptBuilder.swift                (= prompt_builder.py 1971 LOC → ~1,400 Swift)
│   ├── PromptCaching.swift                (= prompt_caching.py 119 LOC → ~80 Swift)
│   ├── SystemPrompt.swift                 (= system_prompt.py 536 LOC → ~400 Swift)
│   ├── ContextCompressor.swift            (= context_compressor.py 3082 LOC → ~2,300 Swift)
│   ├── ConversationCompression.swift      (= conversation_compression.py 1367 LOC → ~1,000 Swift)
│   ├── ContextEngine.swift                (= context_engine.py 924 LOC → ~700 Swift)
│   ├── ContextBreakdown.swift             (= context_breakdown.py)
│   └── ContextReferences.swift            (= context_references.py)
├── Connector/                      (NEW — port of hermes provider layer)
│   ├── LLMConnector.swift                 (= port of auxiliary_client.py 7469 LOC → ~5,500 Swift, provider-agnostic façade)
│   ├── ConnectorProfile.swift             (= provider catalog + auth resolution)
│   ├── ConnectorCredentials.swift         (= credential_pool.py + credential_persistence.py + credential_sources.py + secret_sources/)
│   ├── AnthropicConnector.swift           (= anthropic_adapter.py 2789 LOC → ~2,100 Swift; Anthropic native)
│   ├── OpenAICompatibleConnector.swift    (= OpenAI / DeepSeek / Ollama / OpenRouter / minimax; all OpenAI-compatible protocol)
│   ├── GeminiNativeConnector.swift        (= gemini_native_adapter.py 1021 LOC → ~800 Swift)
│   ├── VertexConnector.swift              (= vertex_adapter.py; P2, deferred to v1.x)
│   ├── ModelMetadata.swift                (= model_metadata.py 2434 LOC → ~1,800 Swift)
│   ├── ErrorClassifier.swift              (= error_classifier.py 1598 LOC → ~1,200 Swift)
│   └── RateLimitTracker.swift             (= rate_limit_tracker.py)
├── Tool/                          (NEW — port of hermes tool layer)
│   ├── ToolExecutor.swift                 (= tool_executor.py 1646 LOC → ~1,200 Swift)
│   ├── ToolDispatchHelpers.swift          (= tool_dispatch_helpers.py)
│   ├── ToolGuardrails.swift               (= tool_guardrails.py)
│   ├── ToolResultClassification.swift     (= tool_result_classification.py)
│   ├── ShellHooks.swift                   (= shell_hooks.py thin port)
│   └── ReadFileTool.swift + WriteFileTool.swift  (TB-B's 2 stub tools)
├── Memory/                        (NEW — wenshu-side memory, NOT a hermes port)
│   ├── MemoryManager.swift
│   ├── MemoryProvider.swift
│   └── MemoryStore.swift                  (= filesystem JSON; wenshu §11 baseline)
├── Skill/                         (NEW — wenshu-side skill, NOT a hermes port)
│   ├── SkillUtils.swift                   (= thin port of skill_utils.py for protocol shape)
│   ├── SkillPreprocessing.swift
│   ├── SkillCommands.swift
│   └── SkillBundles.swift
├── Background/                    (NEW — thin port, no actual background loops)
│   ├── BackgroundReview.swift
│   ├── Curator.swift
│   ├── CreditsTracker.swift
│   └── DisplayStateMachine.swift          (= thin port of display.py state machine)
├── Auth/                          (NEW — wenshu-side credential resolution)
│   ├── SecretScope.swift
│   └── RetryUtils.swift
├── WenshuVerifier.swift           (existing, hooks into new Connector layer)
├── WenshuLLMModel.swift           (existing)
├── WenshuLLMModelFetcher.swift    (existing)
└── RuntimeCWD.swift               (NEW — port of runtime_cwd.py)

Sources/WenshuApp/UI/LLMConnector/  (NEW — Settings pane UI for 7 connectors)
├── LLMConnectorSettingsView.swift
├── ConnectorProfileRow.swift
├── ConnectorAuthField.swift            (= API key / OAuth / endpoint URL)
└── ConnectorTestButton.swift           (= sends a smoke test prompt and shows result)
```

### 3.2 Connector layer (boss Q3, Q4, Q7 outcome)

7 connector profiles, provider-agnostic, BYOK, no default recommendation, no managed mode.

| Priority | Provider | Protocol | wenshu user scenario |
|---|---|---|---|
| P0 | Anthropic (claude-sonnet-4.5, claude-opus-4) | Anthropic native | Overseas direct; high-quality |
| P0 | OpenAI (gpt-5, gpt-4.1) | OpenAI native | Overseas mainstream |
| P0 | minimax cn | Anthropic-compatible | Boss v0 test default key |
| P1 | DeepSeek | Anthropic-compatible | China low-cost |
| P1 | Gemini (gemini-2.5-pro, gemini-2.5-flash) | Gemini native | Cross-provider workflows |
| P1 | Ollama (local) | OpenAI-compatible | Privacy-sensitive, no-key users |
| P2 | OpenRouter | OpenAI-compatible | One key, all models |

Each connector profile = a struct conforming to `LLMConnector` protocol. User picks profile in Settings → LLM Connector pane, supplies credential, tests. Once set, wenshu UI shows no LLM details (per boss Q3 = "no recommendation, user decides").

### 3.3 Cache-stable system prompt (hermes design inheritance)

Hermes invariant: system prompt byte-stable for life of a conversation. Wenshu's port preserves this exactly. Port of `prompt_caching.py` `apply_anthropic_cache_control` → `PromptCaching.applyCacheControl(messages:layout:)` Swift function. 4 breakpoints: system_and_3 (Anthropic), 4 content-block breakpoints. Cache marker preserved on tools + content parts + assistant last block + tool_result. Stripped only from thinking/redacted_thinking blocks. Translation rule: comment header `// SWIFT-PORT:` preserves the source line numbers so future hermes upgrades diff cleanly.

### 3.4 Tool dispatch (TB-B scope)

Two stub tools ported in TB-B (the first tracer-bullet):

1. `ReadFileTool` — reads any file under user-selected `.ws` library root, returns UTF-8 content. Sandbox = inside `.ws` root only. Pre-tool guardrail = `ToolGuardrails.assertPathScope`.
2. `WriteFileTool` — writes any file under `.ws` root, returns success/error classification. Sandbox = inside `.ws` root only. Pre-tool guardrail same.

Other tools (world / character / foreshadow / kanban / session) port later as separate tickets.

**真值 (boss Q21 = truth-survey mode 2026-09-03)** — what `tool_executor.py` actually exposes (= `execute_tool_calls_concurrent` at L306, `execute_tool_calls_sequential` at L965). Both take `(agent, assistant_message, messages: list, effective_task_id: str, api_call_count: int = 0)` and mutate the `messages` list in place (= append tool results). The Swift port preserves this signature: `ToolExecutor.executeConcurrent(assistantMessage:messages:taskId:apiCallCount:)` and `executeSequential(...)`. Mid-call helpers: `_apply_tool_request_middleware_for_agent` (L247), `_run_agent_tool_execution_middleware` (L274), `_tool_search_scoped_names` (L198), `_emit_terminal_post_tool_call` (L124), `_cancelled_tool_result` (L159), `_resolve_concurrent_tool_timeout` (L77), `_budget_for_agent` (L54). Direct port: every helper becomes a Swift `actor`-isolated function with the same name + `// SWIFT-PORT:` comment.

**真值 (boss Q21)** — what `WenshuVerifier.swift` actually exposes today (= v0.34 ship, not yet translated). L279-L337 = `send(request:outputKind:extraSystemPrompt:) async throws -> WenshuLLMResponse`. Currently:

- Resolves credentials via `resolveCredentials()` (UserDefaults + Keychain, fresh per call = boss 8/23 OOB)
- Builds URL = `\(creds.baseURL)/v1/messages` (= Anthropic Messages API endpoint)
- Headers: `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`
- Body: `model`, `max_tokens`, `messages` (text-only mapping, NO tool_use blocks), `system` (single string with English-only built-in prefix), optional `stop_sequences` for `.shortText` outputs
- URLSession.shared.data(for:) = non-streaming path
- v0.34 SSE streaming path = `Sources/WenshuApp/AI/SSEClient.swift` (= URLSession.bytes(for:) + W3C SSE parser, content_block_delta + message_delta + message_stop events)
- `WenshuLLMBlock` enum = `.text(String)` / .thinking / .toolUse / .unknown (Codable)

**Ticket 001 integration point** (= boss Q21 truth): `WenshuVerifier.send()` L279-L337 is REWIRED to delegate to `LLMConnector.send()` instead of building URLRequest directly. `WenshuVerifier` becomes a thin façade that holds the `LLMConnector` (= either AnthropicConnector for Anthropic native, or OpenAICompatibleConnector for minimax/DeepSeek/Ollama/OpenRouter, or GeminiNativeConnector for Gemini). The streaming path is unchanged (= SSEClient.swift continues to call URLSession.bytes directly); `LLMConnector.send()` is the non-streaming equivalent. The existing `ChatMessageView` in `ChatView.swift` L941 is the tool_use rendering surface (= 🟨).

**真值 (boss Q21)** — what `run_conversation()` actually exposes (= v0.34 ship, hermes Python target). L523-L546 = `def run_conversation(agent, user_message: str, system_message: str = None, conversation_history: List[Dict[str, Any]] = None, task_id: str = None, stream_callback: Optional[callable] = None, persist_user_message: Optional[str] = None, persist_user_timestamp: Optional[float] = None, moa_config: Optional[dict[str, Any]] = None) -> Dict[str, Any]`. Returns final response + message history.

Ticket 001's `ConversationLoop.swift` mirrors this signature with Swift equivalents:

```swift
public actor ConversationLoop {
    public func runConversation(
        userMessage: String,
        systemMessage: String? = nil,
        conversationHistory: [LLMMessage]? = nil,
        taskId: String? = nil,
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil,
        persistUserMessage: String? = nil,
        persistUserTimestamp: TimeInterval? = nil,
        moaConfig: MOAConfig? = nil
    ) async throws -> ConversationResult
}
```

Per-turn setup (hermes: `build_turn_context` at `turn_context.py`) lands in `TurnContext.swift` per spec §3.1. Tool dispatch (hermes: `execute_tool_calls_concurrent` at `tool_executor.py` L306) lands in `ToolExecutor.swift`. Cache markers (hermes: `apply_anthropic_cache_control` at `prompt_caching.py`) land in `PromptCaching.swift` (= ticket 002).

### 3.5 Existing-code migration (boss Q18 outcome)

The existing 13 files under `Sources/WenshuApp/Core/Agent/` (= 2,182 Swift LOC, current wenshu agent layer written v0.18 onwards) are renamed and reclassified into the new sub-directory structure:

| Existing file | New location | Rename reason |
|---|---|---|
| `WenshuVerifier.swift` | `Connector/WenshuVerifier.swift` (= becomes the integration point for the new `LLMConnector` protocol; ticket 001 rewires L282-339) | Existing minimax wrapper = origin of new connector layer |
| `WenshuAgentIdentity.swift` | `Conversation/WenshuAgentIdentity.swift` (= becomes part of agent identity namespace) | Identity = conversation concern |
| `AgentProtocol.swift` | `Conversation/AgentProtocol.swift` | Protocol = conversation concern |
| `AgentRuntime.swift` | `Conversation/AgentRuntime.swift` (= extended with `LLMConnector` wiring per ticket 001) | Runtime = conversation concern |
| `AgentLifecycleTracker.swift` | `Conversation/AgentLifecycleTracker.swift` | Lifecycle = conversation concern |
| `AsyncDelegation.swift` | `Conversation/AsyncDelegation.swift` | Delegation = conversation concern |
| `OutputKind.swift` | `Conversation/OutputKind.swift` | Output = conversation concern |
| `SubAgentIdentity.swift` | `Conversation/SubAgentIdentity.swift` | Sub-agent = conversation concern |
| `SubAgentPermissions.swift` | `Conversation/SubAgentPermissions.swift` | Permissions = conversation concern |
| `WenshuLLMModel.swift` | `Connector/WenshuLLMModel.swift` (= kept; model = connector concern) | Model = connector concern |
| `WenshuLLMModelFetcher.swift` | `Connector/WenshuLLMModelFetcher.swift` (= kept; fetcher = connector concern) | Fetcher = connector concern |
| `WenshuVerifierKeyNote.swift` | `Connector/WenshuVerifierKeyNote.swift` (= kept; key note = connector concern) | Key = connector concern |

Renames land with ticket 001 (= the same ticket that introduces `LLMConnector` protocol). git history preserved via `git mv` (= preserves blame). The wenshu-pocock-workflow §11 '1 ticket 1 commit' baseline applies: rename = 1 commit, before any new module is added.

The `Agent/` root sub-directory shown in §3.1 (`├── Agent/   (= existing, becomes the public façade)`) is REMOVED after renames; the namespace becomes `Core/Agent/<子目录>/` (= `Conversation/` / `Connector/` / `Tool/` / `Memory/` / `Skill/` / `Background/` / `Auth/`).

### 3.6 Cross-module interaction principle — agent ↔ wenshu's other 23 Core sub-directories (boss Q19 outcome)

Wenshu currently has 24 `Core/` sub-directories: `Agent / Backup / Bases / Bookmarks / Canvas / Composer / Cron / Graph / Kanban / LinkGraph / Memory / Notifications / Outline / Provider / QuickSwitcher / Registry / Search / Skills / Templates / Todo / Tools / WordCount / Workspace / Chat`. Of these, 5 overlap directly with hermes' ported layer.

**真值 (boss Q21 = truth-survey mode 2026-09-03)**: existing wenshu modules are actor-based (= Swift Concurrency) and already implement a meaningful subset of hermes' design. The hermes port becomes an adapter that adds the hermes-specific surfaces wenshu-side lacks (= OAuth / multi-key rotation / hermes skill hub / Anthropic cache_control / etc.).

| Wenshu existing module | Existing interface (2026-09-03 snapshot) | Hermes port equivalent | Decision (boss Q19 = wenshu-side wins) |
|---|---|---|---|
| `Core/Tools/FileTools.swift` (LOC: 197 + 53 = 250) | `public struct FileTools: Sendable` with `read(path:) throws -> String` / `write(path:content:) throws` / `patch(path:hunk:) throws` / `search(rootDir:pattern:fileExtension:) throws -> [String]` / `list(path:) throws -> [FileEntry]`. **All sync (not async).** Includes `pathDenied` / `isBlockedDevice` / `pathHasBlockedSymlink` safety checks. | `Tool/ReadFileTool.swift` + `WriteFileTool.swift` (ticket 001) | **wenshu-side wins**. Ticket 001's 2 stub tools = thin **async** wrappers that delegate to existing `FileTools.read/write` (the async wrapper is the only thing ticket 001 adds). Do NOT re-implement file I/O; do NOT duplicate the safety checks. |
| `Core/Provider/ProviderKeychain.swift` (LOC: 159 + 128 + 45 + 23 = 355) | `public protocol ProviderKeychainStoring: Sendable` with `saveKeySync / loadKeySync / deleteKeySync / listProvidersWithKeys`. `Provider` enum already exists (= multi-provider, ticket 006 just adds 6 new provider cases). `AppleKeychainStore` = real SecItem implementation. `InMemoryKeychainStore` = test backdoor. | `Connector/ConnectorCredentials.swift` (ticket 006) | **wenshu-side wins**. Ticket 006 extends existing `Provider` enum with 6 new cases (= OpenAI / Anthropic / Gemini / DeepSeek / Ollama / OpenRouter; minimax already in). Adds OAuth flow (= NOT in current wenshu, new auth pattern). Adds key rotation / priority (= NOT in current wenshu, new). Reuses `ProviderKeychainStoring` protocol verbatim. Do NOT create a parallel keychain. |
| `Core/Memory/MemoryManager.swift` + `MemoryProvider.swift` + `MemoryConsolidator.swift` (~700 LOC) | `public actor MemoryManager` (= Swift Concurrency actor, ready for hermes port) with `prefetch(userMessage:) async -> PrefetchResult` / `sync(userMessage:assistantResponse:) async -> SyncResult` / `queuePrefetch / takeQueuedPrefetch`. Already implements hermes' prefetch + write-gate pattern. | `Memory/MemoryManager.swift` + `MemoryProvider.swift` + `MemoryStore.swift` (ticket 009) | **wenshu-side wins**. Ticket 009's hermes port = thin **adapter** that ADDS to existing `MemoryManager`: cross-book reference-library integration (= NOT in current wenshu), context-engine-driven retrieval (= NOT in current wenshu), per-conversation memory scoping (= NOT in current wenshu). Reuses existing `prefetch/sync` methods verbatim. Do NOT re-implement memory storage; do NOT replace the existing `MemoryProvider`. |
| `Core/Skills/SkillRegistry.swift` + `SkillMeta.swift` (~600 LOC) | `public actor SkillRegistry` with `list() throws -> [String]` / `load(name:) throws -> Skill?` / `invoke(name:input:) throws -> String`. `SkillFrontmatter` + `Skill` structs exist. **Existing `invoke` is a SIMPLIFIED version** (= source comment: '不实现 35 do_* 完整 hub'). | `Skill/SkillUtils.swift` + `SkillPreprocessing.swift` + `SkillCommands.swift` + `SkillBundles.swift` (ticket 010) | **wenshu-side wins**. Ticket 010's hermes port = thin **adapter** that ADDS the missing 35 do_* skill-command hub (= from hermes `skill_commands.py`) AND hermes-style slash-command surface (= `/<command>` parsing). Reuses existing `SkillFrontmatter / Skill` structs verbatim. Do NOT re-implement skill registry. |
| `Core/Chat/ChatSessionStore.swift` (~650 LOC) | `public actor ChatSessionStore` (= Swift Concurrency actor) with `bootstrap() throws` / `loadMessages(sessionId:) throws -> [StoredChatMessage]` / `append(_:sessionId:) throws` / `archiveSession(sessionId:messageCount:contextUsed:summary:) throws` / `clear(sessionId:) throws`. **Uses SQLite** (= `chat_messages` + `chat_archives` tables; per §11 baseline). | `Conversation/ConversationLoop.swift` (ticket 001) | **wenshu-side wins**. Ticket 001's `ConversationLoop.swift` is the engine that PRODUCES stream events (`StreamingMessageChunk` per turn); `ChatSessionStore.swift` CONSUMES them and persists to SQLite via existing `append` method. The boundary is clean: `ConversationLoop` does NOT know about persistence; `ChatSessionStore` does NOT know about LLM. Do NOT duplicate session persistence; do NOT add a parallel message store. |

All other 19 wenshu modules (= Backup / Bases / Bookmarks / Canvas / Composer / Cron / Graph / Kanban / LinkGraph / Notifications / Outline / QuickSwitcher / Registry / Search / Templates / Todo / WordCount / Workspace + Library views) are tool/feature consumers of the agent layer (the agent can call them as tools; they don't have hermes equivalents that conflict). No migration needed.

This decision lands as AGENTS.md §11.3 (= project-level baseline; see §7.4).

## 4. Branch strategy (boss Q9 outcome)

Single worktree (`wt/multi-agent-dispatch`) + tracer-bullet + edge tickets.

- Tracer-bullet ticket = issue 001 of this spec, defines the Swift interface (protocols + module skeleton) that every later ticket depends on.
- Each subsequent ticket declares `**Blocked by:**` line referring to earlier ticket IDs. `/to-tickets` skill's blocking-edge model resolves the order.
- Worktrees: NO. Per §11 '1 ticket 1 commit' baseline, all tickets ship into `wt/multi-agent-dispatch` sequentially.

## 5. Ticket list (= step 4 /to-tickets output)

10 tickets total, ~12 weeks with overlap allowed only via protocol contract (issue 001 must land first; all others have explicit `Blocked by: 001`).

| ID | Title | LOC estimate | Blocked by | Verifies |
|---|---|---|---|---|
| 001 | Tracer-bullet: agent loop skeleton + LLMConnector protocol + 1 connector (minimax) + 2 stub tools | ~4,500 Swift | (none) | Z contract + X e2e dual-track |
| 002 | Port `prompt_caching.py` + `system_prompt.py` + cache-stable invariants | ~500 Swift | 001 | Z contract |
| 003 | Port `context_compressor.py` + `conversation_compression.py` + `context_engine.py` | ~4,000 Swift | 001 | Z contract |
| 004 | Port `anthropic_adapter.py` + Anthropic native connector (P0) | ~2,100 Swift | 001 | Z contract + X e2e |
| 005 | Port `auxiliary_client.py` OpenAI-compatible path + OpenAI connector (P0) | ~3,000 Swift | 001 | Z contract + X e2e |
| 006 | Port `credential_pool.py` + `credential_persistence.py` + Keychain integration + Settings pane UI for 7 connectors | ~1,500 Swift | 001, 005 | Z contract + manual UI test |
| 007 | Port DeepSeek connector (P1, Anthropic-compatible) + Gemini native connector (P1) + Ollama connector (P1) | ~2,500 Swift | 004, 005 | Z contract + X e2e |
| 008 | Port OpenRouter connector (P2, OpenAI-compatible) + ModelMetadata catalog | ~1,200 Swift | 005 | Z contract |
| 009 | Port memory subsystem (`memory_manager.py` + `memory_provider.py`) wenshu-side (filesystem JSON, per §11 baseline) | ~1,500 Swift | 001 | Z contract |
| 010 | Port skill subsystem (`skill_utils.py` + `skill_preprocessing.py` + `skill_commands.py` + `skill_bundles.py`) wenshu-side | ~2,000 Swift | 001 | Z contract |

Total: ~22,800 Swift LOC across 10 tickets. (Note: scope includes ~5,000 LOC of additional gray-thin-port + Settings UI + wenshu-side memory/skill that go beyond pure translation; this is the gap between "pure Python→Swift port" and "shippable v0.35+ agent layer".)

## 6. Verification (boss Q12 outcome)

### 6.1 Per-ticket: Z contract test (mandatory before commit)

Each ported Python function gets a `swift-testing` test that:
- Loads a `golden.json` (hermes-side Python fixture = hermes function output for known input)
- Runs the Swift port on the same input
- Asserts output equality (deep equality on the relevant shape)

Golden files stored in `Tests/WenshuAppTests/Agent/PortedFromHermes/golden/<module>_<function>_<input_hash>.json`. Source-of-truth generation script: `Tests/WenshuAppTests/Agent/PortedFromHermes/scripts/generate_golden.py` (runs hermes Python, dumps output).

### 6.2 Every 5 tickets: X e2e dual-track (mandatory before merging that batch)

Run hermes Python and wenshu Swift side-by-side on identical prompts at temperature=0 with same API key:

```
Test_Harness_Prompt = "Read file at $TEMP/book.md, summarize the chapter protagonist in 3 sentences, then write the summary to $TEMP/summary.md"
```

Pass criteria: both runs produce identical tool-call sequence + identical final assistant text + identical file write result. Run after tickets 005 and 010.

### 6.3 Iron rules per ticket (= §11 baseline compliance)

Every commit MUST pass:
- swift build exit 0
- swift test exit 0
- Apple HIG grep first (no custom code if built-in covers)
- AGENTS.md §11.1: use only pinned deps; no new deps without boss拍
- §11 product-positioning rule: no metering / billing / quota tracking code added
- §11 '1 ticket 1 commit' baseline

### 6.4 UI-affordance decision rule (boss Q14 outcome)

Every hermes-port ticket must answer these 3 questions before PR review:

1. **Who triggers it?** (= who calls this Swift API? Chat user? System? Cron? Tool?)
2. **After trigger, what signal does the user see?** (token stream / file change / UI state change / nothing)
3. **If (2) has a visible signal but no UI affordance → MUST add an affordance** (= otherwise the port is invisible to the user = "translated but useless")

Per-ticket UI mapping (boss Q13 outcome, ratified 2026-09-03):

| Signal type | Must UI? | Example |
|---|---|---|
| User actively triggers operation (pick / configure / install) | 🟥 MUST | Settings → LLM Connector / Memory / Skills |
| System auto-executes, but has visible side-effect | 🟥 MUST | ChatView tool_use row / Memory retrieval panel |
| System auto-executes, has visible state change but no operation needed | 🟨 HALF-VISIBLE | Compression status pill / streaming render |
| System auto-executes, no visible side-effect | 🟦 UNDERWATER | Cache control / context engine / system prompt / agent loop engine |

Per-translation-product UI mapping (= boss Q13 full table):

| Translated product | spec ticket | UI landing | Tier | Rationale |
|---|---|---|---|---|
| ConversationLoop | 001 | (underwater) | 🟦 | engine, user does not directly operate |
| ToolExecutor + 2 stub tools | 001 | ChatView shows tool_use row | 🟨 | visible in chat as "🔧 read X" line; no separate panel needed |
| LLMConnector protocol | 001 | (underwater) | 🟦 | protocol layer, no direct UI |
| minimax connector (P0) | 001 | Settings → LLM Connector | 🟥 | user must pick + supply key |
| PromptCaching | 002 | (underwater) | 🟦 | engine-internal; only user-visible signal = Anthropic token billing drop, displayed in model metadata |
| SystemPrompt | 002 | (underwater) | 🟦 | hardcoded, user does not operate |
| ContextCompressor | 003 | ChatView top-bar compression status | 🟨 | user needs to see "context compressed 35%" |
| ConversationCompression (manual) | 003 | ChatView tool menu + button | 🟥 | user must manually trigger "compress and continue" |
| ContextEngine | 003 | (underwater) | 🟦 | aggregator, no direct UI |
| Anthropic native connector | 004 | Settings → LLM Connector | 🟥 | same as minimax |
| OpenAI-compatible + OpenAI connector | 005 | Settings → LLM Connector | 🟥 | same |
| Credential pool + Keychain | 006 | Settings → LLM Connector | 🟥 | key input panel = core user operation |
| Settings pane UI (7 profiles) | 006 | Settings弹窗 new "LLM Connector" view | 🟥 | entire view is new |
| DeepSeek / Gemini / Ollama (P1) | 007 | Settings → LLM Connector | 🟥 | 3 new rows |
| OpenRouter (P2) + ModelMetadata | 008 | Settings → LLM Connector | 🟥 | OpenRouter row + ModelMetadata display in profile row |
| Memory subsystem | 009 | Settings弹窗 new "Memory" view + DynamicZone right-bottom | 🟨 + 🟥 | Settings → Memory config (= similar to hermes `memory/provider-config-panel.tsx`); DynamicZone right-bottom shows current memory retrieval result |
| Skill subsystem | 010 | ChatView `/` slash-command + Settings → Skills view | 🟥 | user types `/<skill>` in chat; Settings → Skills shows installed + install new |

Final landing per Q13: Settings弹窗 = 5 new views (LLM Connector + Memory + Skills + Library Properties + future); DynamicZone right-bottom = memory panel; ChatView bottom half = tool_use + compression + slash-command.

**Counts**: 🟦 underwater = 7/30 (23%); 🟨 half-visible = 3/30 (10%); 🟥 must-UI = 8/30 (27%); the remaining 12/30 (= 40%) are sub-modules that don't directly affect the user but feed into the must-UI ones.

`/code-review` MUST reject any ticket that fails to answer §6.4's 3 questions in its PR body. This rule is non-negotiable; it solves boss's "translated but useless" concern directly.

## 7. AGENTS.md / CLAUDE.md changes (= boss Q7, Q8, Q19 outcome)

Three edits land with issue 011 of this spec (= a docs-only ticket parallel to the code work):

### 7.1 AGENTS.md §11 — line 18 verbatim rewrite

```diff
- v1 LLM provider supports minimax cn only (Anthropic-compatible protocol).
+ v1 LLM connector architecture: 7 connector profiles (Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter / minimax cn). Provider-agnostic. User BYOK (bring your own key). NO default recommendation. Wenshu ships with the connector layer wired but every profile is empty until user supplies credentials. See §11.2 for the 7 profiles.
```

### 7.2 AGENTS.md §11 — top-of-section addition (new "product positioning" rule)

Add to §11, immediately before the existing 'Stack' line:

```diff
+ §11 product positioning (boss 2026-09-03 拍): Wenshu is a writing tool, NOT an LLM platform. Wenshu never resells or bundles LLM access, never holds user tokens on its own backend, never charges for token consumption. LLM is a layer below Wenshu that the user provides via the §11.2 connector layer. Any PR that adds metering, billing, quota tracking, or token-bundling is out of scope.
```

### 7.3 AGENTS.md §11.2 — NEW section (7 connector profiles)

```markdown
§11.2 LLM connector profiles (boss 2026-09-03 拍, ported from hermes agent core v0.x)

| Priority | Profile | Protocol | Auth pattern | First-class scenario |
|---|---|---|---|---|
| P0 | Anthropic | Anthropic native | API key | Overseas direct, high-quality (claude-sonnet-4.5, claude-opus-4) |
| P0 | OpenAI | OpenAI native | API key | Overseas mainstream (gpt-5, gpt-4.1) |
| P0 | minimax cn | Anthropic-compatible | API key | Boss v0 test default; Anthropic-compatible |
| P1 | DeepSeek | Anthropic-compatible | API key | China low-cost |
| P1 | Gemini | Gemini native | API key | Cross-provider workflows (gemini-2.5-pro, gemini-2.5-flash) |
| P1 | Ollama | OpenAI-compatible | None (local) | Privacy-sensitive, no-key users |
| P2 | OpenRouter | OpenAI-compatible | API key | One key, all models |

User picks profile in Settings → LLM Connector pane. No default. Wenshu UI shows no LLM details once a profile is configured.
```

### 7.4 AGENTS.md §11.3 — NEW section (agent ↔ wenshu other modules interaction principle, boss Q19 outcome)

```markdown
§11.3 Agent ↔ other Core module interaction principle (boss 2026-09-03 拍, derived from hermes-core-translation spec §3.6)

When the hermes-core-translation spec lands (= 10 code tickets + 1 docs ticket = spec at `.scratch/2026-09-03-hermes-core-translation/`), 5 wenshu existing modules overlap with hermes' ported layer:

- `Core/Tools/FileTools.swift` + `ProcessTools.swift` + `AVMediaTools.swift` ↔ `Core/Agent/Tool/ReadFileTool.swift` + `WriteFileTool.swift`
- `Core/Provider/ProviderKeychain.swift` ↔ `Core/Agent/Connector/ConnectorCredentials.swift`
- `Core/Memory/MemoryManager.swift` + `MemoryProvider.swift` + `MemoryConsolidator.swift` ↔ `Core/Agent/Memory/MemoryManager.swift` + `MemoryProvider.swift` + `MemoryStore.swift`
- `Core/Skills/SkillMeta.swift` + `SkillRegistry.swift` ↔ `Core/Agent/Skill/SkillUtils.swift` + `SkillPreprocessing.swift` + `SkillCommands.swift` + `SkillBundles.swift`
- `Core/Chat/ChatSessionStore.swift` ↔ `Core/Agent/Conversation/ConversationLoop.swift`

Decision (= wenshu-side wins):

1. **wenshu-side wins**: the existing wenshu module is preserved; the hermes-port is a thin adapter that delegates to it. The port DOES NOT re-implement the wenshu-side behavior. Code duplication is forbidden.
2. **Ticket boundary**: every ticket that touches one of these overlap pairs must state in its PR body "this PR uses wenshu-side wins pattern: [list wenshu modules it delegates to]". `/code-review` rejects any ticket that re-implements wenshu-side behavior.
3. **Existing-code rename** (§3.5): ticket 001 renames 12 existing files under `Core/Agent/` into the new sub-directory structure. Renames happen BEFORE any new module is added. `git mv` preserves blame.
4. **Future hermes-side wins**: any future ticket proposing "hermes port replaces wenshu-side" requires explicit boss拍. Default = wenshu-side wins. No silent replacement.
```

### 7.5 CLAUDE.md lines 15, 16, 19, 40, 51, 58, 103 sync

The 'minimax cn only' language in CLAUDE.md must sync to AGENTS.md §11 wording. Boss拍 2026-09-03 confirms this is acceptable because the §11 baseline rewrite supersedes the earlier minimax-only framing.

## 8. Risk register

| # | Risk | Mitigation |
|---|---|---|
| R1 | Swift Concurrency (`actor` + `AsyncStream`) rewrite of hermes asyncio is +30% work vs direct port | Issue 001 defines Swift concurrency patterns first; later tickets follow the established pattern |
| R2 | hermes Python uses `self.xxx` mutable state heavily; Swift idiom translation needs careful actor isolation | Per-function `// SWIFT-PORT:` comment marks every non-1:1 translation for future re-port audits |
| R3 | Prompt cache byte-stability invariant = subtle; any unintended system-prompt mutation breaks caching | Issue 002 (PromptCaching) has dedicated e2e test that asserts system-prompt bytes are byte-identical across 50 turns |
| R4 | 7 connector profiles × tool schema compatibility matrix = N×M test surface | Issue 006 introduces a `ConnectorSmokeTest` that every connector profile must pass before merge |
| R5 | wenshu §11 baseline says 'minimax cn only'; rewrite is a breaking baseline change | Boss拍 2026-09-03 ratified the rewrite; issue 011 lands the docs change as part of this spec |
| R6 | Direct port may carry hermes bugs into wenshu | Golden file fixtures are pinned to specific hermes commit; hermes bug-fix backports translated as separate fix tickets |
| R7 | LLM stochastic difference between hermes Python and wenshu Swift runs (even at temp=0) | X e2e dual-track uses same provider + same API key + temp=0; expects deterministic byte equality |

## 9. Acceptance criteria (= spec-level)

- [ ] All 10 tickets land per the blocking-edge order in §5
- [ ] AGENTS.md §11 rewrite + §11.2 addition + product-positioning rule all merged
- [ ] CLAUDE.md lines 15, 16, 19, 40, 51, 58, 103 sync-merged
- [ ] wenshu can boot, open a chat, run a 3-turn conversation against minimax cn (via existing WenshuVerifier) — same behavior as pre-translation
- [ ] User can switch connector profile in Settings → LLM Connector pane; wenshu chat restarts against the new provider with no code recompile
- [ ] 7 connector profiles each pass smoke test
- [ ] Z contract tests = 100% pass on every ticket
- [ ] X e2e dual-track pass on the 2 batch boundaries (after ticket 005 and after ticket 010)
- [ ] swift build exit 0; swift test exit 0; macOS visual verification per wenshu-pocock-workflow iron rules

## 11. Source files surveyed (verbatim list, all read 2026-09-03)

| # | Path | LOC | Role |
|---|---|---|---|
| 1 | `agent/conversation_loop.py` | 5,312 | One call site for prompt caching at L883-894; main agent loop |
| 2 | `agent/auxiliary_client.py` | 7,469 | Multi-provider adapter; Anthropic + OpenAI-compatible |
| 3 | `agent/tool_executor.py` | 1,646 | Tool dispatch + classification |
| 4 | `agent/prompt_builder.py` | 1,971 | System prompt composition |
| 5 | `agent/prompt_caching.py` | 119 | Pure cache-control functions |
| 6 | `agent/context_compressor.py` | 3,082 | Token-budget aware compression |
| 7 | `agent/conversation_compression.py` | 1,367 | Long-conversation compaction |
| 8 | `agent/chat_completion_helpers.py` | 3,103 | Request/response marshaling |
| 9 | `agent/agent_runtime_helpers.py` | 3,209 | Runtime state dict, flags |
| 10 | `agent/agent_init.py` | 2,103 | AIAgent bootstrap |
| 11 | `agent/anthropic_adapter.py` | 2,789 | Anthropic native wire format (cache_control markers) |
| 12 | `agent/credential_pool.py` | 2,384 | BYOK credential pool |
| 13 | `agent/gemini_native_adapter.py` | 1,021 | Gemini native wire format |
| 14 | `agent/vertex_adapter.py` | ~700 | Vertex AI adapter (P2 deferred) |
| 15 | `agent/error_classifier.py` | 1,598 | Error taxonomy |
| 16 | `agent/model_metadata.py` | 2,434 | Per-provider model catalog |
| 17 | `agent/memory_manager.py` | 1,086 | Memory subsystem |
| 18 | `agent/skill_utils.py` | ~700 | Skill load + dispatch |
| 19 | `agent/system_prompt.py` | 536 | Byte-stable system prompt tier |
| 20 | `agent/context_engine.py` | 924 | Context aggregator |
| 21 | `agent/turn_context.py` / `turn_finalizer.py` / `turn_retry_state.py` | ~1,700 | Per-turn state |
| 22 | `agent/credential_persistence.py` / `credential_sources.py` / `secret_sources/` / `secret_scope.py` | ~1,600 | BYOK credential resolution |
| 23 | `agent/display.py` | 1,440 | TUI rendering (thin-port state machine only) |
| 24 | `agent/shell_hooks.py` | 928 | Pre-tool safety hook (thin-port protocol only) |
| 25 | `agent/background_review.py` | 960 | Background review (state enum only) |
| 26 | `agent/curator.py` | 1,976 | Curator state machine (no cron, no background loop) |
| 27 | `agent/credits_tracker.py` | ~400 | Token counter (no pricing) |

All LOC counts verified by `find . -name '*.py' | xargs wc -l` 2026-09-03 against `/Volumes/ANAN/.hermes/agent/` (= 93,837 LOC total).

## 12. Wenshu-side files to be modified or created (= spec-level directory inventory)

Already exists:
- `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift` (472 LOC) — becomes the integration point for the new LLMConnector protocol
- `Sources/WenshuApp/Core/Agent/WenshuAgentIdentity.swift` (119 LOC) — preserved
- `Sources/WenshuApp/Core/Agent/AgentRuntime.swift` (105 LOC) — extended with LLMConnector wiring
- `Sources/WenshuApp/Core/Agent/AgentProtocol.swift` (251 LOC) — extended

To create (per §3.1 directory layout):
- `Sources/WenshuApp/Core/Agent/Conversation/` (13 files, ~14,000 Swift LOC)
- `Sources/WenshuApp/Core/Agent/Connector/` (10 files, ~12,000 Swift LOC)
- `Sources/WenshuApp/Core/Agent/Tool/` (5 files, ~2,500 Swift LOC)
- `Sources/WenshuApp/Core/Agent/Memory/` (3 files, ~1,500 Swift LOC)
- `Sources/WenshuApp/Core/Agent/Skill/` (4 files, ~2,000 Swift LOC)
- `Sources/WenshuApp/Core/Agent/Background/` (4 files, ~2,000 Swift LOC)
- `Sources/WenshuApp/Core/Agent/Auth/` (2 files, ~600 Swift LOC)
- `Sources/WenshuApp/Core/Agent/RuntimeCWD.swift` (~150 Swift LOC)
- `Sources/WenshuApp/UI/LLMConnector/` (4 files, ~1,500 Swift LOC)

Tests:
- `Tests/WenshuAppTests/Agent/PortedFromHermes/` (golden file fixtures + contract tests)
- `Tests/WenshuAppTests/Agent/Connector/SmokeTest.swift` (7 connector profiles)

## 13. Timeline estimate (= not a commitment, just budget)

With single worker, sequential per blocking-edge order:

- Week 1-6: Issue 001 (TB-B tracer-bullet)
- Week 7-8: Issue 002 (cache + system prompt)
- Week 9-12: Issue 003 (context compressor)
- Week 13-15: Issue 004 (Anthropic native)
- Week 16-19: Issue 005 (OpenAI-compatible + OpenAI)
- Week 20-22: Issue 006 (credential pool + Settings UI)
- Week 23-26: Issue 007 (DeepSeek + Gemini + Ollama)
- Week 27-28: Issue 008 (OpenRouter + ModelMetadata)
- Week 29-31: Issue 009 (memory subsystem wenshu-side)
- Week 32-34: Issue 010 (skill subsystem wenshu-side)
- Week 35: Issue 011 (docs sync to AGENTS.md + CLAUDE.md)

Total = ~35 weeks (~8 months) single worker. Two workers in parallel could compress to ~22 weeks IF they coordinate via issue 001's interface freeze. Boss拍 not yet asked on parallelization.

## 14. Out of this spec (= parked for v2+)

- MOA (Mixture-of-Agents ensemble) — deferred to v2
- Codex Responses API / Codex App Server transports — boss not using Codex, parked
- hermes Electron desktop / Ink TUI / web dashboard — boss Q1 excludes
- hermes messaging gateway (Telegram / Discord / Slack / WhatsApp / iMessage / Signal / Matrix / Teams / Email) — boss Q1 excludes
- hermes pet mascots — boss Q1 excludes
- hermes LSP server infrastructure — wenshu is novel tool, not code editor
- hermes web search + browser tools — wenshu v1 = desktop tool, no browser
- hermes image / video / STT / TTS generation — wenshu §11 = writing tool, no media gen

---

*Spec v1.0 · 2026-09-03 · boss approved all 12 grill decisions · ready for /to-tickets · worktree = wt/multi-agent-dispatch · this spec lives at `.scratch/2026-09-03-hermes-core-translation/spec.md`*