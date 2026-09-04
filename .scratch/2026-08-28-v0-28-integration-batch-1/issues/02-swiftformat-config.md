# Issue 02 — adopt `nicklockwood/SwiftFormat` 0.62.1 + add `.swift-format` config

> Parent spec: `.scratch/2026-08-28-v0-28-integration-batch-1/spec.md`

## What

Adopt SwiftFormat 0.62.1 (binary tool, Brewfile entry from issue 01) + add `.swift-format` config at repo root + integrate with pre-commit hook.

## Why

- AGENTS.md §11.1 approved SwiftFormat for engineering management.
- 2026-08-28-six-module-audit adopted at 0.62.1.
- No `.swift-format` config exists yet (= SwiftFormat defaults may not match wenshu conventions).

## Where to add

1. `.swift-format` at repo root (= SwiftFormat config):
   ```json
   {
     "indentWidth": 4,
     "tabWidth": 4,
     "maximumLineLength": 140,
     "lineBreakBeforeEachArgument": false,
     "indentConditionalCompilationBlocks": true,
     "respectsExistingLineBreaks": true,
     "rules": {
       "AllPublicDeclarationsHaveDocumentation": false,
       "AlwaysUseLowerCamelCase": true,
       "AmbiguousTrailingClosureOverload": true,
       "AvoidExcessiveParentheticalExpressions": true,
       "NoEmptyTrailingClosureParentheses": true,
       "UseShorthandTypeNames": true,
       "UseTripleSlashForDocumentationComments": true
     }
   }
   ```
2. Pre-commit hook `Tools/wenshu-devtool/hooks/pre-commit` (currently calls only `commit_filter.py`):
   - Add step: `swiftformat --lint Sources Tests` (lint-only at commit time, no auto-fix)
   - This is the standard pattern: format-on-save in IDE + lint-only in pre-commit (= no surprise rewrites)

## Acceptance criteria

- `.swift-format` exists with above config (= can be tweaked per repo needs)
- `swiftformat --lint Sources Tests` exits 0
- pre-commit hook runs swiftformat lint
- No auto-format applied (= user edits not silently rewritten)

## Test results

- PENDING

## UI verify (boss)

N/A — dev tooling only.

## Status: PENDING