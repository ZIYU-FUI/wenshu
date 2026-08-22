# 04 — SettingView rewrite 4 tabs (General / Providers / Models / Shortcuts)

**Blocked by:** ticket 01 (Provider enum), 02 (ProviderKeychain), 03 (ProviderFetcher).

**Status:** ready-for-agent

## Fix approach (5 steps, Hermes list_picker_providers pattern)

1. SettingView add tab "Providers" (position: between General + Models):
   - 4 tabs: General / Providers / Models / Shortcuts
2. "Providers" tab:
   - List Provider.all (radioGroup, currently selectedProvider highlighted)
   - Select provider → pop NSAlert to input key (uses ticket 03 NSWindow sheet prompt truth)
   - Select custom → show base_url input (@AppStorage "wenshu.llm.base_url")
   - Show each provider's status (has key ✓ / no key ✗)
3. "Models" tab:
   - Call ProviderFetcher.loadModelIds(provider: currentProvider, apiKey: ...)
   - Picker shows returned model IDs
   - Switch provider → reload models
4. Rewrite LLMKeychain.promptForLLMKeyIfNeeded to accept provider parameter (or rename to ProviderKeychain.promptForKey)
5. Add `@AppStorage("wenshu.llm.provider")` default "minimax-cn"

## Acceptance

- [ ] SettingView 4 tabs (General / Providers / Models / Shortcuts)
- [ ] Providers tab: List Provider.all radioGroup + current provider highlighted
- [ ] Providers tab: select provider → pop NSAlert to input key → ProviderKeychain.saveKeySync
- [ ] Providers tab: each provider shows status (has/no key)
- [ ] Models tab: use ProviderFetcher to fetch current provider's truth models
- [ ] Switch provider → Models tab reload
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS real verification: Providers tab lists 11 providers → select openrouter → input key → Models tab shows openrouter truth list

## Do not touch

- v0.21 ticket 01/02/03 (provider module)
- v0.21 chat bottom bar (model + context)
- LLMKeychain (preserve backwards-compat API)
- v0.20 ticket 04/05 (LOGO)
