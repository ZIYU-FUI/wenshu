# 003 — unlock AGENTS.md §11 + Package.swift baseline + skill recipe

First line = fact. Last line = fact.

## goal

Reflect owner 2026-08-26 unlock decision in the project's persisted baseline (= `Package.swift`, AGENTS.md audit + cross-check, and the wenshu workflow skill recipes). This is a docs-only ticket (= no source code change). Folded separately from 001 so the baseline shift is revertable without touching the icon layer.

## discoveries (= scope shrinkage)

Issue 003 was originally scoped to update `AGENTS.md §11` line-level wording and the `wenshu-pocock-workflow` skill. The audit (= `grep -n "third.party\|third-party\|第三方\|SDK\|no.+\.dep" AGENTS.md Package.swift CLAUDE.md README.md`) found no explicit "no third-party SDK" ban in `AGENTS.md §11` or anywhere in `CLAUDE.md` or `README.md` — the only place that lock existed was a comment inside `Package.swift:21`. As a result:

- `Package.swift` was already unlocked as part of ticket 001's dep change (comment rewritten to acknowledge the owner grill gate).
- `AGENTS.md §11` has no wording to change (= the section lists the project's technical baseline, not explicit SDK ban). An entry is added (= see deliverables) to record the unlock decision so future contributors know the rule.
- `CLAUDE.md` and `README.md` contain only LLM-framework / stdlib / HTTP-client style bans (= unaffected by Lucide since Lucide is not an LLM framework, ORM, HTTP client, or JSON parser).
- `wenshu-pocock-workflow` skill does not have a `wenshu-pocock-workflow/SKILL.md` on disk (= only `wenshu-hermes-replica-workflow/SKILL.md` and `wenshu-visual-alignment/SKILL.md` exist). The latter is updated with the SDK-grill rule.

Net result = ticket 003 shrinks to: (1) one new bullet in `AGENTS.md §11`, (2) one new bullet in `wenshu-hermes-replica-workflow` skill §"不变 (锁住的事)", (3) audit-log findings committed as evidence.

## deliverables

1. `AGENTS.md §11` — one new bullet recording the unlock rule. The bullet text:
   - "Third-party deps (= SPM packages) are allowed when owner-approved via grill (= owner 2026-08-26 grill, see `.scratch/2026-08-26-lucide-icon-migration/`). ANAN does not silently add SDKs. First applied = `bring-shrubbery/lucide-swift 1.25.0` (v0.25 ticket 001)."
2. `wenshu-hermes-replica-workflow` skill §"不变 (锁住的事)" — one new bullet recording the SDK-grill rule, so future migration streaks that aim to introduce third-party SDKs (= e.g. for icon libs, JSON parsers, ORMs, HTTP clients) do so with owner sign-off.
3. Audit log entry — this very section of the issue 003 doc captures the grep evidence and the decisions (= no AGENTS.md §11 wording change needed for the icon-library case because §11 didn't carry an SDK ban in the first place; Package.swift comment updated in 001).

## acceptance

- `grep -n '2026-08-26' AGENTS.md` returns at least 1 hit (= the §11 bullet references the owner-grill date).
- `grep -n '2026-08-26' ~/.hermes/profiles/pocock/skills/engineering/wenshu-hermes-replica-workflow/SKILL.md` returns at least 1 hit (= the skill references the owner-grill date).
- `grep -n 'no third-party' AGENTS.md Package.swift` returns no matches (= both files clean of the old ban phrasing; `Package.swift` already clean since ticket 001).
- No build touched; no source file edited outside `AGENTS.md` and the skill path.

## acceptance

- `grep -n 'no third-party' AGENTS.md Package.swift` returns no matches (= both files updated).
- `grep -n '2026-08-26' AGENTS.md Package.swift ~/.hermes/profiles/pocock/skills/engineering/wenshu-pocock-workflow/SKILL.md` returns at least 3 hits (= the decision is recorded in 3 places).
- No build touched; no source file edited outside AGENTS.md / Package.swift comment / the skill path.

## risks

- **Missed baseline path**: there may be other files (= CLAUDE.md, README.md, `.scratch/` docs) that mention the SDK ban. Run a project-wide grep first to enumerate every site that needs updating.
- **Cross-profile skill edit**: `~/.hermes/profiles/pocock/...` belongs to the active profile; if any reference to "no 第三方 SDK" lives outside pocock (e.g. in `default` profile or shared skills), ANAN must escalate to owner before touching it.

## source of truth

- spec: `/Volumes/ANAN/Engineering/wenshu/.scratch/2026-08-26-lucide-icon-migration/spec.md` §3
- decisions: owner 2026-08-26 grill (locked in user memory + this file)

The docs reflect the owner 2026-08-26 baseline unlock after ticket 003.
