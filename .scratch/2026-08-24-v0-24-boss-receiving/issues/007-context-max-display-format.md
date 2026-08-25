# Ticket 015.007 — contextMax display format (k → M conversion)

Boss 2026-08-25 OOB context window discussion: '131.1k' display format.
For 1M context, should display as '1.0M' (= standard SI prefix).

## 现状
- ChatView bottom-right context display uses 'k' suffix for kilo (e.g. '131.1k').
- After ticket 015.006 (contextMax = 1_000_000), display would be '0 /1000.0k'
  (= awkward).

## Fix (deferred)
- Display formatter: k for values < 1M, M for values ≥ 1M.
- E.g. 131072 → '131.1k'; 1000000 → '1.0M'.
- Or use Apple standard Foundation `Measurement<UnitInformation>` formatting.
- Or use ByteCountFormatter (designed for bytes, not tokens).

## Decision (per boss 8/25 OOB)
- Boss 拍 '你现在设定的才是 131k' = saw '131.1k' format. Not explicit on whether
  '1.0M' is preferred (= format is cosmetic, not blocking).
- Deferred to ticket 015.007 (= can ship after v0.24 if needed).

## Out of scope
- Token cost calculation (= separate ticket if boss 拍 need)
- Progress bar percentage (= already correct: 0/1M = 0%)