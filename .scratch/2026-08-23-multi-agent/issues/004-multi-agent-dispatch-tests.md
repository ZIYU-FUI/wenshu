# 004 — Multi-agent dispatch tests (TaskGroup + Auditor + cost)

> Parent spec: `.scratch/2026-08-23-multi-agent/spec.md`.
> Depends on: 001 + 002 + 003.
> 1 commit. New test file.

## What to build

Comprehensive tests for the multi-agent dispatch system.

## Implementation outline

**File**: `Tests/WenshuAppTests/Core/Agent/MultiAgentDispatchTests.swift` (new)

Tests:
- `testIntentClassifyReturnsValidAgent` — returns 1-3 sub-agent names
- `testParallelDispatchTiming` — 2 sub-agents finish in ~time of 1
- `testAuditorRunsAfterWriter` — auditor fires when writer in selection
- `testAuditorSkippedWhenOnlyResearcher` — no auditor for researcher-only
- `testSynthesisIncludesAllOutputs` — synthesis prompt contains sub-agent + auditor results
- `testSubAgentSystemPromptsDiffer` — researcher ≠ writer ≠ analyst ≠ ...
- `testAuditorVerdictFormat` — auditor returns valid JSON {verdict, issues, confidence}
- `testGracefulDegradation` — 1 sub-agent fail doesn't kill others

## Acceptance criteria

- [ ] 8 tests pass
- [ ] swift test total: 348 + 8 = 356+
- [ ] Code-review 2 axes

## Out of Scope

- Network calls (LLM is mocked / dev env skipped per existing pattern)
- Token cost assertion (too brittle)