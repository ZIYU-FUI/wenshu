# 16 — Provider API edit panel: inline expansion (`DisclosureGroup`)

Depends on: ticket 15 commit `f0b71d098`

**What to build:**
Fix the `providerApiTab` sub-component (老板 2026-08-22 06:00 ruled "should expand inline at the MiniMax (China) row"):
1. Remove the standalone `Section` block (`if let editing = apiEditingProvider { Section("Enter X API Key") {...} }`)
2. Each `ForEach` provider render = `DisclosureGroup(isExpanded:) { SecureField + buttons } label: { providerApiRow(p) }`
3. `@State expandedProviders: Set<String>` controls each provider's expansion state

**Why:**
ticket 15 commit `f0b71d098` rendered the edit panel at the bottom of the `Form` in a standalone `Section`. 老板 wants the inline expansion under the corresponding provider row. Q26 5-principle judgment: `DisclosureGroup` is the only option passing (Apple official paradigm + pseudo-Apple style + effect-first + business language + po main flow).

**Acceptance:**
- 老板 macOS verification: tap the MiniMax (China) row → the whole row expands an inline edit panel → `SecureField` + Save → status changes to "Key set"
- `swift build` exit 0
- `swift test` exit 0 (`ProviderKeychain` 5/5 pass; no regressions)
- Dual-axis code-review report verbatim into commit body
