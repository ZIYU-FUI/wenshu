# Issue 05 — WenshuReadinessCheck

## What (= scope)

A startup readiness check that verifies wenshu's external dependencies before user interaction (=: chat = API key valid? / LLM Wiki = provider reachable? / image-gen = provider configured?). Returns an array of `ReadinessIssue` (= code + severity). Displayed in the Settings panel as a diagnostic banner.

Reference Card-master `assistant-readiness.ts` (= returns `assistantReadinessIssues` array; surfaced as a banner in the workbench).

## Why (= rationale)

Wenshu currently surfaces API failures only when user actually clicks chat. Better UX = check at startup, show banner.

## Apple-API-first check

- Custom code: `WenshuReadinessCheck.run() -> [ReadinessIssue]` (+ thin banner UI).
- Apple HIG candidate: SwiftUI `ContentUnavailableView` (= macOS 14+; Apple canonical empty / error state view).
- Apple coverage: full (= ContentUnavailableView covers the banner UI).
- LOC delta: ~150.
- Risk: low.

## Files touched

- `Sources/WenshuApp/AI/WenshuReadinessCheck.swift` (NEW): check runner.
- `Sources/WenshuApp/AI/WenshuReadinessProvider.swift` (NEW): protocol for each capability's readiness.
- `Sources/WenshuApp/App.swift`: invoke at app launch + show banner via `ContentUnavailableView` if any critical issue.

## Acceptance criteria

- [ ] `WenshuReadinessCheck.run` returns 0 issues when everything is configured.
- [ ] Returns specific issues for: missing API key (= chat), missing DashScope key (= image gen), unreachable provider endpoint.
- [ ] Banner appears at app launch when any critical issue exists.
- [ ] `ContentUnavailableView` is the banner UI (= Apple canonical).

## Dependencies

None.

## References

- Source: Card-master `src/ai/domain/assistant-readiness.ts`
- Spec: `.scratch/2026-09-02-card-master-port/spec.md` §3 item 5

First line: fact. Last line: fact.