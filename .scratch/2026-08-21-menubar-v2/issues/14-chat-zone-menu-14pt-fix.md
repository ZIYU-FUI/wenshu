# 14 — Chat zone model-picker Menu ICON left 14 PT

Depends on: ticket 13 commit `75a9a882a` (Menu whole-container paradigm installed)

**What to build:**
`ChatZoneView` model-picker Menu ICON left = 14 PT (老板 2026-08-22 04:34 ruled):
1. `.padding(.leading, 18)` → `.padding(.leading, 14)` (boss Path A: 14 + built-in 4 = 18 PT visual)
2. `.menuStyle(.borderlessButton)` untouched (built-in inset can't be cancelled; Apple SwiftUI macOS 27 truth)
3. `ChatView` input-field `HStack` `.padding(.horizontal, 18)` untouched (ticket 13 correct)
4. Context-usage `HStack` `.padding(.trailing, 18)` untouched (ticket 13 correct)

**Why:**
After ticket 13 commit `75a9a882a`, the Menu whole container has `.padding(.leading, 18)` + `borderlessButton` built-in 4 PT inset = visual 22 PT. Boss ruled visual = 18 PT.

**Acceptance:**
- 老板 macOS verification: cpu ICON left visual = 18 PT (= 14 PT + 4 PT inset)
- `swift build` exit 0
- `swift test` exit 0
- Dual-axis code-review report verbatim into commit body
