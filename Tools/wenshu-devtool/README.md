# wenshu-devtool

Remote dev tool for wenshu macOS app. Hermes `tui_gateway` pattern: a standalone Python process that uses Apple standard APIs (`osascript` / `screencapture` / `defaults` / `security`) to read wenshu NSWindow + UI state.

**Core principles (老板 8/19 truth source):**
- Does not embed wenshu core (does not modify `Sources/WenshuApp/`)
- Does not modify `Package.swift` (Tools/ is not part of Swift sources)
- Does not modify `Scripts/build-app.sh`
- Does not enter the wenshu release bundle (`build/Wenshu.app/Contents/Resources/` does not contain devtool)
- At release: simply delete the `Tools/wenshu-devtool/` directory, no need to change wenshu core

## Usage

```bash
# 1. List wenshu NSWindow truth source
python3 Tools/wenshu-devtool/wenshu_devtool.py list_windows

# 2. Screenshot a specific wenshu NSWindow
python3 Tools/wenshu-devtool/wenshu_devtool.py screenshot <window_id> <output.png>

# 3. Dump frontmost window UI tree (System Events UI elements)
python3 Tools/wenshu-devtool/wenshu_devtool.py ui_dump

# 4. Dump menu bar (Apple / 文枢 / File / Edit / View / Window / Help)
python3 Tools/wenshu-devtool/wenshu_devtool.py menu_dump

# 5. Dump UserDefaults (provider / model / appearance)
python3 Tools/wenshu-devtool/wenshu_devtool.py settings_dump

# 6. List ProviderKeychain's stored providers
python3 Tools/wenshu-devtool/wenshu_devtool.py keychain_list

# 7. Return provider key (masked, only first 4 + last 4 shown)
python3 Tools/wenshu-devtool/wenshu_devtool.py keychain_get openrouter
```

## Front-end measurement

A separate tool, because it measures the app's own source tree instead of
the running app.

```bash
# 8. Measure the front end's parameter drilling (= dead parameters + heaviest initializers)
python3 Tools/wenshu-devtool/measure-drill.py --root Sources/WenshuApp

# 8b. Only the heaviest N call sites
python3 Tools/wenshu-devtool/measure-drill.py --root Sources/WenshuApp --top 10
```

It reads the Swift source, strips comments and string literals, and
reports the initializer parameters that are declared, passed down through
their call sites, and never read. Its own test suite runs on fixtures:

```bash
python3 Tools/wenshu-devtool/tests/test_measure_drill.py
```

## Board liveness

`status='running'` on a card means a CLAIM exists, not that an agent is
working on it. The board's own liveness signal is a heartbeat, and a
heartbeating claim looks the same either way.

```bash
# Is every running card actually WORKING, or is it just holding a slot?
python3 Tools/wenshu-devtool/board_liveness.py

# A different freshness window (= seconds without an API call)
python3 Tools/wenshu-devtool/board_liveness.py --fresh 7200

# A different boot window (= seconds after a run starts during which zero API
# calls means "starting", not "slot-only")
python3 Tools/wenshu-devtool/board_liveness.py --grace 300
```

One line per running card, with the verdict:

| verdict | meaning |
| --- | --- |
| `working` | an API call within `--fresh` seconds |
| `stale` | the worker HAS made API calls, but the last is older than `--fresh` (= it may be mid-turn; NOT idle) |
| `starting` | the run began within `--grace` seconds and has NOT made its first API call yet (= the worker is BOOTING; not idle) |
| `slot-only` | the worker made NO API call AT ALL, and the run is older than `--grace`: the claim holds a host slot and nobody is working |
| `no-agent` | no agent session could be resolved for the card |

It exits 2 when a card is `slot-only` / `no-agent`. READ-ONLY: every board is
opened with `mode=ro`.

**Never reclaim a card because it "looks idle".** A reclaim RESTARTS the card
from scratch: the worktree survives, the conversation does not. Measured
2026-10-28: a reclaim justified by "the claim is holding a host slot but no
agent is attached" threw away 32 minutes of work — that worker had made 18
API calls in the window and was working the whole time.

Its test suite runs on fixture boards and fixture logs:

```bash
python3 Tools/wenshu-devtool/tests/test_board_liveness.py
```

## Visual probes

`Tools/wenshu-devtool/probes/` holds the measurements that outlive their
session: one file per measurement, named after what it measures, so a
worker told to "measure the bubble" finds the last worker's measurement
instead of writing its own. `Tools/wenshu-devtool/probe-index.md` lists
every probe with the commit its numbers came from, because a number
measured against one commit does not describe a later commit.

```bash
# 10. The chat bubble's painted width and corner radius, from rendered pixels
swift Tools/wenshu-devtool/probes/chat_bubble_metrics.swift "Hi"

# 11. Whether two neighbouring columns share one chrome band, from a 2x capture
python3 Tools/wenshu-devtool/probes/column_chrome_band.py <capture.png>

# 12. Prove that gate has teeth (it must REJECT a short band whose centre agrees)
python3 Tools/wenshu-devtool/probes/column_chrome_band.py --selftest
```

The index's own test proves the index and the probes directory agree in
both directions (= a probe with no row, and a row with no probe behind it,
are both reported):

```bash
python3 Tools/wenshu-devtool/tests/test_probe_index.py
```

## Ticket difficulty tier

Another separate tool, because it measures a card body instead of the
source tree. It derives a card's difficulty tier (T1 trivial / T2 standard /
T3 deep) from the work the body describes, and prints the runtime cap, the
retry budget and the gate that tier buys.

```bash
# 9. The tier contract (= the caps, the budgets, the gates)
python3 Tools/wenshu-devtool/ticket_tier.py --plan

# 9b. Rate a card body before dispatching it
python3 Tools/wenshu-devtool/ticket_tier.py --body card.md

# 9c. Check every card on the board against the tier it earns
python3 Tools/wenshu-devtool/ticket_tier.py --board wenshu-par --check
```

Its test suite runs on fixture bodies:

```bash
python3 Tools/wenshu-devtool/tests/test_ticket_tier.py
```

The tier's contract and the measurements behind its numbers are in
`docs/agents/ticket-tiers.md`.

**A card in the review lane is held to the review lane's own floor, not to
its tier's cap.** A review run re-reads the diff, re-derives the acceptance
and re-runs the gates, so it is slower than the implementation it audits:
measured on this board, the review runs on a 1500 s cap died at 25.1 min
(seven of them) and a review on a 3600 s cap completed at 27 min. So a card
whose status is `review` must carry at least 3600 s, and a card carrying more
is generous rather than wrong. The floor belongs to the lane, so it does not
move with the card's tier.

## Dead-code gate

Another separate tool, because it measures the source tree instead of the
running app. It reports the types no file can reach: a type whose name
appears in no other file is a candidate only when nothing reads it either
(= no member read, no value received from a called function, no use in its
own file).

```bash
# 13. Scan the view tree for unreachable types
python3 Tools/wenshu-devtool/verify-dead.py --ui-components

# 13b. Why one type is alive (= the reader that reaches it)
python3 Tools/wenshu-devtool/verify-dead.py --ui-components --verbose \
    Sources/WenshuApp/Features/Editor/Service/WordCounter.swift
```

With no file arguments the scan covers the view tree (= every
`Features/*/View` directory plus `Shared/UI`), and it names the
directories it scanned. A directory that does not exist is skipped, so a
moved directory never breaks the scan. With file arguments it checks
exactly those files. The exit code is non-zero when it finds a deletion
candidate.

Its test suite runs on fixture trees:

```bash
python3 Tools/wenshu-devtool/tests/test_verify_dead.py
```

## Registry LOC gate

Another separate tool, because it reads the REGISTRY instead of the
source tree. The registry's merge driver merges at the key level, and a
key's whole row text is its value: so a same-key disagreement is a
conflict only when BOTH sides changed the key. When one side alone
carries a wrong LOC, the driver has nothing to compare it against and
carries it through silently. Measured: pasting one file's count over
another file's row leaves every other gate green.

So this gate holds the rule the driver cannot. The registry's own
header says the LOC column is the count AT THE MOMENT THE ROW WAS
WRITTEN, so a row this change did not add is not this change's
business (= 92 rows carry a stale count by design). This gate reads the
rows this change ADDED, and each must carry that file's own `wc -l`.

```bash
# = = the rows this change added must carry their files' own counts = =
python3 Tools/wenshu-devtool/nfi-loc-check.py --base <base-sha>
```

Its test suite runs on a fixture tree:

```bash
python3 Tools/wenshu-devtool/tests/test_nfi_loc_check.py
```

## Independent-review gate

Another separate tool, because it reads the BOARD instead of the source tree.
It answers the two questions the review contract needs:

- **CONTRACT** = what the card owes: does the body write code, and does it
  name a reviewer profile that is not the implementer?
- **RECORD** = what the board holds: is there an approving verdict, and which
  profile gave it? The verdict lives in ONE field of the approving run's
  metadata (`review_outcome: "approved"`), so a verdict written in the run's
  summary is not a verdict the gate can see, and the field is never
  backfilled by hand.

The obligation to get an independent verdict is DERIVED from the work the body
describes, never hand-set, and it is independent of the difficulty tier: a
T1 code card and a T3 code card owe the same verdict, and a prose card owes
none. That is not a preference. Measured on board `wenshu-par`, 2026-10-26:
113 of 114 done cards carried ZERO review events, the one review that did run
was the implementer reviewing itself, and 5 done cards promised files their
branch does not contain (= a false done) — all 5 wrote code, 0 wrote prose.

```bash
# 14. What does this body owe (= before dispatching it)
python3 Tools/wenshu-devtool/review_gate.py --body card.md

# 14b. What does the board hold for this card
python3 Tools/wenshu-devtool/review_gate.py --card t_xxx

# 14c. Every card on the board
python3 Tools/wenshu-devtool/review_gate.py --board wenshu-par --check
```

Its test suite runs on fixture bodies and fixture board records:

```bash
python3 Tools/wenshu-devtool/tests/test_review_gate.py
```

Exit code: 0 = the gate is satisfied, 1 = a contract error, 2 = the board could
not be read, 3 = a card owes a verdict it does not have. The merge gate
(`Scripts/merge-preflight.sh`) runs the record check for the branch it is
asked to bless and refuses the merge until the verdict is on the record.

## Pre-review gate

A separate tool, because it runs BEFORE a branch goes back to the review
lane, and it reads the WORKING TREE rather than the board. It answers one
question: **was every gate measured on the exact tree that will be
reviewed?**

Six review rounds on one branch found, in order: a tree that did not
compile, a formatting gate that exited 1, a registry row carrying another
file's count, a heading face that never reached the editor, an assertion
written about a range the author had never looked at, and a card whose
GATES did not run the engine's own suite. Every one of those was a claim
made from reasoning and not from a measurement.

```bash
# the branch's own tree, against the base it will land on
python3 Tools/wenshu-devtool/pre_review_gate.py --base main \
    --card <the card body file> \
    --filter '<the card's own suite>'
```

Four rules, each of which can fail:

1. **the tree must be committed** (`swift build --build-tests` reads HEAD,
   so a dirty worktree measures the wrong tree),
2. **the build must build the tests** (`swift build` alone does not build
   the test target),
3. **every gate the card names must run, AND every gate it runs must have
   measured something** — a `swift test --filter` that matches no test
   case exits 0, prints no summary, and prints "No matching test cases
   were run", so a reader that reads only the exit code calls a renamed
   suite a PASS; and a card that names no suite at all measures nothing.
   The card's **GATE lines** are the ones that count: the reader reads the
   GATES section, and within it only the lines that read as commands, so a
   WHY sentence that merely *mentions* `swift test --filter` is not a gate
   (and a filter quoted in prose is not run);
4. **every tree the change touches must have its own suite** (the vendored
   engine has its own, and a change that touches it runs it).

Rule 3 is the one the repository's own CI already holds: a log with no
`Test run with` summary is a failure (`.github/workflows/ci.yml`).

The CJK audit (rule 7.5) reads the **comment part** of a line, not the
whole raw line, so a CJK string literal beside a trailing comment stays a
literal — and a multiline literal's state is carried across its lines, so a
`//` inside one is not a comment either.

Its test suite runs on fixture text:

```bash
python3 Tools/wenshu-devtool/tests/test_pre_review_gate.py
```

Exit code: 0 = every gate measured and green, 1 = a gate failed, or the
tree is dirty, or a gate could not run.

## Review-lane cost meter

A separate tool, because it reads the BOARD and the REVIEWER PROFILE rather
than the source tree. It answers one question: **what does a review run
actually cost, and which of its numbers can a change move?**

The lane's cost is the ROUND TRIP, not the gate's runtime. Every tool call
is one API call, and every API call re-sends the whole history, so a run's
price grows with the SQUARE of its round count. Measured on board
`wenshu-par` over the wenshu-review profile's whole log (2026-11-03, 310
review sessions, 25219 API calls):

- **83% of the wall clock is API latency** (181 h of 219 h); the terminal
  work is the rest. So the gate's width is NOT what makes a review slow.
- a completed review makes **105 shell calls**, and it WRITES its own
  scripts to do it (3894 scratch files written, 3331 of them distinct, so
  the same measurement gets reinvented and rewritten).
- the terminal call correlates **+0.717** with the wall clock and every tool
  call +0.700, while a scratch write alone is +0.400 and a repo gate call is
  far below both. So the scripts the reviewer writes ARE the cost.
- the median latency is 5 s below 50k input tokens and 22 s above 350k, the
  context grows 9x inside a session, and the last third of a session's calls
  eats 37% of its API time.
- **54% of the lane's runs end without a verdict** (timed out, rate limited,
  or crashed), and a retry starts from zero.
- the CARD's shape predicts almost nothing: body length correlates +0.295
  with the call count and nothing else does, and once the body size is held
  constant every other card feature falls to |r| < 0.1. **So there is no
  card-side cost gate**: a card moves the wall clock only by naming the
  command that answers each question, and the meter is how that is checked.

```bash
# The review lane, as a text report
python3 Tools/wenshu-devtool/review_lane_cost.py

# The same numbers, machine-readable (= the before/after of a change)
python3 Tools/wenshu-devtool/review_lane_cost.py --json

# Another lane or board
python3 Tools/wenshu-devtool/review_lane_cost.py --profile wenshu-dev
```

Its test suite runs on fixtures (a temporary board DB and a temporary
agent.log), so it stays valid when the real board and the real logs change:

```bash
python3 Tools/wenshu-devtool/tests/test_review_lane_cost.py
```

The meter is READ-ONLY: it never writes to the board or to the profile logs,
and a board it cannot read yields zeros rather than a crash.

## Skill-sync check

A separate tool, because it reads the SKILL TREE rather than the source
tree. It answers the question a rule-writing session always gets wrong:
**is the rule I just wrote a rule the READER will see?**

A rule that nobody reads is not a rule. Measured on board `wenshu-par`
(2026-11-03): the review lane loads `sdlc-review` **209** times and
`wenshu-parallel-dev` **34** times, so a rule written into the 1199-line
review-round reference is nearly invisible to the worker that has to follow
it. And a skill in the shared tree (`~/.hermes/shared/wenshu-skills`, on
every profile's `skills.external_dirs`) is loaded by EVERY profile, while a
skill in a profile's own directory is loaded only by that profile = two
copies of one skill can drift silently.

So the check answers:

- **who carries the skill** (= the shared tree carries it everywhere; a
  profile's own copy shadows the shared one);
- **do the copies carry the same rules** (= the same `##`/`###` headings,
  not the same bytes: a profile's copy may legitimately carry extra prose,
  but the RULE SET must match, or the reader runs a different rule set
  than the author wrote);
- **is the reader among the carriers** (= a rule written where the reader
  never looks is not a rule);
- **does the named rule appear in the reader's copy.**

```bash
# Every flow skill: who carries it, and do the copies agree
python3 Tools/wenshu-devtool/skill_sync_check.py

# One skill, and one rule that must be in its reader's copy
python3 Tools/wenshu-devtool/skill_sync_check.py \
    --skill sdlc-review --rule "THE COST OF A REVIEW"
```

Its test suite runs on a fixture tree (a temporary `.hermes` with a shared
tree and per-profile skills), so it stays valid when the real skills change:

```bash
python3 Tools/wenshu-devtool/tests/test_skill_sync_check.py
```

## Mutation check

A separate tool, because it reads the TESTS and the code they guard. It
answers the question a passing test suite cannot: **does this suite
actually bite?**

A regression test that asserts on its OWN arithmetic instead of on the
code's output is a guard that cannot fail, and the review lane found
exactly that, three rounds in (2026-11-03): a case that was meant to guard
a headline fix re-implemented the headline's formula inside the test and
asserted on that, so reverting the guarded code left the suite green while
the tool still printed the defective string. The acceptance criterion is
therefore not "the suite passes" but:

```
revert the guarded code  ->  the suite goes RED
leave the code alone     ->  the suite stays GREEN
```

A suite that passes in both states is decoration.

The tool runs the suite against a COPY of the tree with the mutation
applied, in a fresh temporary directory, with a fresh subprocess (= no
bytecode cache, and the real worktree is never edited). It reports the
control run and the mutated run together, so a green control beside a red
mutation is a guard that bites.

```bash
# Prove a guard bites: revert the guarded line and the suite must go red
python3 Tools/wenshu-devtool/mutation_check.py \
    --suite Tools/wenshu-devtool/tests/test_skill_sync_check.py \
    --guard Tools/wenshu-devtool/skill_sync_check.py \
    --mutate 'return not (result.get("drift") or result.get("wording_drift"))' \
    --replace 'return not result.get("drift")'

# The control alone (= the suite is green, so it CAN bite)
python3 Tools/wenshu-devtool/mutation_check.py \
    --suite Tools/wenshu-devtool/tests/test_skill_sync_check.py \
    --control
```

Exit code: 0 = the suite bit, 1 = it did not (= the guard is empty), 2 = the
suite was already red (= no verdict).

## Inventory measure

The tree's own comment census (= the malformed doc comments, = = the collapse
receipts, = = the CJK in comments, = = the boss-directive references, = = the
ticket ids, = = and the production tree's three size rows). = = Every row
prints the method that produced it, = = so a number can be reproduced.

```
python3 Tools/wenshu-devtool/inventory-measure.py
python3 Tools/wenshu-devtool/inventory-measure.py --base main
python3 Tools/wenshu-devtool/inventory-measure.py --base <base sha> --tip <tip sha>
python3 Tools/wenshu-devtool/inventory-measure.py --files <path> [<path> ...]
```

= = The ticket-id row (= = measure 5) = = reaches the families this rule
covers, = = each with a form the rule reaches: = = the hyphenated one
(`T4-SUBAGENT-UI`, = = `P1-02`, = = `C-4`), = = the bare-number one (`A112`,
= = `Q112`, = = `M1`), = = the LETTER-SUFFIXED one (`T20c`, = = `T1a`, = =
`H2s`), = = the lowercase-prefixed one (`round-19`), = = and the
connector-ticket one (`GAP-003`, = = `TICKET-HERMES-GAP-002`, = =
`TKT-028-025`), = = which the tree's own prose calls tickets (= = "out of
scope per the GAP-003 ticket body"). = = The bare-number alternative alone
cannot match the letter-suffixed family, = = because the suffix letter
continues the word: = = measured over the production tree at the base, = =
the old matcher saw **0** of the family's **22** occurrences. = = The
hyphenated family is matched WHOLE (= = `P1-02`, = = not the fragment
`P1`), = = because a truncated id makes the at_base attribution decide on
a fragment. = = So the matcher carries its own cases.

= = The row also publishes EACH HIT's `at_base` status (= = the base's debt
against the change's own) for the files the change touched, = = and the
tree's own row. = = The status is the base's debt IN THAT FILE: = = a
token the base carried in another file is not this file's debt. = = The
aggregate pair alone was not enough: = = the numbers were right and the
reader could not check them.

= = The numbers depend on the base, = = so they are stated with the sha
they were measured at: = = at base `722e73ec13f2a8a5140afce82449fd0689ee1feb`
the tree's row reads `base 362 -> tip 306`; = = at base
`e19d6bb579496a5a81061d172e663c6713bd2288` it reads `base 306 -> tip 306`.
= = And the connector-ticket family (= = the forms the tree's own prose
calls tickets) occurs **22** times in production comment lines at
`722e73ec13f2a8a5140afce82449fd0689ee1feb` and **21** at
`e19d6bb579496a5a81061d172e663c6713bd2288`; = = of those, `GAP-003` alone
occurs **4** times.

```
python3 Tools/wenshu-devtool/tests/test_inventory_measure.py
```

= = The suite names every form the tree really uses, = = every ordinary
word a loose matcher would catch, = = the branch's added comment lines
(= = which must carry no ticket id), = = and the rewritten block (= = which
must carry its clause once). = = It also holds the PRINTED METHOD to what
the code does: = = the method's own skip list must equal the code's, = =
every exemplar it names must be reachable by the matcher, = = and the rule
it prints must be the rule the matcher compiles. = = Those three checks are
general (= = they parse the method's own text), = = so they catch the class
of defect rather than one literal. = = And the tool's PUBLICATION of each
hit's `at_base` status is guarded too, = = because the attribution can be
correct and unpublished. = = Each case can fail: = = narrowing the matcher
turns the family's own cases red, = = putting a ticket id back turns the
added-lines case red, = = and dropping a skip from the method turns the
method's own case red.

## Card sha

A separate tool, because it reads the GIT REPO and the card body. It
answers the question a card author gets wrong by hand: **is the sha in this
card real?**

A sha is 40 hex characters, and it is read by the merge gate
(`review_gate.reviewed_sha(body)` reads the FIRST PARAGRAPH of the
`## WHAT TO BUILD` section and takes its first `[0-9a-f]{7,40}` match).
Measured 2026-11-03 on the wenshu-par board: three cards carried a "full
sha" that was a hand-written guess (= a short sha with random characters
appended), and nothing caught it = the gate could not tell a guess from a
sha. The short sha in the first paragraph was real in every case, so the
cards worked by accident.

So: never type a sha. Read it.

```bash
# The sha a branch points at, read from git
python3 Tools/wenshu-devtool/card_sha.py --read wt/review-lane-cost

# Put a branch's REAL sha into a card body (both sha lines)
python3 Tools/wenshu-devtool/card_sha.py --write card.md --branch wt/review-lane-cost

# Check a card body: every sha it names, and the one the gate would read
python3 Tools/wenshu-devtool/card_sha.py --check card.md
```

`--check` exits 1 when a sha in the body does not exist, when a sha has the
wrong length (= a typed sha), or when the first paragraph names no sha at
all (= the gate reads none, so no verdict on the card can cover the branch).

Its test suite runs on a fixture repo (a temporary directory with two real
commits), so it stays valid when the real repo changes:

```bash
python3 Tools/wenshu-devtool/tests/test_card_sha.py
```

## AGENTS.md contract gate

Another separate tool, because it reads the SSOT instead of the source tree
or the board. It answers one question: is AGENTS.md still loadable and true?

- **frontmatter** parses as YAML, and carries name / version / description
- **budget** the file fits the loader's cap (20,000 chars) AS THE LOADER
  READS IT: the whole file, frontmatter included, plus the `## AGENTS.md`
  label. The cap drops the MIDDLE of a file that is too long, so a
  body-only budget would pass a file whose middle rules silently vanish.
- **references** every path the file names exists, and every skill it names
  is installed
- **vocabulary** CJK appears only in the rules that enumerate the vocabulary
  (1.2 / 1.3 / 1.4), and only as a token from that vocabulary
- **ids** the rule ids of each section are contiguous, no row id is
  duplicated, and every internal section reference resolves
- **structure** the required sections (§1 / §7 / §8 / §10) are present

```bash
# 15. Is AGENTS.md still loadable and true?
python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md

# 15b. The same verdict, machine-readable
python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md --json

# 15c. What the gate checks (= the contract it enforces)
python3 Tools/wenshu-devtool/agents_gate.py --plan
```

Its test suite runs on fixture files:

```bash
python3 Tools/wenshu-devtool/tests/test_agents_gate.py
```

Exit code: 0 = the file is loadable and true, 1 = a contract error, 2 = the
file could not be read.

## Requirements

- macOS (uses `osascript`, `screencapture`, `defaults`, `security`)
- Python 3.9+ (no third-party deps, stdlib only)
- WenshuApp running (for `list_windows` / `screenshot` / `ui_dump` / `menu_dump`)

## Security

- `keychain_get` output only shows the first 4 + last 4 characters (does not expose the full key)
- No log writes (= `print(json.dumps(...))` is not persisted)
- Does not modify any file (= read-only)
- Requires macOS Screen Recording / Accessibility permission (System Settings → Privacy & Security → Screen Recording / Accessibility)

## Release

老板 拍 "for real release we remove it" themselves:
- Delete the `Tools/wenshu-devtool/` directory
- No need to change `Sources/WenshuApp/` / `Package.swift` / `Scripts/build-app.sh`
- wenshu release bundle auto-excludes devtool