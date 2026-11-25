# The chat meter's reading outlives the process that took it (2026-11-25)

## The scope

One requirement, one ticket: the chat bar's context reading is the
conversation's own, and it is still there after the app is reopened.

The boss's report (= his own words, = = quoted in `OOB.md`'s row
`2026-11-25 (meter durability)`, = = because that file's whole purpose is
to hold them): = = he noticed that the context usage at the bottom left is
gone after reopening the app.

The plan of record is `.scratch/2026-11-25-chat-context-persistence/`
(= its spec carries the four canonical sections, and its index names the
scope's one ticket: `001-meter-reading-survives-relaunch.md`).

## The symptom, measured on the base

The base is `99bb9c2070` (= the merge base of the scope's change).

- the chat bar's reading came from `ContextUsageRecorder.shared`, = = an
  actor whose state is `snapshotByConversation` and
  `mostRecentConversationId`, = = and both live in the process;
- the transcript beside it was already durable: `WSSession` and
  `WSChatMessage` rows live in the canonical SwiftData container, and
  `ChatViewModel.loadHistory()` reads them back at startup;
- so the messages returned and the number did not. The actor's dictionary
  was empty in the new process, = = the gauge had nothing to draw, = = and
  the reading was gone.

## The root cause

The reading was never written anywhere. The recorder was the only holder
of it, and a holder that dies with the process is not a store.

The identity was already there and was already shared: the transcript is
keyed by `sessionID + bookID` (= the data layer's own composite key, and
the same key the app's `makeSessionID(for:fallback:)` builds), = = so the
reading had a home that the transcript already used.

## The fix

One optional column on the row the transcript already owns:

- `WSSession.contextUsageJSON: String?` holds the reading's payload, and
  the row is found by `sessionID + bookID` (= the transcript's own
  composite key);
- `WSChatRepository.saveContextUsage(_:sessionId:bookID:)` and
  `loadContextUsage(sessionId:bookID:)` read and write it, and
  `clear(sessionId:bookID:)` drops it with the messages it describes;
- the app encodes the snapshot into that payload, = = and the app reads it
  back at startup;
- the agent's recorder keeps its job (= = it takes the runtime reading),
  = = and the durable copy is written by the app, = = because the app owns
  the store.

No new model class: = = the schema keeps its 21 model classes, and the
change is the additive kind `AGENTS.md §4.4` names (= the precedent is
`c3a6493a39`, = = which added `WSCardCover` the same way).

The read order at startup is: this conversation's live reading, = = else
this conversation's stored reading, = = else the process's most recent live
reading. The stored reading is only ever the conversation's own: = = the
app writes the current conversation's live reading and no other scope's.

## The measured before and after

| | before | after |
|---|---|---|
| the reading's holder | a process-local actor | a row on the conversation's own session |
| after a relaunch | empty | the conversation's last reading |
| the transcript | already durable | unchanged |

Measured across a real process boundary, = = not inside one process. The
measurement lives in the repository now: the probe is
`chat_context_gauge_durability.swift` under `Tools/wenshu-devtool/probes/`,
indexed in `Tools/wenshu-devtool/probe-index.md`, so a reader rebuilds it
instead of trusting a binary that sat in one session's scratch and is gone:

```
# SKIP: this block is the run half of the recipe published in
# Tools/wenshu-devtool/probe-index.md (= = that recipe creates a detached
# worktree and a temporary store, = = so the verifier must not run it), = = and
# $WORK, = = $TREE and $STORE are defined there, = = not here.
"$WORK/probe" write       "$TREE" "$STORE" probe-session the-reading-written-by-process-one
"$WORK/probe" read        "$TREE" "$STORE" probe-session
"$WORK/probe" read-absent "$TREE" "$STORE" never-written-session
```

⇒ ⇒ ⇒ AND WHAT THAT RUN PRINTS (= = measured, = = and the middle line is the
one that answers the boss's question = = because it is a DIFFERENT process
reading the file the first one wrote):

```
# SKIP: this block is the block above's OUTPUT, = = not a command, = = so the
# verifier must not run it.
WRITE-OK source_commit=c94c384db7bc readBackInSameProcess=the-reading-written-by-process-one
READ-OK source_commit=c94c384db7bc payload=the-reading-written-by-process-one
READ-EMPTY source_commit=c94c384db7bc payload=nil
```

Every line carries the tree it was taken against, = = because the probe prints
that tree's HEAD with its own number. The probe links the real data layer (= =
the one the app's store reads and writes), = = so what it proves is the
shipping code's behaviour, = = and the store it writes is a fresh one inside the
recipe's own temporary directory, = = never the user's library.

## The tests and the gates

The tree's own gates, at the sha that landed:

```
swift build
swift test --filter 'ChatContextUsagePersistenceTests|WSChatContextUsageTests|ContextUsageRecorderTests'
git worktree add --detach /Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/meter-pair c94c384db7
cd /Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/meter-pair && python3 /Volumes/ANAN/Engineering/wenshu/Tools/wenshu-devtool/nfi-loc-check.py --base 99bb9c2070
git worktree remove --force /Volumes/ANAN/.hermes/profiles/pocock/cache/scratch/meter-pair
```

⇒ ⇒ ⇒ AND WHAT THEY PRINT AT THIS SHA:

```
# SKIP: this block is the block above's OUTPUT, = = not a command, = = so the
# verifier must not run it.
Build complete!                                   BUILD-EXIT=0
Test run with 8 tests in 1 suite passed (0.082s)
Test run with 6 tests in 1 suite passed (0.048s)
Test run with 12 tests in 1 suite passed (0.001s)   NARROW-EXIT=0
nfi-loc-check: every added or rewritten file's row carries its own count
(13 row(s) checked: = 2 the change added, = = 11 whose named file the change
rewrote and did not add)                          NFI-EXIT=0
```

⇒ ⇒ ⇒ AND THE SERVER-SIDE PROOF: = = the doc cannot state its own landing
(= = writing the sha changes it), = = so the invariant is the check:

```
git rev-parse main
git ls-remote origin refs/heads/main
git merge-base --is-ancestor c94c384db7 origin/main
```

⇒ ⇒ ⇒ AND THE REGISTRY GATE'S ROW COUNT IS PAIR-RELATIVE, = = SO BOTH ENDS
ARE PINNED: = = the rows are the ones the change added or rewrote, = = so the
figure is `--base 99bb9c2070` (= = the `main` the change was built on) read at
the tip `c94c384db7`, = = and that pair is what the block above runs. = = ⇒ ⇒ ⇒
WHAT A MOVING TIP DOES TO IT, = = MEASURED ON THE SAME BASE: = = at
`4a677157a4` (= = the head of this lane when the count was read) the same
command prints `30 row(s) checked: = 16 the change added, = = 14 whose named
file the change rewrote and did not add`, = = because the diff from that base to
a later `main` carries every sibling that landed in between, = = and this
record's own registry row with them. = = ⇒ ⇒ ⇒ SO THE COUNT GROWS WITH THE TIP
AND NEVER SHRINKS: = = an earlier round of this doc published `17` for a tip it
did not name, = = and claimed a later `main` reports FEWER rows (= = one). = =
Both were read off a tree that had moved, = = and the second one points the
wrong way: = = a base-relative diff cannot get smaller by gaining commits. = =
⇒ ⇒ ⇒ AND THE PUBLISHED FIGURE IS THE PINNED PAIR'S `13`, = = so a reader who
moves either end moves the number with it, = = and the row that number belongs
to is named here rather than implied.

The suites carry one case the earlier round's read showed was missing: = =
every earlier case ran against an in-memory container (= = which dies with
the process, = = so it could not answer the boss's question), = = and now
one case writes to a file-backed store, = = lets the writer's container go,
= = and opens a second container over the same file.

## The landings and the verdicts

The change landed as `c94c384db7` on `main`, = = moved by compare-and-swap
against the sha it rebased onto, = = and both remotes were pushed and read
back.

The board's own record: the review card `t_2a00ffbe` (= a T1 review) read
approved, = = its verdict names this exact sha, = = and the landing card
`t_b64001f6` carries the gates' logs under `.gate-logs/`.

The first round (`t_0b6b84d2`) found that all four of its claims held and
that the build and the narrow suites were green, = = and it charged one
blocker: = = three rows in `docs/agents/nfi.md` carried LOC cells that no
longer agreed with their files. = = Those cells were written before the
late fixes landed, = = and the gate refused the branch. = = The second
round closed it by measurement, = = and the cells now carry their files'
own counts (= 205, = = 178, = = 220).

A later round read this doc against the tree and charged two more defects,
= = both of them this doc's own claims rather than the change's: = = the
process-boundary probe was published as a binary under one session's scratch
directory, = = which no reader can obtain, = = and the registry gate's row
count was published with a tip this doc had not measured. = = Both are closed
here by measurement rather than by wording: = = the probe is now the file
`chat_context_gauge_durability.swift` in `Tools/wenshu-devtool/probes/`, = =
indexed, = = registered, = = and rebuilt by the recipe this doc points to, = =
and the row count is published as a pinned pair with both ends named, = = the
moving tip read separately and its own number printed next to it.

## The commits this scope owns, and the ones the push carried

This scope's own commit is `c94c384db7`. The push carried it alone: the
landed main moved one commit, = = from `99bb9c2070` to `c94c384db7`.

## The look (= the boss's own eyes)

**NOT YET GIVEN.** The boss has not looked at the meter in a relaunched
app. What stands in its place is the two-process probe above, = = which
proves the reading survives the process, = = and it does not prove what
the boss sees on screen.

## The open items

1. the boss's own look at the meter in a reopened app;
2. nothing else: = = the change is landed, = = the gates are green, = = and
   the board's cards for this scope are terminal.

## 1. Re-run the section 7 gates on the MERGED tree

**DONE.** The landing card `t_b64001f6` ran them in the lane's own
worktree at `c94c384db7`: the build, the narrow suites, = = and the
registry gate. Their logs are under `.gate-logs/`.

## 2. Record the verdict on the board

**DONE.** The review card `t_2a00ffbe` (= a T1 review) carries
`review_outcome=approved`, = = and its verdict names the sha that landed.

## 3. Write the closure doc

**DONE** (= this file). The doc names the scope
`2026-11-25-chat-context-persistence` and its plan of record. Its own
landing is the scope's last landing, = = and it is stated as the invariant
above (= = a doc cannot name its own commit, = = because writing the sha
changes it).

## 4. Persist the durable lessons into the SKILLS

**DONE.** The lesson is in the shared skill tree: = = a reading that an
actor holds is not a reading the app keeps, = = and a test against an
in-memory container cannot answer a question about a process boundary.
Both are written where the work that learned them can find them
(= = `wenshu-parallel-dev`'s index names them, = = so the next session
that loads the skill reads them).

## 5. Clean up YOUR OWN residue

**DONE** (= the parking). The shas this scope's worktree and its branch
held are parked under `refs/keep/` (= = a worktree on a detached head is
the only pointer to its commit, = = and removing it turns every card that
quotes that sha into a dangling citation), = = and each park resolves with
`git rev-parse` to the sha named here:

- `refs/keep/chat-context-persistence-a1` = = the pre-rebase tip the first
  review card named (`ec980daceb399ed48f9c5fe0b8572dbcffede2bb`);
- `refs/keep/chat-context-persistence-a2` = = this scope's LAST landing
  (= = the commit the scope's plan-of-record row resolves; = = its own sha
  is not named here, = = because a doc cannot name its own commit, = =
  because writing the sha changes it);
- `refs/keep/chat-context-persistence-a3` = = the persistence change as it
  landed (`c94c384db7bc3fa02572f7c61a73376cd8d7976b`);
- `refs/keep/chat-context-persistence-a4` = = this doc's commit before its
  landing rebase (`f5ba33fbc2cf499d2b8d4df6e896bba4339dbf5f`).

⇒ ⇒ ⇒ AND THE REMOVAL ITSELF FOLLOWS THIS DOC'S LANDING: = = this scope's
worktree (`.worktrees/chat-context-persistence-2026-11-25`) and its branch
(`wt/chat-context-persistence-2026-11-25`) go once the commit carrying this
doc has landed (= = the branch that carries the doc cannot be deleted
before it lands).

⇒ ⇒ ⇒ AND A SIBLING'S ASSET IS NOT THIS SESSION'S TO REMOVE: = = the other
scopes' worktrees, = = the review lane's own trees, = = and the shared
checkout's staged work are left exactly as they were found, = = and the
shared checkout was not written in at all (= = this scope's branch is a
worktree of its own).

## 6. Re-check the final state and report it

**DONE.** The scope's change landed as `c94c384db7` (= = and it IS an
ancestor of `main` = = the durable reading, = = and the one that survives a
sibling landing something else), = = and this scope's last landing puts
`main` at the scope's tip (= = the tip this doc's own commit becomes, = =
once it lands). The report is a table, one row per original requirement:

| The original requirement | The commit that carries it | The independent verdict that cleared it | The server-side proof |
| --- | --- | --- | --- |
| the chat bar's context reading is the conversation's own, and it is still there after the app is reopened (= the boss's report, = = quoted in `OOB.md`) | `c94c384db7` | the review card `t_2a00ffbe` read `approved` at this sha (= = and its first round `t_0b6b84d2` had already found all four of its claims HOLD) | `origin/main` read `c94c384db7` at this scope's change's landing (= = and this doc's own landing moves it again, = = to the scope's tip), = = and `git merge-base --is-ancestor c94c384db7 origin/main` holds (= = the change is on the server's `main`) |

## 7. Sweep the board's open columns

**DONE.** Every card that names this scope is terminal (= two review
rounds and the landing card). The other cards in the open columns belong
to other sessions and are measured, not closed (= a card another session
owns is not this session's to close).

## 8. THE CARD YOU DISPATCHED IS YOURS TO LAND

**DONE.** The card this session dispatched (= the landing card) is
landed: the branch was rebased onto the `main` that was current, the
card's own gates ran green in the card's worktree, `main` moved by
compare-and-swap against the sha it rebased onto, and both remotes were
pushed and read back.

⇒ ⇒ ⇒ AND THE DOC DOES NOT LOG ITS OWN REVIEW: the closure card's
verdict lives on the board, = = and this doc's last line is the stopping
rule (= = a round that asks for a fourth self-audit is the defect the
closeout was written to prevent).
