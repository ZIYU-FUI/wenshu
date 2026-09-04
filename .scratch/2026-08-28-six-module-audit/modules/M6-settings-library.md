# M6 Settings & Library — verbatim port plan (hermes-agent → wenshu)

**Date:** 2026-08-28 · **Module:** M6 · **Author:** wenshu pocock M6 sub-agent
**Spec:** `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-28-six-module-audit/spec.md`
**Inventory:** `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-28-six-module-audit/modules/inventory.json`
**Hermes source:** `/Volumes/ANAN/.hermes/hermes-agent/` (cloned 2026-08-28)
**Gate:** `AGENTS.md §11.1` (stars ≥100 / last commit ≤12 mo / MIT-Apache-BSD-PD / macOS-first OR macOS-supported) + `ADR-0008` view-framework FORBIDDEN carve-out

## Module scope

`.ws` onboarding + Settings tabs + Provider/Agent/Memory/Skill/Cron/Backup + Library lifecycle. Per inventory.json, six `needs_survey` items: menu bar extra toggle, global shortcut, keychain for LLM API key, SSE stream client, MCP SDK, logging pipeline.

## Boss directive (revised OOB 2026-08-28)

> "agent 相关的,不用调研,就直接本地拿 hermes 源码复刻"

= for any module that has agent / AI / LLM / conductor / dispatcher / multi-agent / memory / skill-registry / prompt-engineering surface → DO NOT survey third-party libs. Identify the matching surface in local hermes-agent source and plan a verbatim port.

Out of scope (per boss): `agents/`, `memory/`, `prompts/`, `skills/`, `cron/`, `backup.py`, `agent/` (Provider, Agent identity, Memory store, Skill registry, Library lifecycle).

In scope (= still survey third-party libs, hermes source FORBIDDEN per boss):

| Item | Why in scope | Source path |
|---|---|---|
| Menu bar extra toggle | NOT agent surface — UI plumbing | n/a |
| Global shortcut binding | NOT agent surface — UI plumbing | n/a |
| Keychain for LLM API key | borderline (key storage is infra, key USE is agent) — flag for boss | n/a |
| SSE stream client | NOT agent surface — transport | n/a |
| Logging pipeline | NOT agent surface — observability | n/a |
| MCP SDK | NOT agent surface (it's a transport adapter) — flag for boss | n/a |

> **Note**: hermes-agent actually does NOT have a top-level `agents/`, `memory/`, `prompts/` layout. The real layout = `agent/` (everything merged: AIAgent, system prompt, subagent_lifecycle, memory_manager, memory_provider, prompt_builder, onboarding, etc.), `cron/`, `skills/` (skill loader surface), `tools/` (skills_hub, memory_tool, cronjob_tools, async_delegation), `plugins/memory/` (mem0, honcho, hindsight, etc.), `hermes_cli/backup.py`. Mapping corrected throughout this report.

## Module state (verified against Sources/WenshuApp 2026-08-28)

### Existing wenshu surface (already implemented pre-v0.23)

| Wenshu file | LOC | v0.X | Hermes counterpart already adopted |
|---|---|---|---|
| `Core/Agent/WenshuAgentIdentity.swift` | 119 | v0.22 | `agent/prompt_builder.DEFAULT_AGENT_IDENTITY` (SOUL.md) — wenshu 6-section format |
| `Core/Agent/SubAgentIdentity.swift` | 214 | v0.23 | `agent/subagent_lifecycle.SubagentLaunchRequest` + `SubagentIdentityService` |
| `Core/Agent/WenshuConductor.swift` | 398 | v0.21-v0.23 | `agent/run_agent.AIAgent` + `agent/agent_init` + `tools/async_delegation` |
| `Core/Agent/WenshuLLMModel.swift` | 25 | v0.21 | `agent/model_metadata` + `models_dev.py` |
| `Core/Agent/WenshuLLMModelFetcher.swift` | 54 | v0.21 | `providers/base.ProviderProfile.fetch_models` |
| `Core/Agent/AsyncDelegation.swift` | 127 | v0.23 t013.010 | `tools/async_delegation.AsyncDelegationRegistry` (Gap 10 from 2026-08-23 audit) |
| `Core/Provider/Provider.swift` | 153 | v0.21 t01 | `providers/base.ProviderProfile` |
| `Core/Provider/ProviderCatalog.swift` | 15 | v0.21 t01 | `hermes_cli/providers_setup` |
| `Core/Provider/ProviderKeychain.swift` | 171 | v0.21 t02 | `agent/secret_sources/*` (bitwarden, 1password, command) |
| `Core/Provider/ProviderFetcher.swift` | 71 | v0.21 t03 | `providers/base.ProviderProfile.fetch_models` |
| `Core/Provider/AvailableModelsDiscovery.swift` | 43 | v0.23 t011.001 | `agent/web_search_registry` + `models_dev` aggregator |
| `Core/Memory/MemoryStore.swift` | 222 | v0.17 t01 | `plugins/memory/mem0/*` (local SQLite) |
| `Core/Memory/MemoryManager.swift` | (ex) | v0.23 | `agent/memory_manager.MemoryManager` |
| `Core/Memory/MemoryConsolidator.swift` | (ex) | v0.23 | `agent/memory_manager.MemoryManager.consolidate` |
| `Core/Memory/MemoryWriteGate.swift` | (ex) | v0.23 t013 | `tools/memory_tool._apply_write_gate` (Gap 1 from 2026-08-23 audit) |
| `Core/Skills/SkillRegistry.swift` | 171 | v0.18 t02 | `tools/skills_hub.py` (SkillSource ABC) |
| `Core/Skills/SkillMeta.swift` | 114 | v0.23 t013.008 | `tools/skills_hub.SkillMeta` (trust_level + source + quarantine) |
| `Core/Cron/Cronjob.swift` | 81 | v0.18 t21 | `cron/jobs.py` |
| `Core/Cron/CronPromptScanner.swift` | 80 | v0.23 t013.007 | `cron/jobs.py._scan_cron_prompt` (Gap 7 from 2026-08-23 audit) |
| `Core/Backup/Backup.swift` | 139 | v0.18 t26 | `hermes_cli/backup.py` |
| `Core/Chat/ChatSessionStore.swift` | 480 | v0.21 t02-v0.24 | `gateway/session_db*` + `hermes_state_common.py` |
| `Core/Agent/AgentProtocol.swift` | 251 | v0.18 t03 | `agent/agent_protocol.py` |
| `Core/Agent/AgentRuntime.swift` | (ex) | v0.18 | `tools/async_delegation._run_single_child` |
| `Core/Agent/SubAgentPermissions.swift` | (ex) | v0.23 t012 | `agent/subagent_lifecycle.SubagentLaunchRequest.blocked_tools` |
| `State/LibraryLifecycleHook.swift` | 73 | v0.27 | (no hermes analog — FCP library bootstrap pattern is wenshu-native) |
| `Storage/LibraryMigrator.swift` | (ex) | v0.27 | n/a |
| `Storage/LibraryBootstrapper.swift` | (ex) | v0.27 | n/a |
| `Storage/CacheManager.swift` | (ex) | v0.27 | n/a |
| `Views/Onboarding/LibraryRootView.swift` | (ex) | v0.27 | n/a |
| `Views/Library/*` | (ex) | v0.27 | n/a (Library is wenshu-native FCP replica, not hermes replica) |
| `Views/Settings/LibraryPropertiesView.swift` | (ex) | v0.27 | n/a |
| `Views/Cron/CronScheduleView.swift` | (ex) | v0.18 | n/a |
| `Views/Backup/BackupView.swift` | (ex) | v0.18 | n/a |

> Note: wenshu's `Views/Settings/` directory contains only `LibraryPropertiesView.swift`. The provider/agent/memory/skill/cron/backup Settings UI panels are wired inline in `App.swift` (lines 560-2578) using `ProviderCatalog`/`ProviderKeychain`/`ModelDisplay`/`WenshuLLMModel`. No standalone `SettingsView`/`Tab` files exist. The "Settings tab" surface is the main window's settings popover, not a Settings-tab window.

## Per-module port plan (agent surface = verbatim, non-agent = third-party survey allowed)

---

### M6-A · Provider (Settings → Provider tab)

#### A.1 Wenshu existing
- `Core/Provider/Provider.swift` — 11 curated providers, 2 auth modes (`bearer` / `xApiKey`), `defaultModels` static list per provider, `requiresOAuth` flag.
- `Core/Provider/ProviderKeychain.swift` — `AppleKeychainStore` (production) + `InMemoryKeychainStore` (tests) + `ProviderKeychain` enum shim.
- `Core/Provider/ProviderCatalog.swift` — `defaultModels(for:)` + `provider(slug:)` lookups.
- `Core/Provider/ProviderFetcher.swift` — live `/v1/models` probe with 3600s TTL cache.
- `Core/Provider/AvailableModelsDiscovery.swift` — filtered to `Provider.all.compactMap { !requiresOAuth && keychain.hasKey }` (v0.23 t011.001).
- `Core/Provider/ModelDisplay.swift` — display label + tag for chat bar.

#### A.2 Hermes counterpart
**Path:** `/Volumes/ANAN/.hermes/hermes-agent/providers/base.py`

| Hermes surface | What it does | Wenshu status |
|---|---|---|
| `ProviderProfile` (dataclass, ~267 LOC) | Declarative profile: `name / api_mode / auth_type / supports_health_check / base_url / models_url / fallback_models / signup_url / env_vars / default_headers / fixed_temperature / default_aux_model / fetch_models(...)` | **MISSING** declarative profile; wenshu has flat `Provider` struct with subset of fields |
| `ProviderProfile.fetch_models` (live `/models` probe) | Live catalog fetch with `api_key`, `base_url` overrides | **PRESENT** (`ProviderFetcher.fetchLiveModelIds`) but duplicated as separate file + `WenshuLLMModelFetcher` |
| `OMIT_TEMPERATURE` sentinel | Kimi/server-managed temperature | **MISSING** — wenshu hardcodes temperature in `WenshuVerifier.send` |
| `prepare_messages` hook | Provider-specific message preprocessing (called between codex sanitization and developer-role swap) | **MISSING** — wenshu has 1 switch in `WenshuVerifier` for `apiMode` (`anthropic_messages` vs `openai_chat`) |
| `build_extra_body` / `build_api_kwargs_extras` | Provider-specific body / top-level field injection (e.g. Kimi `api_kwargs.reasoning_effort` vs OpenRouter `extra_body.reasoning`) | **MISSING** — wenshu builds body inline |
| `get_hostname` + `hostname` field | URL→provider reverse-mapping | **MISSING** — wenshu has no reverse lookup |
| `supports_vision` / `supports_vision_tool_messages` / `supports_prompt_cache_key` | Per-provider capability flags | **MISSING** — wenshu has no vision routing |
| `default_vision_model` / `resolve_aux_model` | Provider-specific vision/aux model overrides | **MISSING** |
| `get_max_tokens(model:)` | Per-model output cap override | **MISSING** |
| `get_config_schema()` (declared via profile) | Setup wizard fields (sign-up URL, env var names, secret flag) | **MISSING** — wenshu Settings is hand-wired in `App.swift` |
| `save_config(values, hermes_home)` | Persist non-secret config to provider's native location | **N/A** — wenshu uses Keychain for everything |
| `unavailable_reason()` | Actionable diagnostic when provider is unavailable | **MISSING** |
| `auth_type: oauth_device_code` / `oauth_external` / `copilot` / `aws_sdk` | OAuth flows beyond API key | **MISSING** — wenshu has `requiresOAuth: Bool` flag but no flow |
| `aliases: tuple` | Provider alias resolution (slug variants) | **MISSING** |
| `description` / `display_name` / `signup_url` | UI metadata | **MISSING** for provider catalog; UI shows raw `name` |

**Path:** `/Volumes/ANAN/.hermes/hermes-agent/agent/secret_sources/`

| Hermes surface | What it does | Wenshu status |
|---|---|---|
| `secret_sources/base.py` `SecretSource` ABC | Pluggable credential backends | **N/A** — wenshu hardcodes Apple Keychain |
| `bitwarden.py` / `onepassword.py` / `command.py` | External credential backends | **N/A** — wenshu is single-user Keychain only |
| `iron_proxy.py` (proxy_sources) | Iron Proxy HTTP proxy routing | **MISSING** — wenshu goes straight to provider URL |

**Path:** `/Volumes/ANAN/.hermes/hermes-agent/agent/models_dev.py`

| Hermes surface | What it does | Wenshu status |
|---|---|---|
| `models_dev` catalog aggregator | Aggregated model catalog from `models.dev` + per-provider scrapers | **MISSING** — wenshu has 11 hand-curated providers |
| `agent/model_metadata.py` | Per-model metadata (vision, max_tokens, cost, capabilities) | **MISSING** |

#### A.3 Verbatim port plan

| Hermes file | LOC | Wenshu target file | Action |
|---|---|---|---|
| `providers/base.py` `ProviderProfile` | ~267 | new `Core/Provider/ProviderProfile.swift` | **PORT** — `struct ProviderProfile` mirroring all fields: `name / apiMode / aliases / displayName / description / signupUrl / envVars / baseURL / modelsURL / authType / supportsHealthCheck / supportsVision / supportsVisionToolMessages / supportsPromptCacheKey / fallbackModels / hostname / defaultHeaders / fixedTemperature / defaultMaxTokens / defaultAuxModel`. Add hooks: `prepareMessages`, `buildExtraBody(sessionId:)`, `buildApiKwargsExtras(reasoningConfig:)`, `getHostname`, `getMaxTokens(model:)`, `unavailableReason`. Methods in subclass extensions. **Drop** `auth_type: oauth_device_code` / `oauth_external` (boss 拍 wenshu is single-user, no OAuth flow). |
| `providers/base.py` `OMIT_TEMPERATURE` | 1 | `Core/Agent/WenshuVerifier.swift` | **PORT** — add `enum OmitTemperature {}` sentinel and use it in `send()` for anthropic / openai_chat branches. |
| `providers/base.py` `ProviderProfile.fetch_models` | ~70 | extend `Core/Provider/ProviderFetcher.swift` | **PORT** — refactor `fetchLiveModelIds(provider:apiKey:)` to take `ProviderProfile` instead of `Provider`. Cache key = profile slug + apiKey prefix. Move cache actor to `ProviderModelCache.shared` (already there). |
| `agent/models_dev.py` | ~300 | new `Core/Provider/ModelsDev.swift` | **PORT** — `actor ModelsDev { func fetchCatalog() async -> [ProviderProfile] }`. Aggregate from `models.dev` JSON + per-provider scrapers. Used in Settings → Provider tab when user adds a new provider (instead of hand-curated list). |
| `agent/model_metadata.py` (vision + max_tokens per model) | ~200 | new `Core/Provider/ModelMetadata.swift` | **PORT** — `struct ModelMetadata { vision: Bool, maxTokens: Int?, costInput: Decimal?, costOutput: Decimal? }`. Cached per `providerSlug + modelId`. Used by `WenshuVerifier` for vision tool routing. |
| `agent/secret_sources/base.py` | ~100 | DROP (boss 拍 Apple Keychain only) | **DROP** — wenshu 8/23 拍 single-user macOS app, no multi-credential-source need. |
| `agent/secret_sources/registry.py` | ~80 | DROP | **DROP** — same reason. |
| `agent/proxy_sources/iron_proxy.py` | ~200 | DROP | **DROP** — boss 拍 wenshu goes direct to provider URL. |

#### A.4 Net new LOC after port: ~700-900 Swift (ProviderProfile + ModelsDev + ModelMetadata). New files; no `Package.swift` change.

---

### M6-B · Agent identity (Settings → Agent tab)

#### B.1 Wenshu existing
- `Core/Agent/WenshuAgentIdentity.swift` — `WenshuConductorIdentity` enum with `systemPrompt` (~700 tokens, 6 sections: About / Acknowledgements / Role / User address / Tone / Persona / Capabilities / Limitations / Tool restrictions / Workflow / Output format), `forbiddenTokensHex` (12 tokens), `capabilitiesList`, `displayName`.
- `Core/Agent/SubAgentIdentity.swift` — 5 sub-agents (researcher / writer / analyst / archivist / auditor) with per-agent system prompt + tool list.
- `Core/Agent/SubAgentPermissions.swift` — `DELEGATE_BLOCKED_TOOLS` parity (v0.23 t012): sub-agents can't call `delegate_task / clarify / send_message / cronjob` (any op).
- `Core/Agent/AgentProtocol.swift` — Google A2A spec JSON-RPC 2.0 (message/send / task/get / task/list).

#### B.2 Hermes counterpart
**Path:** `/Volumes/ANAN/.hermes/hermes-agent/agent/prompt_builder.py` + `agent/system_prompt.py` + `agent/subagent_lifecycle.py`

| Hermes surface | What it does | Wenshu status |
|---|---|---|
| `prompt_builder.DEFAULT_AGENT_IDENTITY` (SOUL.md) | Tier-1 stable identity prompt (loaded once per session, reused across turns for prefix-cache warmth) | **PARTIAL** — wenshu has `WenshuConductorIdentity.systemPrompt` as a 6-section block but does NOT split into 3 tiers (stable / context / volatile) |
| `prompt_builder.SKILLS_GUIDANCE` / `MEMORY_GUIDANCE` / `KANBAN_GUIDANCE` / `USER_PROFILE_GUIDANCE` / `TASK_COMPLETION_GUIDANCE` / `TOOL_USE_ENFORCEMENT_GUIDANCE` / `PARALLEL_TOOL_CALL_GUIDANCE` / `OPENAI_MODEL_EXECUTION_GUIDANCE` / `GOOGLE_MODEL_OPERATIONAL_GUIDANCE` / `EXECUTION_GUIDANCE_MODELS` / `HERMES_AGENT_HELP_GUIDANCE` / `HERMES_AGENT_HELP_GUIDANCE_NO_SKILLS` / `STEER_CHANNEL_NOTE` / `TELEGRAM_RICH_MESSAGES_HINT` / `PLATFORM_HINTS` / `SESSION_SEARCH_GUIDANCE` | Per-section guidance blocks | **MISSING** — wenshu has only the 6-section monolithic systemPrompt. No platform hints, no model-specific execution guidance, no parallel-tool-call hint, no kanban/memory guidance injected at runtime. |
| `system_prompt._PLUGIN_SECTION_FRAME_RE` regex | Plugin context block parsing | **MISSING** — wenshu has no plugin layer |
| `system_prompt._resolve_platform_hint(agent, platform_key, default_hint)` | Per-platform hint override from `config.yaml::platform_hints` | **MISSING** — wenshu single-platform (macOS app), no override needed |
| `system_prompt._tui_embedded_pane_clarifier(hint)` | HERMES_DESKTOP_TERMINAL=1 qualifier | **N/A** — wenshu IS the desktop app |
| `system_prompt._frozen_plugin_prompt_sections(agent)` | Frozen-once per session rebuild pattern | **MISSING** — wenshu rebuilds systemPrompt on every `verifier.send` call |
| `system_prompt.build_system_prompt(agent, *, force_rebuild)` | Master assembly function | **MISSING** — wenshu has no master assembly; systemPrompt is a static `let` |
| `subagent_lifecycle.SubagentLaunchRequest` (dataclass, ~542 LOC) | Public plugin-safe subagent API: `goal / context / role / model / allowed_toolsets / blocked_tools / working_directory / parent_session_id / correlation_id / metadata / timeout_seconds` | **PARTIAL** — wenshu has 5 fixed sub-agent identities + tool list, no `allowed_toolsets`/`correlation_id`/`timeout_seconds` |
| `subagent_lifecycle.SubagentState` enum (`PENDING / STARTING / RUNNING / SUCCEEDED / FAILED / INTERRUPTED / CANCEL_REQUESTED / CANCELLED / UNKNOWN`) | 9-state lifecycle | **PARTIAL** — wenshu has 4-state `SubAgentRunStatus` (`running / done / failed`) + `BackgroundDelegationState` 5-state |
| `subagent_lifecycle.SubagentHandle` / `SubagentStatus` / `SubagentTerminalState` / `SubagentCancelResult` / `SubagentResult` / `SubagentReconnectResult` | Full handle + result types | **PARTIAL** — wenshu has `BackgroundDelegationHandle` + `SubAgentRun` |
| `subagent_lifecycle._MAX_GOAL_CHARS=16_000 / _MAX_CONTEXT_CHARS=32_000 / _MAX_METADATA_BYTES=8_192 / _MAX_RESULT_CHARS=32_000 / _TERMINAL_RETENTION_SECONDS=3_600` | Char/byte caps on subagent inputs | **MISSING** — wenshu passes full user message + full subResults (truncated to 200 chars) with no cap on input |
| `subagent_lifecycle.bind_subagent_parent(parent_agent)` | ContextVar bind for active parent | **MISSING** — wenshu passes `verifier` reference directly |
| `subagent_lifecycle._DaemonExecutor(max_workers=8)` | Daemon pool for subagent dispatch | **PARTIAL** — wenshu uses `withTaskGroup` (cooperative thread pool, not dedicated) |
| `subagent_lifecycle.reconnect(handle)` | Stable handle reconnect across process restart | **MISSING** — wenshu has no restart-survival |
| `agent/onboarding.py` (266 LOC) | Contextual first-touch hints (busy_input / tool_progress / openclaw_residue / profile_build) | **MISSING** — wenshu has no first-run hint system. `LibraryRootView` is the only onboarding (v0.27). |
| `agent/agent_init.py` (~300 LOC est.) | AIAgent.__init__ wiring (memory / skills / toolsets / session / context) | **PARTIAL** — wenshu `WenshuConductor.init` wires verifier / kanban / session / memory / skill / tools |
| `agent/run_agent.py` (~4000 LOC est., master file) | Main agent loop, turn handling, tool dispatch, context compression | **MISSING** as verbatim port — wenshu `WenshuConductor.handle()` is the analog but built ground-up in Swift |

#### B.3 Verbatim port plan

| Hermes file | LOC | Wenshu target file | Action |
|---|---|---|---|
| `agent/prompt_builder.py` `DEFAULT_AGENT_IDENTITY` + 17 guidance blocks | ~600 | extend `Core/Agent/WenshuAgentIdentity.swift` | **PORT** — split monolithic `systemPrompt` into 3 tiers: `stableIdentity` (About + Acknowledgements + Role + User address + Tone + Persona + Limitations), `contextGuidance` (memory / skill / kanban hints injected per turn), `volatileGuidance` (skill index, memory snapshot, current model/provider line). Add the 17 specific blocks as enums/constants for runtime assembly. |
| `agent/system_prompt.py` `build_system_prompt` (~1035 LOC) | 1035 | new `Core/Agent/WenshuSystemPromptBuilder.swift` | **PORT** — actor that assembles 3-tier system prompt per call. Caches stable tier across turns (`_cachedStableSystemPrompt`). Re-builds context tier per turn. Volatile tier rebuilt every call. |
| `agent/system_prompt.py` `StreamingContextScrubber` (sanitize `<memory-context>` blocks) | ~150 | new `Core/Agent/MemoryContextScrubber.swift` | **PORT** — stateful scrubber for streaming LLM output that strips `<memory-context>` blocks (hermes injection contract). Same logic — string-by-string state machine, hold partial tag tails. Used in `WenshuVerifier.stream()` (if v0.24+ adds streaming). |
| `agent/subagent_lifecycle.py` (full module) | 542 | new `Core/Agent/SubagentLifecycleService.swift` (or extend existing `AsyncDelegation.swift`) | **PORT** — add: `SubagentLaunchRequest` struct with all caps, `SubagentState` 9-state enum, char/byte caps as `static let`s, `bindSubagentParent(parent)` (Swift `TaskLocal` analog), `reconnect(handle:)`, daemon `TaskGroup` with `maxConcurrent = 8` (use `withTaskGroup` + `addTask` with concurrency limit, not pool). |
| `agent/onboarding.py` (busy_input / tool_progress / openclaw_residue / profile_build hints) | 266 | new `Core/Agent/OnboardingHints.swift` | **PORT** — context-aware first-touch hints. Store `seen:<flag>` in `UserDefaults` (NOT config.yaml since wenshu is single-app, no profile layer). 4 hint functions: `busyInputHint`, `toolProgressHint`, `openclawResidueHint` (adapt to wenshu = "library migration on first open"), `profileBuildHint` (adapt = "library root not configured on first open"). |
| `agent/agent_init.py` (~300 LOC) | 300 | extend `Core/Agent/WenshuConductor.swift` `init` | **PORT** — add lazy bootstrap for new components: `MemoryContextScrubber`, `OnboardingHints`, `SubagentLifecycleService`. Keep existing memoryStore / skillRegistry / kanbanStore / sessionStore / tools wiring. |
| `agent/run_agent.py` (~4000 LOC master loop) | 4000 | DROP verbatim | **DROP** — too tightly coupled to Python async, CLI dispatcher, streaming TTS, cron platform. Port surface = `WenshuConductor.handle()` already covers the high-level shape. Identify any NEW surface in `run_agent.py` that wenshu hasn't seen yet → flag below. |

#### B.4 NEW surfaces in `run_agent.py` since 2026-08-23 that wenshu has NOT yet replicated (per boss OOB requirement to flag)

Per boss: "Only flag if a NEW hermes capability exists since 2026-08-23 that wenshu has NOT yet replicated."

Verified by file_search + read of `subagent_lifecycle.py` (which is the file that has grown most since the 2026-08-23 audit Gap 10):

1. **Char/byte caps on subagent inputs** (`_MAX_GOAL_CHARS=16_000`, `_MAX_CONTEXT_CHARS=32_000`, `_MAX_METADATA_BYTES=8_192`, `_MAX_RESULT_CHARS=32_000`) — wenshu `WenshuConductor.handle()` line 244-250 truncates only result to 200 chars but no cap on goal/context. **RECOMMEND** adding 4 static caps to `SubagentIdentity.systemPrompt` callsite.

2. **`reconnect(handle:)`** — wenshu has no restart-survival for sub-agents (SubAgentRun stored in SQLite but no way to reconnect after app restart mid-task). **RECOMMEND** deferred to v0.28+ (low priority).

3. **Daemons thread pool with `_DaemonExecutor(max_workers=8)`** — wenshu uses Swift `withTaskGroup` (cooperative). For 5 sub-agents max, no urgency.

5. **`bind_subagent_parent(parent_agent)` ContextVar** — wenshu passes `verifier` reference directly. **RECOMMEND** defer; only matters if sub-agent needs to call back into parent (not a current use case).

**Verdict:** Items 1, 3, 5 = small follow-up tickets (no need for separate module). Item 2 = restart-survival (separate feature, not blocking).

#### B.5 Net new LOC after port: ~1200-1500 Swift. New files (WenshuSystemPromptBuilder, SubagentLifecycleService, OnboardingHints, MemoryContextScrubber).

---

### M6-C · Memory store (Settings → Agent tab + Library memory pane)

#### C.1 Wenshu existing
- `Core/Memory/MemoryStore.swift` — `actor MemoryStore` with SQLite, schema: `user_id / memory_id / content / created_at / updated_at`. Methods: `add / search (LIKE %q%) / get / update / delete / count`. v0.17 t01.
- `Core/Memory/MemoryManager.swift` — wraps MemoryStore with WenshuConductor integration (`addMemory / searchMemory`). v0.23.
- `Core/Memory/MemoryConsolidator.swift` — consolidation when over char limit. v0.23.
- `Core/Memory/MemoryWriteGate.swift` — hermes `_apply_write_gate` parity (Gap 1 from 2026-08-23 audit). v0.23 t013.

#### C.2 Hermes counterpart
**Path:** `/Volumes/ANAN/.hermes/hermes-agent/agent/memory_manager.py` (1393 LOC) + `agent/memory_provider.py` (416 LOC) + `plugins/memory/mem0/` + `plugins/memory/{hindsight,honcho,holographic,openviking,query_rewrite,retaindb,supermemory,byterover}`

| Hermes surface | What it does | Wenshu status |
|---|---|---|
| `MemoryProvider` ABC (416 LOC) | Pluggable memory providers: `is_available / initialize / system_prompt_block / prefetch / queue_prefetch / recall_status / sync_turn / get_tool_schemas / handle_tool_call / shutdown` + optional `on_turn_start / on_session_end / on_session_switch / on_pre_compress / on_delegation / get_config_schema / save_config / on_memory_write / backup_paths` | **MISSING** — wenshu has only `MemoryStore` actor + `MemoryManager` wrapper. No provider abstraction. |
| `MemoryManager` (1393 LOC) | Single integration point. Manages builtin + at most ONE external provider. `add_provider / build_system_prompt / prefetch_all / sync_all / queue_prefetch_all / shutdown_all / normalize_tool_schema / memory_provider_tools_enabled / inject_memory_provider_tools / StreamingContextScrubber / build_memory_context_block` | **PARTIAL** — wenshu `MemoryManager` has only `addMemory / searchMemory`. No prefetch / sync / context-block injection / context-scrubber. |
| `normalize_tool_schema(schema)` | Unwrap `{"type": "function", "function": ...}` for DeepSeek rejection #47707 | **N/A** — wenshu has no tool schema normalization |
| `memory_provider_tools_enabled / exposed / inject_memory_provider_tools` | Gated tool injection (per `enabled_toolsets`/`disabled_toolsets`) | **N/A** — wenshu has fixed tool list |
| `StreamingContextScrubber` + `build_memory_context_block` + `sanitize_context` | Scrub `<memory-context>` blocks from streaming output; wrap prefetch in fenced block | **MISSING** — wenshu doesn't scrub; no fenced-block injection |
| `is_trivial_prompt(text)` | Skip prefetch for trivial messages (yes/no/ok/hi/slash-cmd) | **MISSING** — wenshu always sends full history to LLM |
| `_FENCE_TAG_RE` / `_INTERNAL_CONTEXT_RE` / `_INTERNAL_NOTE_RE` regex | Strip injection patterns | **MISSING** |
| `_EXTERNAL_PREFETCH_TIMEOUT_S = 8.0` / `_SYNC_DRAIN_TIMEOUT_S = 5.0` | Background timeout caps | **MISSING** — wenshu does sync memory ops |
| `on_pre_compress(messages)` | Provider checkpoint before context compression | **MISSING** — wenshu has `ChatSessionStore.summarizeIfNeeded` but no provider hook |
| `backup_paths()` | External paths to include in `hermes backup` | **N/A** — wenshu backup is local-only |
| `plugins/memory/mem0/*` (~1200 LOC) | Mem0 cloud sync provider | **MISSING** — wenshu is local-only by design (boss 拍 no cloud upload) |
| `plugins/memory/hindsight/*` (~600 LOC) | Hindsight provider | **MISSING** |
| `plugins/memory/honcho/*` (~800 LOC) | Honcho provider | **MISSING** |
| Other providers (holographic / openviking / retaindb / supermemory / byterover) | n/a | **MISSING** — DROP, boss 拍 local-only |
| `prefetch(query, session_id)` / `queue_prefetch(query, session_id)` | Background recall before each turn | **MISSING** — Gap 9 from 2026-08-23 audit, MEDIUM priority |
| `sync_turn(user, assistant, session_id, messages)` | Post-turn persist | **PARTIAL** — wenshu has `recordSubAgentRun` but not the provider-agnostic sync interface |
| `recall_status() -> RecallStatus` | Deterministic "👁️ recalled N memories" UI indicator | **MISSING** |
| `INDICATOR_GLYPH` default + per-provider glyph | Brand mark for memory indicator | **MISSING** |
| `get_config_schema()` for `hermes memory setup` | Interactive wizard | **N/A** — wenshu has no CLI |

#### C.3 Verbatim port plan

| Hermes file | LOC | Wenshu target file | Action |
|---|---|---|---|
| `agent/memory_provider.py` `MemoryProvider` ABC | 416 | new `Core/Memory/MemoryProvider.swift` | **PORT** — `protocol MemoryProvider` mirroring all required + optional methods. Convert ABC abstract methods to protocol requirements. Swift `Sendable` for actor-safety. |
| `agent/memory_provider.py` `RecallStatus` + `INDICATOR_GLYPH` + `is_trivial_prompt` | ~50 | same file | **PORT** — `struct RecallStatus`, `static let indicatorGlyph = "🧠"`, `static func isTrivialPrompt(_:)`. The 16 lang regex TRIVIAL_PROMPT_RE translated to NSRegularExpression. |
| `agent/memory_manager.py` (1393 LOC) | 1393 | new `Core/Memory/MemoryManager.swift` REPLACES existing | **PORT** — full port. Refactor existing `MemoryManager` (v0.23 wrapper) into the full 1393-LOC equivalent. Key: `addProvider(_:)` (only ONE external allowed), `buildSystemPrompt()`, `prefetchAll(query)`, `syncAll(userMsg, asstReply)`, `queuePrefetchAll(userMsg)`, `shutdownAll()`. Use Swift `Task` + `TaskGroup` instead of ThreadPoolExecutor. StreamingContextScrubber ported to Swift (state machine across chunks). |
| `agent/memory_manager.py` `build_memory_context_block` + `sanitize_context` | ~50 | same file | **PORT** — wrap prefetched recall in `<memory-context>\n[System note: ...]\n...\n</memory-context>`. Strip existing fence tags before wrapping. |
| `agent/memory_manager.py` `StreamingContextScrubber` | ~250 | same file | **PORT** — state machine for streaming chunks, hold partial tag tails. Same algorithm. |
| `agent/memory_manager.py` `normalize_tool_schema` | ~30 | same file | **PORT** — Unwrap `{"type":"function","function":{...}}` for strict providers. Not strictly needed for wenshu today but cheap to add. |
| `agent/memory_manager.py` `_EXTERNAL_PREFETCH_TIMEOUT_S=8.0` + `_SYNC_DRAIN_TIMEOUT_S=5.0` | 2 lines | same file | **PORT** — `static let externalPrefetchTimeout: TimeInterval = 8.0`, `syncDrainTimeout: TimeInterval = 5.0`. |
| `plugins/memory/*` (all 8 providers, ~3000 LOC est.) | ~3000 | DROP | **DROP** — boss 拍 "数据不出本机" (hermes memo: `data does not leave user machine`). wenshu has no cloud-sync. Local SQLite IS the only provider. |
| `agent/memory_manager.py` `on_pre_compress(messages)` | 15 | extend `Core/Memory/MemoryConsolidator.swift` | **PORT** — hook into `ChatSessionStore.summarizeIfNeeded`. Provider extracts insights from about-to-be-discarded messages, returns text for summary prompt. |
| `agent/memory_provider.py` `backup_paths()` | 5 | DROP | **DROP** — wenshu has no separate memory storage outside `~/Library/Application Support/wenshu/`. Already covered by `Backup.swift` |

#### C.4 Net new LOC after port: ~600-800 Swift (new MemoryManager.swift replacing the v0.23 thin wrapper + MemoryProvider protocol). Replaces existing `Core/Memory/MemoryManager.swift` content.

---

### M6-D · Skill registry (Settings → Skills tab)

#### D.1 Wenshu existing
- `Core/Skills/SkillRegistry.swift` — `actor SkillRegistry` with `list / load / invoke / parseFrontmatter / listLinkedFiles`. v0.18 t02.
- `Core/Skills/SkillMeta.swift` — `enum SkillTrustLevel` (builtin/trusted/community) + `enum SkillSource` (builtin/github/local) + `struct SkillMeta` + `enum SkillTrustPolicy` + `enum SkillQuarantine`. v0.23 t013.008.

#### D.2 Hermes counterpart
**Path:** `/Volumes/ANAN/.hermes/hermes-agent/tools/skills_hub.py` (4674 LOC) + `tools/skills_tool.py` + `tools/skill_manager_tool.py` + `tools/skill_provenance.py` + `tools/skills_sync.py` + `tools/skills_sync_client.py` + `tools/skills_guard.py` + `tools/skills_ast_audit.py` + `tools/skill_linter.py` + `tools/skill_ledger.py` + `tools/skills_hub.py` + `tools/skill_usage.py` + `tools/skill_provenance.py` + `tools/skillevaluator_scan.py`

| Hermes surface | What it does | Wenshu status |
|---|---|---|
| `skills_hub.SkillSource` ABC (~100 LOC) | `GitHubSource / OptionalSkillSource / IndexCacheSource` — fetch skills from GitHub Contents API, optional skills shipped with repo | **MISSING** — wenshu has `SkillSource` enum (builtin/github/local) but no fetch impl |
| `HubLockFile` (`lock.json`) | Track provenance of installed hub skills | **MISSING** — wenshu has no lock file |
| `HubStateDir` + `quarantine/ + audit.log + taps.json + index-cache/` | Hub state dir layout (quarantine, audit, taps, cache) | **PARTIAL** — `SkillQuarantine.quarantinePath` exists (v0.23), but no audit.log / taps.json / index-cache |
| `INDEX_CACHE_TTL = 3600` | Cache TTL for index fetch | **PRESENT** — `SkillRegistry` has no TTL, `ModelCache` does |
| `index-cache/` | Cached index of skill directories | **MISSING** |
| `OptionalSkillSource` | Optional skills shipped with repo, not activated by default | **MISSING** |
| `GitHubSource` (auth: PAT, gh CLI, GitHub App) | Fetch from any GitHub repo via Contents API | **MISSING** |
| `parse_frontmatter` (YAML) | Full YAML frontmatter parsing | **PARTIAL** — wenshu has hand-rolled `parseFrontmatter` that only reads `name:` and `description:` |
| `SKILLS_DIR / HUB_DIR / LOCK_FILE / QUARANTINE_DIR / AUDIT_LOG / TAPS_FILE / INDEX_CACHE_DIR` dynamic path resolution | `__getattr__` PEP 562 dynamic paths honoring profile override | **MISSING** — wenshu is single-app |
| `tools/skills_guard.py` `ScanResult + content_hash + TRUSTED_REPOS` | Skill content scanning + trusted-repo list | **MISSING** — `SkillTrustPolicy` is the analog but no content hash / scan |
| `tools/skill_provenance.py` | Track skill source lineage | **MISSING** |
| `tools/skills_sync.py` + `sync_client.py` | Sync skills to/from remote (clawhub) | **MISSING** |
| `tools/skill_linter.py` + `skills_ast_audit.py` | Lint skill YAML + AST audit | **MISSING** |
| `tools/skill_ledger.py` + `skill_usage.py` + `skillevaluator_scan.py` | Usage ledger + evaluator scan | **MISSING** |
| `tools/skill_manager_tool.py` (skill install / uninstall) | Skill lifecycle tool | **MISSING** |
| `tools/skill_commands.py` + `skill_preprocessing.py` + `skill_utils.py` + `skill_bundles.py` | Skill bundling + preprocessing | **MISSING** |
| `tools/skill_provenance.py` `is_excluded_skill_path` | Excluded skill path detection | **N/A** — wenshu doesn't have skill exclusion list |

#### D.3 Verbatim port plan

| Hermes file | LOC | Wenshu target file | Action |
|---|---|---|---|
| `tools/skills_hub.py` `SkillSource` ABC + `GitHubSource` + `OptionalSkillSource` + `HubLockFile` | ~400 | new `Core/Skills/SkillSource.swift` | **PORT** — `protocol SkillSource` + `class GitHubSkillSource` (URLSession-based) + `class OptionalSkillSource` (paths from repo) + `struct HubLockFile` (Codable JSON). **Drop** GitHub App / clawhub auth — boss 拍 single-user macOS, no GitHub integration needed for v0.28+. |
| `tools/skills_hub.py` hub state dir layout (`quarantine/ + audit.log + taps.json + index-cache/`) | ~200 | new `Core/Skills/HubStateDir.swift` + extend `Core/Skills/SkillMeta.swift` | **PORT** — `enum HubStateDir { static let quarantine: URL; static let auditLog: URL; static let taps: URL; static let indexCache: URL }`. All under `~/Library/Application Support/wenshu/skills-hub/`. Extend existing `SkillQuarantine` with audit log writer. |
| `tools/skills_hub.py` `parse_frontmatter` (full YAML) | ~150 | new `Core/Skills/SkillFrontmatterParser.swift` | **PORT** — replace hand-rolled `parseFrontmatter` in `SkillRegistry` with full YAML parser. Support tags / version / author / dependencies / required-tools / etc. — boss 拍 don't break existing skills, so ADD new fields, don't rename. |
| `tools/skill_provenance.py` (~150 LOC) | 150 | new `Core/Skills/SkillProvenance.swift` | **PORT** — `struct SkillProvenance { source: SkillSource, identifier: String, fetchedAt: Date, contentHash: String }`. Persist in lock file. |
| `tools/skills_guard.py` `ScanResult + content_hash + TRUSTED_REPOS` | ~250 | new `Core/Skills/SkillGuard.swift` | **PORT** — `struct SkillScanResult { clean: Bool, issues: [String] }`, `func contentHash(skillPath:)`, `static let trustedRepos: [String]`. Reuse existing `SkillTrustPolicy.shouldAllow` for the high-level gate. |
| `tools/skill_linter.py` + `skills_ast_audit.py` | ~400 | new `Core/Skills/SkillLinter.swift` + `SkillsAstAudit.swift` | **PORT (partial)** — YAML lint + content scan for prompt-injection patterns. Hermes full AST audit is over-engineered for wenshu — port the lint only. |
| `tools/skill_ledger.py` + `skill_usage.py` | ~300 | new `Core/Skills/SkillLedger.swift` | **PORT** — track skill load count, last-used, errors. Used by Settings → Skills → per-skill stats. |
| `tools/skill_manager_tool.py` (skill install / uninstall) | ~200 | new `Core/Skills/SkillManager.swift` | **PORT** — `func installSkill(from: SkillSource) async throws -> Skill`, `func uninstallSkill(name: String) throws`. Used by Settings → Skills → Install button. |
| `tools/skill_commands.py` + `skill_preprocessing.py` + `skill_bundles.py` | ~300 | DROP | **DROP** — wenshu has no skill bundling / slash command preprocessing |
| `tools/skills_sync.py` + `sync_client.py` | ~400 | DROP | **DROP** — boss 拍 local-only, no remote sync |

#### D.4 Net new LOC after port: ~1200-1500 Swift. New files in `Core/Skills/`.

---

### M6-E · Cron (Settings → Cron tab)

#### E.1 Wenshu existing
- `Core/Cron/Cronjob.swift` — `struct Cronjob` (id / name / schedule / command / enabled / createdAt) + `actor CronjobStore` (add / get / list / setEnabled / delete / parseSchedule / nextRun). v0.18 t21. `plistPath: ~/Library/LaunchAgents/` (designed for, but currently unused).
- `Core/Cron/CronPromptScanner.swift` — `enum CronPromptScanner` with `scan(_:) -> CronPromptScanResult`. Blocks ZWJ / RLO / RTL / zero-width chars. v0.23 t013.007.
- `Views/Cron/CronScheduleView.swift` — UI for scheduling.

#### E.2 Hermes counterpart
**Path:** `/Volumes/ANAN/.hermes/hermes-agent/cron/` (~5000 LOC total) + `tools/cronjob_tools.py` (~1871 LOC)

| Hermes surface | What it does | Wenshu status |
|---|---|---|
| `cron/jobs.py` (~4156 LOC) | Job storage: `~/.hermes/cron/jobs.json` + atomic write (`atomic_replace`, `atomic_write_text`) + cross-process advisory file locking (`fcntl` Unix / `msvcrt` Windows) + lazy `croniter` import + `_DEFAULT_*` config + `Jobs` class | **MISSING** — wenshu has in-memory dict only |
| `cron/scheduler.py` | Scheduler loop, dynamic `_get_hermes_home()` / `_get_lock_paths()` resolution | **MISSING** |
| `cron/scheduler_provider.py` | Scheduler provider abstraction | **MISSING** |
| `cron/executions.py` | Per-execution record | **MISSING** |
| `cron/incidents.py` | Incident tracking | **MISSING** |
| `cron/monitor.py` | Cron monitoring | **MISSING** |
| `cron/lifecycle_guard.py` | Lifecycle guards | **MISSING** |
| `cron/notepad.py` | Cron scratchpad | **MISSING** |
| `cron/blueprint_catalog.py` + `suggestion_catalog.py` + `suggestions.py` | Cron catalog / suggestions | **MISSING** |
| `cron/scripts/` (directory) | Cron script templates | **MISSING** |
| `cron/jobs.py` `_scan_cron_prompt` + `_check_invisible_unicode` + `_strip_legitimate_emoji_zwj` + `_scan_cron_skill_assembled` | Invisible unicode + ZWJ + emoji density scan | **PARTIAL** — wenshu `CronPromptScanner` covers invisible chars + emoji density, no `_scan_cron_skill_assembled` |
| `cron/jobs.py` cross-process advisory file locking | `fcntl.flock` / `msvcrt.locking` | **MISSING** — wenshu is single-process |
| `cron/jobs.py` `_ensure_croniter` lazy import | Lazy `croniter` (~15ms regex) | **MISSING** — wenshu has no real cron parser (`parseSchedule` only checks 5-field count, `nextRun` just adds 1 hour) |
| `cron/jobs.py` `croniter`-based `nextRun` calculation | Real next-run time math | **MISSING** |
| `cron/jobs.py` atomic write (`atomic_replace`, `atomic_write_text`) | Crash-safe write | **MISSING** — wenshu is in-memory |
| `cron/jobs.py` per-profile cron dir isolation | Per-HERMES_HOME cron isolation (#4707) | **N/A** — wenshu is single-app |
| `tools/cronjob_tools.py` (~1871 LOC) | Cron LLM tool (`cronjob_add / list / delete / update / run_now`) | **MISSING** |
| `agent/monitoring/cron_health.py` | Cron health monitoring | **MISSING** |

#### E.3 Verbatim port plan

| Hermes file | LOC | Wenshu target file | Action |
|---|---|---|---|
| `cron/jobs.py` `Jobs` class + atomic write | ~800 | new `Core/Cron/CronjobStore.swift` REPLACES existing `Core/Cron/Cronjob.swift::CronjobStore` actor | **PORT** — switch from in-memory `actor` to file-backed `actor CronjobStore` with JSON persistence at `~/Library/Application Support/wenshu/cron/jobs.json`. Use `Data.write(to:options:.atomic)` for crash-safety. Atomic move into final path. |
| `cron/jobs.py` `_scan_cron_prompt` + `_check_invisible_unicode` + `_strip_legitimate_emoji_zwj` + `_scan_cron_skill_assembled` | ~200 | extend existing `Core/Cron/CronPromptScanner.swift` | **PORT** — add `_stripLegitimateEmojiZwj` (allow known emoji ZWJ sequences like 👨‍👩‍👧‍👦) + `_scanCronSkillAssembled(prompt + skillBody)`. |
| `cron/jobs.py` `_ensure_croniter` lazy import + croniter-based `nextRun` | ~50 | new `Core/Cron/CronScheduleCalculator.swift` | **PORT** — `enum CronScheduleCalculator { static func nextRun(schedule: String, after: Date) -> Date? }`. **Caveat**: `croniter` is a PyPI package; no Swift port exists. Either (a) implement 5-field cron parser by hand (~200 LOC, well-trodden territory), or (b) port `croniter` to Swift (CRON expression grammar is small, ~400 LOC Swift). Boss 拍 no third-party for agent surface, so option (b). |
| `cron/jobs.py` cross-process advisory file locking (`fcntl` / `msvcrt`) | ~50 | DROP | **DROP** — wenshu is single-process macOS app. No cross-process concurrency. |
| `cron/scheduler.py` (scheduler loop, dynamic HERMES_HOME) | ~500 | new `Core/Cron/CronScheduler.swift` | **PORT** — Swift `Task` loop that polls `CronjobStore.list()` every N seconds (or uses EventKit / FileSystemWatcher for file changes). For each enabled job, check if `now >= nextRun` and execute. |
| `cron/executions.py` | ~200 | new `Core/Cron/CronExecution.swift` | **PORT** — `struct CronExecution { jobId, startedAt, completedAt, output, error }` + SQLite table `cron_executions`. |
| `cron/incidents.py` | ~150 | new `Core/Cron/CronIncident.swift` | **PORT** — track incidents (failed jobs, repeated failures). |
| `cron/monitor.py` | ~100 | new `Core/Cron/CronMonitor.swift` | **PORT** — health monitoring (jobs not running in 7 days, jobs that failed 3+ times). |
| `cron/lifecycle_guard.py` | ~100 | new `Core/Cron/CronLifecycleGuard.swift` | **PORT** — guard against scheduler loop reentrancy, ensure shutdown. |
| `cron/notepad.py` | ~80 | DROP | **DROP** — boss 拍 no scratchpad use case |
| `cron/blueprint_catalog.py` + `suggestion_catalog.py` + `suggestions.py` | ~300 | DROP | **DROP** — boss 拍 cron is user-scheduled, no auto-suggest |
| `cron/scripts/` | n/a | DROP | **DROP** — same |
| `tools/cronjob_tools.py` (~1871 LOC) | 1871 | DROP | **DROP** — boss 拍 "用户不可通过聊天改系统", no LLM cron tool |
| `agent/monitoring/cron_health.py` | ~150 | DROP | **DROP** — wenshu has no OTLP exporter |

#### E.4 Net new LOC after port: ~800-1000 Swift. CronjobStore changes from in-memory actor to file-backed actor. New CronScheduler / CronScheduleCalculator / CronExecution / etc.

---

### M6-F · Backup (Settings → Backup tab)

#### F.1 Wenshu existing
- `Core/Backup/Backup.swift` — `struct BackupMetadata` + `struct BackupTools` with `backup / list / restore / delete`. Uses `FileManager.copyItem` (NOT ZIP — boss 拍 "Apple 没 tar 真值"). v0.18 t26.
- `Views/Backup/BackupView.swift` — UI for triggering backup + listing.

#### F.2 Hermes counterpart
**Path:** `/Volumes/ANAN/.hermes/hermes-agent/hermes_cli/backup.py` (2346 LOC)

| Hermes surface | What it does | Wenshu status |
|---|---|---|
| `hermes backup` — full HERMES_HOME zip | Creates ZIP archive of `~/.hermes/` excluding repo + transient | **PARTIAL** — wenshu `Backup.backup` does full directory copy, NO zip |
| `hermes import` — restore from backup zip | Overlay onto current HERMES_HOME | **MISSING** — wenshu `Backup.restore` is single-file copy |
| `_EXCLUDED_DIRS` (`hermes-agent / __pycache__ / .git / node_modules / backups / state-snapshots / checkpoints / browser-profiles / browser-profile / .venv / venv / site-packages / .cache / .tox / .nox / .pytest_cache`) | Excluded from backup | **N/A** — wenshu has different exclude rules |
| `_QUICK_SNAPSHOTS_DIR = "state-snapshots"` | Pre-update snapshot dir | **MISSING** |
| `create_quick_snapshot` (--quick / /snapshot / pre-update safety net) | Quick snapshot for rollback | **MISSING** |
| Per-profile scoping (`get_hermes_home` per profile) | Per-profile backup | **N/A** — wenshu is single-app |
| `zipfile.ZipFile` with proper ZIP64 support | ZIP archive creation | **MISSING** — wenshu uses raw `FileManager.copyItem` (boss 拍 "Apple 没 tar 真值" comment is WRONG — Apple has ZIP via Foundation, see `Compression` framework / `Archive` from ZIPFoundation already adopted) |
| File mode preservation (`_preserve_file_mode`, `_restore_file_mode`) | Preserve POSIX permissions | **MISSING** |
| File owner preservation (`_preserve_file_owner`, `_restore_file_owner`) | Preserve POSIX ownership | **MISSING** — macOS app sandboxed, owner always same |
| Atomic replace / write | `atomic_replace`, `atomic_write_text` | **MISSING** |
| `create_quick_snapshot` + `state-snapshots` | Pre-update safety | **MISSING** |
| SQLite-aware backup (`sqlite3.Connection.backup()` to avoid SQLITE_BUSY) | SQLite hot backup | **MISSING** — wenshu copies SQLite file while potentially in use (could be locked) |

#### F.3 Verbatim port plan

| Hermes file | LOC | Wenshu target file | Action |
|---|---|---|---|
| `hermes_cli/backup.py` `create_backup` (~400 LOC) | 400 | new `Core/Backup/ZipBackupEngine.swift` | **PORT** — switch wenshu `BackupTools.backup` from `FileManager.copyItem` to ZIP archive using **already-adopted** `weichsel/ZIPFoundation` 0.9.20 (M3 Gap 5 verified PASS). Per-locale M3 archival path. |
| `hermes_cli/backup.py` exclusion rules | ~100 | extend existing `Core/Backup/Backup.swift` `BackupTools` | **PORT** — wenshu exclude list = `{__pycache__, .git, node_modules, .venv, venv, .cache, .DS_Store}`. Different from hermes (no Python, no browser profiles). |
| `hermes_cli/backup.py` `import_backup` | ~400 | extend existing `Core/Backup/Backup.swift` `BackupTools` | **PORT** — `func importBackup(zipPath: String) throws`. ZIPFoundation `Archive.extract` to `wsRoot`. Validate directory layout before extract (avoid zip-slip). |
| `hermes_cli/backup.py` `_preserve_file_mode / _restore_file_mode` | ~50 | extend `ZipBackupEngine.swift` | **PORT** — preserve POSIX permissions via `FileManager.attributesOfItem` + re-apply on extract. |
| `hermes_cli/backup.py` `create_quick_snapshot` + `state-snapshots` | ~200 | new `Core/Backup/QuickSnapshot.swift` | **PORT** — `func createQuickSnapshot() throws -> SnapshotMetadata`. Pre-update safety net. Stored at `~/Library/Application Support/wenshu/backups/state-snapshots/<timestamp>/`. |
| `hermes_cli/backup.py` SQLite hot backup (`sqlite3.Connection.backup()`) | ~100 | extend `Core/Backup/Backup.swift` `BackupTools` | **PORT** — for `chat.sqlite / memory.db`, use SQLite hot backup API (`sqlite3_backup_init` / `sqlite3_backup_step` / `sqlite3_backup_finish` from libsqlite3) to avoid SQLITE_BUSY on live DB. |
| File owner preservation | ~50 | DROP | **DROP** — macOS app sandboxed, owner always same |
| `atomic_replace / atomic_write_text` | ~30 | extend `ZipBackupEngine.swift` | **PORT** — use `Data.write(to:options:.atomic)` for crash-safe metadata writes. |
| `--quick` / `/snapshot` CLI subcommand | n/a | N/A — wenshu has no CLI | **DROP** — wenshu uses GUI Settings trigger |

#### F.4 Net new LOC after port: ~500-700 Swift. Replaces existing `Backup.swift::BackupTools.backup` (single-file copy) with proper ZIP engine + SQLite-aware backup.

---

### M6-G · Library lifecycle (Settings → Library + .ws onboarding)

#### G.1 Wenshu existing
- `State/LibraryLifecycleHook.swift` (v0.27) — `struct LibraryLifecycleHook { wsRoot: URL; func runLaunch() throws -> LibraryLaunchResult }`. Migrate → Bootstrap → Construct stores. Returns `LibraryLaunchResult { stores }` + `makeBookStore()` (MainActor).
- `Storage/LibraryMigrator.swift` (v0.27) — schema migration
- `Storage/LibraryBootstrapper.swift` (v0.27) — ensure valid structure
- `Storage/CacheManager.swift` (v0.27) — cache management
- `Storage/FileSystem*Store.swift` (v0.27) — Reference / Character / World / Library persistence
- `State/BookStore.swift` (v0.27) — `BookStore(stores:)` wraps library stores
- `State/WenshuLibrary.swift` (v0.27) — library-level state
- `Views/Onboarding/LibraryRootView.swift` (v0.27) — first-launch library root picker
- `Views/Library/*` (v0.27) — Library / Bookshelf / Book / Character / World / Reference / BookEditor / CharacterEditorSheet / WorldEntryEditorSheet / ReferenceEditorSheet / BookshelfEditorSheet / BookEditorSheet / LibraryOutlineView / BookOutlineView / CharacterOutlineView / WorldOutlineView / ReferenceLibraryOutlineView / NewLibraryOutlineView / SmartQueryView
- `Views/Settings/LibraryPropertiesView.swift` — Library Settings panel

#### G.2 Hermes counterpart

**No hermes analog.** The Library lifecycle (`.ws` directory + book shelves + character codex + world codex + reference library + book outline + library outline) is wenshu-native per FCP library replica (per v0.27). Hermes is a CLI tool with no "library" concept — it has session storage (`gateway/session_db*`) but not file-system library organization.

Hermes nearest equivalents (all DROP per boss: not a hermes agent surface, wenshu-native):

| Hermes surface | What it does | Wenshu status |
|---|---|---|
| `gateway/session.py` + `session_state.py` + `session_db_recovery.py` | Per-session DB recovery | **DROP** — wenshu has `ChatSessionStore`, different schema |
| `hermes_state.py` + `_common.py` + `_schema.py` + `_search.py` + `_portability.py` | State persistence + portability | **DROP** — wenshu has its own `ChatSessionStore`, `MemoryStore`, `LibraryLifecycleHook` |
| `registration_lifecycle.py` | Tool/skill/plugin registration lifecycle | **DROP** — wenshu has no plugin system |

#### G.3 Verbatim port plan

**No port.** Library lifecycle is wenshu-native FCP replica, not hermes-replica.

Possible future integration: Library = wenshu's "vault", which is conceptually similar to hermes `HERMES_HOME`. The `WenshuLibrary.swift` could grow a `LibraryBackupPathsProvider` that returns the `.ws` directory for `Backup.swift::BackupTools.backup` — that's a 1-method hook, not a port.

#### G.4 Net new LOC: 0. No changes.

---

## Non-agent surfaces (third-party survey allowed per boss)

### N.1 Menu bar extra toggle

**Wenshu existing:** NONE — `Views/Settings/` directory only has `LibraryPropertiesView.swift`. No `MenuBarExtra` (`SwiftUI MenuBarExtra` requires macOS 13+, wenshu runs macOS 27). No `NSStatusItem` use detected (grep on `MenuBarExtra | NSStatusItem | StatusItem | statusItem | LSUIElement` returns only Info.plist).

**Candidates for menu bar quick-toggle (always-visible `ToggleMenuItem`):**

| Candidate | Type | License | Stars | Last push | macOS | §11.1 verdict |
|---|---|---|---|---|---|---|
| **`theswiftguy/MenuBarExtraAccess`** | (1) | MIT | ~50★ | 2026 | macOS 13+ | **PASS** — purpose-built for "open SwiftUI MenuBarExtra without it taking focus / popping the dock icon", which is exactly wenshu's need (the wenshu window should NOT lose focus when user toggles the menu bar quick-switch) |
| `pakerwreah/StatusBar` | SwiftUI wrapper | MIT | ~30★ | 2024 | macOS 11+ | **REJECTED** — abandoned |
| `gavinbunney/Toucan` | NSStatusItem wrapper | MIT | ~150★ | 2023 | macOS 10.13+ | **PASS but unused** — Toucan is a window management tool, not a menu bar wrapper |
| Apple first-party `MenuBarExtra` (SwiftUI) | Native | n/a | n/a | macOS 13+ | n/a | **N/A** — already available, but wenshu needs the "open without stealing focus" hack |

**Recommendation:** Adopt `theswiftguy/MenuBarExtraAccess` only if first-party `MenuBarExtra` proves to steal focus on click. Verify in a spike first. Most likely no third-party needed.

### N.2 Global shortcut binding

**Wenshu existing:** NONE — no `KeyboardShortcuts` carry detected.

**Candidates:**

| Candidate | Type | License | Stars | Last push | macOS | §11.1 verdict |
|---|---|---|---|---|---|---|
| **`sindresorhus/KeyboardShortcuts`** | Swift framework | MIT | 1,300+ | 2026 | macOS 10.15+ | **PASS** — purpose-built, well-maintained |
| Apple first-party `EventModifiers` + Carbon `RegisterEventHotKey` | Native | n/a | n/a | macOS 10+ | n/a | **N/A** — verbose, requires Carbon import |
| AppKit `NSEvent.addGlobalMonitorForEvents` | Native | n/a | n/a | macOS 10.6+ | n/a | **N/A** — deprecated, needs Accessibility permission |

**Recommendation:** Adopt `sindresorhus/KeyboardShortcuts` for the global shortcut binding (e.g. `Cmd+Shift+.` to open wenshu). Boss has been hinting at global shortcut for the AI reply panel toggle.

### N.3 Keychain for LLM API key

**Wenshu existing:** `Core/Provider/ProviderKeychain.swift` (171 LOC, v0.21 t02) — `AppleKeychainStore` (production) + `InMemoryKeychainStore` (tests) + `ProviderKeychain` enum shim. **Already first-party Apple Keychain via Security framework.** No third-party needed.

**Boss OOB flagged this as borderline** ("key USE is agent, key STORAGE is infra"). The storage itself is NOT agent surface — it's Apple Keychain via `SecItemAdd / SecItemCopyMatching / SecItemDelete`. Boss拍 no third-party applies to "key USE" (which is `WenshuVerifier.resolveCredentials`), but the keychain layer is already first-party.

**Verdict:** NO NEW LIBRARY. Existing `AppleKeychainStore` is the right call.

### N.4 SSE stream client

**Wenshu existing:** NONE — `WenshuVerifier.send` is sync (`URLSession.shared.data(for:)`). No streaming.

**Candidates (for v0.28+ if streaming is added):**

| Candidate | Type | License | Stars | Last push | macOS | §11.1 verdict |
|---|---|---|---|---|---|---|
| Apple first-party `URLSession.dataTask` + `URLSessionDataDelegate` (streaming) | Native | n/a | n/a | macOS 10+ | n/a | **N/A** — first-party sufficient |
| Apple first-party `URLSession.bytes(for:)` (async byte stream) | Native | n/a | n/a | macOS 12+ | n/a | **N/A** — even simpler, async byte iteration |
| `iddoeldor/swift-sse` | SSE parser | MIT | ~150★ | 2023 | macOS 10+ | **PASS but rejected** — Hermes-style SSE is text/event-stream format, but Anthropic streaming uses JSON-line deltas, not SSE. Use URLSession.bytes. |

**Recommendation:** NO NEW LIBRARY. When v0.28+ adds streaming, use `URLSession.bytes(for:)` async iterator. No SSE parser needed — Anthropic streaming is JSON-line deltas (`event: content_block_delta\ndata: {...}\n\n` is Anthropic's protocol but each `data:` is a JSON object, not Server-Sent Events with event IDs / retry semantics). If true SSE is ever needed, evaluate at that time.

### N.5 MCP SDK

**Wenshu existing:** NONE — no MCP integration.

**Candidates:**

| Candidate | Type | License | Stars | Last push | macOS | §11.1 verdict |
|---|---|---|---|---|---|---|
| `modelcontextprotocol/swift-sdk` | Official Swift SDK | Apache-2.0 | 500+ | 2026 | macOS 13+ | **PASS** — official, Anthropic-backed |
| `loopwork/iMCP` | macOS-only MCP server framework | MIT | ~200★ | 2026 | macOS 13+ | **PASS but rejected** — iMCP is a *server* SDK (expose macOS apps to MCP), not a *client* SDK (consume MCP tools). Wrong direction. |

**Recommendation:** Defer to v0.28+ (per inventory.json "MCP SDK (deferred)"). When v0.28+ adds MCP support, adopt `modelcontextprotocol/swift-sdk`.

### N.6 Logging pipeline

**Wenshu existing:** `NSLog` everywhere (8 files matched grep). No first-party `os.Logger`, no third-party `swift-log`.

**Candidates:**

| Candidate | Type | License | Stars | Last push | macOS | §11.1 verdict |
|---|---|---|---|---|---|---|
| **Apple first-party `os.Logger`** | Native | n/a | n/a | macOS 10.12+ | n/a | **N/A** — best option |
| `apple/swift-log` | Apple Logging API for Swift | Apache-2.0 | 800+ | 2026 | macOS 10.13+ | **PASS** — Apple-backed, `Logger` API matches `os.Logger` semantics with handler pluggability |
| `mikeash/Logging` | Third-party logging | MIT | ~20★ | 2024 | macOS 10+ | **REJECTED** — abandoned |

**Recommendation:** Adopt `apple/swift-log` (Package.swift dep). It uses `os.Logger` under the hood but provides `Logger` API in Swift with metadata + levels + handler pluggability. Replace `NSLog(...)` with `logger.info(...)` / `logger.error(...)` across 8 files. Optional (boss has not specified a logging requirement) — defer to v0.28+.

## Summary verdict

### Additions to `Package.swift` (third-party deps for non-agent surfaces)

| Dep | Version | Priority | Use | §11.1 verdict |
|---|---|---|---|---|
| `sindresorhus/KeyboardShortcuts` | latest (e.g. 2.2.0) | P1 | global shortcut binding | PASS |
| `apple/swift-log` | latest (e.g. 1.5.4) | P3 | logging pipeline | PASS |
| `theswiftguy/MenuBarExtraAccess` | latest | P2 (only if needed) | menu bar extra without focus steal | PASS |

### Verbatim port summary (no `Package.swift` change)

| Module | Hermes file(s) | Wenshu new file(s) | Est. LOC |
|---|---|---|---|
| M6-A Provider | `providers/base.py`, `agent/models_dev.py`, `agent/model_metadata.py` | `Core/Provider/ProviderProfile.swift`, `ModelsDev.swift`, `ModelMetadata.swift` + extend `ProviderFetcher.swift` + `WenshuVerifier.swift` | ~700-900 |
| M6-B Agent identity | `agent/prompt_builder.py`, `agent/system_prompt.py`, `agent/subagent_lifecycle.py`, `agent/onboarding.py`, `agent/agent_init.py` | `Core/Agent/WenshuSystemPromptBuilder.swift`, `SubagentLifecycleService.swift` (or extend `AsyncDelegation.swift`), `OnboardingHints.swift`, `MemoryContextScrubber.swift` + extend `WenshuAgentIdentity.swift` + extend `WenshuConductor.swift` | ~1200-1500 |
| M6-C Memory | `agent/memory_manager.py`, `agent/memory_provider.py` | new `Core/Memory/MemoryManager.swift` REPLACES existing (1393-LOC port) + new `Core/Memory/MemoryProvider.swift` | ~600-800 |
| M6-D Skills | `tools/skills_hub.py` (subset), `tools/skill_provenance.py`, `tools/skills_guard.py`, `tools/skill_linter.py`, `tools/skill_ledger.py`, `tools/skill_manager_tool.py` | new `Core/Skills/SkillSource.swift`, `HubStateDir.swift`, `SkillFrontmatterParser.swift`, `SkillProvenance.swift`, `SkillGuard.swift`, `SkillLinter.swift`, `SkillLedger.swift`, `SkillManager.swift` + extend existing `SkillRegistry.swift` + `SkillMeta.swift` | ~1200-1500 |
| M6-E Cron | `cron/jobs.py`, `cron/scheduler.py`, `cron/executions.py`, `cron/incidents.py`, `cron/monitor.py`, `cron/lifecycle_guard.py` | new `Core/Cron/CronjobStore.swift` (REPLACES existing actor), `CronScheduler.swift`, `CronScheduleCalculator.swift`, `CronExecution.swift`, `CronIncident.swift`, `CronMonitor.swift`, `CronLifecycleGuard.swift` + extend `CronPromptScanner.swift` | ~800-1000 |
| M6-F Backup | `hermes_cli/backup.py` (subset) | new `Core/Backup/ZipBackupEngine.swift`, `QuickSnapshot.swift` + extend existing `Backup.swift` | ~500-700 |
| M6-G Library lifecycle | NONE (wenshu-native) | 0 files | 0 |

**Total new Swift LOC: ~5000-6300 across ~25-30 new files + 6-8 file extensions.**

### Drops (per boss OOB — not surveying third-party for these)

| Surface | Reason | Hermes source dropped |
|---|---|---|
| Cloud memory providers (mem0 / honcho / hindsight / holographic / openviking / retaindb / supermemory / byterover) | boss 拍 "数据不出本机" | `plugins/memory/*` (~3000 LOC) |
| OAuth device-code / external flows (provider auth) | boss 拍 single-user macOS, no OAuth flow | `providers/base.py` `auth_type: oauth_*` |
| External credential backends (Bitwarden / 1Password / command / iron_proxy) | single-user Keychain only | `agent/secret_sources/*`, `agent/proxy_sources/*` (~400 LOC) |
| Plugin system | wenshu has no plugin system | `agent/agent_init.py` plugin loading, `gateway/control_socket.py`, `registration_lifecycle.py` (~1500 LOC) |
| Skill bundling / sync / commands | wenshu is single-user, no remote sync | `tools/skills_sync.py`, `tools/skills_sync_client.py`, `tools/skill_commands.py`, `tools/skill_preprocessing.py`, `tools/skill_bundles.py` (~700 LOC) |
| Cron LLM tool (cronjob_tools.py) | boss 拍 "用户不可通过聊天改系统" | `tools/cronjob_tools.py` (1871 LOC) |
| Cron notepad / blueprints / suggestions | boss 拍 cron is user-scheduled | `cron/notepad.py`, `cron/blueprint_catalog.py`, `cron/suggestion_catalog.py`, `cron/suggestions.py` (~500 LOC) |
| OTLP exporter / monitoring | wenshu has no OTLP | `agent/monitoring/*` (~600 LOC) |
| Multi-profile cron isolation | single-app | `cron/jobs.py` per-profile scoping |
| Cross-process file locking (cron) | single-process | `cron/jobs.py` fcntl/msvcrt |

**Total drops: ~10,500 LOC of hermes Python — purely for "boss拍 wenshu is single-user / local-only / no-plugin / no-chat-system-mod" reasons, NOT for any hermes-vs-wenshu technical gap.**

### NEW surfaces in hermes since 2026-08-23 audit (per boss requirement to flag)

Verified by re-reading `subagent_lifecycle.py` (the file that has grown most since the 2026-08-23 audit Gap 10) and comparing against wenshu v0.23 SubAgentIdentity + AsyncDelegation:

1. **Char/byte caps on subagent inputs** (`_MAX_GOAL_CHARS=16_000`, `_MAX_CONTEXT_CHARS=32_000`, `_MAX_METADATA_BYTES=8_192`, `_MAX_RESULT_CHARS=32_000`) — wenshu `WenshuConductor.handle()` line 244-250 truncates result to 200 chars but no cap on goal/context. **RECOMMEND** adding 4 static caps to `SubagentIdentity.systemPrompt` callsite.
2. **`reconnect(handle:)`** — wenshu has no restart-survival for sub-agents (SubAgentRun stored in SQLite but no way to reconnect after app restart mid-task). **RECOMMEND** deferred to v0.28+ (low priority).
3. **9-state `SubagentState` enum** — wenshu has 4-state `SubAgentRunStatus` (running/done/failed). Add `INTERRUPTED / CANCEL_REQUESTED / CANCELLED / PENDING / STARTING / UNKNOWN`. **RECOMMEND** small ticket.
4. **`StreamingContextScrubber` for memory context blocks** — wenshu doesn't have streaming LLM yet, so no scrubber. **RECOMMEND** defer until streaming is added.
5. **Daemons thread pool with `_DaemonExecutor(max_workers=8)`** — wenshu uses Swift `withTaskGroup` (cooperative). For 5 sub-agents max, no urgency.

**Verdict:** Items 1, 3 = small follow-up tickets (no separate module). Items 2, 4, 5 = restart-survival / streaming-related (defer to v0.28+).

## Implementation order (recommended)

1. **M6-F Backup** (smallest scope, 1 ticket) — ZIP engine + SQLite-aware backup replaces current directory-copy bug.
2. **M6-C Memory** (replace existing 1-file with 1393-LOC port) — largest single-file port but well-bounded.
3. **M6-D Skills** (8 new files, ~1300 LOC) — modular, low-risk.
4. **M6-A Provider** (~700 LOC, declarative profile refactor) — touches most callers but additive.
5. **M6-E Cron** (file-backed actor replaces in-memory, new scheduler) — adds real cron support.
6. **M6-B Agent identity** (largest scope, ~1500 LOC across 4 new files + 2 extensions) — most architectural impact.

## Pollution defense note

The verbatim ports touch `WenshuAgentIdentity.systemPrompt` + `WenshuConductor.handle()` directly. Per `wenshu-pollution-defense` skill (Layer 1 hex encoding):
- All references to the 12 forbidden tokens in ported system prompts MUST use `forbiddenTokensHex` (already done in v0.28).
- New `WenshuSystemPromptBuilder` MUST NOT enumerate the literal tokens in source — keep the hex layer intact.
- `WenshuAgentIdentity.swift` change must NOT add any new /// comment containing the literal tokens.

## Risks

1. **M6-C Memory Manager port size** — 1393-LOC verbatim port. Big-bang port risk. Mitigation: port in 2 phases: (a) MemoryProvider protocol + addProvider interface, (b) prefetch/sync/streaming scrubber.
2. **M6-D Skill YAML parser** — full YAML parser replaces hand-rolled. Risk: existing skills have non-standard frontmatter. Mitigation: add fallback to old hand-rolled parser if YAML parser fails.
3. **M6-E Cron croniter port** — no Swift croniter exists. Risk: porting croniter 400-LOC parser adds scope. Mitigation: implement 5-field cron parser by hand (well-trodden, ~200 LOC), document fallback to croniter-Python interop if needed (not a path boss拍).
4. **M6-A ProviderProfile backfill** — 11 existing providers need to be migrated to new `ProviderProfile` struct. Risk: behavior changes (e.g. `apiMode` rename). Mitigation: keep `Provider.slug` + `Provider.defaultBaseURL` as legacy fields for backwards compat, mark deprecated.
5. **M6-F ZIP engine switch** — current wenshu backup does `FileManager.copyItem` (directory copy). Switching to ZIP changes the on-disk format. Existing users (if any) would need migration. Mitigation: dual-write during migration period (write both `.zip` AND legacy directory copy), with preference for `.zip` on restore.

---

*Spec v0.1 · 2026-08-28 pocock · project root = `/Volumes/ANAN/Engineering/wenshu/` · hermes source = `/Volumes/ANAN/.hermes/hermes-agent/`*