# Session close — 2026-10-21 — upstream Matt Pocock skill restore

> Boss directives 2026-10-21 (rendered in English per rule 1.1): "enter the wenshu project, load the
> necessary skills", then "does building the missing skills conflict with the wenshu code or the other
> session", then "if it is a skill from the original Matt Pocock repo, install it", then "close out your
> session".
> Sessions: `20261021_092934_6c914f` (this one, desktop) + `20261020_112058_62887e` (parallel TUI, still live).
> Closure type: no production source changed. One profile-level skill install. Zero commits.

## 1. What this session did

| # | Action | Where | Repo impact |
|---|--------|-------|-------------|
| 1 | Loaded the AGENTS.md §0 chain | read-only | none |
| 2 | Diagnosed a live parallel session editing the same repo | read-only | none |
| 3 | Restored 38 upstream `mattpocock/skills` packages | `~/.hermes/profiles/pocock/skills/mattpocock/` | none (outside repo) |
| 4 | Recorded install path + 2 new pitfalls | `wenshu-pocock-workflow/SKILL.md` | none (outside repo) |

`git diff HEAD` inside the repo shows 51 files — **every one belongs to the parallel session**, not this one.

## 2. Upstream restore (= the deliverable)

Source of truth = `github.com/mattpocock/skills` (MIT, 298k stars, last push 2026-10-19). The original
local copy at `~/.hermes/profiles/pocock/skills/mattpocock/` was destroyed by the 2026-10-20 profile
reset and could not be recovered from any local backup, so the upstream repo was cloned and re-installed.

| Bucket | Count | Skills |
|--------|-------|--------|
| engineering | 20 | ask-matt, code-review, codebase-design, diagnosing-bugs, domain-modeling, grill-with-docs, implement, implement-spec, improve-codebase-architecture, pr, prototype, research, retro, setup-matt-pocock-skills, tdd, to-spec, to-tickets, triage, wayfinder, wizard |
| productivity | 7 | grill-me, grilling, handoff, teach, to-questionnaire, wait-what, writing-for-agents |
| in-progress | 7 | chief-of-staff, claude-handoff, loop-me, setup-ts-deep-modules, writing-beats, writing-fragments, writing-shape |
| misc | 4 | git-guardrails-claude-code, migrate-to-shoehorn, scaffold-exercises, setup-pre-commit |

Verified byte-identical to the upstream clone (`filecmp` over all 108 files). `skills_list` now reports 101
skills total; the 38 new entries carry categories `mattpocock/<bucket>`. Zero name collisions against
the 63 pre-existing profile skills (checked on both directory name and frontmatter `name:`).

Refresh command (= recorded in `wenshu-pocock-workflow/SKILL.md`):

```bash
git clone --depth 1 https://github.com/mattpocock/skills.git /tmp/mp
rsync -a --delete /tmp/mp/skills/ ~/.hermes/profiles/pocock/skills/mattpocock/
```

## 3. Open gaps (not fixed — boss decision)

### 3.1 Two locally-authored skills are unrecoverable

`AGENTS.md` §1 and §7.4 reference two skill names that **never existed upstream** (verified: `git log -S`
across the full upstream history returns zero hits). They were Wenshu-local packages, destroyed by the
same 2026-10-20 profile reset:

| Name | AGENTS.md role | Upstream equivalent now installed |
|------|----------------|-----------------------------------|
| `pocock-engineering-audit-existing` | §7.4 Standards axis (= 12 standards + 3 cross-cutting probes, per the archived 2026-09-24 audit report) | `code-review` (two-axis Standards + Spec) |
| `pocock-engineering-design-check` | §6.2 per-feature slot SSOT (= 12 engineering standards, per the archived v1.45 spec) | `codebase-design` (deep-module vocabulary) |

Functional coverage is supplied by the upstream equivalents, but the **names** no longer match the
`AGENTS.md` references. Per boss directive "if it cannot be recovered, forget it" they were not rebuilt, and `AGENTS.md`
was not edited (§10.1 = boss-triggered only).

### 3.2 Two rule enforcers named by AGENTS.md do not exist

| Rule | AGENTS.md says the enforcer is | Reality |
|------|-------------------------------|---------|
| 1.1 + 7.5 (no CJK) | `.hermes/cjk_comment_audit.txt` | **File does not exist.** Not wired into `.git/hooks/pre-commit`. Rule 1.1 currently has no automated enforcer. |
| 1.3 (no hedging vocabulary) | `wenshu-pollution-defense` | **No enforcer exists.** `Tools/wenshu-devtool/commit_filter.py` blocks only the rule-1.4 xianxia word list; the rule-1.3 hedge list (the 10 Chinese hedge words) is not checked anywhere. |

Both are real gaps found during this session, reported but not acted on (= no write into the repo).

### 3.3 Upstream `disable-model-invocation` is not honoured by Hermes

Upstream marks 23 of its 38 packages `disable-model-invocation: true` (= user-invoked only in the Claude
ecosystem). Hermes reads only `name` / `description` / `platforms` / `conditions` from frontmatter, so all
38 are model-invocable here. Invoke them by name to preserve upstream's intent.

## 4. Parallel session finding (= the operational risk of this repo right now)

`20261020_112058_62887e` (TUI, title "check wenshu for impact from the Hermes deletions", instruction "keep cleaning") has been live
since 2026-10-20 11:20 and was still running at closure (535 messages, last activity 10:17). It works the
**same repo** at the same time: it stages deletions, stashes, pops, commits, and resets in a loop.

Observed this session: `git status` went 8 → 50 → 0 → 51 files across a few minutes, with `git stash`
entries appearing and vanishing underfoot (`t9-ab-1` … `t9-ab-4`).

Its work = the dead-code sweep that deleted `PaneView` → `DynamicZoneView` → `TodoListView` → `TodoOps`,
plus `BookTodoStore` and `PaneTabBar`, extracting `PaneTrailingIconButton.swift` as the survivor.

**Rule for the next session:** before writing any file in this repo, confirm no other session is live.
Read `~/.hermes/profiles/pocock/logs/agent.log` and look for a session id other than your own, or query
`state.db` (`sessions` table) for rows whose `git_repo_root` is the wenshu root. Two recorded in
`wenshu-pocock-workflow/SKILL.md` pitfalls 9 and 10.

## 5. Repo state at closure

| Item | Value |
|------|-------|
| Branch | `main` |
| HEAD | `4c5b7748c` = `refactor(wenshu): delete the production types that only tests reach` |
| Working tree | 51 files changed — **all from the parallel session**, none from this one |
| `swift build` | exit 0 |
| `swift build --build-tests` | exit 0 |
| Commits by this session | **none** (= no repo file changed, per AGENTS.md 1.10 / 7.8 one-ticket-one-commit) |

## 6. Acceptance

| Criterion | Status |
|-----------|--------|
| Upstream skills installed and loading | YES (= 38 dirs, byte-identical to upstream clone, `skills_list` confirms) |
| Zero repo production source changed | YES |
| Zero commits created | YES (= nothing to commit) |
| `swift build` exit 0 | YES |
| `swift build --build-tests` exit 0 | YES |
| No name collision with pre-existing skills | YES (= checked on dir name + frontmatter name) |
| Curator will not archive the new skills | YES (= no `created_by: agent` record ⇒ unmanaged) |
| Gap 3.1 (2 local skills) resolved | NO (= unrecoverable, boss said to forget it) |
| Gap 3.2 (2 rule enforcers) resolved | NO (= reported, needs boss approval to write into repo) |
| Gap 3.3 (`disable-model-invocation`) resolved | NO (= Hermes platform limitation, not fixable in the skills) |

## 7. Suggested next session

1. Let the parallel session finish, then re-read this doc's §5 for the true tree state.
2. Boss decision needed on 3.2: build `.hermes/cjk_comment_audit.txt` + wire it into the pre-commit
   hook, and add the rule-1.3 hedge list to `commit_filter.py`. Both land in `Tools/wenshu-devtool/`
   and `.git/hooks/` — disjoint from the dead-code sweep the parallel session is running.
3. Boss decision needed on 3.1: either rebuild the two Wenshu-local skills under their original names,
   or amend `AGENTS.md` §1/§7.4 to name the upstream replacements (`code-review`, `codebase-design`).
   The latter is smaller and matches what the installed skills actually do.
