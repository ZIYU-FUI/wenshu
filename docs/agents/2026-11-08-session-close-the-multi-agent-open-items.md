# Session closeout: the multi-agent work's open items close, = and the corpus search gets its own verdict

## The scope, and what it produced

The multi-agent work (`docs/agents/2026-11-04-what-the-multi-agent-work-still-owes.md`)
listed five open items. = **⇒ This session closed the four that were
still open, and the fifth (= the corpus search) was already closed but
had never been independently reviewed.** = The corpus review then found
three real defects in code the user was already running, = and those
were fixed here too.

**⇒ Twelve commits of this scope, = = = on `main` and on both remotes** (= = =
`b0e7e9ec01d40d3a202890c76a4ecc8cbb188d58`), = = = **and then a second
wave's 34 commits landed on top of them** (= = = `8a9163b1a14416f52dec42087a83eb9dbf640a6a`).

| the requirement | the commit | the verdict |
| --- | --- | --- |
| the corpus narrows by kind and by owner | `1adacbbba` | `t_89793467` approved |
| a body the index does not list is still a member | `f674d3633` | `t_89793467` approved |
| the system index is waited for, = not blocked on | `ceb3ec50e` | `t_89793467` approved |
| the six sub-agent roles, = and what each may do | `74280cace` | `t_89793467` approved |
| the model's default layer is the layer the user can browse | `153c05935` | `t_89793467` approved |
| the open-item ledger | `818e5a140` | = = = |
| the panes the roles added, = and the tripwire they forgot | `dc05b94a3` | = = = |
| the search shows text, = and a stale result cannot land | `508347944` | `t_89793467` approved (= and `t_9a836302` changes_requested against the sha it names) |
| the baseline's five runs, = and this change's failing SET | `5d04e8bf3` | = = = |
| the blank lines the removal left | `8399219ca` | = = = |
| the registry row the landing commit left behind | `b0e7e9ec0` | = = = |
| the closure doc itself | `726cb58719` | = = = |
| **⇒ AND A SECOND WAVE LANDED ON TOP OF THIS ONE** | | |
| the book's style sheet wave (= 34 commits: = = = the footnote marker that swallowed a paragraph's prose, = = = the export that writes the file it was given, = = = the engine's two new content roles) | `8a9163b1a` | `t_782a9e47` **approved** |
| the registry row the footnote fix left behind | (in `8a9163b1a`) | = = = |

## The four defects, and what each one was

**⇒ All three of the corpus's defects were the SAME SHAPE: = a test
that asserted SOURCE TEXT stood in for a behaviour that did not
exist.** = The reviewer measured it by execution, = and the shape is
worth remembering, because it is the shape a review misses when it
reads the code instead of running it.

1. **THE SNIPPET PAINTED THE INDEX'S RAW MARKUP.**
   `TokenOverlapRanking.highlight` returns `<mark>token</mark>`, = and
   the view painted it with `Text(hit.snippet)` (= a `String`
   variable, = = = so SwiftUI takes it verbatim, = = = and the tag
   glyphs reached the screen). = **⇒ Measured: 684 painted ink columns
   against 430, = = = a difference of 254, = = = which is the width of
   the tags.** = The tree had no precedent here: = `CSSearchResult.snippet`
   had no app consumer, = = = so this view was the first to render that
   markup. = **⇒ The fix strips it where the snippet is MADE**, = = =
   so no consumer has to know the index's markup.
2. **THE STALE-RESULT GUARD WAS A TAUTOLOGY.** = It compared the
   query it had just trimmed with the same query trimmed again, = = =
   `x == x`, = = = true by construction, = = = so it could never drop
   anything. = **⇒ AND CANCELLATION DID NOT RESCUE IT**: = a cancelled
   task still resumes from `await Task.detached { … }.value`, = = = so
   the older search still lands, = = = and lands last whenever it
   finishes last. = **⇒ The fix tells a stale result from a fresh one
   by its NUMBER**, = = = and the rule lives in `LibrarySearchState`
   (= a type the view AND the test both use, = = = so the test measures
   the product's rule and not a copy of it).
3. **THE UI SUITE HELD NO BEHAVIOUR.** = All six tests asserted source
   text, = = = so mutation A (= the search returns no hits at all) and
   mutation B (= the app searches titles only and never a body) both
   left the suite 6/6 green, = = = and the whole `--filter Library` run
   was 187/37 green. = **⇒ The suite now measures behaviour**, = = =
   and the markup test goes through the PRODUCTION search (= a test
   that called the strip helper directly stayed green when the search
   stopped calling it).
4. **THE REGISTRY'S LOC COLUMN WENT STALE, = = = TWICE.** = The
   corpus review's fourth finding (= its run metadata said "3 blocking
   + 1 registry LOC", = = = and its summary said only "three") named
   four rows whose LOC did not match their files. = **⇒ The fix
   rewrote those files, = = = so the rows had to be rewritten with
   them** (= and the landing commit changed a file's length again,
   = = = and the row went stale a second time, = = = and no gate caught
   it: = `test_nfi_registry.sh` was rc 0 both times). = **⇒ The
   durable rule: a fix that changes a file's LENGTH must rewrite that
   file's registry row IN THE SAME COMMIT.**

## The gates on the merged tree

**⇒ Re-run on the MERGED tree (= `main` at `b0e7e9ec0`), = = = not on
the branch that was measured before the merge:**

| the gate | the result |
| --- | --- |
| `ci_change_gate.py --check pollution` | 0 |
| `ci_change_gate.py --check formatting` | 0 (= 21 changed Swift files) |
| `verify-dead.py` | DEAD 0 |
| `nfi-split.py --check` | PASS |
| `test_nfi_registry.sh` | all tests passed |
| `effort_budget_gate.py` | ok |
| `swift build --build-tests` | 0 errors |
| the whole suite | 3534 tests / 547 suites = **4 issues, = = = every one of them in the untouched base's union** (= five base runs, = 8 sites) = **⇒ zero new failures** |

**⇒ The two review cards, = = = and their verdicts are in the run
METADATA (= the only place a verdict lives):** = `t_89793467`
= `approved` at `5d04e8bf3dc22756150dffaf1e77a3bec0a7eeca`, = and
`t_9a836302` = `changes_requested` at
`c2859419d79aa314c04c21940b75000d722b8eaa` (= the corpus's own commit,
= = = which is already in `main`).

**⇒ AND THE REVIEW LANE WAS STARVED, = = = NOT THE CARDS' FAULT.** = A
direct probe of the provider showed HTTP 429 on one of its two credentials (= the body said the token plan's quota was exhausted)
on one of its two credentials, = = = and `fill_first` always picked the
exhausted one. = **⇒ The card was routed to the local `magpie` provider
the reviewer profile already declared** (= `hermes kanban set-model
<card> group/free-pool --provider magpie`), = = = and the review
profile is unchanged, = = = so the verdict is still independent.

## The data check, and the boundary

**⇒ The user's real library was only ever READ.** =
`~/Documents/anbaiqiang.ws` has **0 files modified** since
2026-11-06, = and **no `.write-records/`** (= the second-writer rule's
witness was never written into the user's own library). = Every probe
in this session ran against a temporary directory.

**⇒ The other session's four branches were not touched**: =
`feature/librarian-corpus-p0` = `6ff219900`, =
`feature/librarian-write-authority` = `8fa6a8b24`, =
`feature/library-and-archive-surfaces` = `0e88ae42e`, =
`feature/subagent-return-path` = `ad43f225b`. = **⇒ And their
worktrees still hold their own work** (= `library-search` 3 entries, =
`return-path` 1).

## The open items, and who owns them

- **⇒ THE OWNER AXIS CANNOT NAME AN AGENT.** = No producer records
  WHICH agent wrote a document, = = = so the axis offers the two
  owners the second-writer rule's witness can prove (= "you" and "an
  agent"). = **⇒ A menu naming the six roles would be a menu of lies.**
- **⇒ THE ROLES PANE IS READ-ONLY.** = The role table is the app's
  contract with the model; = = = editing it is a different piece of
  work.
- **⇒ THE BODY AND THE INDEX ARE STILL TWO WRITES.** = This change
  makes the READ answer the question (= the membership is what is on
  disk); = = = it does not make the WRITE one unit.
- **⇒ THE RECOVERED MEMBER CARRIES NO KIND, = NO TAGS, = AND NO
  CATEGORY.** = They lived in the lost index row, = = = and inventing
  them is a worse lie than "other".
- **⇒ THE CORPUS'S SEARCH STILL DOES NOT SEARCH THE CHAPTERS** (= the
  book's own documents). = **⇒ The chapters ARE reachable by a word in
  them, = = = through the system-wide search** (= `⌘Space`: = the
  chapter's body is indexed into `CSSearchableIndex`'s
  `contentDescription` on every save, = = = and the query reads that
  attribute). = **⇒ What is missing is the corpus's OWN retrieval
  surface covering them**, = = = which is a separate piece of work.
- **⇒ SIX REAL DOCUMENTS CARRY ONE KIND.** = All six of the user's
  documents are `entityType: "other"`, = = = so the kind axis has one
  bucket today. = **⇒ The classifier IS wired into the import path**,
  = = = so every new import gets a real kind; = = = the six predate it.
- **⇒ THE SIX REAL DOCUMENTS ARE 5 AGENT AND 1 USER**, = = = measured
  by running the landed production code over them (= the fallback
  branch of `resolveOwnership`, = = = because the library has no write
  records).

## What the next session should read first

**⇒ `docs/agents/2026-11-07-the-multi-agent-works-open-items.md`** = = =
the open-item ledger this change closed, = = = and
**⇒ `docs/agents/nfi.md`** = = = the registry, = = = where a row's LOC
column is "the count at the moment the row was written" = = = and so a
commit that changes a file's length rewrites its row in the same
commit.

## What is not this session's work

- **⇒ The four librarian branches and their worktrees belong to
  another session.** = They were not deleted, not pushed, = = = and not
  rebased.
- **⇒ The six truth/mirror divergences in the user's real library** =
  = = they involve the user's own text, = = = and the library was only
  ever read, = = = so they stay as they are.
- **⇒ `ProcessTools.swift` carries its own `group.wait()`**, = = = on
  the process-execution path, = = = which this change did not touch.
