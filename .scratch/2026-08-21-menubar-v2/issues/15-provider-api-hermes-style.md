# 15 — Provider API config page: imitate the hermes auth interaction

Depends on: none (`ProviderKeychain` backend already exists)

**What to build:**
Add a 4th tab "Provider API" to `SettingView`, imitating the hermes auth list + add interaction (老板 2026-08-22 04:50 ruled):
1. `SettingsTab` adds `.providerApi` case (icon `"key.horizontal"`)
2. body `switch` adds `.providerApi` case → `providerApiTab`
3. `providerApiTab` new view: `List` showing `Provider.all` + tap to expand an inline editing panel (`SecureField` + Save button — no `NSWindow` popup)
4. `providerTab` L364 `ProviderKeyPrompt.prompt` invocation is removed (fix: no popup)

**Why:**
老板 ruled "completely imitate hermes' provider API config page's functionality and interaction" + "stop popping up a key-input dialog to paste keys; reference hermes' page interaction". The current provider tab, when the user taps a provider without a key, calls `ProviderKeyPrompt.prompt` = pop up `NSWindow` standalone sheet = a hard violation per 老板's ruling.

**Acceptance:**
- 老板 macOS verification: Provider API tab is clickable → tap a row → expands inline editor → `SecureField` for key → Save → status changes to "Key set"
- `swift build` exit 0
- `swift test` exit 0
- Dual-axis code-review report verbatim into commit body
- Q40: no file / log / commit contains 老板's real key
