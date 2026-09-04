---
name: Wenshu bug report
about: Report a bug or crash in wenshu (文枢)
title: "[BUG] "
labels: bug
assignees: ''
---

<!--
Wenshu bug report template.
Boss拍板 protocol: 1 bug 1 ticket. Reproduce locally before opening issue.
-->

## Bug summary

<!-- 1 sentence: what's broken -->

## How to reproduce

<!-- Step-by-step. Numbered list. -->

## Expected behavior

<!-- What should happen -->

## Actual behavior

<!-- What actually happens. Include error message if any. -->

## Environment

- wenshu version: `git describe --tags` or commit SHA
- macOS version: `sw_vers`
- Branch: `git branch --show-current`
- LLM provider: minimax-cn / anthropic / openai / other
- LLM model: M3 / claude-sonnet / gpt-4o / other
- API key status: configured / not configured

## Logs / Screenshots

<!-- Paste console output, attach screenshot, etc. -->

## Pollution check

- [ ] Not caused by forbidden vocab (修真/渡劫/etc.) — verified by `git log --all -p | grep -E "修真|渡劫"`
- [ ] Not a hallucination from LLM (use system prompt to constrain)

## Priority (boss拍)

- [ ] HIGH — app crash / data loss / security issue
- [ ] MED — broken feature / wrong behavior
- [ ] LOW — typo / minor UX / cosmetic

## Related

<!-- Link to issue / ticket / commit. -->