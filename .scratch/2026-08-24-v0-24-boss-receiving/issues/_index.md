# v0.24 boss验收 — issues index

> Parent spec: `.scratch/2026-08-24-v0-24-boss-receiving/spec.md`.
> Po main flow step 2: 1 PR = 4 commits + 1 test commit. Each issue = 1 commit.

## Tickets (already done by boss + assistant)

| # | Commit | Ticket file | Status | Description |
|---|--------|-------------|--------|-------------|
| 015.001 | `aa7caca7f` | [`001-wenshu-llm-error-localized.md`](./001-wenshu-llm-error-localized.md) | **DONE** (boss) | SwiftUI 失败 path 显示 default error → 加 LocalizedError + 中文 errorDescription |
| 015.002 | `4f4a22f17` | [`002-keychain-34018-multi-provider-picker.md`](./002-keychain-34018-multi-provider-picker.md) | **DONE** (boss) | iOS-only `kSecUseDataProtectionKeychain` removed on macOS; ChatView fallback rewired to AvailableModelsDiscovery |
| 015.003 | `c83a131b2` | [`003-model-picker-no-model-placeholder.md`](./003-model-picker-no-model-placeholder.md) | **DONE** (boss, partial) | 4 default locations in App.swift set to '' + UI placeholder text |
| 015.004 | `0e306f6b4` | [`004-chatview-doc-drift-catch.md`](./004-chatview-doc-drift-catch.md) | **DONE** (assistant) | Boss's commit message claimed 4 locations fixed, only App.swift was — ChatView.swift was missed. Caught by regression test, fixed in this commit |
| 015.005 | `351704a08` | [`005-regression-tests.md`](./005-regression-tests.md) | **DONE** (assistant) | Tests for boss's 3 fixes + 2 doc-drift catches |

## Execution order (already happened)

1. Boss found bug 1 in UI → fix 015.001 (commit `aa7caca7f`)
2. Boss found bug 2 in UI → fix 015.002 (commit `4f4a22f17`)
3. Boss found bug 3 in UI → fix 015.003 (commit `c83a131b2`, partial — only App.swift)
4. Assistant reviewed commit 015.003 message vs diff → found doc drift
5. Assistant wrote regression tests (commit `351704a08`) — 2 tests caught the drift
6. Assistant fixed the drift (commit `0e306f6b4`) — ChatView.swift line 76 + 154

## Verification

- `swift test`: 584 / 80 suites pass (was 575 / 79, +9 tests)
- `swift build`: clean, 0 warnings
- 0 pollution leak in any commit
- Working tree clean
- Binary running (PID 49790, 10:25AM, includes all 4 fixes)

## Boss UI verification pending

1. Open WenshuApp (PID 49790 already running, or `open build/Wenshu.app`)
2. Model picker (bottom-left): "无模型可用" (not "MiniMax M3") ← boss v0.24 fix verify
3. Settings → Provider API → save key (no -34018 error) ← boss v0.24 fix verify
4. Chat "在?" → human error message (not generic Swift error) ← boss v0.24 fix verify
5. Configure key + chat → LLM call + sub-agent dispatch ← integration test

## Cross-references

- Acceptance checklist: `.scratch/2026-08-23-monday-acceptance-checklist/spec.md` §0.3 (binary launch) + §1.x (sub-agent dispatch)
- Monday handoff report: `.scratch/2026-08-23-monday-handoff-report.md` (commits at time of report = 64)
- Now at 69 commits (after 5 v0.24 commits: 3 boss + 2 assistant)
