# Ticket 015.004 — ChatView.swift doc drift catch (line 76 + 154)

> Parent spec: `.scratch/2026-08-24-v0-24-boss-receiving/spec.md` Bug 3 (doc drift).
> Implementation commit: `0e306f6b4` (assistant).
> Po main flow: implement (assistant) + code-review (in commit body) + domain-modeling (in CONTEXT.md) + confirm (boss UI verify).

## Background

Boss commit `c83a131b2` (ticket 015.003) commit message claimed:

> 4 default locations changed:
> - App.swift line 1282: Settings page default
> - App.swift line 1348: model menu text
> - ChatView.swift line 72: ChatViewModel default
> - ChatView.swift line 149: send() fallback

Reality: diff only modified `Sources/WenshuApp/App.swift`. `ChatView.swift` was NOT actually fixed.

Assistant caught via regression test `ChatView.swift ChatViewModel.currentModel default = '' (NOT YET FIXED)` in commit `351704a08` (test was failing as expected).

## Acceptance criteria

- [x] ChatView.swift:76 ChatViewModel `currentModel: String = UserDefaults... ?? ""` (was `?? WenshuLLMModel.m3.rawValue`)
- [x] ChatView.swift:154 send() fallback `?? ""` (was `?? "MiniMax-M3"`)
- [x] Regression test 'ChatView.swift ChatViewModel.currentModel default' now PASSES
- [x] Regression test 'ChatView.swift send() fallback uses empty string' now PASSES
- [x] swift test: PASS (584/80)
- [x] swift build: clean (0 warnings)
- [x] 0 pollution leak

## Test results (before fix)

```
❌ ChatView.swift ChatViewModel.currentModel default = '' (NOT YET FIXED)   FAIL
❌ ChatView.swift send() fallback uses empty string (NOT YET FIXED)         FAIL
```

## Test results (after fix)

```
✅ ChatView.swift ChatViewModel.currentModel default = '' (NOT YET FIXED)   PASS
✅ ChatView.swift send() fallback uses empty string (NOT YET FIXED)         PASS
```

## UI verify (boss)

Same as ticket 015.003 — verify "无模型可用" appears in BOTH App.swift model picker AND ChatView.swift's ChatViewModel currentModel fallback (when chat input is open).

## Risk

- Low: same change as ticket 015.003 (just 2 more default value changes).
- Boss may want to consolidate into 015.003 (single commit). Acceptable as separate ticket for traceability.

## Files changed

- `Sources/WenshuApp/Views/Chat/ChatView.swift` — 2 default value changes (line 76 + 154)

## Status: ✅ DONE (assistant commit + tests + verified)
## Process note: this doc drift was caught by regression test, not by manual review. Future fix: add CI check that compares commit message "files changed" count vs actual `git show --stat` count.
