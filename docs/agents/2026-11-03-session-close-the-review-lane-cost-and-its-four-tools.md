# Session close: the review lane's cost, and the four tools that measure it

Date: 2026-11-03
Scope: the review lane's cost model, the four devtool tools that make it
measurable, the review-card body shape (a card as a MISSION DOCUMENT), and
the three false greens the review rounds found in the tools themselves.

## What landed

Eight commits on `main`, on BOTH remotes (`origin` = gitcode.com, `old-origin`
= github.com), read back with `git ls-remote`:

| the commit | what it carries |
| --- | --- |
| `ac20eff1f2` | the review-lane cost meter (`Tools/wenshu-devtool/review_lane_cost.py` + its 11-case suite) |
| `37c366718e` | the skill-sync check (`Tools/wenshu-devtool/skill_sync_check.py`) |
| `917e087b09` | the first round's three fixes (F1 the `--json` stdout, F2 the BLOB body, F3 the hardcoded profile list) |
| `0b7bfca144` | the wording-drift fix (F4: the checker compares each section's body, not only its heading) |
| `80282c9c65` | the second round's three residual fixes (R1 the `--json` exit code, R2 `missing_from`, R3 the headline) |
| `7dbecde4a5` | the third round's fix: the guard that could not fail |
| `9f3de596a2` | the card-sha tool (`Tools/wenshu-devtool/card_sha.py` + its 14-case suite), the mutation check's own 7-case suite, and the three non-blocking observations the fourth round named |
| `ccbb47db6d` | the fourth round's two fixes (D1 the uppercase/non-hex guess, D2 the `--write` that reported success while it changed nothing) |

Two branches (`wt/review-lane-cost`, `wt/card-sha`) and their worktrees are
gone. The review cards that carried the work are `done`.

## THE SYMPTOM: a review took an hour and a half, and nothing said why

A review card on board `wenshu-par` ran for 42 minutes and 39 seconds, and
the board's own numbers could not explain it. The question was whether a
review is a FULL review, and whether it has to be one every time.

**It is not a full review.** A verdict is bound to the CHANGE it read (= the
diff from where the branch left `main`, with the hunk headers dropped), and
the tier decides how wide the gate is (= a T2 buys a filtered suite per
touched area, not the whole suite). The full-repo audit is a separate lane.

**But it was a full re-derivation every time**, because the rule that says
"a later round checks the delta, not the whole change again" lived in a
1199-line reference that the review lane opens **34 times**, against the
`sdlc-review` skill it opens **209 times**. A rule nobody reads is not a
rule.

## THE ROOT CAUSE: the cost is the ROUND TRIP, and the card cannot lower it

Measured over the wenshu-review profile's whole log (310 review sessions,
25219 API calls), with `review_lane_cost.py`:

| the number | the value | what it decides |
| --- | --- | --- |
| API latency as a share of the wall clock | **83%** (181 h of 219 h) | the gate's width is NOT what makes a review slow |
| tool calls per completed review | **105** | the number of round trips |
| scratch scripts a review writes | **3894** (3331 distinct) | the reviewer reinventing the same measurement |
| terminal call vs the wall clock | **+0.717** | the scripts the reviewer writes ARE the cost |
| scratch write vs the wall clock | +0.400 | |
| a repo gate call vs the wall clock | far below both | |
| the median latency below 50k input tokens | 5 s | |
| the median latency above 350k input tokens | 22 s | |
| context growth inside one session | **9x** | the price of a call rises with it |
| the last third of a session's calls | **37%** of its API time | |
| runs that end without a verdict | **54%** | timed out, rate limited, or crashed, and a retry starts from zero |

**Every card-side lever was measured and none of them moved the number.**
Three cost gates were designed, implemented and then DROPPED:

| the gate | what it forbade | why it was dropped |
| --- | --- | --- |
| every claim names a command | a claim without a command | controlling for the body's length, the correlation with the call count is **-0.004**; on the real board it flagged 132 of 155 candidates, i.e. almost all false |
| the body names what an earlier card confirmed | a card that re-derives | the carried-forward feature correlates **+0.005**, and the later-round cards DO get shorter while their call count does NOT fall |
| the card declares its cost budget | a wide gate | the body length correlates **+0.295** with the call count and nothing else does, and once the body size is held constant every other card feature falls to \|r\| < 0.1 |

Also measured and dropped: a bigger cap (cap=7200 wastes 57% against
cap=5400's 39%, and a re-dispatch is a fresh session that re-reads from
zero), a narrower gate (the gate is 12% of the wall clock), and a delta-only
re-review (the later cards get shorter, 8 of 9 branches, and the call
count does not fall).

**So the lever is the reviewer's own round trips**, and two things move
them: a card that names the command that answers each question (= a number
with no command beside it is what makes the reviewer write a script), and a
rule written where the reader already looks.

## THE MEASURED RESULT, INCLUDING THE PART THAT DID NOT WORK

Two consecutive review rounds over the same branch:

| | round 1 (run 2542) | round 2 (run 2545) |
| --- | --- | --- |
| tool calls | 96 | 91 |
| terminal calls | 74 | 75 |
| scratch scripts | 9 | 7 |
| duplicate commands | 0 | 0 |
| the wall clock | 39 min | 42 min |

**No improvement**, and the reason is visible in what the scripts WERE:
every script in both rounds was a PROBE FOR A DEFECT (= round 1's nine were
checking the defects the round before had found, round 2's seven were
checking the ones before them). So the script count fell because the
DEFECTS fell, not because the reviewer got more efficient.

**The price is set by how much is wrong with the subject, and the reviewer's
habits are a second-order term.** A rule that says "ask fewer questions"
therefore has no measurable effect while the subject is defective. This
session's value is QUALITY, not minutes: the tools below caught three false
greens that would otherwise have shipped.

## THE FOUR TOOLS

| the tool | the question it answers |
| --- | --- |
| `review_lane_cost.py` | what does a review run cost, and which of its numbers can a change move? |
| `skill_sync_check.py` | is the rule I just wrote a rule the READER will see? |
| `mutation_check.py` | does this test suite actually bite? |
| `card_sha.py` | is the sha in this card real? |

Each ships with its own suite (11, 17, 7 and 14 cases), and each suite is
proved to bite by a mutation: revert the guarded line, the suite must go RED.

**`skill_sync_check.py`** answers a question a passing test cannot. A rule
written into a skill nobody opens is not a rule, and two copies of a skill
can drift silently. It answers who carries the skill (the shared tree
`~/.hermes/shared/wenshu-skills` is on every profile's `skills.external_dirs`,
so it is loaded everywhere; a profile's own copy shadows it), whether the
copies carry the same rule SET (= the same `##`/`###` headings), whether they
carry the same WORDS (= the same body of every section, because a copy can
have the same headings and a lesson the other does not), whether the reader
is among the carriers, and whether a named rule is in the reader's copy.

**`mutation_check.py`** answers the question a passing suite cannot: a
regression test that asserts on its OWN arithmetic instead of on the code's
output is a guard that cannot fail. The acceptance criterion is therefore
not "the suite passes" but:

```
revert the guarded code  ->  the suite goes RED
leave the code alone     ->  the suite stays GREEN
```

**`card_sha.py`** exists because three review cards carried a "full sha"
that was a hand-written guess (= a short sha with random characters appended
to reach 40), and nothing caught it: the gate reads the sha in the body's
FIRST paragraph, and that one was real, so the cards worked by accident. The
tool reads a sha from git, writes it into a card body, and checks that
every sha a body names exists, that the length is 40, and that the first
paragraph names one. Its reader is `review_gate.reviewed_sha(body)` CALLED,
not a second implementation of it (= a copy that read further would report a
sha the gate never looks at).

## THE CARD BODY IS A MISSION DOCUMENT

The card's skeleton is now the four parts of a mission document (the pocock
`teach` skill's `MISSION-FORMAT.md`), MAPPED onto the existing sections
rather than added to them:

| the mission part | the card's section |
| --- | --- |
| Why | `WHY` (the claims live inside it) |
| Success looks like | `SUCCESS LOOKS LIKE` (a review card; a build card carries `ACCEPTANCE`) |
| Constraints | `EVIDENCE BUDGET` + `HOW TO VERIFY` |
| Out of scope | `OUT OF SCOPE` + the `no:` line of `EVIDENCE BUDGET` |

**It costs nothing in sections.** The number of body sections is the
strongest predictor of how long a card takes (r = **+0.589** against
minutes per card, against +0.406 for the body's length) and the tier buys a
fixed count (T1 7, T2 9, T3 12), so the four parts had to fit the existing
budget. `OUT OF SCOPE` is FREE (= `ticket_tier._is_exclusion()` matches it,
because it is an exclusion heading, and the tier tool does not charge an
exclusion section), `REVIEW HANDOFF` is free (= a routing section), and
`SUCCESS LOOKS LIKE` costs exactly what `THE CLAIMS TO CONFIRM` used to.
Measured: the new shape = **7 charged sections**, the old shape = **7
charged sections**.

## WHAT THE REVIEW ROUNDS FOUND, AND WHAT THEY COST

Six rounds over two branches, five of them `changes_requested`. The
defects were all FALSE GREENS (= a gate that reports success while the
defect is present), and three of them were introduced by the fixes for the
previous round:

| round | the defect | whose |
| --- | --- | --- |
| 1 | the `--json` mode printed a summary line after the JSON, so `json.loads` failed | the first implementation's |
| 1 | the cost meter crashed on a BLOB card body (= `body or ""` does not help, because a non-empty bytes is truthy) | the first implementation's |
| 1 | the sync check hardcoded a profile list naming a profile with no directory, and computed a check it never promoted into a failure | the first implementation's |
| 2 | **the `--json` fix introduced a regression**: an early `return 0` skipped the failure check, so the tool reported success while its own summary said "3 skill(s) need attention" | **the fix's** |
| 2 | `missing_from` still read the hardcoded constant | the fix's |
| 2 | the headline still printed "copies identical: yes" in the case the fix was for | the fix's |
| 3 | **the new guard could not fail**: it re-implemented the formula it was guarding inside the test, so reverting the guarded line left the suite green | **the fix's** |
| 5 | `--check` gave a false green on a guess typed in UPPERCASE (= the candidate detector only recognised lowercase hex) | the second implementation's |
| 5 | `--write` reported success on 109 board cards while changing nothing | the second implementation's |

**The recurring shape**: a fix repairs the instance the review named and not
the CLASS it belongs to, and the fix itself carries the next defect. The
countermeasure that worked was the mutation check (= revert the guarded line
and require the suite to go RED), because it catches a guard that cannot
fail, and one of the mutations was GREEN on the first pass (= a rule with no
test is a rule that can be deleted without anyone noticing).

The review lane also did something the implementer did not ask for: it
snapshotted the in-flight fix, ran its own acceptance criterion against it,
and left the next round's notes on the card, so the next round did not have
to re-derive them.

## THE GATES ON THE MERGED TREE

- `swift build --build-tests` = **Build complete** (5 s)
- `swift test --skip CSSearchableIndexSearchTests` = **3200 tests in 512
  suites failed with 4 issues**, and **those 4 issues are NOT this session's**
  (= measured on both trees, not reasoned).

  **Both frameworks are covered**, because they report differently and a
  report that reads only one of them quotes half the suite:

  | the framework | what it prints | this run |
  | --- | --- | --- |
  | Swift Testing | `Test run with N tests in M suites ... with K issues` | **143/32 passed**, **3200/512 failed with 4 issues**, **208/24 passed** |
  | XCTest | `Executed N tests, with M failures` and `Test Case '-[...]' failed` | **57 `Executed` lines, every one 0 failures**, and **0** `Test Case ... failed` |

  and the trailer names the failing target AND its framework: `Note: Some
  test targets reported failures: - WenshuAppTests (Swift Testing)`.

  **The deterministic core is 3 sites, and all three fail on BOTH trees**,
  with the same assertion:

  | the site | the assertion | the base (`5442b96f12`, before this session's first commit) | the merged tree (`ccbb47db6d`) |
  | --- | --- | --- | --- |
  | `ChatViewHistoryShortcutTests.swift:35` | the chat's history shortcut | **FAILS** | **FAILS** |
  | `EditorTabTitleTests.swift:60` | `displayTitle` prefers the document's path | **FAILS** | **FAILS** |
  | `AsyncDelegationRegistryTests.swift:104` | `Expectation failed: mentionsReported` | **FAILS** | **FAILS** |

  The fourth site is **not** deterministic: `HermesTodoStoreConcurrencyTests.swift:268`
  is a TIMING assertion (`judged.elapsed < 5.0`), and it PASSES when its
  suite runs alone on **both** trees (= 0.646 s on the base, 0.365 s on the
  merged tree) and fails only in the full concurrent run. So the honest
  claim is about the 3 deterministic sites, not about an issue count (= the
  same tree measures 5 issues in one run and 4 in the next, because a
  load-sensitive site appears and disappears).

  And the proof that none of them can be this session's: **the eight commits
  touched nine paths, all of them under `Tools/wenshu-devtool/`** (four
  tools, four test suites and the README), and **zero `.swift` files**. So
  no Swift source and no Swift test moved.
- `review_lane_cost.py` 11 cases, `skill_sync_check.py` 17 cases,
  `mutation_check.py` 7 cases, `card_sha.py` 14 cases = **all green**
- the four mutations of the card-sha suite = **all RED** under the mutation,
  **GREEN** as shipped
- `ci_change_gate.py --check formatting` and `--check pollution` = clean
- `verify-dead.py` = DEAD **0**
- the session's commits added **0 CJK lines** out of **817** added lines
- `commit_filter.py --hook commit-msg` = rc 0 on every one of the eight
  commits
- `gate_width_gate.py` and `effort_budget_gate.py` = rc 0 on all FIVE review
  cards this session created (the board-wide sweep reports 38 cards that
  ask for a gate wider than their tier buys, and NONE of them is this
  session's = they are a sibling's)

## THE OPEN ITEMS

1. **The card body is edited while the reviewer runs, and the reviewer
   does not see it.** The body is delivered ONCE, as the opening turn, so
   `hermes kanban edit` reaches the next dispatcher and every human reader
   and NO running session. A subject that moves under a running review is
   fixed with a COMMENT (= the only channel that reaches a live worker),
   and the comment must name the sha the verdict must name. Both happened
   here, and the reviewer read the comment and re-anchored its own verdict.
2. **A branch that GAINS a commit is not covered by the "same change"
   fallback.** The gate resolves a card by (1) the sha equal to the branch
   tip, else (2) the sha being in the branch reflog AND `change_id` of the
   card's sha equalling `change_id` of the tip. Rule 2 rescues a REBASE
   (the edit is identical) but a branch that gained a commit has a
   different change id, so rule 2 misses too. The body's first WHAT TO BUILD
   paragraph must name the new tip. Measured here: the fix is one line, and
   `card_sha.py --write` makes it.
3. **The cost of a review is still set by the subject's defect count**, and
   nothing this session did changed that. The lever that remains is to make
   the subject have no defects before the review (= run the tool's own tests
   and the mutation checks BEFORE the card is written). A review card that
   arrives with a defectless subject is the only review that is cheap.
4. **The two skill copies drift, and the reader's copy is the one that
   accumulates.** The review lane wrote a measured lesson into its own
   `sdlc-review` during a round (the cost model this session confirmed), so
   the copies diverged again. The reader's copy is the canonical one (= it
   holds what the lane has learned), the author's copy follows it, and
   `skill_sync_check.py` proves they are in step.
5. **The review lane's quota wall is not a transient 429.** Measured today:
   14 consecutive runs of one card each lived 60 seconds and ended
   `rate_limited` (the Token Plan allowance was spent), and the card was
   re-dispatched every 6 minutes without counting a failure. The run that
   succeeded took 39 minutes. The judge is the newest `rate_limit_error`
   timestamp in the reviewer's `errors.log`, not the card's status.
