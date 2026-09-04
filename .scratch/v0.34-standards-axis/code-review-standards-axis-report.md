## Standards Axis — v0.34 tonight 5 commits

Scope: `dcde7cff5..ecddef4a3` (= 5 commits, +571/-495 LOC across 13 files; full patch `/tmp/v0.34-tonight.patch`).
Boss explicit focus: Provider API settings path end-to-end wiring.
Method: Standards-axis checklist A (AGENTS.md hard rules) + B (zero-config iron rules) + C (Provider path integrity grep) + D (engineering hygiene).

### Verdict: PASS

### Findings

#### CRITICAL: Provider path integrity (= boss explicit focus)

**Status: INTACT.** Provider API settings path is byte-identical to `88c2858e2`. No file in `Sources/WenshuApp/Core/Provider/` or `Sources/WenshuApp/Views/Settings/` was touched in tonight's 5 commits (`git diff 88c2858e2..HEAD -- Sources/WenshuApp/Core/Provider/ Sources/WenshuApp/Views/Settings/` = empty).

End-to-end path verification (= 9 caller sites across 3 files; all unchanged):

1. **User clicks Settings tab "提供方 API"** — `App.swift:563` (`case providerApi = "提供方 API"`) → `App.swift:591` (`.onChange` triggers `refreshProviderStatus()`) → `App.swift:603` (switch dispatches to `providerApiTab`).
2. **`providerApiTab` Form** — `App.swift:747-776`. Lists `Provider.all` (11 slugs from `Sources/WenshuApp/Core/Provider/Provider.swift:144`). Tap → `toggleExpand(p:)` opens `providerApiEditor(for: p)` (`App.swift:812`).
3. **Key save** — `App.swift:816-820` "保存" button → `saveApiKey(for: provider)` (`App.swift:859`) → `ProviderKeychain.saveKeySync(trimmed, for: provider)` (`App.swift:863`). **Provider argument = real `Provider` struct** (not String slug, not Int).
4. **Key load (preview)** — `App.swift:854-857` `keyPrefix12(for: Provider)` → `ProviderKeychain.loadKeySync(for: provider)` (`App.swift:855`). `currentDraftPreview(for: Provider)` (`App.swift:803-809`) → same loader. Both pass real `Provider`.
5. **Notification posted** — `App.swift:871-875` posts `NotificationCenter.default.post(name: .wenshuProviderKeychainChanged, object: nil, userInfo: ["slug": provider.slug])` with `provider.slug` as the userInfo slug.
6. **Notification listener** — `App.swift:1618` `.onReceive(NotificationCenter.default.publisher(for: .wenshuProviderKeychainChanged)) { _ in availableSections = AvailableModelsDiscovery.loadFromKeychain() ... }` (= chat-zone refresh; preserved).
7. **AvailableModelsDiscovery** — `Sources/WenshuApp/Core/Provider/AvailableModelsDiscovery.swift:34-45` `loadFromKeychain()` iterates `Provider.all`, calls `ProviderKeychain.loadKeySync(for: provider)`, returns providers with non-empty keys + their `defaultModels`. Unchanged.
8. **WenshuVerifier** — `Sources/WenshuApp/Core/Agent/WenshuVerifier.swift:224` `guard let key = ProviderKeychain.loadKeySync(for: provider), !key.isEmpty else { throw WenshuLLMError.missingAPIKey }`. Unchanged.

**Notification.Name backward-compat verified** (`95a2d96ba` B-04 refactor):

- `Sources/WenshuApp/Core/Notifications/AppNotifications.swift:121` declares `static let wenshuProviderKeychainChanged = Notification.Name(AppStateEvents.providerKeychainChanged.rawValue)` — exact same rawValue `"com.wenshu.providerKeychainChanged"` as the old `App.swift:34` definition. Behavior preserved 1:1.
- The `post` site at `App.swift:872` and the `onReceive` site at `App.swift:1618` resolve through this backward-compat accessor. Both compile and behave identically.
- Migration window open per `AppNotifications.swift:99-110` doc-comment; v0.35+ ticket can delete the accessor once 17 call sites rename.

**`LLMKeychain.swift` deletion verified** (`ecddef4a3` B-10 chore):

- Pre-delete: `grep -rn 'LLMKeychain' Sources/` = 2 hits (the file's own header + 1 comment in `WenshuVerifierKeyNote.swift:6` describing the historical role). Commit message documents this exactly.
- Post-delete: `grep -rn 'LLMKeychain' Sources/` = 1 hit (`Sources/WenshuApp/Core/Agent/WenshuVerifierKeyNote.swift:6` — a stale historical comment referencing the now-deleted type). **No functional callers — only doc-comment residue.**
- `LLMKeychain.loadKeySync()` (deleted file L97) internally delegated to `ProviderKeychain.loadKeySync(for: .minimaxCn)` — this was the only reason `LLMKeychain` was kept around, and the boss backlog B-10 confirms this caller path was zeroed in v0.28 (= ProviderKeychain became the canonical replacement).

**Stub state confirmed intentional, NOT a regression:**

- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift:50-141` save/load/delete/list all return early (= SecItem* code commented out per boss 8/29 OOB '注释掉密码功能').
- Load returns hardcoded `"wenshu.debug.api.key"` so live model fetch + LLM calls succeed with a fake credential.
- This stub state predates tonight's 5 commits (it dates to v0.28) and is the explicit subject of `.scratch/backlog.md:180-204` B-10 re-enable ticket (= boss拍 pending; gated on accepting the macOS SecurityAgent modal prompt at first key save).
- **Standards review does NOT flag this as a regression** — it's a tracked intentional state, not something tonight's refactors introduced or worsened.

#### HARD (= AGENTS.md violations)

**No AGENTS.md hard-rule violations found** in tonight's 5 commits.

Verified:
- **English-only in commit messages + new code comments**: All 5 commit subjects + bodies are English. The 22 CJK comment translations in `dcde7cff5` (= §5 of that commit) cleaned every CJK comment introduced by that commit (= F1b resolved per commit doc; F1a = the 36 older CJK commit bodies = backlog B-03, pre-existing).
- **Forbidden Chinese vocabulary (修真/渡劫/筑基/返虚/结丹/金丹/元婴/飞升/天劫/雷劫/心魔/魔障)**: 0 hits in `/tmp/v0.34-tonight.patch`.
- **Forbidden neutral words (可/应当/或许/可能/应该/建议/考虑/试图/尽量/大概/也许/或/任意/大概率/通常/一般来说)**: 0 hits in `/tmp/v0.34-tonight.patch`.
- **Sole user address = 老板**: 5 commit bodies reference "Boss" (= English) and "老板" (= Chinese char literal) only in the documented places (commit messages that cite prior boss拍 directives). No new honorific forms introduced.

**One SOFT (not HARD) finding** under AGENTS.md:

- `Sources/WenshuApp/Core/Agent/WenshuVerifierKeyNote.swift:6` still says `"sourced from Keychain via LLMKeychain"` but `LLMKeychain.swift` was deleted by `ecddef4a3`. Comment now references a non-existent type. Doc inconsistency, low severity (purely cosmetic, no functional impact). **Suggested fix: replace `LLMKeychain` with `ProviderKeychain` in that one comment** (= 1-word patch, can land in a follow-up).

#### SOFT (= iron-rule violations)

**No zero-config iron-rule violations introduced by tonight's 5 commits.**

Verified by grep on the `+` lines of the patch:
- **Rule 1 (colors)**: 0 hardcoded `Color(red:...)` / `Color(.red)` / `Color(.blue)` / hex codes added.
- **Rule 2 (fonts)**: 0 `.system(size: ...)` additions.
- **Rule 3 (dark mode)**: 0 `overrideUserInterfaceStyle` / `NSAppearance.customAppearanceNamed` additions.
- **Rule 4 (glass)**: 0 `.glassEffect` regressions; the existing `.glassEffect()` / `.glassEffect(.regular.tint(.accentColor))` / `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` patterns are unchanged. `dcde7cff5` actually strengthens Rule 4 by extending `LucideIconSystemFallback` mapping so every Lucide callsite now resolves through real Lucide (no SF Symbol fall-through to `Image(systemName:)`).
- **Rule 5 (accessibility)**: No new `.animation(nil, value:)` to kill motion.
- **Rule 6 (layout/spacing)**: 0 new `.padding(.all, N)` / `Spacer().frame(height: N)` additions. `PaneTrailingIconButton` helper added in `dcde7cff5` uses `Color.clear.frame(28,28).overlay(LucideIcon)` for the hot area — this is the canonical wenshu hit-area pattern (no manual padding magic).
- **Rule 7 (controls)**: 0 new custom-drawn buttons / sliders / pickers. `PaneTrailingIconButton` helper added in `dcde7cff5` wraps an existing `Button { }.buttonStyle(.plain)` pattern (= system component, just deduped across 2 callsites).
- **Rule 8 (window/scene)**: No scene-type changes tonight.
- **Rule 9 (menu/shortcuts)**: No new menu / shortcut code tonight.
- **Rule 10 (nav)**: No navigation changes tonight.
- **Rule 11 (state persistence)**: `dcde7cff5` §3 = "Sidebar state unified persistence" consolidates 4 scattered `@AppStorage` keys into 1 `@AppStorage("wenshu.sidebarState")` holding a `Codable SidebarState` struct. **Strengthens Rule 11** (= fewer scattered storage keys, single JSON-encoded source of truth).

### Engineering hygiene

**Clean.**

- **Dead-code deletion correctness** (`ecddef4a3`): LLMKeychain.swift removed with 0 functional callers pre-delete (commit doc cites grep; verified by post-delete grep = 1 doc-only hit in WenshuVerifierKeyNote.swift).
- **Notification.Name centralization** (`95a2d96ba`): 11 names moved to `AppNotifications.swift` with backward-compat accessors preserving all 17 post/observe sites. No callsite renamed in this commit (= minimal auditable diff). Migration window documented for v0.35+ cleanup.
- **No accidental deletions**: `git show --stat` on each of the 5 commits shows expected file scope. `a6b6c75d3` (ChatZoneTopChrome delete) verified the wrapper had 0 remaining callers before delete; `dcde7cff5` (ZoneContentTabBar delete + Card unify + sidebar merge + Lucide extension) preserved all consumer call sites by routing them through the unified `PaneTabBar` / single `Card` / single `SidebarState`.

### Build verification

`swift build` from `/Volumes/ANAN/Engineering/wenshu` = **Build complete! (21.09秒)**. 0 errors. Pre-existing `case will never be executed` warnings in `NewLibraryOutlineView.swift:1132, 1162` (= unrelated to tonight's refactors; flagged in commit `dcde7cff5` build verification as pre-existing).

### Files verified intact

- `Sources/WenshuApp/Core/Provider/ProviderKeychain.swift` — untouched by tonight's 5 commits. Shim + AppleKeychainStore stub + InMemoryKeychainStore test backend + 4 static facade methods + setBackendForTesting all intact.
- `Sources/WenshuApp/Core/Provider/Provider.swift` — untouched.
- `Sources/WenshuApp/Core/Provider/ProviderCatalog.swift` — untouched.
- `Sources/WenshuApp/Core/Provider/AvailableModelsDiscovery.swift` — untouched.
- `Sources/WenshuApp/Core/Provider/ProviderFetcher.swift` — untouched.
- `Sources/WenshuApp/Core/Provider/ModelDisplay.swift` — untouched.
- `Sources/WenshuApp/Core/Provider/ProviderProfileExt.swift` — untouched.
- `Sources/WenshuApp/Views/Settings/LibraryPropertiesView.swift` — untouched.
- `Sources/WenshuApp/App.swift:561-879` (SettingView + case providerApi + providerApiTab + providerApiRow + providerApiEditor + saveApiKey) — byte-identical to `88c2858e2`.
- `Sources/WenshuApp/App.swift:1187-1189` (debug keychain backend override) — byte-identical.
- `Sources/WenshuApp/Core/Agent/WenshuVerifierKeyNote.swift:224` (WenshuVerifier → ProviderKeychain.loadKeySync) — untouched. **Note: L6 comment references deleted `LLMKeychain` type — doc fix recommended but non-blocking.**

### Recommendations (non-blocking, v0.35+ candidates)

1. **Doc fix**: `Sources/WenshuApp/Core/Agent/WenshuVerifierKeyNote.swift:6` — replace `LLMKeychain` with `ProviderKeychain` (1-word patch). Not a HARD regression; just stale doc reference after `ecddef4a3`.
2. **Migration window close-out** (B-04 follow-up): rename the 17 `.wenshuXxx` call sites to `Notification.name(AppCommands.x)` / `.wenshuChatStoreReady` → `.wenshuChatStoreReady` (i.e. enum-driven factories), then delete the backward-compat accessors in `AppNotifications.swift:111-128`. Tracked in backlog B-04.
3. **B-10 SecItemAdd re-enable** (NOT a regression to fix tonight): `.scratch/backlog.md:180-204` — uncomment real `SecItemAdd` / `SecItemCopyMatching` / `SecItemDelete` in `ProviderKeychain.swift:50-141` once boss拍 confirms the SecurityAgent modal prompt is acceptable.

---

Last line: fact.