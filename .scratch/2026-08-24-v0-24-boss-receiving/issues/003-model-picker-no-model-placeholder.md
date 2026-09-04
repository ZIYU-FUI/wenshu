# Ticket 015.003 — Model picker "无模型可用" (App.swift only)

> Parent spec: `.scratch/2026-08-24-v0-24-boss-receiving/spec.md` Bug 3.
> Implementation commit: `c83a131b2` (boss, App.swift only).
> Po main flow: implement (boss done) + code-review (in commit body) + domain-modeling (in CONTEXT.md) + confirm (boss UI verify).

## Acceptance criteria

- [x] App.swift:222 SettingView `llmModel: String = ""` (was `WenshuLLMModel.m3.rawValue`)
- [x] App.swift:1281 ChatZoneView `currentModel: String = ""` (was `WenshuLLMModel.m3.rawValue`)
- [x] App.swift:1349 model menu text: `Text(currentModel.isEmpty ? "无模型可用" : ModelDisplay.lookup(currentModel).display)`
- [x] App.swift:1358 fallback section: skip when `currentModel.isEmpty` (no fallback section, "无模型可用" shown alone)
- [x] Tests added (3 in `ChatViewModelDefaultModelTests.swift`)
- [x] swift test: PASS (584/80)
- [x] swift build: clean (0 warnings)
- [x] 0 pollution leak

## Test results

```
✅ App.swift SettingView.llmModel default = '' when no UserDefaults          PASS
✅ App.swift ChatZoneView.currentModel default = '' when no UserDefaults     PASS
✅ App.swift model menu text shows '无模型可用' when currentModel empty     PASS
```

## UI verify (boss)

1. Open WenshuApp (no key configured)
2. Check bottom-left model picker text
3. Old: "MiniMax M3" (hardcoded)
4. New: "无模型可用" (literal: "no model available")

## Risk

- Low: just changes default values + adds UI placeholder text.
- When user configures key + selects model, currentModel is set → "无模型可用" replaced by selected model display.
- Tests are static source code checks (since SwiftUI `Text(...)` is hard to test directly).

## Files changed

- `Sources/WenshuApp/App.swift` — 4 default locations + UI text

## Status: ✅ DONE (boss commit App.swift + tests)
## Note: ChatView.swift line 76 + 154 NOT fixed in this commit (doc drift) — see ticket 015.004
