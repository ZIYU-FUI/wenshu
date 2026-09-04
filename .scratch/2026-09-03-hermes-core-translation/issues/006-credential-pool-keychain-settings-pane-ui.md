# 006: Credential pool + Keychain integration + Settings pane UI for 7 connectors

**What to build:** Port the BYOK credential pool from hermes (`agent/credential_pool.py` 2,384 LOC + `credential_persistence.py` + `credential_sources.py` + `secret_sources/` + `secret_scope.py` = ~3,500 LOC total). Integrate with Apple's Keychain via the existing `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (currently holds the minimax key). Build the Settings pane UI for all 7 connector profiles — user picks profile, supplies credential, tests. After this ticket, wenshu is fully BYOK and the connector layer has real Settings UI.

**Blocked by:** 001, 004 (Anthropic connector), 005 (OpenAI connector)

**Status:** blocked

## Source files surveyed

| Path | LOC | What ports |
|---|---|---|
| `agent/credential_pool.py` | 2,384 | Full port = BYOK credential pool, key rotation |
| `agent/credential_persistence.py` | ~400 | Full port |
| `agent/credential_sources.py` | ~300 | Full port |
| `agent/secret_sources/` | ~500 | Full port |
| `agent/secret_scope.py` | ~200 | Full port |

Plus NEW wenshu-side authoring of:
- `Sources/WenshuApp/UI/LLMConnector/LLMConnectorSettingsView.swift`
- `Sources/WenshuApp/UI/LLMConnector/ConnectorProfileRow.swift`
- `Sources/WenshuApp/UI/LLMConnector/ConnectorAuthField.swift`
- `Sources/WenshuApp/UI/LLMConnector/ConnectorTestButton.swift`

## UI-affordance mapping (per spec §6.4)

This ticket's translated products and their UI landing:

| Translated product | UI landing | Tier | Rationale |
|---|---|---|---|
| Credential pool + Keychain | Settings → LLM Connector | 🟥 | key input panel = core user operation |
| Settings pane UI (7 profiles) | Settings弹窗 new "LLM Connector" view | 🟥 | entire view is new |
| ConnectorTestButton | Settings → LLM Connector (test button per profile row) | 🟥 | user must verify credentials work before using |

**3-question check** (per spec §6.4):

1. **Who triggers it?** User opens Settings弹窗 → LLM Connector pane. User selects a profile, types API key into `ConnectorAuthField`, clicks `ConnectorTestButton`. Internally, `ConnectorCredentials` resolves the key via `ProviderKeychain.swift` (existing wenshu code, per §3.6 wenshu-side wins).
2. **What signal does the user see?** A new Settings view "LLM Connector" appears with 7 profile rows. Each row has: profile name, protocol label, API key field, test button. After test = ✓ green checkmark + "smoke test passed" text, or ✗ red X + error message. Connector test = real LLM API call (model metadata + minimal prompt + 200 OK check).
3. **UI affordances added**: New Settings弹窗 view "LLM Connector" (= 🟥); 7 `ConnectorProfileRow` components (= 🟥); 7 `ConnectorAuthField` components (= 🟥); 7 `ConnectorTestButton` components (= 🟥).

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Agent/Connector/ConnectorCredentials.swift` extended to full credential pool (= from issue 001's minimal version)
- [ ] `Sources/WenshuApp/Core/Agent/Auth/SecretScope.swift` + `RetryUtils.swift` port their Python counterparts
- [ ] Integration with existing `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` (currently holds minimax key); all 7 connector credentials stored in Keychain
- [ ] Settings → LLM Connector pane: 7 profile rows visible. NO default selected. User picks + supplies key + tests.
- [ ] ConnectorTestButton: sends smoke prompt to selected profile, shows ✓/✗
- [ ] Credential rotation: same profile, multiple keys (e.g. 2 OpenAI keys) — pool rotates
- [ ] `swift build` exit 0; `swift test` exit 0
- [ ] Manual UI test: open Settings → LLM Connector → pick minimax, paste key, test → see "✓ smoke test passed"
- [ ] Z contract test: golden files for credential pool entry/exit, keychain resolution paths

## Iron rules applied

- [ ] Rule 6: layout/spacing uses DesignTokens (= no magic numbers in Settings pane)
- [ ] Rule 11: state persistence via @AppStorage (= selected connector profile stored in UserDefaults)
- [ ] wenshu-apple-api-first: Keychain via existing `ProviderKeychain.swift` (= Apple HIG standard); NO new third-party credential manager
- [ ] AGENTS.md §11 product-positioning rule: NO metering / billing / quota tracking added in this UI
- [ ] §11 product-positioning rule audit: confirm Settings pane has NO "Buy more tokens" / "Quota" / "Subscription" affordance

## Estimated LOC

~1,500 Swift LOC (1,200 connector/credential code + 1,500 Settings UI = total ~2,700).

## Commit format

`feat(wenshu): v0.35 -- credential pool + Keychain + LLM Connector Settings pane (= ticket 006 of 11)`