<!--
Thanks for contributing to wenshu (文枢)!

Before opening a PR, make sure:

1. Branch hygiene:
   - Branch name pattern: `wt/<feature-name>` (e.g. wt/multi-agent-dispatch)
   - 1 commit per ticket / 1 ticket per PR
   - Rebased onto latest `main` before merge

2. Commit message format:
   - First line: `<type>(wenshu): <subject>` (max 72 chars)
   - type: feat | fix | docs | test | refactor | chore | perf | build
   - Subject: English only, no Chinese characters
   - Blank line, then body explaining WHY (not WHAT)
   - Last line: `Code-review axes: Standards + Spec`

3. Pollution check:
   - Run `git diff --cached` and grep for `修真|渡劫|筑基|返虚|结丹|金丹|元婴|飞升|天劫|雷劫|心魔|魔障`
   - Pre-commit hook auto-blocks these

4. Tests:
   - `swift build` clean
   - `swift test` pass (current count in commit body)
   - New tests for new features

5. Spec sync:
   - If your change touches public API, update CONTEXT.md
   - If your change introduces new module, add .scratch/<date>-<feature>/

6. Domain modeling (po main flow):
   - Per `mattpocock/engineering/wayfinder` skill: spec → tickets → implement → review → domain-model
   - For each new feature, add CONTEXT.md entry with class name + 1-line definition + ADR pointer

7. Boss拍板 protocol:
   - If scope creep, surface to boss via kanban comment + commit body
   - If multi-decision, ask via clarify before implementing
-->
## What does this PR do?

<!-- 1-3 sentence summary -->

## Why is this change needed?

<!-- Link to ticket / issue. What problem does it solve? -->

## How does it work?

<!-- Implementation notes (high-level). What changed? -->

## How to verify?

<!-- Step-by-step. What commands to run. What to look for. -->

## Risk assessment

<!-- What could break? How to recover? -->

## Boss拍板 verification

<!-- If boss needs to confirm something, list here. -->

## Pollution check (auto-blocked by pre-commit hook)

- [ ] No 修真/渡劫/筑基/返虚/结丹/金丹/元婴/飞升/天劫/雷劫/心魔/魔障 in commit message or diff
- [ ] All English (no CJK characters outside AGENTS.md §12 allowlist)

## Tests

- [ ] `swift build` clean
- [ ] `swift test` X pass in Y suites (current: 574 / 79)

## Domain modeling

- [ ] CONTEXT.md entry added (if new public API)
- [ ] ADR pointer (commit SHA or spec filename)

<!-- Code-review axes (per po main flow):
- Standards: code style, naming conventions, file organization, dependency choices
- Spec: spec/code alignment, ticket acceptance criteria met, ticket commits per pair
-->