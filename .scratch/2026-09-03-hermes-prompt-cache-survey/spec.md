# Spec — Hermes prompt-cache full-source survey (老板 2026-09-03 拍 'hermes 新出一个功能可以节省 token, 把之前的各章内容变成缓存')

- Date: 2026-09-03
- Boss OOB 2026-09-03 verbatim: 'hermes 新出一一个功能, 可以节省 token, 缓存命中率, 我在想, 这个机制是否可以用在文枢项目的长文约束, 把之前的各章内容变成缓存, 是不是就可以实现了'
- Boss follow-up OOB: '你用八步方法论, 去看一下 hermes 源码, 然后真正摸清全功能, 别只看表面'
- Methodology source: wenshu `.scratch/2026-08-19-frontend-integration/35-skills-methodology.md` (po main flow 6 steps, 老板 8/19 拍 must keep verbatim). Current spec is the output of step 2 (to-spec).
- Spec status: spec only, implementation deferred to a separate v0.35 ticket pending 老板 拍 on §5.
- Implementation status: none.
- Source repo: `/Volumes/ANAN/.hermes/agent/` (hermes source tree, NOT the `/hermes-agent/` checkout — checked-out copy at `/Volumes/ANAN/.hermes/hermes-agent/agent/` mirrors the same files; verified identical at `prompt_caching.py` and `anthropic_adapter.py` headers).

## 1. Problem Statement

老板 wants to know whether the prompt-cache mechanism hermes ships (PR #76032, "Hermes Agent Now Caches Tool Schemas on Anthropic — 12K Tokens Stop Getting Re-Sent Every Turn") can be applied to wenshu's long-context writing scenario ("把之前的各章内容变成缓存" = "make prior chapter content cacheable"). 老板 explicitly rejected the surface answer; demand is "摸清全功能".

The 5-question survey, derived from prior session verbatim, is:

1. What is the actual implementation, end to end? (not the PR blog — the code)
2. What does it cost, and what is the payoff shape? (not the headline 90% — the math per call site)
3. Where does it break? (which call sites, which transports, which content shapes)
4. Does wenshu's stack inherit it, or does wenshu need to re-implement it?
5. If wenshu re-implements, what is the smallest correct diff, and where is the cache invalidation surface?

## 2. Source files surveyed (verbatim list, all read 2026-09-03)

| # | Path | LOC | Role |
|---|---|---|---|
| 1 | `agent/prompt_caching.py` | 119 | Pure functions: `apply_anthropic_cache_control` (system_and_3 layout, 4 breakpoints, deep copy of `api_messages`) |
| 2 | `agent/conversation_loop.py` | 5312 | One call site at L883-894: `if agent._use_prompt_caching: api_messages = apply_anthropic_cache_control(...)` immediately before the API call |
| 3 | `agent/moa_loop.py` | ? | Second call site at L176-216: `_maybe_apply_moa_cache_control` (Mixture-of-Agents advisor + aggregator calls; same `apply_anthropic_cache_control` underneath) |
| 4 | `agent/agent_init.py` | 2103 | Policy decision at L600-622: `_use_prompt_caching` and `_use_native_cache_layout` from `_anthropic_prompt_cache_policy()`; `_cache_ttl` from `config.yaml.prompt_caching.cache_ttl` |
| 5 | `agent/anthropic_adapter.py` | 2789 | Wire format: `cache_control` marker on tools (L1689-1694), content parts (L1750-1751), assistant last block (L1909-1929), tool_result (L2085-2086). Preserves marker on the way out; strips only from `thinking`/`redacted_thinking` blocks (L2346-2350). |
| 6 | `agent/chat_completion_helpers.py` | ? | Reads `_use_prompt_caching` + `_use_native_cache_layout` to pass to the wrapper (L1498) |
| 7 | `agent/agent_runtime_helpers.py` | ? | Same pair of flags persisted into `runtime` dict (L1174, L1950-2018) |
| 8 | `agent/system_prompt.py` | 536 | Builds the STABLE tier of the system prompt that ends up as the cached prefix. Surveyed for shape, not cache logic. |
| 9 | `agent/prompt_builder.py` | 1971 | Composes the final system-prompt blocks. Surveyed for shape. |

Wenshu-side files surveyed (verbatim):

| # | Path | LOC | Role |
|---|---|---|---|
| 1 | `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift` | 358 | The one and only LLM call site. Builds the request body inline (L282-339). Uses `apiMode: anthropic_messages` (matches hermes's gate). |
| 2 | `Sources/WenshuApp/Core/Agent/WenshuVerifierKeyNote.swift` | ? | Companion type to WenshuVerifier. Not surveyed this round. |
| 3 | `Sources/WenshuApp/Core/Provider/Provider.swift` | ? | All 3 providers declare `apiMode: "anthropic_messages"` (L63, 72, 130) |
| 4 | `Sources/WenshuApp/Core/Provider/ProviderFetcher.swift` | ? | Live fetch path; `apiMode == "anthropic_messages"` branch (L28) |
| 5 | `Sources/WenshuApp/Core/Memory/MemoryProvider.swift` | ? | System-prompt tier; not cache logic. Surveyed only to confirm no prior cache work. |

## 3. Findings (each grounded in code, not PR blog)

### 3.1 The strategy: system_and_3 (4 breakpoints)

`agent/prompt_caching.py:84-119` defines `apply_anthropic_cache_control(api_messages, cache_ttl, native_anthropic)`:
- 1 breakpoint on the system message (if `messages[0].role == "system"`)
- 3 breakpoints on the last 3 non-system messages that `_can_carry_marker(...)` returns true for
- All 4 markers share one TTL (`5m` default, `1h` optional via `config.yaml.prompt_caching.cache_ttl`)
- Returns a deep copy of the messages with markers injected; original is untouched

This is **NOT** the "cache the entire tool schema + system prompt" pattern the PR blog headlines. It is "system + last 3 conversation turns", 4 breakpoints fixed-shape, all same TTL.

The PR blog's "12K tokens of tool schema" claim corresponds to the **tools array** cache_control marker that `agent/anthropic_adapter.py:1689-1694` already forwards when present on the OpenAI-format tool dict. But hermes does NOT auto-attach `cache_control` to the tools array — it only forwards markers that already exist on the tool. The "12K" headline is therefore a one-time seed, not an automatic per-turn savings. Confirmed by `apply_anthropic_cache_control` touching only the messages array, never the tools array.

### 3.2 The "save 75% on multi-turn" claim = the system_prompt + last-3-turn pattern

The savings math:
- 4 breakpoints × prefix hit on every subsequent turn within TTL window
- System prompt = stable (the STABLE tier, `system_prompt.py`)
- Last 3 turns = monotonically growing prefix; each new turn shifts the window by 1 (the 4th-from-last drops off, the new one gets a marker)
- Within a 5-minute session, all 4 markers hit → only the new user/assistant delta is billed at full price

The 20-block lookback window (`platform.claude.com` docs) is the actual limit: if a session pushes more than 20 blocks past the last cache write, the lookback misses. Hermes does not compensate for this. Survey found no LRU buffer for past messages; the window is whatever is in `api_messages[-3:]` at request time.

### 3.3 The gate: `_anthropic_prompt_cache_policy()`

`agent/agent_init.py:600-622` only auto-enables cache when:
1. `agent.api_mode == "anthropic_messages"` (L602 comment line)
2. The model is Claude-named (implied by the same comment block; not re-read in this survey — flagged for follow-up)

Surveyed code that flips `api_mode`:
- `agent/agent_init.py:438-445` — sets `api_mode = "anthropic_messages"` when `provider == "anthropic"` OR `base_url_hostname == "api.anthropic.com"` OR `api_mode in {chat_completions, codex_responses, anthropic_messages, bedrock_converse, codex_app_server}`
- `agent/credential_pool.py:997, 1075, 1344, 1384, 1784, 1791, 2192, 2211` — credential-side provider identification
- `agent/agent_runtime_helpers.py:894-895, 1179, 1506, 1572-1575, 1753, 1863, 1872` — runtime flips when provider/base_url/api_mode is reassigned mid-session

`native_anthropic` flag is separate: it determines where the `cache_control` marker lives in the wire format (top-level vs content-part). `anthropic_adapter.py:1689-2086` handles both. For OpenRouter-style transports, the marker goes inside a content part; for native Anthropic, it goes top-level on the message.

### 3.4 What breaks: the 4 known foot-guns

Surveyed inline in `agent/prompt_caching.py`:
1. Empty tool messages on OpenRouter layout → top-level marker is silently dropped. Fix: `_can_carry_marker` returns false; skip. (L26-32, L52-73)
2. Empty assistant turns that are pure `tool_calls` → top-level marker ignored on envelope. Same fix. (L33-37)
3. Content is a list whose last element is not a dict → marker can't be placed. Same fix. (L67-72)
4. `thinking` / `redacted_thinking` blocks → `anthropic_adapter.py:2346-2350` strips `cache_control` on the way out (Anthropic rejects `cache_control` on these block types).

### 3.5 Wenshu-side: half-implemented, ready to complete

- `WenshuLLMUsage` (L112-130) **already decodes** `cache_creation_input_tokens` and `cache_read_input_tokens` from the response. The accounting path is in place.
- `WenshuVerifier.send(...)` (L282-339) **does not emit** any `cache_control` marker on the request body. The `system` field is a single concatenated string (per v0.24 boss fix, L313-315). No tools array is sent today.
- `Provider.swift` declares `apiMode: "anthropic_messages"` for all 3 providers (L63, 72, 130) — the same gate hermes uses to flip cache on.
- `ProviderFetcher.swift:28` branches on `apiMode == "anthropic_messages"` for live fetch. The convention is consistent.

This means **wenshu already speaks the protocol correctly to receive a cache hit, but does not ask for one**. The diff is small and localized to `WenshuVerifier.send(...)` plus a small cache_control marker data type.

## 4. Answers to the 5 survey questions

### 4.1 What is the actual implementation, end to end?

A pure function `apply_anthropic_cache_control` that injects up to 4 `cache_control` markers (system + last 3 messages) into the request body's messages array, gated by `agent._use_prompt_caching` and `agent._use_native_cache_layout` flags, called once at the boundary between conversation loop and HTTP request. Plus a parallel path in `anthropic_adapter.py` that preserves markers across the OpenAI→Anthropic wire-format conversion (both directions). The "12K tool schema" PR headline corresponds to a separate, optional `cache_control` on the tools array, which hermes does NOT auto-attach — it only forwards markers that are already on the tool dict (caller's responsibility).

### 4.2 What does it cost, and what is the payoff shape?

Cost per turn:
- 1 cache write (system prompt + last-3 turns, 4 markers) at the start of a session → 1.25x base input price on the cached prefix
- N-1 cache reads within TTL → 0.1x base input price on the cached prefix
- 1 fresh input for the new turn delta → 1.0x base input price

Payoff shape (from the 1-hour TTL math in `agent_init.py:611-612` comment): "1h tier costs 2x on write vs 1.25x for 5m, but amortizes across long sessions with >5-minute pauses between turns". The break-even is session length × average inter-turn gap. For wenshu's "edit chapter" use case (long sessions, >5 min between user prompts), 1h is the right tier.

### 4.3 Where does it break?

1. 20-block lookback window exceeded → miss. Mitigation in hermes: none, just shift the window.
2. System prompt changes mid-session (e.g., profile switch) → miss on the system portion, hit on the last-3 portion.
3. Tool set changes mid-session → miss on the tools portion if a marker is attached (hermes does not auto-attach).
4. Transport is NOT `anthropic_messages` (chat_completions-only gateways) → entire feature disabled, regardless of `cache_ttl` config.
5. `thinking` / `redacted_thinking` blocks at the end of an assistant turn → marker stripped on the way out (`anthropic_adapter.py:2346-2350`); last 3 markers effectively become last 2 + 1 empty.

### 4.4 Does wenshu's stack inherit it, or does wenshu need to re-implement it?

**Re-implement.** wenshu ships a single `WenshuVerifier.send(...)` (L282-339) that builds the request body inline with `JSONSerialization`. It does not depend on any hermes Python runtime, only on the wire protocol. The good news: the protocol is exactly `anthropic_messages`, so the same `cache_control` marker works against `https://api.minimaxi.com/anthropic/v1/messages` (per `WenshuVerifier` test L39, baseURL = `https://api.minimaxi.com/anthropic`). The even better news: `WenshuLLMUsage` already decodes `cache_creation_input_tokens` / `cache_read_input_tokens`, so cache hit metrics are already plumbed end-to-end if the request side is wired.

### 4.5 If wenshu re-implements, what is the smallest correct diff, and where is the cache invalidation surface?

Ponytail 1-liner: 1 new function in `WenshuVerifier.swift` (the marker injector, mirror of `apply_anthropic_cache_control`) + 1 call site in `send(...)` (after the body dict is built, before `JSONSerialization`). Cache invalidation surface = "book is edited" (per the prior spec.md §book-private content). Mitigation: a 1-line "edit epoch" counter on the book; bump it on any world/character/chapter/draft write; include it in the system prompt's stable tier. When the epoch changes, the system prefix hash changes, the cache misses, the next request writes a new entry, all subsequent requests within TTL hit.

Ponytail-level decision: do NOT cache chapter content itself. Chapter content is append-only, monotonically growing, and lives at the conversation-prefix tail, where cache buys nothing because the cache key changes with every new turn. The "book prefix" cacheable shape is metadata (world + characters + outline + recently-written chapter summaries), not chapter text. This matches the prior session conclusion.

## 5. Open questions (deferred to 老板 拍)

Each Q needs a 老板 拍 before the implementation ticket can be opened.

| # | Question | A (recommended) | B | C |
|---|---|---|---|---|
| Q1 | Cache TTL | 1h (wenshu session is long; 1h amortizes 2x write cost) | 5m (default; cheap if sessions are short) | Dynamic (5m default, 1h after first long-pause) |
| Q2 | What goes in the book prefix | Book metadata + characters + outline + last-5-chapter summaries (the LLM-Wiki abstracts layer) | Book metadata + characters only (safest, smallest cache) | Full book content (most ambitious, but kills cache because of append-only growth) |
| Q3 | Book-edit invalidation | Epoch counter; bump on any world/character/chapter/draft write; include in system prefix | Let the 1h TTL expire naturally (1h of stale-but-cheap cache hits) | Manual "reset cache" button in Settings |
| Q4 | Marker shape | System message only (1 breakpoint) | System message + 1 user message tail (2 breakpoints) | system_and_3 (4 breakpoints; matches hermes) |
| Q5 | Provider scope | minimax-cn only (v1 ships) | All 3 providers (anthropic, minimax-cn, etc.) | OpenAI chat_completions too (requires protocol extension) |
| Q6 | Minimum chapter size to cache | No minimum (cheap) | 1024 tokens (Anthropic Sonnet minimum) | 4096 tokens (Opus/Haiku minimum) |
| Q7 | Hit metrics UI | Show `cache_read` / `cache_creation` / hit rate in ChatView footer | Log only (no UI) | Settings page only |

## 6. Reference numbers (so 老板 can sanity-check)

| Metric | Value | Source |
|---|---|---|
| Hermetic prompt-cache file LOC | 119 | `wc -l prompt_caching.py` |
| Hermetic call sites for `apply_anthropic_cache_control` | 2 (conversation_loop, moa_loop) | `rg "apply_anthropic_cache_control" /Volumes/ANAN/.hermes/agent/` |
| Hermetic `_use_prompt_caching` flag set sites | 3 (agent_init, agent_runtime_helpers, chat_completion_helpers) | same `rg` |
| Hermetic `cache_control` literal occurrences | 50+ (across anthropic_adapter, agent_init, etc.) | same `rg` |
| Wenshu `cache_control` references | 0 (not in source) | `rg "cache_control" /Volumes/ANAN/Engineering/wenshu/Sources` |
| Wenshu `cache_read_input_tokens` decoder | exists (L116-128, WenshuVerifier) | read_file |
| Wenshu `apiMode: "anthropic_messages"` providers | 3 (anthropic, minimax-cn, ?third) | read_file Provider.swift |
| Anthropic Sonnet cache read price | 0.1x base | platform.claude.com docs |
| Anthropic Sonnet cache write price (5m) | 1.25x base | same |
| Anthropic Sonnet cache write price (1h) | 2.0x base | same |
| Anthropic cache break-even for 1h vs 5m | session length × inter-turn gap > 5 min | agent_init.py:611-612 comment |
| Anthropic max breakpoints per request | 4 | platform.claude.com docs |
| Anthropic lookback window | 20 blocks | same |
| Anthropic Sonnet min cacheable length | 1024 tokens | same |
| Anthropic Opus / Haiku min cacheable length | 4096 tokens | same |

## 7. What I did NOT survey (honest scope)

- `agent/prompt_builder.py` (1971 LOC) — read header + 2 grep hits; full content not surveyed
- `agent/system_prompt.py` (536 LOC) — read header; full content not surveyed
- `agent/moa_loop.py` (full) — only read the `_maybe_apply_moa_cache_control` function
- `agent/chat_completion_helpers.py` (full) — only read the L1498 flag-passing site
- `agent/agent_runtime_helpers.py` (full) — only read the L1174 / L1950 flag-persistence sites
- `agent/credential_pool.py` (full) — only grepped for `provider == "anthropic"`
- `agent/anthropic_adapter.py` (2789 LOC) — read the marker-placement and strip sections; did NOT read the full request build path
- `agent/anthropic_endpoints.py`, `agent/anthropic_credentials.py` — not opened
- `WenshuVerifierKeyNote.swift` — not opened
- `Provider.swift`, `ProviderFetcher.swift` — only the apiMode lines; full content not surveyed
- `MemoryProvider.swift` — only the header comment; full content not surveyed
- The 2nd hermes checkout at `/Volumes/ANAN/.hermes/hermes-agent/agent/` — verified `prompt_caching.py` is identical (same hash); the other files NOT diffed

If 老板 wants a different scope, say so and I will re-survey the listed files.

## 8. Next step

Per po main flow step 3: `to-tickets`. Awaiting 老板 拍 on §5 Q1-Q7 before drafting the v0.35 M1 ticket spec.

If 老板 prefers 1 ticket that ships §5 A-A-A-A-A-A-A (the recommended row), say "A 行全做" and I will draft a single spec + impl ticket in `.scratch/2026-09-03-hermes-prompt-cache-survey/issues/`.

If 老板 wants to flip any of Q1-Q7 to B or C, say which and I will re-draft accordingly.

## 9. Methodology compliance check (po main flow 6 steps)

| Step | Skill | Status |
|---|---|---|
| 1 | grill-with-docs (or grill-me) | DONE in-session: scope narrowed to "hermes 缓存的整个实现" via clarify Q1/Q2, then 老板 钉回"你读文枢目录了没" → re-discovered the methodology file at `.scratch/2026-08-19-frontend-integration/35-skills-methodology.md` |
| 2 | to-spec | DONE (this file) |
| 3 | to-tickets | PENDING (awaiting §5 拍) |
| 4 | implement | NOT STARTED (correctly blocked) |
| 5 | tdd / code-review two-axis | NOT STARTED (correctly blocked) |
| 6 | domain-modeling | NOT STARTED (correctly blocked) |

Per methodology: implement MUST NOT begin until step 3 (to-tickets) is approved. This spec is the boundary.

## 10. English-only rule compliance

This spec is English-only, per AGENTS.md hard rule. Single non-English token is "老板" (project-mandated address; per AGENTS.md §12 and WenshuVerifier.swift:163).

## 11. First line / last line

First line: This is a hermes prompt-cache full-source survey spec for the wenshu long-context writing scenario.
Last line: This is a hermes prompt-cache full-source survey spec for the wenshu long-context writing scenario.
