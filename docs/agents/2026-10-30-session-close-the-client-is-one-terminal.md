# Session close: the client is one terminal, and the method is one copy

2026-10-30. A session that moved the native client into this repository,
declared the two product lines once, and closed the separate repository,
the separate board and the separate project.

## What the boss ruled

On 2026-10-30 the boss said the client is ONE TERMINAL of the wenshu
project, not a project of its own, and that the independent-project logic
was already inventoried and clear. On 2026-10-28 the boss had ruled that
the client enters the product line and MAY carry its own `wenshu-XXX`
project, with its related documents in a new project directory.

**What was built on that was a PM's inference.** The separate GIT
repository was added on top of the boss's "new project directory", and
ADR-0028 recorded it as if it had been ruled (the ADR's own
`Decision-maker(s): boss` line said so at the time, and the reasoning
under it was the PM's).

## The cost, counted

Forty-one files existed under both names, twenty-one of them the gate
scripts and the method documents. Every change to a gate had to land in
both, and the port rule was the only thing keeping them honest. It cost a
card every time: the review-gate fix this week was one card on the desktop
and another to port it, and the anchor rule in the effort gate was the
same pair.

Two repos also meant two boards, two Hermes projects, two sets of
worktrees, two AGENTS.md files, two NFI registries, two CI workflows and
two upstreams registries, for one product line.

## The three facts that decided the shape

**1. SwiftPM uses the NEAREST manifest.** Measured 2026-10-30: `swift
package describe` inside `Mobile/` resolves `Mobile/Package.swift`, and at
the repository root it resolves the root one. So a package in a
subdirectory builds with the plain command from inside it, and the root
manifest keeps declaring macOS only while the client declares ios and
macos for itself.

**2. A package's target path may NOT escape its package root.** So the
client could not become two nested packages; it moved as ONE package
(= app + kit + tests), which is what it is now.

**3. The client's manifest needed no change.** A package's target paths
are relative to its own root, so the manifest moved with the tree.

## What landed

| Requirement | Commit | Verdict | Server truth |
|---|---|---|---|
| The client's code and history arrive | `dd3164b77` (9 commits, rewritten so the paths sit under `Mobile/`) | review: 8 checks PASS | `origin/main` = `old-origin/main` = `0162af78a1` |
| The client's own files come back | `0c7fe47e3` | review: approved (19/19 cases) | same |
| The two product lines are declared once | `81f2e08a1f`, `e93296ea4c`, `b3397b19da` | 15 devtool suites PASS + mutation tests | same |
| The CI proves the client | `4005382f89` | the assistant's own verification | same |
| The client's repository is gone | `04e1420911` | ADR-0028 superseded, not deleted | same |
| The ruling is on the record | `0162af78a1` | OOB.md row | same |

### The verification, on the MERGED tree (= not on a branch)

- `swift build` at the root: exit 0.
- `cd Mobile && swift build`: exit 0; `swift test`: 53 tests in 7 suites.
- The iOS simulator build: BUILD SUCCEEDED, and `vtool` on the product
  reads platform IOSSIMULATOR, minos 18.0, **sdk 27.1** (= the `-Xlinker`
  stamp works; the comma form is split by xcodebuild and the link dies).
- The design sweep over the client's 32 files: clean. Over a file with a
  naked `Image(systemName:)`: exit 1 with the violation named (= the gate
  can fail).
- 15 devtool suites: all PASS.
- `verify-dead`: 102 ALIVE / 4 PARTIAL / 0 DEAD, **byte-identical to the
  baseline** at `81c3c3d000` (= the 4 PARTIAL files predate this work).
- Both SSOTs pass `agents_gate.py` (= the root at 19996 of 20000
  characters, the client's at 19719).

## The three defects the review carried, and what happened to them

**1. The client's own files were dropped as duplicates.** The migration
deleted every file whose NAME existed in both repositories, and three of
the client's were not copies: its `design-sweep.sh` (this repository has no
design sweep at all), its `upstreams.json` (the client's says none; the
desktop's lists four), and its 31 NFI rows. All three are back: the sweep
is in the devtool directory, the client's rule 5.4 now says the client has
no dependencies and that the desktop's four are not the client's, and the
rows are in the one registry with their paths under `Mobile/` and their
LOC re-measured (four were stale).

**2. ADR-0027 pointed at decisions nobody wrote.** It reserved ADR-0028 and
ADR-0029, and both numbers now name a different decision (= the mobile
product line, and the native client's authority). The reservations moved
to ADR-0034 and ADR-0035.

**3. The client's CI was replaced by the desktop's.** The client's workflow
proved five things; the desktop's proves none of them. The client has its
own job now, and the design sweep is called over an explicit file list
(= its own default list is `git diff main...HEAD`, which is empty in both
shapes the workflow runs in: a pull-request checkout has no local `main`,
and a push to `main` has `main...HEAD` empty by definition).

## One thing the migration left behind, found while closing out

`Mobile/docs/product-line-plan.md` was written on 2026-10-28, when the client
was going to be its own repository, and it says so in eight places (= "Lives
in: the wenshu-mobile repository", "the macOS repository keeps the desktop
app", "a second repository wenshu-core holds the code both sides share", the
remote-URL consumption rule, and the C2.1/C2.2 cards that build it). The
client moved into this repository on 2026-10-30, so those sentences described
a layout that no longer existed.

The technical claims survive the move and they were kept: the root package
still declares macOS only, a shared package still must not BE the root
package, and section 2.2 still holds for a package consumed over the network.
What the move changes is the sharing reason. A local path package does not
drift when there is one checkout, so the shared package does not need its own
repository, and neither does the client.

**A plan document that names a layout is a gate on that layout.** It was
written for a decision that was later reversed, and nothing read it between
those two dates. The read that would have caught it is the same read that
catches a stale path in any other file: grep for the old name. Eight hits in
one document is a document whose premise moved, not eight typos.

## Two defects found while landing, in their own rows

**The SwiftFormat step had never checked anything.** It read `swiftformat
lint Sources Tests`; in SwiftFormat 0.62.1 `lint` is a FLAG, not a
subcommand, so the command looked for a FILE named `lint`, exited 70, and
the step's hard-fail pattern matched nothing. It now checks the files the
change touched (= the tree carries 1032 files that were never formatted, so
a whole-tree check could never be green), and the base ref resolves in
every trigger.

**The pollution check is red on `main`, and predates this work.** It greps
the whole history, so `git log -p` prints DELETED lines, and the
vocabulary it names was in code that was later removed (= it asks "does it
exist NOW" and counts "did it ever exist"). Measured 3940 on `main`, 4788
over all refs. The step is PATH-AGNOSTIC, so it already reaches the
client's files, and the client's own Swift files carry none of the
vocabulary. **Fixing it is its own card**; it is reported in the workflow
so the state is not mistaken for a green check.

## The open item this session left on the table

**One commit has no independent review.** `4005382f89` (= the client's CI
job and the root SSOT's pointer) was implemented by the assistant after
four runs of the card burned their budget on re-reading, and the review
lane was unavailable (= `t_b6315868`'s own review timed out twice, at
1548s and 1541s against a 1500s cap). The assistant ran every gate the
card named, on the merged tree, and the numbers are in the card's comment,
but the verdict is not an independent one. **That gap is real and it is
the one thing here that would not survive a strict reading of rule 1.14.**

## What is gone, and what the record keeps

Gone: the client's repository at `/Volumes/ANAN/Engineering/wenshu-mobile`
(its 36 files are byte-identical to `Mobile/`'s, verified file by file
before the deletion); the board `wenshu-mob-par` (its history is kept at
`~/.hermes/kanban/boards/wenshu-mob-par-archived-2026-10-30/`, with every
card's verdict in it); the Hermes project `project-2` (it pointed at the
deleted directory).

Kept, deliberately: ADR-0028, marked superseded rather than deleted (= the
reason it was made is the reason the move was hard), and the client's
rules, at `Mobile/AGENTS.md`, because a worker on the client reads those
and not the root's.

What stays separate, because a separate PRODUCT is not a separate
REPOSITORY: the release train, the signing identity, the CI job, and the
client's own rules.
