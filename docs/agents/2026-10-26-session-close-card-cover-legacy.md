# Session close — 2026-10-26 — the card-cover session's legacy is closed, and 25 failures became 8 cards

> Boss directives (rendered in English per rule 1.1): take over the "card
> cover" session (= a session that was cut off by context pollution) and
> find out whether it left work behind; the session was archived by the
> boss; report in Chinese; "is there work left over to take over?"; "close
> it out".
>
> Closure type: no production source changed by this session (= three
> documentation commits, one skill section, eight cards created).

## 1. What the archived session left, and what it did not

The session titled "card cover" (`20261022_213545_3a3e7c`, 2026-10-22 21:35
-> 2026-10-24 16:27) ended without a wrap-up: its last message reported that
a final verification command had been stopped by the safety gateway, and it
said so (= the work it left for whoever came next).

**Its own eight board cards are all `done`, and every commit is on `main`**
(= the tool registration `ff51cc2617`, the reference-store index
`e31c04a192`, the stale source-text assertions `4d1ca31a51` (+ `adc38eb029`),
the toolbar probe `fc068319bd`, and four more). The cover feature itself is
on `main`: the protocol layer, the settings pane, the plant-growth rule, the
strict constraints, the failure message, the split still/clip states. Every
`project/*cover*` branch is `ahead=0` against `main`.

**The one thing it did not do was measure the final number.** Its last
trusted figure was 38 issues, and it could not confirm the count after the
last three fixes landed. It also left the remaining failures listed per
file, in a comment on `t_80d05a7e`.

**Two cards that look like its legacy are not.** `t_c3850b57` (a cover
cascade on delete) and `t_e4f1c60d` (the novel-side context) belong to the
2026-10-24 "unfinished work audit" session (`20261024_131806_f8e785`).
`t_c3850b57`'s premise (= "three orphan `bookDoc` cover directories on
disk") is false: all three keys map onto documents that still exist, so
deleting them would destroy the covers of live documents. That card is
still running, and its worker had independently derived the same key
formula the reconciler uses (`BookDocIDFactory.make`), with the rule that a
cover whose card cannot be named is never removed by guesswork. It was left
alone.

## 2. The number, measured (2026-10-26, `main` = `d4cd276834`)

A single-arm `swift test` on a clean worktree of `main`, with no other test
run concurrent: **29 recorded issues**, of which 4 are an artefact of where
the run happened (= see section 3) -> **25 real failures**, spread over 16
test files. (The counts differ because a few tests assert more than once.)

For comparison: the 2026-10-26 import-chain session measured the untouched
baseline `15901058d` at 30 failures and its own tree at 12, with 0 new. The
counts are not directly comparable (= different trees, different days), but
both show the tree is not red.

## 3. The four failures that are not the tree's fault

`FileToolsTests` builds its temp paths from `FileManager.currentDirectoryPath`.
A worktree under `~/.hermes/profiles/.../scratch/...` matches the
deny-list prefix, so the path guard refuses the write: `Caught error:
.pathDenied(path: ".../.test-...")`. The four affected tests are the
write/read round-trip, the single-replacement patch, the
patch-with-missing-old-text, and the pattern search (= all four live in
`FileToolsTests.swift`). **Run the suite from a path the deny-list does not
cover** before reading them as failures.

## 4. The 25 are now on the board (= 8 cards)

Each of the 25 was judged first (= "is the behaviour it protects still
there?"), because turning a real defect into a green test is the failure
mode this work exists to avoid. The judgement changed two of the three
kinds, so the cards do not say what the first draft of this document said.

| Card | Kind | What it does |
|---|---|---|
| `t_8288f038` | (a) | five tests that read a file that no longer holds the code (= the sidebar's and the library view's code moved) |
| `t_93e682c3` | (a) + (c) | eight editor-side tests that describe moved or redesigned code, and the one real breach (= four raw `Color(red:green:blue:)` literals in `PreviewPaneCard.swift`) |
| `t_45937eb2` | (b) | the two load symptoms |
| `t_04bcd39e` | (d) | the two `Issue.record` bodies |

**Two of the first draft's judgements were wrong, and running the tests one
at a time is what showed it:**

- `ConversationLoopMultiTurnTests` was called a real defect (= "the loop
  made zero LLM calls"). It is not. The production path stopped calling
  `connector.send` in 2026-09-18 (= the streaming change) and calls
  `connector.stream` now; the test's stub counts only `send`, so the count
  is always zero. The test measures a call the app stopped making. It
  fails on its own in 1.9 s, so it is not a load symptom either.
- `HermesTodoStoreConcurrencyTests` was called a real defect (= "the todo
  write took more than five seconds"). It is not. Run alone it is 5/5 green
  in 0.05 s. The five seconds in the full run are the suite's own main
  actor being busy, not a deadlock. The budget stays; the test must learn
  to tell the two apart.

The other (a) cases split further once the production code was read: five
are "the file moved" (= point the assertion at the file that holds the
code now) and eight are "the behaviour was changed on purpose" (= reverse
the assertion so it pins that the old design must not come back). Four of
the eight are the app being redesigned: the tab close icon became a double
click, the status bar moved to the shared `ChromeBottomFooter` shell, the
reading width was pinned to fix a text-wrapping bug, the cursor-location
chunk was dropped, the tab title order changed, the sidebar's directory row
got its own pinyin letter-circle icon (= the file says why: the canonical
16 PT slot would clip the letter glyph), and the history log line reports
`contextTokens` instead of a sum.

## 5. The other four cards this session put on the board

The card-cover session's own findings produced four more cards, whose bodies
were written by the previous session but never landed (= the board had none
of them):

| Card | What it does |
|---|---|
| `t_f52d79e2` | the image provider searches `worlds/` while the book's folder is `world` (= pictures in a world folder never resolve, and the cache fingerprint never changes) |
| `t_88aa2faa` | the rule that decides which cards need completion does not exist (= a new completion-checker service) |
| `t_50c95782` | the three live `Card(...)` call sites never pass the flag (= no orange border, no badge, no completion menu) |
| `t_08a56d9b` | the completion request has no channel to the chat, and the agent's chapter write never announces the library change |

` t_50c95782` and `t_08a56d9b` are children of `t_88aa2faa` (= they use
the file it lands), so they sit in `todo` until it is done. All eight cards
pass `ticket_tier.py --check` against the board's own rows (= tier tag, cap,
retries, body budget and section count all agree).

## 6. The board's blocked column (= swept, not closed)

Five cards are `blocked`. None of them is this session's work, and the
closeout contract says a sibling's card is not this session's to close, so
each was measured and left with its reason intact:

| Card | State on 2026-10-26 | Why it stays blocked |
|---|---|---|
| `t_ee712cb3` | the fix is committed (`e4a1e6f066`), the branch is CLEAN against `main`, the review was REQUESTED and that review run timed out | it needs one approving verdict from a profile that is not its implementer before it can land (= `merge-preflight.sh` refuses it) |
| `t_980a1ca8` | 8 files uncommitted in its worktree (= the four stores it fixes are among them), and the card carries the boss's merge order | the work is not on `main` yet; the card's own comment records that `main` alone freezes the same way (= the blocker is the machine, not any card's diff) |
| `t_9631281e` | 2 files uncommitted in its worktree (= `AppStateLocator.swift`, the file it fixes) | the work is not on `main` yet; the card's own comment records a hand-checked collision check |
| `t_f70e2a3b` | direction decided on the card (= the warehouse is the single source of truth, the container resolves per operation) | the work is not on `main` yet |
| `t_798b4132` | prose card, no deliverable in the tree | it waits for a provider key and the network (= the card names the blocker; the credential is not in this document) |

## 7. The skills that carry the lesson forward

`wenshu-parallel-dev/SKILL.md` already said that a failing source-text
assertion is a QUESTION, not a chore. Two things it did not say, and this
session paid for both:

- **A behavioural assertion needs the production PATH read before it is
  called a defect.** A stub that counts `connector.send` measures zero
  forever once the app moved to `connector.stream`. The path is in the
  source, not in the failure message.
- **A test that fails only on a busy machine is a load symptom until proven
  otherwise.** Run the suspect suite alone; the elapsed time is the tell.
  And the two facts of this machine: `swift test --skip-update` is
  required (= the default resolution hangs on the ssh fetch through the
  local proxy), and a worktree under `~/.hermes/profiles/.../scratch/...`
  makes `FileToolsTests` fail with `pathDenied` (= the location, not the
  tree).

## 8. The tree state

`main` is clean at `29f4238183`. This session's three commits are
documentation: `b06f85740a` (= the card-cover session's legacy, closed out),
`326d93c0cb` (= the count was 25, not 22), `29f4238183` (= the 25 are on the
board, and two of the three kinds were mis-judged until the tests ran
alone). The closure document for the card-cover legacy is
`docs/agents/2026-10-26-card-cover-session-legacy.md`.

The temporary worktrees and logs this session created are gone (= one
verification worktree and one single-suite worktree, both removed). The
scratch notes under the profile's cache directory were left in place (= they
are the evidence trail, and they cost nothing). No sibling's worktree,
branch, build cache or running instance was touched.
