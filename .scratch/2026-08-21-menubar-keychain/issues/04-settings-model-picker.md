# 04 — Settings: add a model-configuration Picker (hide the configured value)

**What to build:**
老板 2026-08-21 macOS verification feedback: "add a model-configuration feature inside Settings. After configuring it, hide the display." The current `App.swift` `Settings { ... }` Scene only has an "Appearance" Picker; no model configuration. The current `MiniMaxVerifier` model is hardcoded to `"MiniMax-M3"`; once 老板 verifies, it can't be changed.

Fix: add `Picker("Model", selection: $model)` to the Settings Scene, listing the 3 default MiniMax models (`MiniMax-M3` / `MiniMax-M2` / `MiniMax-Reasoning`); persist the choice with `@AppStorage("wenshu.llm.model")`. **Do not display the current model name** (老板 verbatim: "after configuring, hide the display"). `MiniMaxVerifier.init` reads `@AppStorage`, with env var taking priority.

**Blocked by:** None.

**Status:** ready-for-agent

## Fix specification (4 steps)

1. In `App.swift`'s `Settings { ... }` Scene, add:
   - `@AppStorage("wenshu.llm.model") private var llmModel: String = "MiniMax-M3"`
   - `Picker("Model", selection: $llmModel) { ForEach(MiniMaxModel.allCases) { Text($0.label).tag($0.rawValue) } }` (don't display the current-value label)
2. Add `Sources/WenshuApp/Core/Agent/MiniMaxModel.swift` (the source-of-truth enum):
   - `case m3 = "MiniMax-M3"`
   - `case m2 = "MiniMax-M2"`
   - `case reasoning = "MiniMax-Reasoning"`
   - `var label: String { switch self { case .m3: "MiniMax-M3" ... } }`
3. Add a `model` parameter to `MiniMaxVerifier.init` (default `MiniMax-M3`); `applicationDidFinishLaunching` reads `@AppStorage("wenshu.llm.model")` and injects it.
4. 老板 macOS verification: open ⌘, → see the "Model" Picker → pick one → close → reopen Settings → the current model is no longer displayed (hidden).

## Acceptance

- [ ] `MiniMaxModel` enum with 3 cases
- [ ] `App.swift` Settings Scene has the new Picker (no current-value label)
- [ ] `@AppStorage("wenshu.llm.model")` persists
- [ ] `MiniMaxVerifier.init` accepts a `model` parameter (default `MiniMax-M3`)
- [ ] `swift build` exit 0
- [ ] `swift test` exit 0
- [ ] 老板 macOS verification: after configuring, the model name is not displayed (hidden)

## Out of scope (Q20 hard constraint)

- v0.20 tickets 04 + 05 (LOGO untouched)
- v0.21 chat streak tickets 02-06 (already committed; untouched)
- The existing "Appearance" Picker inside `App.swift` L188 Settings Scene (kept)
- `AppIcon.icon/` (老板 ruled: leave it for now)

## Apple HIG references

- https://developer.apple.com/documentation/swiftui/picker
- https://developer.apple.com/documentation/swiftui/settings (Settings Scene truth)
- https://developer.apple.com/documentation/swiftui/appstorage
- CLAUDE.md L42 "LLM key stored in macOS Keychain — not in files, not in logs, not in commits"

## References

- Depends on: none
- Required by: ticket 02 (LLM Keychain) — `MiniMaxVerifier`'s `model` field pairs with ticket 02's Keychain integration
