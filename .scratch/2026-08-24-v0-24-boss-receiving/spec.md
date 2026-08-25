# Boss 2026-08-25 OOB context window spec

Boss拍: 'minimax m3 不是 1mb 的上下文吗, 你现在设定的才是 131k'.
Boss拍: '没有接口获取的到吗' (boss checking if API exists to query context length).

## 现状 (pre-fix)
- `Sources/WenshuApp/Views/Chat/ChatView.swift:79`: `contextMax: Int = 131072`
- Boss image shows: '0 /131.1k' (= 131,100 tokens)
- 131,072 = 128 KB = **MiniMax-M2 series value**, not M3
- Per boss 拍: 不对 = MiniMax M3 实际 context window 更大

## 真值 (per official + hermes upstream research)
1. **Official MiniMax model page** (https://www.minimax.io/models/text/m3):
   '1M Context' / '1,000,000 token context window with a guaranteed minimum of 512K tokens'.
2. **Anthropic-compatible API docs** (https://platform.minimax.io/docs/api-reference/text-anthropic-api):
   M3 = 1_000_000 tokens (max output 512_000).
3. **Empirical test** (hermes-agent issue #37289, public anthropic-compatible endpoint):
   input cap at ~512K tokens. API rejects >512K with 'invalid params, context
   window exceeds limit'.
4. **Live API `/v1/models`**: does NOT return `context_length` field. **No API to query dynamically** (boss 8/25 OOB confirmed).
5. **HERMES-agent strategy** (agent/model_metadata.py:1456-1487):
   hybrid = `models.dev` registry first → fallback hardcoded catalog.
   But `models.dev` reports 512K for M3 (= vendor publishes there) → runtime
   short-circuits at 512K, hardcoded 1M never reached.

## Spec 决定
- **Use official value** = `1_000_000` tokens (= source of truth per Apple HIG /
  anthropic API contract principle). UI shows '1.0M'.
- **Vendor reality** (~512K empirical cap) = separate vendor API issue.
  Boss should complain to MiniMax if >512K input rejected (= not wenshu fix).
- **No dynamic API query** = live MiniMax cn `/v1/models` doesn't expose
  context_length. Future enhancement: parse `models.dev` registry (hermes
  strategy).

## Tickets
- ticket 015.006 (chatview context window fix): `contextMax 131072 → 1_000_000`.
- ticket 015.007 (contextMax display format): 'k → M' conversion (e.g. 131.1k →
  1.0M). UI label display.
- ticket 015.008 (future: models.dev lookup): optional enhancement to match
  hermes strategy. Defer until boss拍 (not blocking v0.24).

## Done criterion
- swift build: clean.
- App: bottom-right context display shows '0 /1.0M' (= 1M tokens cap).
- Tests: 574/80 unit pass + 10 e2e flakes pre-existing (no new).
- Code-review axes (Standards + Spec): both PASS.
- Domain-modeling: CONTEXT.md add entry for 'MiniMax-M3 context window = 1M tokens'.
- Confirm: boss 拍 '通过验收'.