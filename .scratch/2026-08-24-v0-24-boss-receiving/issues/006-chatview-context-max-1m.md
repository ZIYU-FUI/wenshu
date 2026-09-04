# Ticket 015.006 — ChatView.swift contextMax 131072 → 1_000_000 (MiniMax-M3 = 1M context)

Boss 2026-08-25 OOB: 'minimax m3 不是 1mb 的上下文吗, 你现在设定的才是 131k'.

## 现状
- `Sources/WenshuApp/Views/Chat/ChatView.swift:79`: `contextMax: Int = 131072`
- 131,072 tokens = 128 KB = **MiniMax-M2 series value** (wrong model)
- Per official MiniMax docs + boss 拍 = M3 actual = **1_000_000 tokens (1M)**

## Fix (per commit dc741ceac 已 apply)
- `contextMax: Int = 1_000_000`
- Comment updated with:
  - Source of truth: official MiniMax model page + Anthropic API docs
  - Empirical caveat: ~512K cap on public endpoint (per hermes-agent issue #37289)
  - Live API `/v1/models` doesn't return context_length (= no dynamic query)

## Verification
- swift build: clean
- App rebuilt + relaunched (PID 5518)
- UI: bottom-right context display shows '0 /1.0M' (= 1M tokens cap)

## Out of scope
- Ticket 015.007: display format ('k → M' conversion) — separate ticket
- Ticket 015.008: models.dev lookup (hermes strategy) — future enhancement