# Issue 002 · Defer CronjobTools (= mark as intentionally unwired)

**Ticket**: 002-defer-cronjobtools
**Scope**: 1 file (= source comment update only)
**Methodology**: Q112 (1 ticket 1 commit 1 file)

## Problem

`Sources/WenshuApp/Core/Agent/Cron/CronjobTools.swift` (= 1:1 port of hermes `tools/cronjob_tools.py` 1,137 LOC, shipped in HERMES-PARTIAL-010) defines the canonical LLM-facing cron dispatcher with 8 actions (create / list / get / update / remove / pause / resume / run-now / history). **No Tool wrapper exists**.

## Decision (per spec.md §Acceptance)

**Defer.** Per boss 2026-09-04 OOB 'A' + `AGENTS.md §11.2`:
- wenshu cron = Apple HIG macOS LaunchAgent (= wenshu-side wins per §11.3)
- NOT hermes's cross-process claim/lock
- LLM-side cron dispatcher is over-engineering for v0.73
- wenshu cron runs at OS level; user can `launchctl list` to inspect, no need for LLM to manage

## Plan

### 1. Update file: `Sources/WenshuApp/Core/Agent/Cron/CronjobTools.swift`

Add a doc-comment header block at the top of the file (= the existing `HERMES-PARTIAL-010` comment is already there; = extend it):

```
//
//  DEFERRED (v0.73 spec decision):
//  This 1:1 port of hermes `tools/cronjob_tools.py` is intentionally NOT
//  wired into ToolRegistry (= see .scratch/v0.73-hermes-agent-wiring-gap/spec.md
//  §Acceptance row "CronjobTools"). Wenshu cron runs at OS level via LaunchAgent
//  per AGENTS.md §11.2; LLM-side cron dispatcher is over-engineering.
//  Future ticket (= v0.74+) may wire it IF the user requests cron-via-chat.
//
//  This file is NOT dead code (= per Q57: 3rd-party verdict ≠ authority);
//  it documents the deferred surface and remains as a reference for future work.
//
```

No code change. No Tool class. No tests.

## Files changed

- `Sources/WenshuApp/Core/Agent/Cron/CronjobTools.swift` (+8 lines doc-comment)

## Commit message template

```
docs(wenshu): mark CronjobTools as deferred per v0.73 spec

- Per .scratch/v0.73-hermes-agent-wiring-gap/spec.md §Acceptance
- Wenshu cron = Apple HIG LaunchAgent per AGENTS.md §11.2 (= wenshu-side wins)
- LLM-side cron dispatcher is over-engineering for v0.73
- File remains as documented future work (= NOT deleted per Q57)

Refs: .scratch/v0.73-hermes-agent-wiring-gap/spec.md
Ticket: 002-defer-cronjobtools
```

## Acceptance

- [ ] `swift build` = BUILD COMPLETE (no code change)
- [ ] Doc-comment header present + verbatim matches template above
- [ ] Code-review 双轴 = Standards pass + Spec pass (= doc-only ticket)

## Out-of-scope

- Deletion (= NEVER delete hermes-port files per Q57)
- Wrapping in a Tool class (= explicitly out-of-scope per spec)
- Wenshu-side cron UI (= separate ticket, future work)