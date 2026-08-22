# 06 — Settings panel UI rebuild (Pages paradigm + Hermes provider/model truth, 老板 2026-08-21 ruled)

**What to build:**
老板 8/21 ruled (3 requirements):
1. **Pages-paradigm settings panel UI** (= Pages top toolbar tab + `Toggle` + `Picker` + divider)
2. **Provider config follows the hermes Settings → Provider API truth** (= List of 11 providers + status icon + "Paste X Key" prompt)
3. **Model settings follow the hermes Settings → Model truth** (= provider dropdown + model dropdown + reasoning effort dropdown + auxiliary model list)
4. **Replace bottom-bar placeholder strings only in the chat zone, not the other zones; do not replace directly on the parent component** (= revert the `ZoneBottomToolbar` global 6-zone replacement)

**Hermes source truth (apps/desktop/src/):**
- `providers-settings.tsx`: sidebar sub-nav + List of provider rows + status icon (`key.fill` green / `key` gray) + "Paste X Key" prompt
- `model-settings.tsx`: provider `Select` + model `Select` + Apply button + reasoning effort `EFFORT_VALUES = none / minimal / low / medium / high / xhigh` + auxiliary models `AUX_TASKS = vision / web_extract / compression / skills_hub / approval / mcp / title_generation / curator`
- No MoA (老板 8/21 evening ruled MOA is not done)
- Pages macOS 27 settings panel (authoritative reference)

**Blocked by:** None.

**Status:** ready-for-agent

## Fix specification (3 steps, satisfying principles 1 + 4)

### Step 1: Rebuild `SettingView` to Pages paradigm
- Top toolbar 3 tabs (`Tab` API macOS 15+): General / Providers / Model
- General tab (Pages paradigm):
  - "For New Documents" group: `Toggle` group
  - Default zoom level: `Picker`
  - Default font: `Toggle`
  - "Edit" group: `Toggle` group
  - Invisible elements: `Toggle`
  - "Add Media" group: `Toggle` group
  - Touch ID: `Toggle`
  - Author: `TextField` (boss enters their own name)
  - Text size: `Picker` "12 points"
- Providers tab (Hermes truth):
  - `SearchField` to search providers
  - `List` of all 11 `Provider`s (priority + name sort)
  - Each row: status icon (`key.fill` green / `key` gray) + provider.name + "Paste X Key" or existing-key preview
  - Tap a row → `ProviderKeyPrompt` opens an `NSWindow` sheet to enter the key (commit `a894d6a52` already installed)
- Model tab (Hermes truth):
  - Provider `Picker` (`Select` style)
  - Model `Picker` (`Select` style, `availableModels = ProviderFetcher.loadModelIds`)
  - "Apply" button → writes UserDefaults
  - Reasoning effort: `Picker` `low / medium / high / xhigh` (Hermes `EFFORT_VALUES` truth, boss 8/21 evening ruled MED truth, MOA not done)
  - Auxiliary models: `List` of `AUX_TASKS` = 8 entries, each row "Use primary model" + "Change" button (future work)

### Step 2: `ChatView` zone bottom bar replaces only the chat zone; other zones untouched
- Revert commit `55d3844d1` which replaced `ZoneBottomToolbar` entirely (= changed all 6 zones)
- Update `ZoneModule` to add slot-specific:
  - `.aiChat` → `ChatBottomToolbar` (model picker + context usage)
  - Other zones → `ZoneBottomToolbar` original version (placeholder strings)

### Step 3: Domain-modeling
- Add to `CONTEXT.md`:
  - `SettingView` Pages paradigm (new domain word)
  - `ProviderAuthStatus` enum (Hermes truth)
  - `ReasoningEffort` enum (`low` / `medium` / `high` / `xhigh`, Hermes `EFFORT_VALUES` truth)
  - `AuxTask` enum (`vision` / `web_extract` / … / `curator`, Hermes `AUX_TASKS` truth)

## Acceptance

- [ ] `SettingView` 3-tab Pages paradigm
- [ ] General tab content matches the Pages paradigm
- [ ] Providers tab: `List` of 11 providers + status icon + key prompt
- [ ] Model tab: provider + model + reasoning effort + auxiliary models
- [ ] `ZoneBottomToolbar` global 6-zone replacement reverted; only chat zone installs
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS verification: settings panel matches Pages + Hermes truth

## Out of scope (Q20 hard constraint)

- v0.20 LOGO + menubar
- v0.21 chat-streak tickets 02-06
- `Provider` / `ProviderKeychain` / `ProviderFetcher` / `ProviderCatalog`
- `ProviderKeyPrompt`
- `MiniMaxModelFetcher`
- `AppIcon.icon/`

## Apple HIG references

- https://developer.apple.com/documentation/swiftui/tabview
- https://developer.apple.com/documentation/swiftui/form
- https://developer.apple.com/documentation/swiftui/toggle
- https://developer.apple.com/documentation/swiftui/picker
- hermes apps/desktop/src/app/settings/providers-settings.tsx
- hermes apps/desktop/src/app/settings/model-settings.tsx
- Pages settings panel macOS 27

## References

- Depends on: none
- Required by: none
