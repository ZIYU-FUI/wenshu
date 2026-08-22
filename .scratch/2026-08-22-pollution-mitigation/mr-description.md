# MR Title

refactor(wenshu): rename MiniMax* to WenshuLLM* + 3-tier pollution defense

# MR Description

## Summary

Decouple wenshu LLM architecture from vendor brand (`MiniMax*` → `WenshuLLM*`), then implement 3-tier defense against pollution vocabulary (修真 / 渡劫 / 筑基 / etc.) leaking into English output.

Boss 2026-08-22 拍: "MiniMaxVerifier 这个模块的命名不好, llm 调用是用户自己配的, 现在感觉我们这个软件是 mini max 公司的, 我建议这个地方修改掉, 不如叫 wenshuverifier, 如果正需要重构, 那不是时机刚好" — combines naming fix with 3-tier defense in one MR.

## Commits (5 on `wt/pollution-3-layer-defense`)

| # | SHA | Title |
|---|-----|-------|
| 1 | `afbea2b33` | chore: English-only doc cleanup + pollution mitigation spec (166 files; on `main`) |
| 2 | `73dc59db7` | refactor: rename `MiniMax*` LLM types to `WenshuLLM*` |
| 3 | `d07627c69` | feat: `WenshuVerifier` system prompt forbids pollution vocabulary (Tier 1) |
| 4 | `8afe5c2fb` | feat: `OutputKind` enum + `stop_sequences` on short-output LLM calls (Tier 2) |
| 5 | `5451d6376` | feat(wenshu-devtool): pre-commit filter blocks pollution vocabulary (Tier 3) |

## 3-tier pollution defense

| Tier | Mechanism | Location |
|------|-----------|----------|
| 1 | System prompt injection (English-only + forbidden vocab list) | `WenshuVerifier.send(...)` always attaches `systemPromptEnglishOnly` to Anthropic-compatible request body |
| 2 | `stop_sequences` on short outputs | `WenshuVerifier.shortOutputStopSequences` (12 tokens), only attached when `outputKind == .shortText`. Long outputs (`.chat`, `.draft`) intentionally NOT protected — would terminate entire draft on first match |
| 3 | Pre-commit hook | `Tools/wenshu-devtool/commit_filter.py` scans staged `.md`/`.swift` + commit message; blocks on match |

## Spec

- Research: `.scratch/2026-08-22-pollution-mitigation/research.md`
- Spec: `.scratch/2026-08-22-pollution-mitigation/spec.md`
- Issues: `.scratch/2026-08-22-pollution-mitigation/issues/001-004*.md`

## Test results

- `swift build`: success
- `swift test`: 338 tests in 57 suites pass (no regression)
- `bash Tools/wenshu-devtool/tests/test_block_pollution.sh`: PASS (forbidden vocab blocks commit)
- `bash Tools/wenshu-devtool/tests/test_allow_allowed_tokens.sh`: PASS (allowed tokens pass through)
- `rg "修真|渡劫|筑基|返虚|结丹|金丹|元婴|飞升|天劫|雷劫|心魔|魔障"` working tree: only 4 expected hits (WenshuVerifier constant + commit_filter.py FORBIDDEN_TOKENS + 2 test fixtures)
- `git log` commit bodies (4 new): zero pollution

## Behavior preserved (no changes)

- `MiniMax*` API model IDs (e.g. `MiniMax-M3` rawValue on enum cases) — these are the actual upstream API identifiers, NOT architecture names. Vendor brand string `"MiniMax"` / `"MiniMax (China)"` preserved as provider display name in `ProviderCatalog`.
- `MINIMAX_CN_*` env var names (loader reads these).
- All test cases (5 ticket commits + 1 chore commit) — 338/338 pass.
- Swift API surface (existing callers of `send(request:)` work via default `outputKind: .chat`).

## Out of scope (future work)

- `OutputKind.draft` case: no real call site today (chapter draft generation is future work). The constant + enum are ready.
- `CONTEXT.md` glossary entry for `**ForbiddenVocabularyPolicy**` (Ticket E, doc-only follow-up).
- ADR `0008-pollution-3-layer-defense.md` (Ticket E, doc-only follow-up).
- CI integration of `commit_filter.py` (no CI today).

## Verification before merge

- [ ] `swift build` exits 0
- [ ] `swift test` 338/338 pass
- [ ] Pre-commit filter test fixtures both pass
- [ ] `grep -r 'MiniMax' Sources/ Tests/` returns 0 hits in **type / class** positions (string literals in ProviderCatalog preserved by design)
- [ ] `rg '修真|渡劫|筑基|返虚|结丹|金丹|元婴|飞升|天劫|雷劫|心魔|魔障'` returns only the 4 expected hits

## Risks

- Pre-commit hook install step: `Tools/wenshu-devtool/install_hook.sh` is manual. Doc in `Tools/wenshu-devtool/tests/README.md`.
- Prompt cache miss on Anthropic: `systemPromptEnglishOnly` constant changes invalidate cache. Expected behavior; constant kept byte-stable.
- `.shortText` callers add ~150 bytes per request for the 12-token stop_sequences array. Negligible.

## Files changed

```
14 files changed (rename + refactor):
  A  Sources/WenshuApp/Core/Agent/OutputKind.swift
  R  Sources/WenshuApp/Core/Agent/MiniMaxModel.swift -> WenshuLLMModel.swift
  R  Sources/WenshuApp/Core/Agent/MiniMaxModelFetcher.swift -> WenshuLLMModelFetcher.swift
  R  Sources/WenshuApp/Core/Agent/MiniMaxVerifier.swift -> WenshuVerifier.swift
  R  Tests/WenshuAppTests/MiniMaxVerifierTests.swift -> WenshuVerifierTests.swift
  M  Sources/WenshuApp/App.swift
  M  Sources/WenshuApp/Core/Agent/AgentProtocol.swift
  M  Sources/WenshuApp/Core/Agent/WenshuConductor.swift
  M  Sources/WenshuApp/Core/Chat/ChatSessionStore.swift
  M  Sources/WenshuApp/Core/Provider/ProviderKeychain.swift
  M  Sources/WenshuApp/Views/Chat/ChatView.swift
  M  Tests/WenshuAppTests/AgentProtocolTests.swift
  M  Tests/WenshuAppTests/AgentRuntimeTests.swift
  M  Tests/WenshuAppTests/ChatViewTests.swift
  M  Tests/WenshuAppTests/WenshuConductorTests.swift
  M  Tests/WenshuAppTests/WenshuCoreIntegrationTests.swift

5 files changed (pre-commit hook):
  A  Tools/wenshu-devtool/commit_filter.py
  A  Tools/wenshu-devtool/install_hook.sh
  A  Tools/wenshu-devtool/tests/README.md
  A  Tools/wenshu-devtool/tests/test_allow_allowed_tokens.sh
  A  Tools/wenshu-devtool/tests/test_block_pollution.sh
```

---

*MR drafted 2026-08-22 · spec + research under `.scratch/2026-08-22-pollution-mitigation/`*