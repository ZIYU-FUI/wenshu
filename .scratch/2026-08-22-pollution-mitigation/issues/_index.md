# Pollution mitigation issues index

> Parent spec: `.scratch/2026-08-22-pollution-mitigation/spec.md`.
> PR scope = 1 PR, 4 commits. Issue = 1 commit each.
>
> **STATUS (v0.23 audit update 2026-08-23)**: All 4 tickets SHIPPED on `wt/pollution-3-layer-defense`
> branch (commits `73dc59db7` rename / `d07627c69` system prompt / `8afe5c2fb` OutputKind /
> `5451d6376` pre-commit filter). Branch merged to `main` at `v0.07.2` tag.
> This index was stale ("pending" → actually "done"). Boss 8/23 audit spec #014 fix.

## Tickets (1 PR = 4 commits)

| # | Commit | Issue | Status | Depends on |
|---|--------|-------|--------|------------|
| 1 | Rename MiniMax* → Wenshu* + extract LLM types | `001-rename-minimax-to-wenshu.md` | **DONE** (commit `73dc59db7`) | — |
| 2 | WenshuVerifier system prompt + forbidden vocab | `002-wenshu-verifier-system-prompt.md` | **DONE** (commit `d07627c69`) | 1 |
| 3 | OutputKind enum + stop sequences on short output | `003-output-kind-stop-sequences.md` | **DONE** (commit `8afe5c2fb`) | 2 |
| 4 | Pre-commit filter script + install + tests | `004-pre-commit-filter.md` | **DONE** (commit `5451d6376`) | — |

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