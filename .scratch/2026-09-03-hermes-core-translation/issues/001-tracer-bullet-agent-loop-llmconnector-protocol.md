# 001: Tracer-bullet — agent loop skeleton + LLMConnector protocol + 1 connector (minimax) + 2 stub tools

**What to build:** Port the minimum end-to-end agent slice from hermes `agent/conversation_loop.py` (5312 LOC → ~4,000 Swift target, TB-B scope). Establish the `LLMConnector` protocol that all later connector ports will conform to. Wire one P0 connector (minimax cn via Anthropic-compatible protocol). Wire 2 stub tools (`ReadFileTool` + `WriteFileTool`) so the tool executor end-to-end runs. After this ticket lands, wenshu can run a 3-turn conversation that reads a file from the user's `.ws` library, summarizes it via LLM, and writes the summary back. Goal = establish the Swift concurrency patterns + protocol shapes that every later ticket follows.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

## Source files surveyed (= what this ticket ports)

| Path | LOC | What ports |
|---|---|---|
| `agent/conversation_loop.py` | 5,312 | Full port = the whole agent turn loop |
| `agent/tool_executor.py` | 1,646 | Full port = single tool-call dispatch + classification |
| `agent/turn_context.py` | ~700 | Full port = per-turn state bundle |
| `agent/turn_finalizer.py` | ~600 | Full port = turn-end normalization |
| `agent/turn_retry_state.py` | ~400 | Full port = retry budget per turn |
| `agent/message_sanitization.py` | ~300 | Full port = strip control chars |
| `agent/message_content.py` | ~400 | Full port = content-block canonicalization |
| `agent/tool_dispatch_helpers.py` | ~600 | Full port = tool dispatch pre/post hooks |
| `agent/tool_result_classification.py` | ~400 | Full port = tool result classification |

Plus thin Wenshu-side authoring of 2 stub tools (`ReadFileTool.swift`, `WriteFileTool.swift`).

## UI-affordance mapping (per spec §6.4)

This ticket's translated products and their UI landing:

| Translated product | UI landing | Tier | Rationale |
|---|---|---|---|
| ConversationLoop | (underwater) | 🟦 | engine, user does not directly operate |
| ToolExecutor + 2 stub tools | ChatView shows tool_use row | 🟨 | visible in chat as "🔧 read X" line; no separate panel needed |
| LLMConnector protocol | (underwater) | 🟦 | protocol layer, no direct UI |
| minimax connector (P0) | Settings → LLM Connector | 🟥 | user must pick + supply key |

**3-question check** (per spec §6.4):

1. **Who triggers it?** Chat user types a message in `ChatView.swift`; system invokes `ConversationLoop.runTurn()`. User picks connector profile in Settings.
2. **What signal does the user see?** Streaming text appears in chat; tool_use line ("🔧 read X") appears mid-stream when tool is invoked; if Settings → LLM Connector pane is open, user sees minimax profile row.
3. **UI affordances added**: ChatView extension to render `tool_use` content blocks (= 🟨); Settings弹窗 new "LLM Connector" view introduced (full UI in ticket 006, but the minimax row needs to render here for `ConnectorTestButton` to work).

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Agent/Conversation/ConversationLoop.swift` exists, ports `conversation_loop.py` L1-L1200 (the entry + turn loop skeleton)
- [ ] `Sources/WenshuApp/Core/Agent/Conversation/TurnContext.swift` ports `turn_context.py` 1:1 with `// SWIFT-PORT:` markers
- [ ] `Sources/WenshuApp/Core/Agent/Conversation/TurnFinalizer.swift` + `TurnRetryState.swift` + `MessageSanitization.swift` + `MessageContent.swift` port their Python counterparts
- [ ] `Sources/WenshuApp/Core/Agent/Tool/ToolExecutor.swift` ports `tool_executor.py`
- [ ] `Sources/WenshuApp/Core/Agent/Tool/ToolDispatchHelpers.swift` + `ToolResultClassification.swift` port their Python counterparts
- [ ] `Sources/WenshuApp/Core/Agent/Tool/ReadFileTool.swift` + `WriteFileTool.swift` authored (wenshu-side, not hermes port). Sandbox = inside `.ws` library root only.
- [ ] `Sources/WenshuApp/Core/Agent/Connector/LLMConnector.swift` protocol defined (= public façade; all 7 connectors will conform in later tickets)
- [ ] `Sources/WenshuApp/Core/Agent/Connector/MinimaxConnector.swift` implements LLMConnector for minimax cn (= minimax cn = Anthropic-compatible protocol per AGENTS.md §11.2; MinimaxConnector is a thin Anthropic-compatible wrapper, NOT routed via OpenAI-compatible path). [2026-09-03 boss拍 reconciliation: minimax cn actual wire format = Anthropic-compatible (x-api-key header + anthropic-version + content array union), so the dedicated MinimaxConnector is the canonical implementation. OpenAICompatibleConnector covers minimax-cn-overlapping-but-not-equal providers (DeepSeek / Ollama / OpenRouter) instead.]
- [ ] `Sources/WenshuApp/Core/Agent/Connector/ConnectorCredentials.swift` defines credential struct + keychain resolution (= minimal version; full credential pool comes in issue 006)
- [ ] Existing `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift` L282-339 (current LLM call site) is rewired to invoke the new `LLMConnector` instead of direct URLSession
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] Manual e2e: open wenshu, run 3-turn conversation: "read book.md" → "summarize the protagonist in 3 sentences" → "write the summary to summary.md". All 3 turns complete, file written.
- [ ] Z contract test: golden file `Tests/WenshuAppTests/Agent/PortedFromHermes/golden/conversation_loop_minimal_3turn.json` matches Swift output (run `scripts/generate_golden.py` against hermes Python first)
- [ ] X e2e dual-track: same 3-turn prompt against hermes Python and wenshu Swift — identical tool-call sequence + identical final text + identical file write result

## Iron rules applied (= check before commit)

- [ ] Rule 1: git grep BEFORE patch — confirm zero callers of any symbol you delete
- [ ] Rule 6: layout/spacing uses DesignTokens (= no magic numbers)
- [ ] Rule 7: Button + system buttonStyle (= no custom-drawn icons, Lucide only)
- [ ] Rule 8: stays inside WindowGroup scene tree (= no new NSWindow)
- [ ] Rule 11: state persistence via @AppStorage / @SceneStorage
- [ ] wenshu-apple-api-first: grep Apple HIG first, write ZERO custom code if built-in covers it
- [ ] AGENTS.md §11.1: use pinned deps only — NO add new deps
- [ ] AGENTS.md hard rule: English-only commit body + new comments; "老板" sole address
- [ ] Direct port style: keep function names + variable names from hermes Python; mark every non-1:1 Swift idiom adjustment with `// SWIFT-PORT: <reason>`
- [ ] Swift Concurrency only — `actor` + `AsyncStream` + `withTaskGroup` for what hermes does with asyncio
- [ ] Protocol-first: every ported module exposes a Swift protocol, default impl = direct translation, other connectors can conform later

## Estimated LOC

~4,500 Swift LOC (4,000 from port + 500 from 2 stub tools + LLMConnector protocol authoring).

## Out of scope (= later tickets)

- `prompt_caching.py` cache control — issue 002
- `system_prompt.py` byte-stable tier — issue 002
- `context_compressor.py` + `conversation_compression.py` — issue 003
- `context_engine.py` — issue 003
- `prompt_builder.py` — issue 002 (after cache layer lands)
- Anthropic native connector — issue 004
- OpenAI connector — issue 005
- DeepSeek / Gemini / Ollama — issue 007
- OpenRouter — issue 008
- Credential pool + Settings UI — issue 006
- Memory subsystem — issue 009
- Skill subsystem — issue 010

## Commit format

`feat(wenshu): v0.35 -- tracer-bullet agent loop + LLMConnector protocol (= ticket 001 of 11)`