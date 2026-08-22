# Pollution mitigation issues index

> Parent spec: `.scratch/2026-08-22-pollution-mitigation/spec.md`.
> PR scope = 1 PR, 4 commits. Issue = 1 commit each.

## Tickets (1 PR = 4 commits)

| # | Commit | Issue | Status | Depends on |
|---|--------|-------|--------|------------|
| 1 | Rename MiniMax* → Wenshu* + extract LLM types | `001-rename-minimax-to-wenshu.md` | pending | — |
| 2 | WenshuVerifier system prompt + forbidden vocab | `002-wenshu-verifier-system-prompt.md` | pending | 1 |
| 3 | OutputKind enum + stop sequences on short output | `003-output-kind-stop-sequences.md` | pending | 2 |
| 4 | Pre-commit filter script + install + tests | `004-pre-commit-filter.md` | pending | — |

## Execution order

1. Issue 001 (rename) — first commit.
2. Issue 002 (system prompt) — second commit, depends on 001.
3. Issue 003 (OutputKind + stop_sequences) — third commit, depends on 002.
4. Issue 004 (pre-commit filter) — independent, can be merged in any order. Landed last for PR cohesion (defense layers grouped).

All 4 on branch `wt/pollution-3-layer-defense` → 1 PR → merge.

## Blocking edges

- 002 blocked by 001 (rename must land first so commit message references `WenshuVerifier`, not `MiniMaxVerifier`).
- 003 blocked by 002 (system prompt constant must exist before stop_sequences logic).

001 and 004 are independent entry points but follow sequential commit order for review clarity.

## Post-merge follow-up tickets (NOT in this PR)

- Ticket E — `CONTEXT.md` glossary entry for `**ForbiddenVocabularyPolicy**` + ADR `0008-pollution-3-layer-defense.md`. Doc-only, separate PR.
- Ticket D — CI integration of `commit_filter.py` (no CI today).
- Historical git log cleanup — out of scope, escalate to 老板.