# 005 — Tool security tests

> Parent spec: `.scratch/2026-08-23-agent-safety-guardrails/spec.md`.
> Depends on: 001 + 002 + 003 + 004.
> 1 commit. New test file.

## What to build

Comprehensive tests for the security guardrails.

## Implementation outline

**File**: `Tests/WenshuAppTests/Core/Tools/ToolSecurityTests.swift` (new)

Tests:
- `testPathDenyListBlocksSources` — Sources/ in path → denied
- `testPathDenyListBlocksTests` — Tests/ → denied
- `testPathDenyListBlocksScratch` — .scratch/ → denied
- `testPathDenyListBlocksHermes` — ~/.hermes/ → denied
- `testPathDenyListBlocksShellInit` — .zshrc → denied
- `testPathDenyListAllowsTmp` — /tmp/legit.txt → allowed
- `testPathDenyListStandardizesPath` — symlink resolution works
- `testFileWriteBlockedOnSources` — FileTools.write on Sources/ throws
- `testFileWriteSucceedsOnTmp` — FileTools.write on /tmp/ works
- `testProcessRunShellAlwaysThrows` — ProcessTools.runShell always throws
- `testConductorInvokeToolBlocksFileWrite` — invokeTool file.write returns blocked message
- `testConductorInvokeToolBlocksProcess` — invokeTool process returns blocked message
- `testConductorInvokeToolAllowsFileRead` — invokeTool file.read still works
- `testConductorInvokeToolAllowsWeb` — invokeTool web.extract still works
- `testIdentityPromptMentionsRestrictions` — main identity prompt has禁止 section
- `testAllSubAgentPromptsMentionRestrictions` — all 5 sub-agent prompts have禁止 section

## Acceptance criteria

- [ ] 16 tests pass
- [ ] swift test total: 380 + 16 = 396+