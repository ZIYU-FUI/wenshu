# Ticket 015.005 — Regression tests for v0.24 boss接收

> Parent spec: `.scratch/2026-08-24-v0-24-boss-receiving/spec.md`.
> Implementation commit: `351704a08` (assistant).
> Po main flow: implement + code-review (in commit body) + domain-modeling + confirm.

## Acceptance criteria

- [x] 9 tests added in `Tests/WenshuAppTests/Views/Chat/ChatViewModelDefaultModelTests.swift`
- [x] 4 tests cover boss's 3 fixes (WenshuLLMError × 3 + Keychain × 1)
- [x] 3 tests cover App.swift model picker fix
- [x] 2 tests catch ChatView.swift doc drift (initially failed → now passing)
- [x] swift test: PASS (584/80)
- [x] swift build: clean (0 warnings)
- [x] 0 pollution leak

## Test breakdown

| # | Test | Verifies | Result |
|---|------|----------|--------|
| 1 | `WenshuLLMError conforms to LocalizedError` | boss fix 015.001 | ✅ PASS |
| 2 | `WenshuLLMError.invalidBaseURL has human description` | boss fix 015.001 | ✅ PASS |
| 3 | `WenshuLLMError.httpError includes status code` | boss fix 015.001 | ✅ PASS |
| 4 | `Keychain -34018 handling: graceful error` | boss fix 015.002 | ✅ PASS |
| 5 | `App.swift SettingView.llmModel default = ''` | boss fix 015.003 | ✅ PASS |
| 6 | `App.swift ChatZoneView.currentModel default = ''` | boss fix 015.003 | ✅ PASS |
| 7 | `App.swift model menu text shows '无模型可用'` | boss fix 015.003 | ✅ PASS |
| 8 | `ChatView.swift ChatViewModel.currentModel default = ''` | drift catch 015.004 | ✅ PASS (after fix) |
| 9 | `ChatView.swift send() fallback uses empty string` | drift catch 015.004 | ✅ PASS (after fix) |

## Approach

Tests are static source code checks (read file + grep for patterns) rather than runtime SwiftUI tests, because:
1. SwiftUI `Text(...)` and `@AppStorage` defaults are hard to test directly without complex harness
2. Source code checks are deterministic and don't require entitlements / running app
3. Catch the actual issue (commit message vs actual diff) by verifying both files match the boss's intent

## Risk

- Low: tests are read-only operations on source files.
- Test fragility: if App.swift / ChatView.swift line numbers change, tests need updates. Tests check for `contains("...")` patterns, not line numbers.

## Files added

- `Tests/WenshuAppTests/Views/Chat/ChatViewModelDefaultModelTests.swift` — 9 tests in 1 suite

## Status: ✅ DONE (assistant commit + tests)
