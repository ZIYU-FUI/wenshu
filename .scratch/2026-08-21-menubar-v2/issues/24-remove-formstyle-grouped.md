# 24 — Edit-box whole-row Apple-standard appear/exit animation — hard truth

Depends on: ticket 21 + 22 + 23 commits

**What to build:**
Remove `.formStyle(.grouped)` interception (1-line patch) = the edit-box whole row's Apple default appear/exit animation takes effect.

**Why:**
老板 2026-08-22 07:14 ruled "the whole row in the red box doesn't have appear/exit animation" + authorized the agent to advance per the core principles. Q28 docs lookup: Apple SwiftUI `.formStyle(.grouped)` intercepts `.transition` + `.animation` = 老板 saw "instant".

**Acceptance:**
- 老板 macOS verification: edit-box whole row (red box) Apple default appear/exit animation, elegant
- `swift build` exit 0
- `swift test` exit 0 (`ProviderKeychain` 5/5 pass)
- Dual-axis code-review verbatim into commit body
