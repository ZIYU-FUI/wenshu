# The book's own claims reach the writer's turn (2026-11-26)

## The scope

Five requirements, one lane each, = = and every one of them is a change to the
tree and not a change to the plan.

| # | requirement | the commit that carries it | the adjudication that cleared it | the server's proof |
|---|---|---|---|---|
| 1 | the consistency kernel weighs a book's claims (= their moment, their grade) against rules and reports the conflicts | `82053cb5c3` | card `t_a0a508ab` (= run 5104, = = `review_outcome: approved` at `dacc9a1822`) | on `main`; = = `git ls-remote origin main` carries it |
| 2 | the thread-chain kernel reads a book's own marker lines and names the three ways they break | `99bb9c2070` | card `t_f740d791` (= run 5100, = = `review_outcome: approved` at `4eff976b10`) | on `main`; = = the same remote ref carries it |
| 3 | the claim reader turns a book's **own field lines** into claims (= no LLM, = = no prose NER) | `9cd252eb63` + `2ce7c3ed69` + `f0d47ff60f` | card `t_b5010f45` (= run 5137, = = `review_outcome: approved` at `2ce7c3ed69`); = = card `t_70beccd3` (= run 5162, = = `review_outcome: approved` at `3d609749d7`, = = and `matched by change` at `f0d47ff60f`) | on `main`; = = the same remote ref carries it |
| 4 | the app reads a book through the stores that already own it, runs the two kernels over it, and hands the report to the writing turn | `fc5d087c69` + `aca111a245` + `447c94c29e` + `6b5b0c2a56` + `4268be4136` | card `t_12246b70` (= run 5140, = = `review_outcome: approved` at `4268be4136`) | on `main`; = = the same remote ref carries it |
| 5 | the tree carries no dead code from that lane | `38e45fe6fd` | card `t_55b333f1` (= run 5143, = = `review_outcome: approved` at `38e45fe6fd`) | on `main`; = = the same remote ref carries it |

**⇒ AND THE LANDING THIS RECORD MEASURES AGAINST**: the content tip is
`f0d47ff60f` (= = the ADR-scope lane's landing), = = and every commit in the table
above is an ancestor of it (= = `git merge-base --is-ancestor <sha> f0d47ff60f` = =
exits 0 for all eleven). `main` had moved twice under the lane (= = `97ac0dfde5`
and `a85273a0b7`), = = and both are ancestors of that same content tip.

**⇒ AND NO VIEW, NO GAME, NO SECOND PERSISTENCE SYSTEM.** = = The report travels as
text rows in the writing turn's prompt; = = the `.ws` format does not move; = = the agent
package reads no file (= = `FileManager|String(contentsOf|Data(contentsOf` = = 0 hits over
`Context/` and the prompt path); = = and no file under a UI folder is in any of the
diffs.

## What the two kernels actually find on a real book

The one real book in the library reads as **17 documents, 121 claims, 117 distinct
property names, 0 rules, 0 conflicts, 0 breaks, = = an empty report**. = = So the
writer's prompt on that book is byte-identical to what it was before this change, = =
and that is the book's state, = = not a defect in the reading: = = the book has no
chapters yet, = = and it repeats no property about one subject. = = A book whose
chapters plant a thread and never pay it off produces a break; = = a book that states
one subject's property twice produces a conflict. = = The measurement is in
`docs/adr/0040-the-books-own-report-reaches-the-writers-turn.md`.

**⇒ AND THE SEVENTEEN IS THE BOOK'S, NOT THE STORE'S.** = = The library holds two books
(= = the store's eighteenth document is the help book's own topic document), = = and
the book's own seventeen documents are the scope every measurement here uses. = = The
reviewer re-measured that census for itself: = = the book holds **17** world documents
(= = 121 claims, = = 15 carrying them, = = 2 at zero), = = the store holds **18** (= =
the same 121 claims, = = 15 carrying, = = 3 at zero).

## The two things this lane got wrong, and what fixed them

- **A claim's name was the subject plus the line**, = = so two documents about one
  subject stated claims that shared a name, = = and a report could not point at one of
  them. = = The caller now says which document is which (`StoryDocument.identity`),
  = = and the name carries it, = = while the subject stays what the document is about, = =
  so the kernel still weighs two documents about one subject together.
- **Two shipped tests could not fail** (= = a prose test that checked the value for a
  word that sits BEFORE the colon, = = and a nested-bullet test that checked the
  attribute for a word that sits AFTER the name). = = Both now check both halves, = =
  and both bite under their own arms.

## The four rounds the delivery took, and why they were not a wording loop

Round 1 reproduced **19 of 19** functional claims and charged four record defects
(= = a comment that named a mechanism the code does not have, = = three wrong figures in
the card's own body, = = a document count the shipped reader does not produce, = = and the
real book's outcome missing from the record). = = Round 2 reproduced every claim it could,
ran its own arms, = = and charged **two lines of text**: = = the loop's slot comment still
equated "no provider" with "no book", = = and the record named a type the tree does not
have (`StoryForeshadow` = = the entry the reader calls is `ForeshadowChain.scan(chapters:)`).
= = Round 3 = = = = two lines = = = = approved.

**⇒ AND THE FOURTH ROUND WAS THE REVIEWER'S OWN CARD AGAINST THE RECORD.** = = Card
`t_b50f8f05` (= = "[T1] ADR-0039 gives one book the store's document count, = = and 16
pointers in the round-4 card text land on the wrong line") charged two things the
approval could not see: = = the ADR contradicted **itself** about its own scope (= =
`:37` and `:55` said "the eighteen world documents **of the book**", = = while `:110`
and `:113` said **seventeen** and named the store's eighteenth as the help book's), = =
and the round-4 card's own pointers had drifted. = = The fix is two lines of prose plus
the registry's row for the file it made one line longer (`116` → `117`), = = and it
carries no code change at all. = = The reviewer then re-measured everything itself: = =
the store census (17 against 18), = = the six claims, = = and the four arms (= = ARM A
red at `Tests:139`, `:339`, `:341`, `:365`; = = ARM B at `:46`, `:339`, `:341`, `:383`,
`:395`; = = ARM C at `:282`, `:283`; = = ARM D at `:192`, `:193`), = = and it found that
no other file cites ADR-0039 by line number, = = so the one-line shift breaks no
citation.

**⇒ AND A FINDING MEASURED ON A HALF-FINISHED CONTROL IS NOT A FINDING.** = = The
whole-tree comparison first charged the branch with a failure that **main already had**
(= = `EditorTabStripOverflowTests.swift:582:13`), = = because the control run had not
reached it yet. = = The two finished whole-tree runs read **3** failing sites in this
record's own tree and **5** at `a85273a0b7`, = = and this record's commit changes two
`.md` files and **no** Swift file (`git show --numstat` on it): = = where two trees differ
by documentation only, = = no difference between their test sets can be a property of the
change, = = so the sites are main's own debt (= = the one tip-only name, = =
`ChatViewHistoryShortcutTests.swift:35`, = = is absent from the base run and red there in
an earlier one).

## The one thing the landing scripts got wrong

`land_card.sh` takes its worktree from the **card**, = = not from the branch. = = A card
whose `workspace_path` is the dispatcher's tree (= = at main's tip) makes the script's
gate step measure an **empty window** (= = "0 changed Swift file(s) checked", = = "nothing
to check", = = and the lineage judge's own "nothing was measured, = = so this is not a
pass on the rule") = = while the landing itself still moves `main` to the reviewed tip
(= = the compare-and-swap reads the branch ref). = = So the gate block was re-taken in the
lane's own worktree (= = HEAD = the branch tip, = = base = the pre-landing main), = = and
every denominator is non-zero: = = 13 changed Swift files, = = 3 changed `.md` files, = =
12 registry rows, = = 0 offending comment lines.

## The open items this lane leaves behind

- **The one real book's report is empty**, = = and it stays empty until the writer's own
  chapters plant a thread, or the book states one subject's property twice. = = That is
  the book's state, = = not a defect in the reading, = = and it is the honest boundary of
  what this lane bought.
- **`SidebarIconUniformityTests.swift:73` and `:74` are red on `main`**, = = and not by
  this lane: = = the two assertions quote `IconStyles.swift` in its single-line form
  (`var sidebarWidth: CGFloat { 16 }`), = = while `97ac0dfde5` reformatted that accessor
  across three lines (`:221`-`:223`), = = where `5787fab850` still carried the one-line
  form. = = A source-text assertion is layout-sensitive, = = so the comment-honesty
  landing owns the reconciliation.
- **`Tools/wenshu-devtool/pre_review_gate.py:173` takes a FILE PATH, not a task id**,
  = = so its `--card` form dies with `FileNotFoundError` after it has already printed
  its first two lines. = = The reviewer found it and marked it non-blocking; = = it
  belongs to the devtool lane, = = and this lane records it instead of fixing it.
- **The open cards on the board are not this lane's, and they are reported here, not
  closed here.** = = This bullet used to carry eleven card names and a count; = = both
  were readings, not properties of this lane, and both moved inside the session that
  wrote them (= = one card closed while another opened, = = so the count held at eleven
  while the set behind it changed). = = A closeout record that publishes a moving board
  state has to be re-measured, not re-read, so the command is what lives here:
  `sqlite3 ~/.hermes/kanban/boards/wenshu-par/kanban.db "SELECT id, status,
  substr(title, 1, 60) FROM tasks WHERE status NOT IN ('done', 'archived') ORDER BY id"`.
- **`wt/nfi-dedup-2026-11-23` is retained** (= = its review returned
  `changes_requested`, = = and the property it carries is already true on `main` by
  another route), = = and the branch's owner decides what happens to it.
