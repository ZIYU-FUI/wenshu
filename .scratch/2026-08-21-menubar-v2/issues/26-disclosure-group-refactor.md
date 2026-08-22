# 26 — Refactor `providerApiTab` with Apple `DisclosureGroup` (老板 2026-08-22 ruled + authorized to advance per core principles)

Depends on: ticket 16 (`bindingForExpanded`) + ticket 17 (whole-row hot area) + ticket 22 + 23 (`.transition` + `.animation`) + ticket 25 (brand "文枢" restored) + ticket 24 revert (`.formStyle` restored)

**What to build:**
Refactor `providerApiTab` with Apple `DisclosureGroup` (Apple SwiftUI 11+ standard accordion disclosure control), removing my previous hand-written `Button` + `if` condition + `.transition` + `.animation` paradigm.

**Why:**
老板 2026-08-22 ruled "accordion component" + "Apple's" + "components come with animations" + 老板 authorized "advance per core principles" (= `WenshuCommonSenseInteractionPrinciple` 老板 verbatim "use Apple's APIs")

**Acceptance:**
- 老板 macOS verification: Apple standard accordion expansion (`DisclosureGroup` brings its own animation + its own chevron) / whole-row hot area responds
- `swift build` exit 0
- `swift test` exit 0 (`ProviderKeychain` 5/5 pass)
