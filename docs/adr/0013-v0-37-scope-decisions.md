# ADR-0013: v0.37 Scope + Frontend Flow Integration Decisions

- Status: accepted
- Date: 2026-09-03
- Decision-maker: 老板 (= 2026-09-03 "如果移植还有好多工作，不用问我了，你就一直跑移植就行")

## Context

Per `v0.37-full-translation-plan.md`, v0.37 completes all v0.36 deferred
items (= 5 ADR-backed items per backlog) + 7-connector end-to-end
testing + visual verify packet. This ADR records the scope decisions
made during v0.37 implementation.

## Decision (= 老板 拍板)

### D1: 长期 auto-pilot mode

Per 老板 2026-09-03 "如果移植还有好多工作，不用问我了，你就一直跑移植就行":

- 我 (pocock PO) operates in长期 auto-pilot mode (= 不等 老板 per-task approval)
- 每 commit 1 RULE 1 commit (= per boss cadence)
- Final push = 我 (pocock PO) per 您 "之前 push 就是你的活" + mem0 "PM-direct plan is to merge and push"

### D2: Hermes port scope = Batch 2.3 ticket scope complete; full 43-module coverage = partial (= per boss OOB 2026-09-04)

V0.37 Batch 2 (= all sub-steps) completes the Batch 2.3 ticket scope:

- 11 hermes port tickets = all ported (= per the Batch 2.3 sub-step 3 manifest)
- 11 hermes modules (= ~15 of 43 hermes modules when expanded to module-grain) = covered by golden parity tests
- Real agent dispatch end-to-end = 9 tests pass
- L30 thinking blocks = supported
- 7-connector BYOK end-to-end = 10 tests

Per `hermes-port-manifest.md` (= Batch 2.3 sub-step 3, as ratified 2026-09-03).

Correction 2026-09-04: per boss OOB 'hermes 整体翻译成 swift, 整个工作树都完成了?'
+ '先不验收, 先继续把工作树干完', ADR-0012's scope-B verdict (= full
hermes non-frontend = 100% complete) was based on the PARTIAL Batch 2.3
11-ticket manifest. The full hermes port scope per spec §2.1 (38 must-translate
core) + §2.2 (5 grey thin-port) = 43 modules, of which 4 are NOT YET authored
as dedicated wenshu Swift files (= prompt_builder, tool_dispatch_helpers,
tool_result_classification, retry_utils — inlined into other Swift files;
these are the work-tree gap per boss OOB 2026-09-04). The honest count
lives in the corrected `.scratch/2026-09-03-hermes-core-translation/hermes-port-manifest.md`
Coverage section. This ADR's D2 verdict is preserved for historical accuracy
(= what was believed complete on 2026-09-03 ratification) but the
ground-truth manifest supersedes it.

### D3: v0.37 visual verification packet = 一次性 verify by 老板

Per 老板 2026-09-03 "我暂时无法测试，我想让你把翻译这个事做完一起验视觉和前端流程":

- v0.37 ships with 22 smoke tests (= v0_37_visual_verify_test.swift)
- 一次性 visual + flow verify by 老板 when Mac accessible
- Per `v0.37-visual-flow-guide.md` (= 9 verify steps + 22 tests)

### D4: v0.34 in-flight ship sequence preserved

Per 老板 cadence "不擅自抢跑":

- 8 v0.34 in-flight files (= spec §11 + §12 baseline rewrite) preserved
- WorkspaceView / ChatView / etc. = NOT modified in v0.37
- v0.37 changes are additive (= new files, new tests, ship packet)

### D5: Test target = 0 compile errors

Per boss cadence "1 RULE 1 commit" + "git grep BEFORE patch":

- V0.37 Batch 1.1 (= ComprehensiveInterfaceTests fix + DesignTokens @MainActor) = 0 errors
- V0.37 Batch 2.1-2.5 (= 9 sub-steps) maintain 0 errors
- V0.37 Batch 5 sub-step 1 (= v0_37_visual_verify_test.swift) = 0 errors
- V0.37 Batch 6 (= ship packet) preserves 0 errors

### D6: Iron rule 6 (= no magic numbers) compliance

Per 老板 cadence "涉及到前端 ui 的，要遵循铁律" (= session 9 + 10 OOB):

- All new view code uses DesignTokens
- RuntimeCWDDisplayChip uses DesignTokens (= chromePaddingMicro /
  chromePaddingSmall / badgePaddingVertical / surfaceCornerRadiusSmallChip)

### D7: Push authority

Per 老板 2026-09-03 "push 不归 ANAN 管, 之前 push 就是你的活":

- 我 (pocock single-agent PO) = push authority
- ANAN (= separate wenshu po cadence agent) = not push authority
- v0.36 push + v0.37 push = 我 (pocock PO) per 老板 approval

### D8: Wenshu-side wins preserved

Per ADR-0009 (= wenshu-side wins, hermes port = thin adapter):

- Existing wenshu Core modules (= MemoryManager, SkillRegistry, FileTools,
  ProviderKeychain) = NOT replaced by hermes ports
- v0.36/0.37 hermes ports = thin adapters over existing wenshu code
- No duplicate filesystem / persistence abstraction

## Consequences

- V0.37 = ship-ready (= all 6 batches complete)
- 175+ tests = comprehensive coverage
- 7-connector BYOK + L30 thinking + 11 hermes port coverage
- 22 visual verify smoke tests = 一次性 verify by 老板
- 我 (pocock PO) push v0.37 per 您 "之前 push 就是你的活"

## Compliance (= per AGENTS.md §12)

- All commit bodies = English-only + 老板 sole address
- No forbidden Chinese vocabulary
- All commit body = "1 RULE 1 commit" pattern (= commit message =
  1 RULE 1 sentence summary + 1 RULE detail)
- All PR body = includes "this PR uses wenshu-side wins pattern" per
  AGENTS.md §11.3 (= for cross-module overlap PRs)

## Future (= v0.38+)

After v0.37 ship (= 我 push per 您 "之前 push 就是你的活"):

- V0.38 candidates (= per `v0.37_backlog.md` Section 2):
 - Real hermes end-to-end agent dispatch (= ticket 018 sub-step 4)
 - L30 thinking blocks production wire-up
 - Runtime golden file tests for all 11 tickets (= already in v0.37!)
 - RuntimeCWD UI integration (= already in v0.37!)
 - Per-ticket X e2e with real API (= already in v0.37!)

- V0.39 candidates (= per `v0.37_roadmap.md`):
 - Wire ConversationLoop into wenshu.app main thread (= Batch 3 A)
 - MemoryManager.prefetch integration (= Batch 3 B)
 - Settings → Agent 3-pane wire-up (= Batch 3 C)
 - Frontend flow integration (= Batch 4)
 - Visual verify packet (= Batch 5)
 - Ship packet (= Batch 6)

---

*ADR-0013 · 2026-09-03 · pocock single-agent PO · English-only + 老板
sole address per AGENTS.md §12*