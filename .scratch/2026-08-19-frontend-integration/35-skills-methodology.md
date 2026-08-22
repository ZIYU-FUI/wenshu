# Spec — 35 po god methodology truth (老板 2026-08-20 拍 'load god's full development chain')

> Date: 2026-08-20
> 老板 2026-08-20 拍 "load god's full development chain, load methodology"
> Truth source: `~/.hermes/profiles/pocock/skills/mattpocock/` (35 SKILL.md)

## Problem Statement

老板 拍: wenshu replica work should load 35 po god skills, full-chain development methodology.

## 35 po god skills full table (4 buckets)

### engineering/ (18 promoted skills, main flow)

| # | Skill | Methodology summary |
|---|---|---|
| 1 | **ask-matt** | Routing skill — ask which skill / which flow fits the current situation |
| 2 | **code-review** | Two-axis review: Standards (code follows repo standards) + Spec (code matches issue/spec). Run 2 parallel sub-agent reports |
| 3 | **codebase-design** | Deep module shared vocabulary — design / improve module interfaces + find deepening opportunities + find seams + make code more testable / AI-navigable |
| 4 | **diagnosing-bugs** | Hard bug / performance regression diagnosis loop — user says "diagnose/debug" or "broken/throw/failing/slow" |
| 5 | **domain-modeling** | Build / sharpen project domain model — pin down domain terminology + record ADRs |
| 6 | **grill-with-docs** | Strict interview sharpen plan / design, synchronously create docs (ADR + glossary) |
| 7 | **implement** | Implement work per spec / ticket |
| 8 | **improve-codebase-architecture** | Scan find deepening opportunities, visualize HTML report, grill pick 1 |
| 9 | **prototype** | One-off prototype to validate design questions (state model / UI) |
| 10 | **research** | Investigate questions, grab high-trust primary sources, write markdown |
| 11 | **resolving-merge-conflicts** | Resolve in-progress git merge / rebase conflicts |
| 12 | **setup-matt-pocock-skills** | Configure repo with 35 skills — first run (set issue tracker + triage words + domain doc layout) |
| 13 | **tdd** | TDD — user says "test-first" / "red-green-refactor" / wants integration test |
| 14 | **to-spec** | Convert current conversation to spec + publish to project issue tracker — no interview, only synthesize already discussed |
| 15 | **to-tickets** | Break plan / spec / conversation into tracer-bullet tickets — each ticket declares blocking edges |
| 16 | **triage** | Issue / external PR through triage state machine — categorize + verify + grill if needed + write agent-ready brief |
| 17 | **wayfinder** | Plan huge work (>1 session capacity) — shared map of decision tickets, solve 1 at a time |
| 18 | **wizard** | Interactive bash wizard guides human through steps agents can't do (provision infra / set credentials / navigate unfamiliar dashboard / one-off migration) |

### productivity/ (7 promoted skills, general)

| # | Skill | Methodology summary |
|---|---|---|
| 1 | **grill-me** | Strict interview sharpen plan / design |
| 2 | **grilling** | User says "grill" triggers strict grill |
| 3 | **handoff** | Compress current conversation into handoff doc for another agent |
| 4 | **teach** | Teach user 1 new skill / concept within the workspace |
| 5 | **to-questionnaire** | Convert unanswerable decisions to questionnaire for others to fill |
| 6 | **wait-what** | Stop. Last message didn't land — resend |
| 7 | **writing-for-agents** | Write documents for agents — create / edit skills, modify AGENTS.md / CLAUDE.md |

### misc/ (4 skills, archived)

| # | Skill | Methodology summary |
|---|---|---|
| 1 | **git-guardrails-claude-code** | Set Claude Code hooks to block dangerous git commands (push / reset --hard / clean / branch -D etc.) |
| 2 | **migrate-to-shoehorn** | Migrate test files from `as` to `@total-typescript/shoehorn` |
| 3 | **scaffold-exercises** | Create exercise directory structures (sections / problems / solutions / explainers) |
| 4 | **setup-pre-commit** | Set Husky pre-commit + lint-staged (Prettier) + type check + test |

### in-progress/ (6 skills, beta)

| # | Skill | Methodology summary |
|---|---|---|
| 1 | **claude-handoff** | Hand current conversation to fresh background agent for immediate pickup |
| 2 | **loop-me** | Grill me about specs for workflows I want to build (within workspace) |
| 3 | **setup-ts-deep-modules** | Wire dependency-cruiser into TypeScript repo so each package is a deep module |
| 4 | **writing-beats** | Writing exploit — assemble raw material into a journey of beats |
| 5 | **writing-fragments** | Writing explore — mine raw fragments, no structure |
| 6 | **writing-shape** | Writing exploit — shape raw material into an article |

## po main flow 6 steps (core)

老板 8/19 拍 "must keep verbatim" + "code-review cannot be skipped":

1. **grill-with-docs** (or grill-me) — sharpen plan
2. **to-spec** — write spec
3. **to-tickets** — break into tickets
4. **implement** — implement
5. **tdd** (or code-review two-axis) — verify
6. **domain-modeling** — record domain words

## wenshu replica full-chain mapping (35 skills × replica workflow)

| wenshu replica work | Which skill to run |
|---|---|
| 1. Clarify replica scope | ask-matt + grill-with-docs |
| 2. Survey hermes truth | research (deleg subagent) |
| 3. Write replica spec | to-spec |
| 4. Break into tickets | to-tickets |
| 5. Implement each module | implement + tdd |
| 6. code review | code-review two-axis (Standards + Spec) |
| 7. Record domain words | domain-modeling + CONTEXT.md |
| 8. Fix bug | diagnosing-bugs + deleg subagent |
| 9. Large work (>1 session) | wayfinder (first break into decision tickets) |
| 10. UI end-to-end | prototype + implement + 老板 verify |
| 11. Skip step / context lost | wait-what |
| 12. agent-to-agent handoff | handoff + claude-handoff |
| 13. Hard design decision | improve-codebase-architecture |
| 14. Module design | codebase-design |
| 15. Teach user | teach |
| 16. User gives incomplete decision | to-questionnaire |
| 17. Strictly grill 老板 | grill-me / grilling |
| 18. Write documents for agents | writing-for-agents |
| 19. pre-commit config | setup-pre-commit |
| 20. TS deep module | setup-ts-deep-modules |
| 21. git dangerous commands | git-guardrails-claude-code |
| 22. One-off prototype | prototype |
| 23. Write documents | writing-beats / writing-fragments / writing-shape |
| 24. One-off migration | migrate-to-shoehorn |
| 25. Create exercises | scaffold-exercises |
| 26. wizard guidance | wizard |
| 27. triage issue | triage |
| 28. Resolve merge conflict | resolving-merge-conflicts |
| 29. Setup 35 skills | setup-matt-pocock-skills |
| 30. loop me | loop-me |

## wenshu replica already-run skills (historical tickets 01-31 + ChatView)

| ticket | Which skills ran |
|---|---|
| 01 MemoryStore | ask-matt → to-spec → to-tickets → implement → tdd (4/4 tests) → domain-modeling |
| 02 SkillRegistry | same (6/6 tests) |
| 03 AgentProtocol (A2A) | same (6/6 tests) |
| 04 AgentRuntime | same (7/7 tests) |
| 05 KanbanStore | same (6/6 tests) |
| 06 TodoStore | same (6/6 tests) |
| 07 FileTools | same (5/5 tests) |
| 08 ProcessTools | cc-runner ran (4/4 tests) |
| 09 WebTools | same (5/5 tests) |
| 10 VisionTools | same (3/3 tests) |
| 11 AVMediaTools | same (5/5 tests) |
| 21 Cronjob | same (7/7 tests) |
| 26 Backup | same (4/4 tests) |
| 29 IntegrationTests | research + to-spec (3/3 tests) |
| 30 DomainModeling | domain-modeling + CONTEXT.md 14 words |
| 31 MiniMaxVerifier | research + to-spec + implement + tdd + **Q22 truth-verified** (curl HTTP 200) |
| 32 ChatView (v0.20 ticket01) | prototype + implement + tdd (4/4 tests) + Q22 truth value |

## Full-chain development methodology truth

Per 老板 8/19 evening "keep going" + "replica" + 35 skills truth + 4 principles + 1 pseudo-Apple-official = **wenshu replica must use 35 skills full chain**.

老板 拍 next step:
1. Continue advancing 19 UI requirements (use prototype + implement + tdd)
2. SlashCommand replica (v0.21 ticket 01)
3. Wrap up / 拍 other requirements

## Next step 老板 拍

Per po main flow run 35 skills full chain:
- 19 UI requirements → prototype + implement + tdd + code-review + domain-modeling
- SlashCommand → grill-with-docs + to-spec + to-tickets + implement + tdd + code-review + domain-modeling