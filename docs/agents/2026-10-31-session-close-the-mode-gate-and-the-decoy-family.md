# Session close: the mode gate reads the branch, and a decoy cannot point it

2026-10-31. A session that took one editor gate from "a phrase appears in
the file" to "this branch, read structurally", measured it against every
way a decoy could point the reader at the wrong branch, and closed the
five shapes the review rounds found. The production behaviour did not
change in this session's second half: the one production commit of this
session's lane is the `fitsContent` scroller, and every commit this
session made after it is a test. (Other sessions' commits landed on
`main` in the same window = see "The open item" for the one residual
this session's own reviews filed, = and for the one limit a static
reader cannot cross.)

## The symptom, in the board's own words

The CUA proof of the `fitsContent` mode was good: the tab strip and the
format toolbar now sit inside the window, the document renders, and the
document scrolls. The review of that card then read the test that was
supposed to hold the behaviour and found it did not hold it.

> The mode gate is not pinned = the assertion is a substring check on
> "surface.configuration.heightBehavior == .fitsContent", so moving the
> ScrollView to the `.scrolls` branch (M1) or putting it on BOTH branches
> (M3, = the nested-scroller/wheel-swallowing harm the card names) leaves
> the suite GREEN.

> The "NOT on EditorPaperCanvas" assertion is vacuous = it checks the HOST
> file for the string "EditorPaperCanvas", = which that file never
> contains in code or raw source, = so it is true for every possible
> content of the file and cannot fail for the reason its message states.

So the card shipped a real fix behind a test that could not tell the fix
from its absence. The test was replaced by one that reads the branch, and
the question that then consumed the session was the harder one: **what
makes a reader point at the wrong branch?**

## The shape of the gate

The editor's height-mode check can be written six ways
(`surface.configuration.heightBehavior == .fitsContent`, a computed
property, a negation, a negation in place, `!=`, the enum spelled in
full), so a phrase search cannot find it. The gate now finds the branch
structurally: the editor's own `var body`, the `if`/`else` pair whose
condition resolves to the height-mode check, and the two branch bodies
matched by braces. What the gate asserts is a property of the two
bodies: the branch the height-mode check selects carries the vertical
scroller, and the branch it does not select does not.

The gate is measured, not asserted. A mutation matrix mutates the REAL
production source, runs the REAL suite in a fresh process per case,
restores the source after every case, and verifies the restore by
sha256. Every case names the shape it mutates and the verdict it
requires. The matrix grew as the reviews found more shapes: 29 cases,
then 33, then 36, then 39.

## The decoy family, and what each review added

Each review round found one more way for the reader to be pointed at the
wrong branch. All of them are the same defect wearing different clothes:
**the reader took the FIRST match instead of the RIGHT one.**  Five
shapes are closed below (= and one is not: = see "The open item").  Six
commits carry that: `9ada828657` (the structural read), `551996320e` (the
negation), `899d853486` (what it NAMES), `ddad267e75` (the WHOLE type),
`8020db7965` (the editor's OWN declaration) and `7ac8eb5cb1` (the
conditional-compilation scope).

| the reader anchored on | a decoy that captured it | fixed by |
| --- | --- | --- |
| the phrase `ScrollView(.vertical)` | a trailing comment, a string literal, a block comment | reading the code with comments and strings blanked |
| the first `} else {` in the file | an unrelated `} else {` earlier | matching braces from the `if` |
| the first `struct WenshuMarkdownEditor` | `WenshuMarkdownEditorPreview`, `WenshuMarkdownEditor_Previews` | the word boundaries: `\bstruct\s+WenshuMarkdownEditor\b` |
| the first match of that pattern | a type with the editor's EXACT name, NESTED inside another type | the brace depth: the editor's own declaration is at depth zero |
| the first match at depth zero | a type inside an INACTIVE `#if` block (= which adds no braces) | the conditional-compilation scope: the editor's declaration is outside every `#if` |

The general form, and the one worth keeping: **a substring anchor on a
name is a prefix anchor, and a prefix anchor takes the wrong thing.**
And a brace depth is not a scope = a conditional-compilation block adds
no braces, = so a depth alone cannot tell a declaration inside one from
the editor's own.

Each of those five was found by a reviewer, not by the implementer. The
implementer's matrix proved the fix it had just made; it could not prove
the absence of the next shape. That is what the review lane is for, and
the two lanes each shipped what the other could not.

## The measured result

The matrix grew as the reviews found more shapes: 29 cases, then 33, then
36, then 39, then 42, then 53 (= the last two rounds added the decoys a
branch chain can hide: = the `#elseif true` of an `#if true` chain, = an
`#if true` under an unknown outer guard, = and the `#else` of an `#if
true / #elseif false` chain, = each with its capture proof and its
correct-tree control). The last review round measured the card's own 40
named cases and 85 probes, every one of them in a reviewer-owned copy of
the tree, with the source restored and the restore sha256-verified after
every case, and with the implementer's worktree verified pristine before,
during and after.

The decisive flip was measured on BOTH trees: the `#if` decoy plus an
inverted real branch was GREEN on the pre-fix test file and is DETECTED
on the tip. A green gate on a tree whose real branch was inverted is a
defect shipping, and the flip is what says the defect no longer ships.

## The open items

The last residual was the reviewer's own: the conditional-block FALLBACK
kept the FIRST candidate, so a decoy won when the editor's own
declaration was itself inside a conditional block (card `t_1915ca4d`).

It is closed now. The reader no longer asks "is this declaration inside
a conditional block?" = it asks "does this declaration EXIST in the
compiled program?": = a declaration inside a `#if false` block does not,
= one inside a `#if true` block does, = and one inside a block guarded
by a build flag is UNKNOWN (= only the compiler resolves that). = So the
reader takes the declaration that certainly exists, = and the fallback
that kept the first candidate is gone.

What remains is where a static reader stops: a decoy and the editor
BOTH inside blocks whose conditions are build flags are
indistinguishable to a reader that cannot see the build settings. = That
is a limit, not a defect to be fixed, = and it is the honest end-state
of the family: = the reader resolves the editor's declaration whenever it
sits at file scope or inside a block it can evaluate, = and it says so
when it cannot.

The second open item is about the review lane, not about the code: the
docs review of this record timed out three times (= 2400 s, 5400 s and
5400 s) before it was scoped down to eight commands, = and it then
answered in twenty-two minutes. The lane's clock is a budget, = and a
card that sends the reviewer to a 122 KB skill file and a board history
spends it there. The lesson is the same shape as the code's: = a bar
that says exactly which commands to run fits the clock, = and a bar that
says "check everything this record claims" does not.

## What the session did not do

It did not change the production behaviour a second time. The
`WenshuMarkdownEditor.swift` and `EditorPaperCanvas.swift` blobs on
`main` are byte-identical to the blobs the `fitsContent` scroller commit
left them with (= sha256 `46afb1a5` and `1544c8bd`), and the
reviewer checked that on every round. The CUA proof still bears, because
the tree it was taken on still holds.

It did not add a behavioural test. The gate's own case is the one that
changed, and the number of `@Test` cases in the suite is the same at
every commit.

## The board's own rule, learned the hard way

Two things cost a round each, and both are now in the skill:

**A killed matrix leaves the source mutated on disk.** The restore runs
at the end of a case, so a killed run skips it, and the next run starts
from a mutated tree. The restore has to be verified by hash after every
case, including after a kill, and the tree has to be checked before the
next run starts.

**A reviewer's harness that mutates the implementer's worktree collides
with it.** The round-6 harness pointed at the implementer's worktree, so
two harnesses mutated the same file at the same time, and the
implementer's run reported a case as FAILED that reproduced neither
standalone nor in sequence. A reviewer that mutates the source gets its
own copy.

## The merge gate reads the first claim

A review card whose verdict was approved (= `review_outcome: approved`
in the completion metadata, = and the reviewer measured 44/44 cases)
was still refused by `merge-preflight.sh` with `UNREVIEWED`. The gate
reads the sha under review from the FIRST paragraph of the card's
`## WHAT TO BUILD`, and that card named its sha in the goal and again
at the end. The verdict was on the record and the gate could not find
it. One line moved = the sha into the first claim = and the landing was
clean.
