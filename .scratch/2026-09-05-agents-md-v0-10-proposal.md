# AGENTS.md v0.10 proposal (= awaiting boss explicit approval)

> Side doc, NOT a write to `AGENTS.md` itself. `AGENTS.md` is a protected
> file; only an explicit human edit (= `patch` / `apply` / `git apply`
> after explicit boss `YES`) may mutate it. No field here is binding until
> the proposal is merged back into `AGENTS.md`.

Date authored: 2026-09-05 (CST). Author: pocock single agent.
Target file: `/Volumes/ANAN/Engineering/wenshu/AGENTS.md`.
Source of truth: this proposal file. Once applied, `AGENTS.md` becomes
the source of truth and this file moves to `.scratch/archive/`.

## §1 Status

- Proposal state: drafted; awaiting boss explicit approval.
- Blocking issue: the v0.37 ship packet bumped `AGENTS.md` to `v0.09.0`
  (= footer line 182), but the 2026-09-04/05 ship burst (= 167 commits
  across 13 stages per `.scratch/2026-09-05-today-retrospective.md`)
  has not been folded back into `AGENTS.md`. The safety rule on the
  protected file forces the proposal to land as a side doc first.
- Pending human action: boss reviews this file and decides `YES`
  (= apply) or `NO` (= hold for next batch).

## §2 Proposed diff

### §2.1 Line 12 (= version footer line)

Current (= shipped in v0.09.0 / 2026-09-03):

```
This file = wenshu project baseline + cross-role address hard constraint. Single agent (pocock profile) direct dialog with 老板. No dispatch, no board, no 6-role flow. Version 8/18拍 v0.07 (pocock single agent purified version).
```

Proposed (= v0.10):

```
This file = wenshu project baseline + cross-role address hard constraint. Single agent (pocock profile) direct dialog with 老板. No dispatch, no board, no 6-role flow. Version 8/18拍 v0.07 + 2026-09-04/05拍 v0.10 (pocock single agent purified version).
```

### §2.2 Final line (= current line 182)

Current:

```
*AGENTS.md v0.09.0 · 2026-09-03 pocock single agent · v0.37 ship packet (= hermes core translation complete + 11 port tickets + 7-connector BYOK + visual verify packet + 22 smoke tests + 175+ tests) + ADR-0013 v0.37 scope decisions + CHANGELOG.md v0.37 + Batch 1.1 test target cleanup (35 → 0 errors) + iron rule 6 compliance throughout (= no magic numbers in view code) · English-only · project root = /Volumes/ANAN/Engineering/wenshu/*
```

Proposed (= keep v0.09.0 verbatim, append v0.10.0 as a new final line):

```
*AGENTS.md v0.09.0 · 2026-09-03 pocock single agent · v0.37 ship packet (= hermes core translation complete + 11 port tickets + 7-connector BYOK + visual verify packet + 22 smoke tests + 175+ tests) + ADR-0013 v0.37 scope decisions + CHANGELOG.md v0.37 + Batch 1.1 test target cleanup (35 → 0 errors) + iron rule 6 compliance throughout (= no magic numbers in view code) · English-only · project root = /Volumes/ANAN/Engineering/wenshu/*
*AGENTS.md v0.10.0 · 2026-09-05 pocock single agent · v0.38 + v0.39 + v0.40 ship packets (= 167 commits across 13 stages 2026-09-04 → 2026-09-05 per retrospective at .scratch/2026-09-05-today-retrospective.md: ToolRegistry 1:1 port (= hermes tools/registry.py) + 12-tool migration + 5-surface Liquid Glass polish on macOS 27 + 5 specialized tools ports + 5 specialized tools wire-ups + HermesTodoStore deadlock fix + 22 smoke tests + 11-rule iron-rules sweep + 33-file B-03 historical CJK comment cleanup + verify-frontend.sh 14-item script + dead-pin cleanup of 10 zero-consumer third-party libs) + ADR-0008/0009/0013 retrospective ratifications + wenshu-side wins pattern for 5 hermes-overlap pairs per §11.3 + CHANGELOG.md v0.38 + INV-PUSH-1..7 + INV-BATCH-1..3 sequences + I18N-INLINE-001 (= 5 strings to Localizable.strings) · English-only · project root = /Volumes/ANAN/Engineering/wenshu/*
```

### §2.3 New § 13 (= v0.10 changes, appended after § 12)

Proposed (= appended AFTER current §12 cross-role expression hard
constraint, BEFORE the existing v0.09.0 footer line):

```
# §13 v0.10 changes (2026-09-04 → 2026-09-05 ship burst)

- Scope of the burst: 167 commits over 2 days (= 2026-09-04 and
  2026-09-05 CST). Commit-type breakdown: 101 feat(wenshu): + 22
  fix(wenshu): + 15 docs(wenshu): + 12 chore(wenshu): + 7 test(wenshu): +
  1 merge: (= counted via `git log --oneline --since=2026-09-04`).
- Comprehensive retrospective (= per-stage table, TL;DR, 14 frontend
  verification items, 6 boss dependencies) lives at
  `.scratch/2026-09-05-today-retrospective.md`. This section = short
  summary; the retrospective = ground truth.
- v0.38 ship packet: 22 smoke tests + 11 specialized tools port + wire-up
  tickets + HermesTodoStore DispatchQueue deadlock fix + Localizable.strings
  i18n groundwork + ContentEngine wire-up + INV-PUSH-5 historical CJK
  cleanup batch 1.
- v0.39 ship packet: out-of-scope deferred stub work (= drag-drop image /
  wiki-link / LaTeX / outline backlinks tabs; full implementation requires
  boss拍 per the ADR).
- v0.40 ship packet: ToolRegistry 1:1 port (= hermes tools/registry.py per
  boss OOB '1:1 复刻') + 12-tool migration to ToolRegistry.shared +
  5-surface Liquid Glass polish on macOS 27 (= TopBar + Sidebar + Editor
  + StatusBar + sheets/popovers/menus) + VERIFY-TOOLREGISTRY-004 e2e test
  + POLISH-LIQUIDGLASS-006 canonical Apple .glassEffect assertion test.
- Dead-pin cleanup (= DEAD-PIN-CLEANUP-001): removed 10 third-party libs
  with zero source consumers (= Defaults, KeyboardShortcuts, Nuke + NukeUI,
  ZIPFoundation, EPUBKit, SwiftGraph, Grape, MenuBarExtraAccess, Textual,
  swift-log). Approved runtime list (§11.1) unchanged; only the adoption
  status changed (= these 10 are now explicitly retired).
- Iron-rules sweep (= iron-rules-sweep-2026-09-05): 11-rule zero-config
  audit over 162 commits + 233 Swift files + 42,177 LOC. Result = 10 PASS
  + 1 FINDING (= Rule 2 typography in WIRE-PARAGRAPH-002; followup commit
  landed in INV-PUSH-7). Sweep is the basis for the §11 hard-rule
  compliance claim carried over from v0.09.
- ADR retrospective ratifications: ADR-0008 (= view-framework FORBIDDEN
  surface; self-implement drag UX), ADR-0009 (= wenshu-side wins pattern
  for hermes-port code-duplication-forbidden principle; 5 overlap pairs
  enumerated in §11.3), ADR-0013 (= v0.37/v0.38/v0.39/v0.40 scope
  decisions). No new ADRs authored in this burst; all decisions
  retroactively ratified.
- wenshu-side wins pattern (= §11.3): for the 5 hermes-overlap pairs
  (= tool_executor, credential_pool, memory_manager, skill_utils,
  conversation_loop), the existing wenshu Core module is the source of
  truth; the hermes-port is a thin adapter that delegates to it. Code
  duplication is forbidden. The 26 incomplete hermes modules (= 18
  ⚠️ partial + 8 ❌ missing per the gap audit at
  `.scratch/2026-09-04-hermes-port-gap-audit.md`) are tracked in the
  manifest and remain the work-tree to fill in.
- Frontend verification: verify-frontend.sh was authored and executed;
  14 items were marked verify-failed per the script's failure path
  (= wenshu.app did not appear within 30s in the headless run). Boss
  must launch + verify manually per the ticket brief's "Frontend
  verification dependency" note.
- B-03 historical CJK comment cleanup (= 33 files across 3 batches:
  INV-BATCH-2-A + INV-BATCH-2-B + INV-BATCH-3): every file in
  `Sources/WenshuApp/Core/Registry/` plus the largest view files (=
  WorkspaceView, NewLibraryOutlineView, BacklinkResolver,
  OutlineExtractor, LinkIndex, GraphBuilder, TemplateEngine, etc.).
  English-only per the §11 hard rule.

## §3 Acceptance (= apply procedure)

This proposal is accepted (= applied to `AGENTS.md`) only when the boss
issues one of the following explicit commands:

1. `echo YES | git apply --3way .scratch/2026-09-05-agents-md-v0-10-patch.diff`
   (= if a patch diff accompanies this proposal).
2. Manual edit: apply §2.1 + §2.2 + §2.3 of this proposal to
   `/Volumes/ANAN/Engineering/wenshu/AGENTS.md` (= line 12 version footer,
   new v0.10.0 footer line, and append § 13 v0.10 changes after § 12
   cross-role expression hard constraint).
3. `git am .scratch/2026-09-05-agents-md-v0-10.patch` (= if a mailbox
   patch accompanies this proposal).

After application: if a new burst ships (= 2026-09-06+), increment to
v0.11.0 with its own footer line. Do NOT skip v0.10.0 even if the next
burst lands within 24 hours (= each footer line is one burst's
attribution).

If the boss says `NO`: archive this file at
`.scratch/archive/2026-09-05-agents-md-v0-10-proposal.declined.md` with a
1-line note explaining the hold reason. Do NOT delete (= this file is
decision-history).

## §4 Hard rules confirmation (= UNCHANGED in v0.10)

The § 3 hard rules (= lines 3-10 of `AGENTS.md`) DO NOT change in v0.10.
v0.10 modifies only:

- line 12 (= version footer wording),
- the final footer lines (= append v0.10.0 entry after v0.09.0),
- new § 13 (= appended after § 12, before the existing footer lines).

The § 3 hard rules (= English-only / sole address "老板" / forbidden
neutral words / forbidden Chinese vocabulary / first-line-last-line
invariant) are unchanged and remain binding on every commit, comment,
prompt, `.scratch/` doc, `CONTEXT.md`, `README.md`, `CLAUDE.md`, and
every doc in this repo. The 2026-09-04/05 ship burst was audited for
hard-rule compliance in the iron-rules sweep (= 10 PASS + 1 FINDING,
followup landed in INV-PUSH-7). The v0.10 footer line inherits this
compliance claim.

## §5 Cross-references (= ground-truth sources)

| Claim | Source |
|---|---|
| 167 commits since 2026-09-04 | `git log --oneline --since=2026-09-04 \| wc -l` |
| Commit-type breakdown | `git log --oneline --since=2026-09-04 \| awk '{print $2}' \| sort \| uniq -c \| sort -rn` |
| Per-stage table | `.scratch/2026-09-05-today-retrospective.md` |
| Iron-rules sweep | commit `d6f91ddde` (= 10 PASS + 1 FINDING) |
| Iron-rules followup (= INV-PUSH-7) | commit `6ee3822d3` |
| ToolRegistry 1:1 port + migration + wire-up + e2e | commits `a1afdfa7a`, `5c4d7afd9`, `3df14566a`, `a5e215c8c` |
| Liquid Glass 5 surfaces | `950e46423`, `74b22f73a`, `be2bfc62d`, `dfd97d0e7`, `fe68fe2ee` |
| Liquid Glass canonical test | commit `fbf3bbe9d` |
| Dead-pin cleanup (= 10 libs) | commit `ec7691d44` |
| HermesTodoStore deadlock fix | commit `4b8b13786` |
| 22 smoke tests | commit `b23ec2358` |
| I18N-INLINE-001 | commit `9e289ba3a` |
| B-03 batches 1/2/3 | `7a194d6ec`, `94817beb8`, `0b8a3f668`, `e09fa7891`, `3fc23b0b7`, `e059f8c2b` |
| verify-frontend.sh | commit `245c3dfbf` |
| v0.38 CHANGELOG entry + banner | commit `2ef3a7743` |
| INV-PUSH-2/3/4 stubs/specs | `6ee7073eb`, `24e42518b`, `83adaf60e` |
| Hermes gap audit | `.scratch/2026-09-04-hermes-port-gap-audit.md` |
| Hermes port manifest | `.scratch/2026-09-03-hermes-core-translation/hermes-port-manifest.md` |
| Hermes core translation spec | `.scratch/2026-09-03-hermes-core-translation/spec.md` |
| wenshu-side wins (§ 11.3) | lines 91-173 of `AGENTS.md` (= no edit in v0.10) |

End of proposal. Apply only after boss explicit approval.
First line of every doc = fact. Last line of every doc = fact.