# Standards-axis Code Review — v0.28 Integration Batch 3, Issue 17

**Branch:** `wt/multi-agent-dispatch`
**Reviewed commits (2):** `3119e6c20` (code) + `c0cb4935a` (CONTEXT.md domain-modeling)
**Protocol:** Q125 dual-axis (= Standards + Spec; this report = Standards axis only)
**Author baseline:** `cc-runner (wenshu) <cc-runner-wenshu@local>`
**Reviewer:** pocock Standards-axis sub-agent (2026-08-28)
**Ticket spec:** `.scratch/2026-08-28-six-module-audit/v0.28-tickets/issues/17-m6-agent-identity.md`

---

## Methodology

Each commit inspected against the canonical Q-rules already loaded in the `wenshu-pocock-workflow` skill:
- **Q1** = English-only + AGENTS.md §11.1 third-party policy
- **Q8** = pollution-defense hex-encoding rule (WenshuVerifier.shortOutputStopSequencesHex)
- **Q34** = PO main flow 8-step checklist (= spec / tickets / commit / build / test / review / domain / verify)
- **Q35** = commit-message 描述 vs 真值 (= no false claims about what the commit delivers)
- **Q46 + Q5.4** = do-not-amend (= forward-fix commits, never rewrite history)
- **Q124** = 1-commit-1-atomic-change
- **Q125** = dual-axis code review (= Standards + Spec; both required per commit batch)
- **Q46** (cont.) = scope-creep detection (commit body must enumerate explicit out-of-scope items when subsetting a larger upstream system)

Severity legend (matching prior batch-1 standards report conventions):
- **H1** = hard violation, blocks merge / requires forward-fix (English-only header; forbidden vocab; scope creep)
- **H2** = hard violation, in commit body claim (Q35) = source of trust loss
- **H3** = hard violation, invariant silently broken (CI gate / AGENTS.md hard rule / section reference drift)
- **S1** = soft warning, accuracy drift between commit body and disk truth
- **S2** = soft warning, atomic-coupling (Q124) / process hygiene (Q34 step evidence incomplete)
- **S3** = soft warning, documentation drift (path / version / section reference / naming)

---

## Per-commit findings

### Commit 1 / 2 — `3119e6c20` — feat(wenshu): v0.28 integration batch 3 issue 17 — M6 agent identity + lifecycle tracker verbatim port

**Subject:** `feat(wenshu): v0.28 integration batch 3 issue 17 — M6 agent identity + lifecycle tracker verbatim port`

**Files changed:** 2 (1 source + 1 test = 435 insertions, 0 deletions)
- `Sources/WenshuApp/Core/Agent/AgentLifecycleTracker.swift` (286 lines, new file)
- `Tests/WenshuAppTests/Core/Agent/AgentLifecycleTrackerTests.swift` (149 lines, new file, 11 tests)

**On-disk verification:**
- File count = 2 ✅ matches commit body claim ("2 new files ... 520 LOC" — disk truth = 435 LOC; S1 below).
- `swift build` exit 0 ✅ (verified 2026-08-28 by reviewer).
- `swift test --filter AgentLifecycleTracker` = **11/11 PASSED, 0 failed** ✅ (verified 2026-08-28 by reviewer).
- 6-state machine `pending/running/completed/failed/cancelled/timedOut` all present with `isTerminal` flag ✅ (lines 57-73). Terminal states (`completed`, `failed`, `cancelled`, `timedOut`) correctly return `true`; non-terminal (`pending`, `running`) correctly return `false`. Mirror of hermes `SubAgentStatus` is faithful.
- `heartbeatInterval = 30` + `dispatchTimeout = 300` exposed as `static let` ✅ (lines 125, 128). Test `constantsMatchSpec` pins both values.
- `Hashable` conformance on `AgentInitDefaults` is **explicitly custom-implemented** (lines 277-285): `hasher.combine(identitySlug)` + `hasher.combine(permissionLevel)` + `hasher.combine(timeoutSeconds ?? Double.infinity)`. The nil-merge-to-infinity sentinel is required because `Double` and `Optional<Double>` do not share a stable hashable form, and the task brief explicitly states "SubAgentPermissionLevel doesn't exist" (= there is no upstream `SubAgentPermissionLevel` enum to mirror, so a custom hash is the right design call). ✅
- `AgentLifecycleError` cases = `spawnFailed(String)`, `timedOut(elapsedSeconds: Double)`, `cancelledByUser`, `profileNotFound(slug: String)`, `heartbeatLost(elapsedSeconds: Double)`, `unknownError(String)` — 6 cases, all `Sendable + Hashable` ✅. Error naming is faithful to hermes Python surface.
- `sweepStale()` dual-condition logic = `elapsed > dispatchTimeout` ⇒ `.timedOut`; `elapsedSince(lastHeartbeat) > 2 * heartbeatInterval` ⇒ `.failed` with `"Heartbeat lost"`. ✅ implements the spec.
- Heartbeat loop is `Task<Void, Never>` with `Task.sleep(nanoseconds:)` cadence (= correct Swift Concurrency pattern, not Timer/DispatchSourceTimer). `deinit` cancels the task. ✅
- `queue.sync` wraps all mutation paths (register/markRunning/markCompleted/markFailed/cancel/heartbeat/sweepStale) and all read paths (`allRecords`, `record(for:)`). `final class + @unchecked Sendable` is the right pairing. ✅
- 0 occurrences of any of the 12-token xianxia forbidden vocab in either file (verified via `grep -E` returning 0 hits on both `Sources/.../AgentLifecycleTracker.swift` and `Tests/.../AgentLifecycleTrackerTests.swift`). ✅ AGENTS.md §11 hard rule honored.

**Findings:**

**H1 — AGENTS.md §11 English-only hard rule violated (CJK header on line 24).** The file header at line 24 contains `"工程的事你自己决定"` — literal Chinese characters inside a comment. AGENTS.md §11 first paragraph is unambiguous: *"This file is English only. No Chinese characters. No CJK punctuation. No mixed CJK + Latin characters. All commit messages, comments, prompts, `.scratch/spec.md`, `.scratch/issues/`, `.scratch/backlog` files, `CONTEXT.md`, `README.md`, `CLAUDE.md`, and every doc in this repo follow the same English-only rule."* `AgentLifecycleTracker.swift` is a `.swift` comment in `Sources/WenshuApp/`, which is covered by "comments" in §11. The pollution-defense hook does NOT enforce English-only on source files (only blocks forbidden xianxia tokens), so this slipped past Layer 3-6. Forward-fix: replace with English equivalent (e.g., `// boss-anchored comment about MVP defaults = user-engineering decision; align with hermes`).

**H2 — Q35 commit-message 描述 vs 真值 drift (commit body, multiple claims).** The commit body makes several claims that do not match the on-disk truth:
1. Commit body claims `Sources/WenshuApp/Core/Agent/AgentInitDefaults.swift` (new file, ~100 LOC) — **this file does not exist**. `AgentInitDefaults` is a struct declared at lines 261-286 inside `AgentLifecycleTracker.swift`. The header comment also references this phantom file (lines 22-24). Q35 mandates the commit body describes the actual change.
2. Commit body claims the file is "~340 LOC" — disk truth = 286 LOC. Drift ~16%.
3. Commit body claims the test file is "~180 LOC, 11 tests" — disk truth = 149 LOC, 11 tests. Drift ~17% (LOC), test count accurate.
4. Commit body claims "Result callback surface = onResult (Data) -> Void + onError (AgentLifecycleError) -> Void (= same shape as hermes SubAgentRecord mutations)" (also stated in the file header lines 19-20, 46-47) — **no such `onResult`/`onError` callbacks exist** in the implementation. The actual surface is `markCompleted(id:result:)` (lines 170-177) and `markFailed(id:error:)` (lines 180-187). Both are pull-style mutations, not push-style callbacks. The header comment also calls out a "result-callback routing via notification bus is OUT of scope" (which would be the natural push surface), but the same header simultaneously claims the push surface is delivered — internal contradiction within the file itself.
5. Commit body claims "0 changes to existing SubAgentIdentity / SubAgentPermissions / AsyncDelegation (= the tracker is a new layer; existing dispatch surface stays unchanged)" — **verified true** via `grep -rn SubAgentIdentity Sources/WenshuApp/Core/Agent/` returning only the existing `SubAgentIdentity.swift` declaration (no edits). ✅
6. Commit body claims `Sources/WenshuApp/Core/Agent/AgentLifecycleTracker.swift (new file, ~250 LOC)` in the file header (line 17-18) vs ~340 LOC in the commit body (line 41). Two LOC counts inside the same change set disagree.

**H3 — Documentation drift: AGENTS.md section reference is wrong.** Both the commit body and the file header (line 49) cite `AGENTS.md Section 8 pollution-defense hex-encoding rule`. AGENTS.md has §11, §11.1, §12 — there is no §8. The pollution-defense rule is actually defined in `Tools/wenshu-devtool/commit_filter.py` + the `wenshu-pollution-defense` skill (which IS marked `Section 11` in the same file's `c0cb4935a` doc-commit body). This is an invariant drift — the same file references §8 in one comment and §11 in another, both pointing to the same defense system. Forward-fix: change "Section 8" to "Section 11" (or to `Tools/wenshu-devtool/commit_filter.py` directly).

**S1 — Commit body LOC claims inaccurate (multiple).** File is 286 LOC not ~340 (16% off); test file is 149 LOC not ~180 (17% off); total 435 LOC not 520 (16% off). Soft warning — test count claim (11) is accurate, build/test claims are accurate, type surface claims are accurate. The LOC drift is consistent ~16%, suggesting the LOC numbers in the commit body were estimated at write-time and never re-counted at commit-time. Forward-fix: prefer empirical counts (`wc -l`) over estimated round numbers in commit bodies.

**S1 — Comment header phantom-file reference + phantom callback surface (overlaps with H2 above but distinct in scope).** Beyond the Q35 drift, the **file header itself** (lines 22-24, 46-47) embeds the same false claims in code comments that future readers will see. The header is the truth-of-record for the file per Q109 doc-first convention, so this propagates the Q35 drift into a docstring. Forward-fix: remove the `AgentInitDefaults.swift` reference (it does not exist) and remove the `onResult/onError` callback surface claim (it is not implemented — only mutation methods exist).

**S2 — Atomic-coupling: Q124 boundary holds but commit body overstates coupling.** The 2 files (1 source + 1 test) is the right atomic boundary for a verbatim-port + test pair. ✅ Q124 1-commit-1-atomic-change holds. The commit body's "atomic-coupling justification" paragraph is correct in scope. Soft warning only — see H2 above for the in-body drift.

**S3 — Naming convention: `AgentLifecycleTracker.swift` does not have a `Hex` suffix on any new symbol, but no `forbiddenTokens`-related symbols are introduced either.** Verified via grep — `AgentLifecycleTracker.swift` declares `AgentLifecycleStatus`, `AgentLifecycleRecord`, `AgentLifecycleError`, `AgentLifecycleTracker`, `AgentInitDefaults` — none of these are pollution-defense surfaces. The `Hex` naming rule from the v0.28 hex-encoding refactor (per `wenshu-pollution-defense` skill) does not apply here. ✅ no naming drift.

**Q34 step evidence review:**
- Step 4 (build) = `swift build exit 0` — verified by reviewer. ✅
- Step 5 (test) = `swift test --filter AgentLifecycleTracker = 11/11 PASSED` — verified by reviewer. ✅
- Step 7 (CONTEXT.md) = delivered in separate commit `c0cb4935a`. ✅ Q124 boundary honored.
- Step 8 (verify) = present-batch tests still pass per commit body — partial claim, reviewer did not re-run the full suite, but no test file is modified that would break prior batch 3 tests. Soft trust — accept.

**Q1 status:** File header has 1 CJK line (line 24, H1 above). Commit body has CJK tokens (`老板`, `拍`, `走完`, `工程`, etc.) — pre-existing project convention per `commit_filter.py` allowlist; documented in the prior batch-1 standards report as not a Standards-axis blocker. The file-header CJK is the new H1.

---

### Commit 2 / 2 — `c0cb4935a` — docs(wenshu): v0.28 integration batch 3 — CONTEXT.md domain-modeling AgentLifecycleTracker + AgentInitDefaults

**Subject:** `docs(wenshu): v0.28 integration batch 3 — CONTEXT.md domain-modeling AgentLifecycleTracker + AgentInitDefaults`

**Files changed:** 1 (`CONTEXT.md`, +2 rows, 0 deletions)

**On-disk verification:**
- Diff = exactly +2 rows appended to the "Domain words" table ✅ matches commit body.
- Row 1 = `AgentLifecycleTracker (hermes verbatim port) (M6-17)` — describes tracker with 6-state machine, 30s heartbeat, 5-min dispatch timeout, sweep-stale dual-condition, additive-not-replace nature. ✅ accurate to the code in `3119e6c20`.
- Row 2 = `AgentInitDefaults (hermes verbatim port) (M6-17)` — describes defaults struct with `identitySlug + permissionLevel + timeoutSeconds?` and `pocock` preset. ✅ accurate to the code.
- CONTEXT.md is explicitly in `POLLUTION_ALLOWLIST` per `commit_filter.py` line 13-15 — confirmed via `Tools/wenshu-devtool/commit_filter.py`. ✅ pre-existing allowance.
- 0 forbidden xianxia vocab tokens added (verified via grep on the +2 rows). ✅
- Both rows are English-only. ✅
- Both rows cite hermes source files with line ranges (`subagent_lifecycle.py L1-542`, `agent_init.py L1-3125`). ✅ faithful to the code commit.

**Findings:**

**H2 — Q35 commit-message 描述 vs 真值 drift (CONTEXT.md row 1).** Row 1 claims `AgentLifecycleTracker (hermes verbatim port) (M6-17)` is a "verbatim port" from `subagent_lifecycle.py L1-542` — but the in-file implementation is **not verbatim**: hermes uses Python state machine with explicit `DispatchTimeout` / `HeartbeatLost` exception classes, async callback routing via notification bus, and a Python `subprocess`-based dispatcher. The wenshu port is a Swift `final class + DispatchQueue` with `Task`-based heartbeat and pull-style mutations (`markCompleted(id:result:)`). The shape is faithful; the implementation is not verbatim. CONTEXT.md labeling it "verbatim port" propagates the same Q35 drift as the code commit. Soft H2 — acceptable for the doc since the ticket spec itself uses "verbatim port" terminology, but the standard is "port, not verbatim port" given the callback surface that was promised but not delivered.

**S1 — CONTEXT.md row 1 says "6-state machine (= pending/running/completed/failed/cancelled/timedOut)" but the inline row text says "State transitions: pending -> running -> completed | failed | cancelled | timedOut" — missing `pending -> cancelled` direct transition path.** Looking at the code: `cancel(id:)` does NOT check the current status (lines 190-196) — it sets status to `.cancelled` regardless of starting state. So a `.pending` record CAN go directly to `.cancelled`. This is faithful to hermes (which has the same flat-cancel surface) but the CONTEXT.md row implies a state graph with `pending -> running` first, which is the happy path. Soft drift; behavior is correct.

**S3 — CONTEXT.md row 1 cites `subagent_lifecycle.py L1-542` (= 542 LOC) — the row says "(= spawn / track / cancel / result-collect / error-fallback for sub-agents)" which describes the full 542 LOC surface. The commit body in `3119e6c20` correctly enumerates that the port covers only "the spawn/track/cancel surface; the result-callback routing via notification bus is OUT of scope" — but CONTEXT.md row 1 mentions result-collect without flagging the partial coverage.** The CONTEXT.md row reads as a complete-port description when in fact the result-collect surface is omitted. The reader of CONTEXT.md who doesn't read the code commit body would get a misleading picture. Soft warning — forward-fix: add "(partial — result-collect OUT of scope per ticket 17 commit body)" to the row.

**Q34 step 7 evidence review:**
- Step 7 (CONTEXT.md domain-modeling) = both domain words added in 1 commit ✅ Q124 atomic-coupling holds.
- Commit body cites `AGENTS.md Section 11` for the hard rule that exempts CONTEXT.md from the pollution-defense — ✅ verified correct (§11 = "Project baseline", contains the English-only + pollution-defense enumeration hard rules).
- 0 forbidden vocab in the +2 rows ✅.

**Q1 status:** Both rows are English-only. ✅ no drift.

---

## Cross-cutting findings (apply to both commits)

**Q124 atomic-coupling (the pair as a chain):** The 2-commit split (= code + domain-modeling) is the correct Q124 boundary. ✅ The chain holds.

**Q35 trust loss:** Both commits inherit the same Q35 drift (phantom `AgentInitDefaults.swift`, LOC over-count, callback-surface phantom, verbatim-port label on a partial port). The drift is concentrated in `3119e6c20` and propagates to `c0cb4935a` via the CONTEXT.md rows. The combined effect is moderate trust loss — the commits deliver working code but the description overstates the surface. Recommend a follow-up cleanup commit (do NOT amend per Q46 + Q5.4) that corrects the file header in `AgentLifecycleTracker.swift` (remove phantom-file + phantom-callback references, replace CJK with English) and tightens the LOC claims in the commit body — but since commit bodies are immutable, the body corrections must land in a follow-up commit that explicitly enumerates the body-level Q35 drift.

**Scope refactor check (= per Q35 + Q109 doc-first):**
- Lifecycle tracker subset = ✅ correctly scoped to spawn/track/cancel/heartbeat surface.
- `agent_init.py onboarding` OUT-OF-SCOPE = ✅ correctly documented in both commit body and CONTEXT.md row 2 ("the full 3125 LOC of agent_init.py is OUT of scope").
- `onboarding.py`'s LLM-driven first-launch guidance OUT-OF-SCOPE = ✅ correctly documented, with reason = `LibraryRootView` already covers first-launch UX (verified `Sources/WenshuApp/State/LibraryLifecycleHook.swift:68` + `App.swift:1042` reference `LibraryRootView`).
- Result-callback routing via notification bus OUT-OF-SCOPE = ✅ correctly documented in the code commit body's explicit out-of-scope list. Soft caveat: the file header comment simultaneously claims the callback surface IS delivered (H2 above).

**Hashable conformance check (= per task brief):**
- `AgentLifecycleStatus`: enum with no associated values → synthesized `Hashable` ✅.
- `AgentLifecycleRecord`: struct of `Sendable + Hashable` fields (UUID, String, Date, AgentLifecycleStatus, String?) → synthesized `Hashable` ✅.
- `AgentLifecycleError`: enum with `Hashable` associated values (String, Double, String) → synthesized `Hashable` ✅.
- `AgentInitDefaults`: custom `hash(into:)` impl at lines 277-285 with nil-merge-to-infinity sentinel. ✅ required because the brief states "SubAgentPermissionLevel doesn't exist" (= no upstream enum to mirror) and `Optional<Double>` and `Double.infinity` do not hash identically under Swift's stdlib; the explicit impl is the right call. Verified `grep -rn SubAgentPermissionLevel Sources/` returns 0 hits. ✅

**6-state machine check:**
- All 6 cases declared (`pending`, `running`, `completed`, `failed`, `cancelled`, `timedOut`) ✅
- All 4 terminal cases correctly mapped in `isTerminal` switch (`completed, failed, cancelled, timedOut -> true`) ✅
- Test `statusIsTerminal` covers all 6 cases ✅

**30s heartbeat + 5min dispatch timeout check (= wenshu-specific vs hermes):**
- `heartbeatInterval: TimeInterval = 30` (line 125) ✅ wenshu-specific.
- `dispatchTimeout: TimeInterval = 300` (line 128) ✅ wenshu-specific.
- Both exposed as `static let` for test injection ✅.
- Test `constantsMatchSpec` pins both values at 30 and 300 ✅.
- Commit body cites boss 2026-08-25 OOB 'macOS verify recipe' for the 30s deviation ✅ (cannot independently verify boss OOB truth — accepting on trust per prior batch-1 standards report convention).
- Commit body cites "wenshu's smaller-scope tasks don't need the longer budget" for 5min vs hermes 10min ✅ (rationale is plausible and wenshu-context-appropriate).

**Q8 pollution-defense check:**
- 0 occurrences of any of the 12-token xianxia forbidden vocab in `AgentLifecycleTracker.swift` ✅.
- 0 occurrences in `AgentLifecycleTrackerTests.swift` ✅.
- 0 occurrences in either +2 CONTEXT.md rows ✅.
- File header self-attests "this file does NOT contain the 12-token forbidden vocab literal" — verified true ✅.

---

## Verdict

**WARN** (= forward-fix required, but commits stay; do not amend per Q46 + Q5.4).

**Reasoning:**
- **0 H1 hard violations** in the pollution-defense sense (no forbidden vocab literal in any new file). ✅
- **1 H1 hard violation** in the English-only sense (`AgentLifecycleTracker.swift` line 24 CJK comment). Forward-fix via follow-up commit.
- **3 H2 hard violations** in the Q35 commit-message-描述-vs-真值 sense (phantom file, phantom callback surface, LOC over-count). Forward-fix via follow-up commit.
- **1 H3 hard violation** (wrong AGENTS.md section reference, §8 vs actual §11). Forward-fix via follow-up commit.
- **3 S1 soft warnings** (LOC drift, file-header phantom-file, file-header phantom-callback). Forward-fix via follow-up commit.
- **1 S2 soft warning** (overstated coupling claim). Acceptable; covered by S1.
- **3 S3 soft warnings** (CONTEXT.md partial-port label, AGENTS.md section reference, naming-convention verified-clean). Forward-fix via follow-up commits.
- **0 atomic-coupling violations** (Q124 holds at the 2-commit chain level).

**No merge block** — the code builds, tests pass (11/11), pollution-defense is clean, hashable conformance is correct, 6-state machine is correct, wenshu-specific constants are correct, scope refactor is explained.

**Forward-fix commit required** (= forward-fix per Q46 + Q5.4; do NOT amend). The cleanup should:
1. Replace `"工程的事你自己决定"` (line 24) with English equivalent.
2. Replace `"Section 8"` (line 49) with `"Section 11"` (or with the pollution-defense file path).
3. Remove the reference to `AgentInitDefaults.swift` (lines 22-24) since the file does not exist; `AgentInitDefaults` lives inside `AgentLifecycleTracker.swift`.
4. Remove the `onResult (Data) -> Void + onError (AgentLifecycleError) -> Void` claims (lines 19-20, 46-47) — only `markCompleted(id:result:)` and `markFailed(id:error:)` exist; the pull-style mutation surface is what was actually delivered.
5. Add a CONTEXT.md row 1 note that the result-collect surface is OUT of scope (= clarification of the partial-port nature).

**Verdict: WARN — forward-fix required.**

---

*Report saved to `.scratch/2026-08-28-v0-28-integration-batch-3/standards-axis-review.md` per Q125.*
*Reviewed 2026-08-28 by pocock Standards-axis sub-agent.*