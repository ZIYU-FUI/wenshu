# 17 — Provider tab removal + whole-row hot area response + already-set key shows first 8 chars + Settings popup rename to "Settings"

Depends on: ticket 16 commit `1c531223f`

**What to build:**
Fix 4 hard-violation items that 老板 2026-08-22 06:12 ruled:
1. `SettingsTab` removes `.provider` case + body `switch` removes `.provider` route (老板 ruled "the Provider tab can be deleted; keep the Provider API tab")
2. `providerApiTab` uses `List` + `onTapGesture` instead of `DisclosureGroup` (老板 ruled "remove the `>` in front of each row; the whole row should respond to expand/collapse")
3. `providerApiEditor` — when expanded with a key already set, pre-fill `apiDraftKey` with "first 8 chars + ********" (老板 ruled "for already-configured entries, on re-expand the text field shouldn't be empty; show the first 8 chars of the truth + **** padding")
4. `Settings` Scene popup title rename to "Settings" (老板 ruled "the settings popup is just called Settings; don't go out of your way to call it 文枢 Settings") — fix truth pending Q28 docs lookup

**Why:**
The current implementation has 4 hard violations: `providerTab` duplicated / `DisclosureGroup` brings its own chevron / `SecureField` always empty / Settings Scene title "WenshuApp Settings"

**Acceptance:**
- 老板 macOS verification: Provider tab is gone → tap the whole row → expands inline edit → already-set key shows first 8 chars + padding → settings popup title = "Settings"
- `swift build` exit 0
- `swift test` exit 0 (`ProviderKeychain` 5/5 pass; no regressions)
- Dual-axis code-review report verbatim into commit body
- Q40: `SecureField` display = first 8 chars + padding ≠ real key; the real key still goes through Apple Keychain, not into files / log / commit
