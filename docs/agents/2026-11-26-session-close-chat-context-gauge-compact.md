# The context meter counts in unit form (2026-11-26)

## The scope

The chat bar's context gauge and its popover showed a token count as its raw
digits. The boss's out-of-band row `2026-11-26 (unit form)` (see
`OOB.md #2026-11-26 (unit form)`) asked that a displayed count carry a unit,
because the digit string was too long to read at a glance. The scope is the
gauge's second unit: the first one (`2026-11-24-chat-context-gauge`) put the
meter there, this one changed how it counts.

Plan of record: `.scratch/2026-11-26-chat-context-gauge-compact/` (spec.md,
`issues/001-the-meter-counts-in-unit-form.md`, `issues/_index.md`).

The change was cut from `97ac0dfde5` and landed as `b943733a9b` on `main`.

## The symptom, measured on the base

The label passed two raw `Int`s straight into a catalog string whose slots
were integer slots:

```
git show 97ac0dfde5:Sources/WenshuApp/Features/Chat/View/ChatContextGaugeView.swift | sed -n '101,110p'
```

⇒ ⇒ ⇒ AND WHAT IT PRINTS (= = the base's `reading`, = = and the two catalog values it fills):

```
# SKIP: this block is the block above's OUTPUT, = = not a command, = = so the
# verifier must not run it.
        return String(
            format: String(localized: "chat.context.gauge.reading"),
            snapshot.promptTokens,
            snapshot.contextWindow
        )
```

```
git show 97ac0dfde5:Sources/WenshuApp/Resources/Localizable.xcstrings | python3 -c 'import json,sys; c=json.load(sys.stdin)["strings"]; [print(k, {l: v["localizations"][l]["stringUnit"]["value"] for l in v["localizations"]}) for k, v in c.items() if k in ("chat.context.gauge.reading", "chat.context.breakdown.summary")]'
```

```
# SKIP: this block is the block above's OUTPUT, = = not a command.
chat.context.gauge.reading {'en': 'Context: %lld / %lld tokens', 'zh-Hans': '上下文 %lld / %lld tokens'}
chat.context.breakdown.summary {'en': 'Context: %lld / %lld tokens (%lld%%)', 'zh-Hans': '上下文 %lld / %lld tokens（%lld%%）'}
```

`%lld` prints the whole number, so a real reading of 118,339 tokens against a
128,000 window filled the bar with twelve digits and four separators. The
popover's headline repeated the same pair. The tree asked Foundation for no
abbreviated form anywhere:

```
git grep -c compactName 97ac0dfde5 -- Sources    # prints nothing
```

## The fix

One entry point owns the conversion: `TokenUnitFormat`
(`Sources/WenshuApp/Shared/Foundation/TokenUnitFormat.swift:35`).
`string(_:locale:)` at `:43` returns the locale's compact-name form for a
count at or above `unitThreshold` (`:67`, `10000`) and the plain grouped form
below it; `exactString(_:locale:)` at `:59` returns the whole number, and it is
what the label's hover carries. The unit and the magnitude it starts at are
Foundation's (`IntegerFormatStyle.NumberScheme` and `.notation(.compactName)`),
not a divisor and a suffix the app wrote.

The precision is pinned: `.precision(.fractionLength(0 ... 1))`. The reason is
in the reading below: Foundation's default rounds `128000` to thirteen
whole ten-thousands in Chinese (`13` plus the unit), which hides the window's
own size, and a glance at the bar is exactly where the window's size matters.

The view changed at four seams in `ChatContextGaugeView.swift`: the label
(`:93`) gains `.help(exactReading)` at `:97`, `reading` (`:105`) passes the two
converted values at `:111` and `:112`, `exactReading` (`:120`) is the new hover's
string, and the popover's header passes the same pair at `:219` and `:220`. The catalog's two keys moved from `%lld`
slots to `%1$@` / `%2$@`, and the new key `chat.context.gauge.exact` carries
the exact pair. The popover's part rows still print `.formatted()`, so the
full numbers stay where a reader goes for them.

## The measured before and after

The probe compiles the shipped file and calls it. It does not re-implement it:

```
cd /Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/chat-context-gauge-compact
xcrun swiftc /Volumes/ANAN/Engineering/wenshu/Sources/WenshuApp/Shared/Foundation/TokenUnitFormat.swift main.swift -o unitprobe
./unitprobe
```

⇒ ⇒ ⇒ AND WHAT IT PRINTS AT `b943733a9b` (= = `unit` is the bar's form, = =
`exact` is the hover's, = = `compact_default` is what an unpinned precision
would have shown):

```
# SKIP: this block is the block above's OUTPUT, = = not a command.
zh_Hans 3027 unit=3,027 exact=3,027 compact_default=3027
zh_Hans 9999 unit=9,999 exact=9,999 compact_default=9999
zh_Hans 10000 unit=1万 exact=10,000 compact_default=1万
zh_Hans 118339 unit=11.8万 exact=118,339 compact_default=12万
zh_Hans 128000 unit=12.8万 exact=128,000 compact_default=13万
en_US 3027 unit=3,027 exact=3,027 compact_default=3K
en_US 9999 unit=9,999 exact=9,999 compact_default=10K
en_US 10000 unit=10K exact=10,000 compact_default=10K
en_US 118339 unit=118.3K exact=118,339 compact_default=118K
en_US 128000 unit=128K exact=128,000 compact_default=128K
```

The label's pair for the reading above is `11.8` and `12.8` against the
ten-thousand unit in Chinese, and `118.3K / 128K` in English. Both are thirteen characters where the base's pair
(`118339 / 128000`) was fifteen, and the reader's eye no longer counts digits:
the unit says which magnitude the window is in.

The cost is named in the plan's last section and it is real: below 10,000 an
English count keeps its grouped digits (`3,027`) where Foundation's bare
`.compactName` would have said `3K`, because the threshold is Chinese's first
unit and one rule for both locales is cheaper to hold than two.

## The gates, and the one that proved nothing

`Scripts/land_card.sh t_9adb4b4a wt/chat-context-gauge-compact-2026-11-26` ran
sixteen lines in the lane's own worktree before it moved `main`, and each log
opens with the tree it measured (= = `.gate-logs/t_9adb4b4a_a1_<n>.log`, = =
every one of them first line `tree=b943733a9b5f8f7f96fb3163a739414efbc4b840`).
The readings:

Every reading below is verbatim, including the unit the tool printed it in.

| Gate | Reading |
| --- | --- |
| `swift build --build-tests` | `Build complete! (36.72秒)` |
| `swift test --filter TokenUnitFormatTests` | `Test run with 5 tests in 1 suite passed` (= `Tests/WenshuAppTests/Shared/Foundation/TokenUnitFormatTests.swift`, the suite that owns this change) |
| `swift test --filter EditorChromeReserveAndContextUsageTests` | `Test run with 6 tests in 1 suite passed` |
| `swift test --filter ContextUsageRecorderTests` | `Test run with 12 tests in 1 suite passed` |
| `ci_change_gate.py --base 703a3fcd60 --check pollution` | `the change adds no forbidden vocabulary` |
| `… --check formatting` | `the change adds no unformatted line (4 changed Swift file(s) checked)` |
| `… --check markdown-newline` | `the change drops no .md's trailing newline (2 changed .md file(s) checked)` |
| `… --check loc-cap` | `every changed Swift file is within the 600-LOC cap (4 file(s) checked)` |
| `comment_lineage.py --base 703a3fcd60 --head HEAD` | `added comment lines: 83`, `offending: 0 rows / 0 files` |
| `nfi-loc-check.py --base 703a3fcd60` | `3 row(s) checked: 2 the change added, 1 whose named file the change rewrote` |
| `review_gate.py --card t_35c29c67 --sha b943733a9b` | `approved approved by wenshu-review` |
| `Scripts/merge-preflight.sh wt/chat-context-gauge-compact-2026-11-26` | `CLEAN` |

**One line was a defect in the card, not in the tree.** The landing card
published `swift test --skip-build --filter ChatContextGaugeViewTests` as its
sixth gate, and that filter names no suite:

```
grep -rl "ChatContextGaugeView" Tests | wc -l        # prints 0
```

The run exited 0 while printing `warning: No matching test cases were run`. An
exit code from a filter that selects nothing is not evidence, and a card that
lists it as a gate has a hole in its gate list. The wide filter the review
rounds actually used was never in the landing card's list, so it ran after the
landing, on the merged tree, at the same sha:

```
cd /Volumes/ANAN/Engineering/wenshu/.worktrees/chat-context-gauge-compact-2026-11-26
echo tree=$(git rev-parse HEAD); swift test --skip-build --filter "Context|Token|Localization"
```

```
# SKIP: this block is the block above's OUTPUT, = = not a command.
tree=b943733a9b5f8f7f96fb3163a739414efbc4b840
Test run with 8 tests in 1 suite passed after 0.291 seconds.
Test run with 181 tests in 53 suites passed after 14.973 seconds.
Test run with 36 tests in 5 suites passed after 0.039 seconds.
WIDE_RC=0
```

`swift test` prints one `Test run started` line per test bundle, so the three
summaries are three bundles, and the log names them in its order and nothing
else: the pairing of a summary to a target is not something the tool prints, so
this record does not print it either. What is pinned is that the suite owning
this change (`TokenUnitFormatTests`, five cases) passes on its own, and that no
line of the wide run failed.

⇒ ⇒ ⇒ AND THE REPAIR IS THE RULE: = = a gate line is published only with the
summary line its own command prints, and a filter that reports no cases is
replaced, not excused.

**The same species bit this record's own landing.** Card `t_f49ddf3e` published
its registry-row check as a `grep -c` whose pattern held the row's backticks
inside double quotes, so the shell substituted them:

```
grep -c "``docs/agents/<record>.md``" docs/agents/nfi.md
```

`Scripts/gate_run.sh` hands each line to `bash -lc`. The log therefore carries
`bash: docs/agents/…: Permission denied` and a count of 587 rows instead of one,
and the line exited 0 with the runner printing `PASS`. The row's real reading came
from two commands whose pattern reaches `grep` at all:

```
grep -c "session-close-chat-context-gauge-compact.md" docs/agents/nfi.md
python3 Tools/wenshu-devtool/nfi-loc-check.py --base 703a3fcd60
```

⇒ ⇒ ⇒ AND THE RULE GAINS ITS SECOND HALF: = = no backtick sits inside a
double-quoted gate line, = = and a gate's printed number is read against the number
the card claims, = = because `PASS` is the runner's exit code and nothing more.

## The rebase, and which identity survived it

Round 3 approved `9108f18f79` (card `t_35c29c67`, run 5169). `main` moved by
eleven commits while the round ran, so the lane was rebased onto `703a3fcd60`
and the landing carries `b943733a9b` instead. Which identity survived the
rebase is a measurement, not an assumption:

```
python3 -c 'import sys; sys.path.insert(0, "Tools/wenshu-devtool"); import review_gate as rg; print(rg.change_id("9108f18f79", "97ac0dfde5")); print(rg.change_id("b943733a9b", "703a3fcd60")); print(rg.patch_id("9108f18f79", "97ac0dfde5")); print(rg.patch_id("b943733a9b", "703a3fcd60"))'
```

```
# SKIP: this block is the block above's OUTPUT, = = not a command.
change_id b2595b1be9b76e08c5398e22ca34541aa35af037792229cb3b4e91a13d57f453   (one value, both shas)
change_id b2595b1be9b76e08c5398e22ca34541aa35af037792229cb3b4e91a13d57f453
patch_id  3105f4880f768d5ce4353cb986c1ca4ee06cb79e
patch_id  9f4262347b8de299fab67f080f6a352f0251466b
```

`change_id` is what a verdict binds to and it held. `patch_id` moved, and that
is what it means: a patch-id carries context lines, and the two neighbours
differ because `main` did. The two shas' trees also differ by other scopes'
work (`ChatViewModel.swift`, `ChatTranscriptBottom.swift`, `ChatView.swift`,
the two scroll suites, the devtool's register lock), which is why the card's
proof is a diff restricted to the five paths this change owns:

```
git diff 9108f18f79 b943733a9b -- Sources/WenshuApp/Features/Chat/View/ChatContextGaugeView.swift Sources/WenshuApp/Resources/Localizable.xcstrings Sources/WenshuApp/Shared/Foundation/TokenUnitFormat.swift Tests/WenshuAppTests/Shared/Foundation/TokenUnitFormatTests.swift Tests/WenshuAppTests/Editor/View/EditorChromeReserveAndContextUsageTests.swift
```

which prints nothing, and one shape on both bases: 7 files, 216 insertions,
11 deletions.

## The landings and the verdicts

The board's record for this scope, in order:

| Card | Kind | Verdict |
| --- | --- | --- |
| `t_64194b6d` | review, round 1 | `changes_requested` — one blocker: two catalog strings moved and a landed test still asserted the old one |
| `t_4ee63ed5` | review, round 2 | `changes_requested` — one blocker (B2, comment 2929): the commit message attributed `Test run with 1 test in 1 suite failed` to a filter that cannot print it |
| `t_35c29c67` | review, round 3 | `approved` (run 5169) at `9108f18f79`, message-only round, tree byte-identical to round 2 |
| `t_9adb4b4a` | landing | ran the sixteen lines above and moved `main` |
| `t_f49ddf3e` | landing, this record | found `main` already at `37f5b69768` (compare-and-swap from `b943733a9b`, no rebase), and named its own gate 11 as defective: double quotes around a backticked path made the shell substitute it |
| `t_88aa61ec` | review, this record round 1 | `approved` (run 5183, after run 5182 came back `rate_limited`) at `37f5b69768` |
| `t_c4a6829e` | review, this record round 2 | `approved` (run 5193) at `360bc2495f`, the commit that rebases to these corrections |

The landing moved `main` by compare-and-swap against the sha it rebased onto
(`.gate-logs/t_9adb4b4a_update_ref.log`), and both remotes were pushed and read
back at that instant:

```
git ls-remote origin refs/heads/main
git ls-remote old-origin refs/heads/main
```

```
# SKIP: this block is the block above's OUTPUT, = = not a command.
b943733a9b5f8f7f96fb3163a739414efbc4b840        refs/heads/main
b943733a9b5f8f7f96fb3163a739414efbc4b840        refs/heads/main
```

This record's first landing ran the same path twelve lines and parked them in
`.gate-logs/gauge-compact-record_a1_<n>.log`, every one of them headlined
`tree=37f5b69768e1a41d5c249b8af6fd0877d7e4d1bb`, and both remotes read that sha
at that instant.

⇒ AND A REMOTE'S TIP IS AN INSTANT, NOT A STATE. `Scripts/land_card.sh` pushes
the compare-and-swap to `origin` and to nothing else, so every landing after a
push, by any scope, moves `origin` and leaves `old-origin` where the last manual
push put it. Measured while these corrections were written: `git ls-remote
origin refs/heads/main` prints `0f9c784db6`, `git ls-remote old-origin
refs/heads/main` prints `37f5b69768`, and the distance is `git rev-list --count
old-origin/main..origin/main` = `4` commits belonging to other scopes
(`a694f4ffeb`, `9421df43a8`, `3ad2ccebfa`, `0f9c784db6`). ⇒ The claim that
movement cannot break is the ancestry, so that is what is published and the tips
are re-measured:

```
git merge-base --is-ancestor b943733a9b origin/main
git merge-base --is-ancestor b943733a9b old-origin/main
git rev-list --count old-origin/main..origin/main
```

⇒ AND THIS RECORD'S OWN LANDING IS PUSHED TO BOTH REMOTES, so at that instant
both print the scope's last landing. That sha is not written here, because
writing it changes the file that would carry it.

## The commits this scope owns, and the ones the push carried

This scope owns two commits on `main`: the change `b943733a9b`, and this record,
first as `37f5b69768` and then as the commit carrying these corrections. Its two
earlier shas, `1e536a1778` and `9108f18f79`, are not on `main`: the first was
amended into the second, and the second was rebased into `b943733a9b`. While the
rounds ran, `9108f18f79` was also `origin/wt/chat-context-gauge-compact-2026-11-26`
and the same branch on `old-origin`; the cleanup after the round-2 verdict
deleted that branch on both remotes, and `git ls-remote origin 'refs/keep/*'`
prints nothing, so the parks under `refs/keep/` live on this machine only.
`9108f18f79` is therefore held by exactly one reference,
`refs/keep/chat-context-gauge-compact-r3`, and a reader proves it with
`git rev-parse refs/keep/chat-context-gauge-compact-r3` beside
`git merge-base --is-ancestor 9108f18f79 main`, which exits 1: the reviewed sha
is not an ancestor of `main`, which is what a rebase is.

The push to `old-origin` carried five commits that are not this scope's:
`8900318cf9`, `f520d85302`, `ab648fbde4`, `cca55924cf`, `703a3fcd60`. They are
other sessions' work that `origin/main` already held, carried as maintenance of
the lagging remote, not as this scope's authorship. The push to `origin`
carried this scope's commit alone.

## The look (= the boss's own eyes)

AGENTS.md 7.7 makes a UI change's merge gate the boss looking at the running
build. This scope does not have that look yet, and it is not faked: no second
Wenshu instance was launched (the boss's own instance is running under the same
bundle id, and two of them both die), and no screenshot stands in for the
verdict. The surface changed at one visible seam: the bar's label, the popover
headline, and a new hover on the label.

## The open items

1. the boss's look at the meter's label in the running app, in both languages;
2. the key-specific assertion at
   `Tests/WenshuAppTests/Editor/View/EditorChromeReserveAndContextUsageTests.swift:319`,
   which this scope left alone on purpose and which is its own unit;
3. nothing else: the change is landed and is an ancestor of both remotes'
   `main`, and every card that names this scope is terminal (= the read-only
   query against `task_runs`'s board returns no row in `todo`, `ready`,
   `running`, `blocked`, `review`, `scheduled` or `triage`).

## The eight steps, as this scope ran them

The order matters and is stated first: this record is the scope's last commit,
so steps 4 to 7 happen after it lands and are described with the check a reader
runs, not with a claim of completion. `closeout_gate.py` is what decides them,
and it reads the tree, the board and the shared skill tree, not this prose.

1. **The §7 gates on the merged tree: every landing runs them in its own lane,
   and the log names the tree.** The landing card `t_9adb4b4a` ran sixteen lines
   before `main` moved, and every one of `.gate-logs/t_9adb4b4a_a1_<n>.log`
   opens with `tree=b943733a9b5f8f7f96fb3163a739414efbc4b840`. This record's
   first landing ran twelve at its own tip under the prefix
   `gauge-compact-record_a1_`, and its repair landing runs the same twelve under
   its own card's prefix, after the lane's tip equals `main`. ⇒ A run is bound to
   a tree by the log's first line, so the check is `head -1` on that prefix read
   beside `git rev-parse main`, and never a count of files.
2. **The verdict on the board: DONE.** `t_35c29c67` carries
   `review_outcome=approved`, and the gate binds it to the landed tree by the
   change's identity rather than the commit id (= `review_gate.py --card
   t_35c29c67 --branch wt/chat-context-gauge-compact-2026-11-26 --sha
   b943733a9b` prints `approved`); this record gets its own round, and that
   round's verdict lives on the board and not here.
3. **The closure doc: DONE** (= this file), landed with its registry row in the
   same commit, because two commits would leave the registry's own count gate
   reading a stale row in between.
4. **The durable lessons, into the shared skill tree.** The landing's two
   lessons are in `wenshu-pocock-workflow/references/a-gate-line-that-selects-nothing.md`:
   a test filter that matches nothing exits 0, so a published gate line has to
   carry the summary its own command prints; and a rebase keeps
   `review_gate.change_id` while it drops `patch_id`, so a verdict survives a
   rebase only through the identity the gate reads. This round adds a third, in
   `references/a-records-remote-tip-is-an-instant.md`, written after this commit
   lands so its mtime postdates the landing: a record that publishes a remote
   tip, a lane ref, or a row count publishes an instant, so it publishes the
   ancestry and the re-measure command instead. Check with `grep -l
   chat-context-gauge-compact
   /Users/anbaiqiang/.hermes/shared/wenshu-skills/wenshu-pocock-workflow/references/*.md`.
5. **The residue: what this scope owned, and what it keeps.** Removed once this
   record landed: the lane's worktree
   `.worktrees/chat-context-gauge-compact-2026-11-26`, the local branch
   `wt/chat-context-gauge-compact-2026-11-26`, and the same branch on both
   remotes. Kept, on purpose: the probe's driver
   `/Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/chat-context-gauge-compact/main.swift`,
   which this record's compile command names (= a reader runs that command
   against the shipped file, so the driver is the record's evidence and not
   residue), the two card bodies and their runners beside it, and the parked
   shas `refs/keep/chat-context-gauge-compact-a1` (the change as it landed),
   `-a2` (this record's first landing), `-r3` (the sha the third code review
   bound its verdict to), and `-a3`, which this record's landing parks as the
   scope's last commit and which the plan of record's row resolves. The parks
   are local: `git ls-remote origin 'refs/keep/*'` prints nothing. The proof of
   a landing is `main`'s ancestry plus `.gate-logs/`, never a remote lane ref.
   Check with `git for-each-ref refs/keep | grep gauge-compact` (= one row per
   landing and per reviewed sha this record binds) and
   `git worktree list | grep gauge-compact` (= empty, once this round's own lane
   is gone).
6. **The final state and the report: one row per requirement, each with its
   carrier, its independent verdict, and its server-side proof.** Every number
   above is printed by the command named beside it.

| The requirement | The commit that carries it | The verdict that cleared it | The server-side proof |
| --- | --- | --- | --- |
| a displayed token count carries a unit, in both locales, and the exact reading stays reachable (`OOB.md #2026-11-26 (unit form)`) | `b943733a9b` | `t_35c29c67` `approved` at `9108f18f79`, bound to the landed tree by the change identity `b2595b1be9…`, which the rebase kept | `git merge-base --is-ancestor b943733a9b origin/main` and the same against `old-origin/main`, both exit 0 |
| the meter's reading survives a relaunch (`OOB.md #2026-11-25 (meter durability)`, carried by the previous scope) | `c94c384db7` | `t_2a00ffbe` `approved` at that sha | `git merge-base --is-ancestor c94c384db7 main` exits 0 |
| the closeout record is the scope's last commit and its eight steps are decided by a tool, not by prose | this record's own landing, which is the scope's last commit | `t_c4a6829e` `approved` at `360bc2495f` for the repair, and this round's card for these lines | (= this proof runs after this commit lands, because it reads the landed tree) `python3 Tools/wenshu-devtool/closeout_gate.py --scope chat-context-gauge-compact` exits 0 with `8/8`, and the index row's ref resolves to `main`'s tip |

7. **The board's open columns: swept after this commit lands,** by the query
   above rather than by memory, and the rule holds: a card the boss created
   stays where the boss left it.
8. **The card this session dispatched is its own to land: DONE** for
   `b943733a9b` (= both remotes pushed, both read back below), and the record's
   landing follows the same path.

## The stopping rule

This record's own review lives on the board and is not logged here. A record
that keeps writing entries about its own reviews becomes the defect it was
written to report, so the section above is the last one: the closure commit gets
its card, its gates and its server proof, and the doc stops at its substance.
