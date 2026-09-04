# ADR-0012: hermes-core-translation Scope B (= full non-frontend + agent core)

> Status: accepted
> Date: 2026-09-03
> Decision-maker(s): 老板 (Q1 of grilling round 1, 拍板)

## Context

Hermes-agent (Python) is a 93,837 LOC, 116-file codebase covering 8 major subsystems:
1. Agent core (loop, tools, memory, skills, context) — ~20,000 LOC
2. LLM connectors (anthropic, openai, gemini, deepseek, ollama, openrouter, minimax) — ~15,000 LOC
3. Prompt caching + system prompt — ~700 LOC
4. Context compression + conversation compression — ~4,500 LOC
5. Auxiliary client (multi-model orchestration) — ~7,500 LOC
6. Frontends: Electron desktop / TUI / web dashboard / iOS / Android — ~30,000 LOC
7. Messaging platform integrations (20+ channels: Telegram / Discord / Slack / iMessage / etc.) — ~10,000 LOC
8. Peripheral: LSP / browser tool / pet avatar / scheduler / etc. — ~5,000 LOC

The v0.35 project (= hermes-core-translation) ports subsets of hermes to Swift for wenshu's agent subsystem. Boss Q1 of grilling round 1 set the scope: "hermes 核心 agent 相关的所有, 几个前端, 消息平台不包括, 其它的在我看来应该是全都需要的". Boss added: "如果你觉的文枢用不到的, 你可以罗列, 然后告诉我这是做什么的, 我来判断是不是真的非必要".

Three concrete concerns force the decision:

1. **Scope lock-in**: Once scope is set, all 11 tickets derive from it. Wrong scope = wasted tickets + missing requirements.
2. **Engineering ROI**: 93,837 LOC Python → Swift = 5-10x = ~500,000-1,000,000 LOC Swift (= 5-10 years of engineering effort). Wenshu can't afford that.
3. **Wenshu product positioning**: Writing tool, not LLM platform (= §11 hard rule). Frontends / messaging platforms are LLM-platform concerns.

## Decision

Adopt **Scope B** (= hermes 全部非前端 + agent core). Concretely: port subsystems 1-5 (= ~47,700 LOC Python → ~10,000-15,000 LOC Swift) + skip subsystems 6-8 (= ~45,000 LOC Python = 0 LOC Swift).

Three constraints flowing from this decision:

1. **Skip frontends** (subsystem 6): Electron desktop / TUI / web dashboard / iOS / Android. Wenshu has its own SwiftUI 6-zone layout (= v0.20-v0.34 = 38,749 LOC). Herme Electron = reference for design parity only (= hermes `apps/desktop/` informs wenshu 6-zone UX), no code port.

2. **Skip messaging platforms** (subsystem 7): 20+ channel integrations. Wenshu single-user desktop app; no messaging UX in wenshu's product roadmap (= §11 product-positioning rule).

3. **Port agent core + LLM + caching + auxiliary** (subsystems 1-5): All non-frontend herme Python = wenshu agent subsystem. 11 tickets cover: agent loop / tools / memory / skills / context / 7 connectors / prompt caching / system prompt / context compression / conversation compression / context engine / auxiliary client.

Five concrete scope cuts:

- **Skip messaging**: Telegram / Discord / Slack / iMessage / WhatsApp / Line / Signal / Matrix / etc. (= 20+ channels) — boss Q1 explicit "消息平台不包括".
- **Skip frontend parity**: Don't replicate Electron / TUI / web dashboard in Swift. Wenshu SwiftUI is its own UX paradigm (= 6-zone library+editor+agent, not chat-stream).
- **Skip LSP**: Herme LSP server for IDE integration. Wenshu is a desktop app, not an IDE plugin.
- **Skip browser tool**: Herme Playwright-based browser automation. Wenshu has `WebTools` (= v0.18 ticket 09 = `URLSession` + HTML→markdown, sufficient for web fetch).
- **Skip pet avatar + scheduler cron UI**: Herme pet (= cute AI companion avatar) + cron UI (= scheduled task dashboard). Wenshu has no pet UX; cron is purely background (= Apple LaunchAgent, no UI).

11 ticket scope (= all under Scope B):

| Ticket | Subsystem | LOC Python | LOC Swift | Status |
|---|---|---|---|---|
| 001 | Agent loop + Tool protocol | 5,312 | ~600 | done |
| 002 | Prompt caching + System prompt | 655 | ~300 | done |
| 003 | Context compression + engine | 5,373 | ~700 | done |
| 004 | Anthropic native connector | 2,789 | ~180 | done |
| 005 | OpenAI + OpenAI-compatible | 7,469 | ~250 | done |
| 006 | Connector settings UI | 2,384 | ~400 | done |
| 007 | Gemini native + DeepSeek + Ollama | ~3,000 | ~150 | done (Gemini) / N/A (DeepSeek + Ollama reuse OpenAICompatible) |
| 008 | OpenRouter + WenshuModelCatalog | 2,434 | ~150 | done (catalog) / OpenRouter reuses OpenAICompatible |
| 009 | Memory subsystem | 1,486 | ~250 | done |
| 010 | Skill subsystem | 1,900 | ~250 | done |
| 011 | AGENTS.md §11 baseline rewrite | 0 (= docs) | ~100 | done |
| **Total** | | **~32,800** | **~3,330** | **10x reduction (= Swift type safety + Apple frameworks)** |

## Consequences

**Easier**:
- 11 tickets = manageable scope (= 32,800 LOC Python → 3,330 LOC Swift = 10x reduction)
- Apple HIG integration (= SwiftUI + @Observable + Keychain + URLSession native)
- Wenshu product positioning preservation (= writing tool not platform)

**Harder**:
- Hermes parity partial (= hermes has 8 subsystems; wenshu has 3.5 = frontend SwiftUI + agent core + LLM connector; missing messaging / frontend replication / peripheral)
- Future messaging integration (= if boss later wants Telegram bot integration, separate ticket; would inherit Scope B cutoff)

**Locked in**:
- No messaging platform integration (= cannot add Telegram / Discord etc. without scope re-open)
- No frontend parity work (= cannot add Electron / TUI port)
- Wenshu SwiftUI = canonical UI (= 6-zone layout, no chat-stream paradigm)

## Alternatives considered

1. **Scope A (= hermes core only, no LLM connectors)**: Rejected. Boss Q1 "全都需要" includes 7 connectors. Scope A would force boss to re-Q for each connector later (= friction).
2. **Scope C (= full hermes port including messaging + frontends)**: Rejected. ~45,000 LOC Python extra + no wenshu UX value (= wenshu SwiftUI is canonical).
3. **Scope D (= hermes Python embedded in wenshu via Python C-API)**: Rejected. AGENTS.md §11 hard rule "no external AI platform calls in any code file". Single-process Swift .app only.
4. **Scope E (= hermes as remote API, wenshu as UI client)**: Rejected. §11 product-positioning rule. Wenshu = tool, not platform.
5. **Scope B (= full non-frontend + agent core)**: ACCEPTED.

## Cross-references

- spec.md §1 (scope statement) + §7.4 (acceptance criteria)
- tickets 001-011 (= all 11 tickets derive from this scope)
- AGENTS.md §11 baseline
- ADR-0008 (7-connector BYOK = part of Scope B)
- ADR-0009 (wenshu-side wins = part of Scope B adapter pattern)