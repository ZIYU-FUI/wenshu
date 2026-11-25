# The book's own claims reach the writer's turn (2026-11-26)

## The scope

Five requirements, one lane each, = = and every one of them is a change to the
tree and not a change to the plan.

| # | requirement | the commit that carries it | the adjudication that cleared it | the server's proof |
|---|---|---|---|---|
| 1 | the consistency kernel weighs a book's claims (= their moment, their grade) against rules and reports the conflicts | `82053cb5c3` | card `t_a0a508ab` (= run 5104, = = `review_outcome: approved` at `dacc9a1822`) | on `main`; = = `git ls-remote origin main` carries it |
| 2 | the thread-chain kernel reads a book's own marker lines and names the three ways they break | `99bb9c2070` | card `t_f740d791` (= run 5100, = = `review_outcome: approved` at `4eff976b10`) | on `main`; = = the same remote ref carries it |
| 3 | the claim reader turns a book's **own field lines** into claims (= no LLM, = = no prose NER) | `9cd252eb63` + `2ce7c3ed69` | card `t_b5010f45` (= run 5137, = = `review_outcome: approved` at `2ce7c3ed69`) | on `main`; = = the same remote ref carries it |
| 4 | the app reads a book through the stores that already own it, runs the two kernels over it, and hands the report to the writing turn | `fc5d087c69` + `aca111a245` + `447c94c29e` + `6b5b0c2a56` + `4268be4136` | card `t_12246b70` (= run 5140, = = `review_outcome: approved` at `4268be4136`) | on `main`; = = the same remote ref carries it |
| 5 | the tree carries no dead code from that lane | `38e45fe6fd` | card `t_55b333f1` (= run 5143, = = `review_outcome: approved` at `38e45fe6fd`) | on `main`; = = the same remote ref carries it |

**⇒ AND THE SERVER'S MAIN AT THE CLOSE**: `38e45fe6fda7c5a6f72c889b35f0aa6817b3ef42`
(= = `git ls-remote origin main`), = = and every commit above is its ancestor.

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

## The three rounds the delivery took, and why they were not a wording loop

Round 1 reproduced **19 of 19** functional claims and charged four record defects
(= = a comment that named a mechanism the code does not have, = = three wrong figures in
the card's own body, = = a document count the shipped reader does not produce, = = and the
real book's outcome missing from the record). = = Round 2 reproduced every claim it could,
ran its own arms, = = and charged **two lines of text**: = = the loop's slot comment still
equated "no provider" with "no book", = = and the record named a type the tree does not
have (`StoryForeshadow` = = the entry the reader calls is `ForeshadowChain.scan(chapters:)`).
= = Round 3 = = = = two lines = = = = approved.

**⇒ AND A FINDING MEASURED ON A HALF-FINISHED CONTROL IS NOT A FINDING.** = = The
whole-tree comparison first charged the branch with a failure that **main already had**
(= = `EditorTabStripOverflowTests.swift:582:13`), = = because the control run had not
reached it yet. = = With both runs finished (= = 13 failing sites each), = = the tip's
failing set is a **subset** of main's, = = and the one name on each side that the other
side does not carry passes on both trees when it is run alone (= = load-sensitive, = = not
this change's).

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
