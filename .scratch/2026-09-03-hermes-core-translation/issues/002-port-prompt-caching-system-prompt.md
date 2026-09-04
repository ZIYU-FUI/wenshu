# 002: Port prompt_caching + system_prompt + cache-stable invariants

**What to build:** Port hermes `agent/prompt_caching.py` (119 LOC) and `agent/system_prompt.py` (536 LOC). Wire the cache-stable invariant that hermes AGENTS.md declares sacred: "system prompt byte-stable for life of a conversation". Implement `PromptCaching.applyCacheControl(messages:layout:)` Swift function with the 4-breakpoint layout (system_and_3). Wire Anthropic cache_control markers on tools + content parts + assistant last block + tool_result. Strip markers only from thinking/redacted_thinking blocks. This ticket introduces the `// SWIFT-PORT:` comment style that every later ported module follows.

**Blocked by:** 001 (LLMConnector protocol must exist so cache markers can be applied to outgoing requests)

**Status:** blocked

## Source files surveyed

| Path | LOC | What ports |
|---|---|---|
| `agent/prompt_caching.py` | 119 | Full port = `apply_anthropic_cache_control` function (4 breakpoints) |
| `agent/system_prompt.py` | 536 | Full port = stable tier builder |

Plus partial port of `agent/prompt_builder.py` (1,971 LOC) = only the cache-stable tier composition (the dynamic tier waits for issue 003 context engine).

## UI-affordance mapping (per spec §6.4)

All translated products in this ticket are 🟦 **underwater** (no direct UI). Per spec §6.4: no UI affordance required.

| Translated product | UI landing | Tier | Rationale |
|---|---|---|---|
| PromptCaching | (underwater) | 🟦 | engine-internal; only user-visible signal = Anthropic token billing drop, displayed in model metadata (= ticket 008) |
| SystemPrompt | (underwater) | 🟦 | hardcoded, user does not operate |

**3-question check** (per spec §6.4): cache control runs inside `LLMConnector.send()` before outgoing API call. User signal = Anthropic billing drop; user does not interact with caching directly. No UI affordance needed in this ticket.

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Agent/Conversation/PromptCaching.swift` ports `prompt_caching.py` 1:1 with `// SWIFT-PORT:` markers on every non-trivial Swift adjustment
- [ ] `Sources/WenshuApp/Core/Agent/Conversation/SystemPrompt.swift` ports `system_prompt.py` 1:1
- [ ] `PromptCaching.applyCacheControl(messages:layout:)` exists with 4 breakpoints: `system_and_3` (Anthropic standard)
- [ ] Cache marker preserved on: tools (passed to LLMConnector), content parts, assistant last block, tool_result
- [ ] Cache marker stripped from: `thinking` blocks, `redacted_thinking` blocks
- [ ] `LLMConnector.send(messages:)` (from issue 001) integrates cache marker injection before outgoing API call
- [ ] `swift build` exit 0; `swift test` exit 0
- [ ] **Cache-stability e2e test**: 50-turn conversation against Anthropic connector; assert system-prompt bytes are byte-identical across all 50 turns (test name `test_cache_byte_stability_50turns`)
- [ ] Z contract test: golden file `golden/prompt_caching_system_and_3.json` matches Swift output

## Iron rules applied

- [ ] Direct port with `// SWIFT-PORT:` markers
- [ ] `prompt_caching.py` is 119 LOC of pure functions — port must be ~80 Swift LOC (idiomatic Swift can be tighter)
- [ ] Cache-stable invariant = project-level hard rule (per hermes AGENTS.md "Per-conversation prompt caching is sacred"). Any change that mutates past context invalidates cache. Mark this as a `/// Cache-stable. Do NOT mutate after turn 1.` doc-comment on every public function in this module.

## Estimated LOC

~500 Swift LOC (PromptCaching.swift ~80, SystemPrompt.swift ~400, partial PromptBuilder ~50).

## Commit format

`feat(wenshu): v0.35 -- port prompt caching + cache-stable system prompt (= ticket 002 of 11)`