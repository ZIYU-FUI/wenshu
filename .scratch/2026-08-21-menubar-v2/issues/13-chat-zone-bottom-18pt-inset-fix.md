# 13 — Chat zone bottom bar 18PT horizontal inset fix

Depends on: none

**What to build:**
Fix the chat zone bottom bar 18PT horizontal inset (老板 2026-08-22 04:29 ruled):
1. `ChatZoneView` model-picker `Menu` whole container `.padding(.leading, 18)`; no extra padding inside the label (= 18 PT from the cpu ICON)
2. `ChatView` input-field `HStack` `.padding(.horizontal, 18)` (= 18 PT to the right of the send button)
3. Context usage `.padding(.trailing, 18)` untouched (老板 ruled "if it's right")

**Why:**
commit `f1fe8e64c` (ticket 10) was written with the wrong inset placement:
- `Menu` label's internal `.padding(.leading, 18)` was eaten by `Menu`'s built-in inset; visually ≠ 18 PT
- `ChatView` input field `.padding(.horizontal, 8)` was too small; the right side of the send button < 18 PT

**Acceptance:**
- 老板 macOS verification: cpu ICON left = 18 PT + paperplane right = 18 PT
- `swift build` exit 0
- `swift test` exit 0
- Dual-axis code-review report verbatim into commit body
