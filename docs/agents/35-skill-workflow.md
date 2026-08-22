# 35-skill complete development workflow (wenshu landing version)

> All 35 Matt Pocock `SKILL.md` files loaded into the pocock profile. This document = wenshu's complete development workflow diagram for the 35 skills (no step skipped).
> Landing point = wenshu repo `/Volumes/ANAN/Engineering/wenshu/`.

## 0. Overview — 35 skill layers

| Layer | Bucket | Count | Trigger |
|-------|--------|-------|---------|
| Router (entry) | engineering | 1 | user-invoked `/ask-matt` |
| Main flow (idea → ship) | engineering + productivity | 10 | chained, each step drives next |
| On-ramp (branch) | engineering | 3 | enters from anomaly states |
| Codebase health | engineering | 1 | periodic |
| Vocabulary (underneath) | engineering | 2 | automatic / referenced |
| Boundary (phase) | productivity | 3 | triggered between phases |
| Standalone (off-flow) | productivity | 7 | 老板 explicit invoke |
| In-progress (beta) | in-progress | 6 | test only, not promoted |
| Misc (archive) | misc | 4 | historical archive, not actively used |
| **Total** | | **35** | |

## 1. Main flow 10 steps (idea → ship, strict order)

| # | Skill | User-invoked | Trigger | Landing artifact |
|---|-------|--------------|---------|------------------|
| 1 | `ask-matt` | ✓ | 老板 says want to do X | router picks 1-N below |
| 2 | `grill-with-docs` | ✓ | has working dir (wenshu repo) | `CONTEXT.md` addition + ADR |
| 3 | `wayfinder` | ✓ | fog too thick, 1 session cannot hold | decision tickets in `.scratch/` |
| 4 | `to-spec` | ✓ | grill / wayfinder done, thinking clear | spec doc |
| 5 | `to-tickets` | ✓ | spec complete | `.scratch/<feature>/issues/NNN-*.md` |
| 6 | `triage` | ✓ | external issue only (not `to-tickets` artifact) | issue state switch |
| 7 | `implement` | ✓ | per ticket, self-driven, 1 ticket 1 session | code + tests + screenshot |
| 8 | `code-review` | ✓ | implement done | two axes (Standards + Spec) review |
| 9 | `domain-modeling` | auto | new domain word enters code | `CONTEXT.md` +1 line |
| 10 | `improve-codebase-architecture` | ✓ | periodic (when spare time) | HTML report + deepening candidates |

**3 on-ramps** (anomaly state → main flow):

| On-ramp | Trigger | Flow to main flow position |
|---------|---------|----------------------------|
| `triage` | issue / external PR pile up | state machine → ready → `/implement` |
| `diagnosing-bugs` | hard bug, intermittent flake, regression | 4-phase → fix → `/code-review` |
| `wayfinder` | greenfield / huge build | decision tickets → `/to-spec` |

**2 vocabulary layers** (underneath, auto / referenced):

| Skill | Role | Trigger |
|-------|------|---------|
| `codebase-design` | deep-module vocab (module / interface / depth / seam / adapter) | `tdd` / `improve-codebase-architecture` internal |
| `domain-modeling` | domain vocab (fuzzy term / overload / ADR) | `grill-with-docs` internal |

## 2. Phase-boundary 3 steps

| Tool | When | 老板 拍 |
|------|------|---------|
| `clear` | phase boundary, whole context useless | one sentence |
| `compact` | phase boundary, context useful, preserve | one sentence |
| `subagent` | phase-internal short task split | give to sub-agent |

## 3. Standalone 7 steps (off-flow, 老板 explicit invoke)

| Skill | Role | Example |
|-------|------|---------|
| `grill-me` | no-repo-state interview | 老板 wants to sharpen an idea outside wenshu repo |
| `grilling` | interview primitive, no wrapper | used internally by other skills |
| `prototype` | one-shot throwaway to answer 1 design question | "SwiftUI 6-zone scaling behavior on 2K screen" |
| `research` | background research, write cited markdown | "Apple HIG §3.4 Window Resize behavior" |
| `wizard` | generate interactive bash, only-human steps | Apple Developer Program application |
| `wait-what` | previous sentence did not land, restate | 老板 says "not what I meant" |
| `teach` | multi-session learning | 老板 wants to learn SwiftUI 6-zone layout |
| `to-questionnaire` | decision needs others' input, write questionnaire | align with external designer |
| `handoff` | compress conversation for next agent | current session done, switch to next |
| `writing-for-agents` | standard for writing skill / AGENTS.md / spec | current document |

## 4. In-progress 6 (beta, not promoted)

| Skill | Status | Usage |
|-------|--------|-------|
| `claude-handoff` | beta | hand to fresh background agent |
| `loop-me` | beta | grill workflows for build |
| `setup-ts-deep-modules` | beta | TypeScript dep-cruiser (wenshu = Swift, not directly used) |
| `writing-beats` | beta | writing exploit |
| `writing-fragments` | beta | writing explore |
| `writing-shape` | beta | writing exploit |

## 5. Misc 4 (historical archive)

| Skill | Status | Usage |
|-------|--------|-------|
| `git-guardrails-claude-code` | historical | CC hook blocks dangerous git (push / reset --hard / clean) |
| `migrate-to-shoehorn` | historical | migrate tests from `as` to @total-typescript/shoehorn (TS only) |
| `scaffold-exercises` | historical | exercise dir sections / problems / solutions |
| `setup-pre-commit` | historical | husky + lint-staged pre-commit (wenshu does NOT use husky) |

## 6. Mandatory steps (大神 flow, run on every code change)

| Mandatory step | When | 老板 acceptance standard |
|----------------|------|--------------------------|
| `ask-matt` | every new task | router correct, no key skill skipped |
| `grill-with-docs` | working in wenshu repo | `CONTEXT.md` / ADR has delta |
| `to-spec` | after grill | spec exists, 老板 can read |
| `to-tickets` | after spec | tickets written complete in `.scratch/` |
| `triage` | external issue | state machine runs through |
| `implement` | per ticket | 1 ticket 1 session, context not mixed |
| `tdd` | implement internal | RED-GREEN-REFACTOR (UI uses form-test) |
| `code-review` | after implement | two axes (Standards + Spec) pass |
| `domain-modeling` | new domain word | `CONTEXT.md` +1 line |
| `improve-codebase-architecture` | periodic (1 per week) | HTML report + 1 deepening candidate |

## 7. Skip decisions (boss有权 skip any step, but pocock must know)

| Decision | Skip cost | 老板 拍板 |
|----------|-----------|-----------|
| Skip `ask-matt` | direct into a skill, will be wrong | 老板 can 拍 any time |
| Skip `grill-with-docs` | no `CONTEXT.md` delta, future onboarding hard | one-shot small change can skip |
| Skip `to-spec` | thinking unclear, ticket split wrong | medium / large change cannot skip |
| Skip `to-tickets` | no parallelism, no blame | 1 ticket 1 commit can skip |
| Skip `triage` | — | internal ticket not needed |
| Skip `implement` self-driven `tdd` | no tests | UI can skip (form-test cannot), backend must |
| Skip `code-review` | bug / spec drift, big commit then rollback | **CANNOT skip** (老板 8/18 拍) |
| Skip `domain-modeling` | vocab drift | 1 week can skip |
| Skip `improve-codebase-architecture` | no deepening candidate, project stalls | 1 week can skip |

## 8. wenshu project current 35-skill landing status

| Status | Skill | Note |
|--------|-------|------|
| ✅ landed | `ask-matt`, `code-review`, `setup-matt-pocock-skills` | setup run this time |
| 🟡 ran once | `implement`, `grill-with-docs` (implicit), `codebase-design` (implicit) | historical commit 8/18 ran implement + code-review |
| 🟡 router layer | `codebase-design`, `domain-modeling` (vocabulary) | injected automatically via `CONTEXT.md` |
| ⚪ await trigger | `wayfinder`, `to-spec`, `to-tickets`, `triage`, `tdd`, `improve-codebase-architecture`, `diagnosing-bugs`, `resolving-merge-conflicts`, `prototype`, `research`, `wizard`, `wait-what`, `teach`, `to-questionnaire`, `handoff`, `writing-for-agents`, `grill-me`, `grilling` | 老板 explicit invoke |
| 🟡 beta | in-progress 6 + misc 4 | not promoted |

## 9. Expected changes after setup complete

- `CONTEXT.md` exists → any agent entering wenshu repo reads first
- `docs/agents/issue-tracker.md` → `to-tickets` / `triage` / `implement` know issue is in `.scratch/`
- `docs/agents/triage-labels.md` → `triage` knows 5 canonical states
- `docs/agents/domain.md` → agent knows single-context, when to write ADR
- `docs/adr/0000-template.md` → ADR template
- `docs/adr/0001-0005` → 5 truth-source decisions stored (6-zone / componentize / drag line / Library / Document)
- `CLAUDE.md` ## Agent skills block → CC reads whole 35-skill flow once on launch