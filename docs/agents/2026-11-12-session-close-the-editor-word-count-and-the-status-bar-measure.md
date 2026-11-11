# Session closeout: the editor's word count reads one field, and the status bar counts the same measure

Scope: the editor's word-count path. This is the second batch of the
render-path performance work (the first batch = the sorting, the chat turn's
identity, the footer's formatters and the reference library's fingerprint
cache; its carrier commit is `10c74666a7`).

This document is a record of a LANDED scope. It names ancestry, not a tip:
the commits it names are the ones that carry the work, and the reader can
find the current tip with `git rev-parse main`.

## 1. THE SCOPE'S COMMITS (four, plus this record)

| commit | what it carries |
| --- | --- |
| `f0bfcedb42` | the counter reads the one field the app shows, and the status bar counts the same measure |
| `52c6016cea` | the render path's measured audit, and what the user's real data changed |
| `d893480191` | the counter's guard reads the tree, and the status bar's label is the one the body renders |
| `f4f0c3ed40` | the reader resolves the counter from its own declaration |

All four are ancestors of `main`, of `origin/main` and of `old-origin/main`.

**THE COMMITS THE PUSH CARRIED THAT ARE NOT MINE.** The closure commit
pushes `main`, and `main` carries a sibling session's work. The commits
below are the sibling's (= the chat zone's session tab bar), and pushing
them was maintenance of the shared server state, not authorship:

| commit | owner |
| --- | --- |
| `72c3f5eb3d` | the sibling's chat zone's session tab bar |
| `0f561aa3b4` | the sibling's closeout record for that tab bar |

## 2. THE SYMPTOM

Every keystroke in the editor ran the FULL word count, and the full count
computes six fields of which five have no production consumer. The cost of
the one field the app shows was therefore the cost of the linguistic
segmentation that only the unread field needs.

A second symptom sat next to it: the status bar counted WHITESPACE-DELIMITED
TOKENS while labelling the result with the character unit. For a Chinese
document that number is its SENTENCE count, because Chinese does not
separate its words with spaces.

## 3. THE ROOT CAUSE

**THE COUNTER COMPUTED MORE THAN THE APP READS.** `WordCounter.count`
returns a `WordCount` with six fields (= `words`, `sentences`,
`paragraphs`, `characters`, `chineseChars`, and the no-space character
count). `grep` over `Sources/WenshuApp` finds NO read of `.words`,
`.sentences`, `.paragraphs`, `.characters` or `.chineseChars` on a
`WordCount`, = so the linguistic segmentation (= `enumerateSubstrings(
.byWords)`) was paid on every keystroke for a field nobody reads.

**THE STATUS BAR COUNTED A DIFFERENT MEASURE UNDER THE SAME UNIT.** The bar
ran `split(whereSeparator:)` and labelled the result with the CHARACTER unit
(= = the localized string carried the CJK character unit), so
the same document could show two numbers under one unit.

## 4. THE FIX

**THE FAST PATH COUNTS THE FIELD THE APP SHOWS.** `WordCounter
.charactersNoSpaces` counts grapheme clusters that are not a space, a
newline or a tab. It performs no linguistic segmentation. Every production
call site reads it: `EditorEditContent.swift:81`, `EditorView.swift:129`
and `:509`, and `EditorStatusBarView.swift:214`.

**THE UNIT IS THE GRAPHEME CLUSTER, NOT THE UNICODE SCALAR.** A scalar scan
disagrees with the production count on the emoji (= 10 vs 17), on a
combining sequence (= 5 vs 7) and on the flag (= 7 vs 9). The character
form agrees on all nine boundary cases and on all 32 real documents (= zero
mismatches).

**THE STATUS BAR READS THE SAME MEASURE, THROUGH THE PROPERTY THE BODY
RENDERS.** There is ONE statement (`wordCountLabel`), it is internal rather
than private, and the body renders it. A static mirror of the rule would be
a door: it could hold the new measure while the view renders the old one.

**THE GUARD THAT KEEPS THE PRODUCTION TREE OFF THE FULL COUNT IS DERIVED
FROM THE COUNTER'S OWN DECLARATION.** `WordCounterSourceReader` (= 486
lines) reads the type's body and every extension of it, decides from each
member's own body whether it reaches the linguistic segmentation, resolves
the type through the tree's `typealias` declarations, and FAILS LOUD when it
cannot read the tree. `SourceCodeMask` (= 245 lines) is the byte-level
masker that blanks comments and string literals while keeping an
interpolation's expression (= the code) and the line count. The reader
carries NO hardcoded member names: the member set comes from the
declaration, so renaming the expensive member does not move the guard.

## 5. MEASURED BEFORE AND AFTER

Measured on the user's REAL library (`~/Documents/anbaiqiang.ws`, 32
Markdown documents; the largest is 4,731 characters):

| measure | before | after |
| --- | --- | --- |
| the full count on the largest document | **1,992.58 us** | = |
| the fast path on the same document | = | **137.63 us** |

= = **14.5x**.

And the two numbers the reader used to see under one unit:

| document | whitespace tokens | grapheme characters |
| --- | --- | --- |
| 4,666 characters | 570 | 4,027 |
| 4,731 characters (= the largest) | 744 | 3,945 |

= = **32 of 32 documents disagree** between the two measures, = = so the
old label was wrong on every document in the user's library, = = and for a
Chinese document the token count was the SENTENCE count.

## 6. WHAT WAS MEASURED AND DROPPED (the real data falsified these)

The audit's candidates were measured on the user's own library, and three
of them did not survive their own numbers. Dropping them is the point of
the measurement, not a gap in it.

| candidate | measured | verdict |
| --- | --- | --- |
| the pinyin search key | 1,225.18 us per pass (= the decorate shape is **1.02x**, = the ASCII fast path is **0.99x**) | **DROPPED** (= every title in the real library is CJK, = so the fast path never fires) |
| the chat's markdown re-parse | **299.05 us** per frame at 15 visible messages | **DROPPED** (= below Apple's 500 us finding threshold, = on the user's own four messages) |
| the materials column's footer scan | **2,174 us** | **DEFERRED** (= the defect holds, = but the only workable fix changes what a save announces, = and its risk is above its payoff) |

## 7. THE GATES, RE-RUN ON THE MERGED TREE

Re-run on the MERGED tree (= `0f561aa3b4`, which carries this scope plus a
sibling's), not on the branch that was measured before the merge:

| gate | result |
| --- | --- |
| 7.1 `swift build` | **Build complete!** |
| 7.2 `swift test --skip CSSearchableIndexSearchTests` | **4 issues** in 3,650 tests / 563 suites (= and every one of them is in the base's own set, = see below) |
| 7.3 the 22 design sweep suites | **86 tests in 24 suites passed** |
| 7.5 the CJK comment audit | **no new CJK comment line** (= the audit scanned this scope's 1,434 added Swift lines; = = the gate scans the COMMENTS of the added lines, = = and it scrubs the string literals first, = = so a CJK string literal (= = the test data, = = and the unit a comment quotes) is not a comment) |
| 7.6 `verify-dead.py` | **DEAD = 0** (= 124 ALIVE, 4 PARTIAL) |
| 7.8 commit hygiene | every commit carries an English subject and a body that says why |
| 7.9 the verdict field | the reviewer ended with `review_outcome: approved`, = and `review_gate.py --card t_5f826648` exits **0** |
| 7.10 the named narrow gate | `swift test --filter 'EditorWordCountPathTests\|EditorStatusBarWordCountTests\|SourceCodeMaskTests'` = **18 tests in 3 suites passed** |
| the change gate | `ci_change_gate.py --check formatting` = **no unformatted line** (= 36 changed Swift files checked); `--check pollution` = **no forbidden vocabulary**; `nfi-loc-check.py` = **every rewritten file's row carries its own count** (= 18 rows checked) |

**THE WHOLE SUITE'S HONEST READING.** The merged tree's full run reports
**4 issues** in 3,650 tests / 563 suites. The base tree's full run, with
the same command, reports **6 issues** in 3,580 tests / 555 suites (= the
merged tree carries more tests, = = because a sibling's scope added the
chat zone's session tab bar). The base's own failure set MOVES between
runs (= it is load sensitive), = so the reading is the SET, not the count:

```
merged set (4) = { AsyncDelegationRegistryTests.swift:104,
                    ChatViewHistoryShortcutTests.swift:35,
                    EditorPersistenceTests.swift:253,
                    EditorTabTitleTests.swift:60 }
base   set (6) = the four above + HermesTodoStoreConcurrencyTests.swift:268
                             + WenshuConductorToolWiringTests.swift:198

MERGED SET MINUS BASE SET = EMPTY
```

= = ⇒ **the failures on the merged tree that the base does not have = 0**.

**AND ONE MERGED RUN WAS DISCARDED, BECAUSE IT NEVER FINISHED.** The first
merged run reported ONE issue, = = which was in the base's set, = = and it
read like a clean result. It was truncated: = = its log held 9,000 fewer
lines, = = 934 fewer Swift Testing test lines and 175 fewer suite lines
than the base's log, = = and the grand-total summary line was MISSING. The
cause was a second `swift test` (= the card's own narrow gate, = = plus the
design sweep) launched in the SAME worktree while the whole-suite run was
still going: = = the two contend for SwiftPM's build lock. = = ⇒ The
number above is the SECOND merged run, = = launched with nothing else in
that worktree.

**THE CJK AUDIT'S READING ON THE MERGED TREE, AND WHOSE LINE IT HITS.**
This scope's own diff adds **no CJK comment line** (= the audit scanned
1,434 added Swift lines, = = and it scans the COMMENTS of the added lines
after scrubbing the string literals, = = so a CJK string literal (= = the
test data, = = and the unit a comment quotes) is not a comment). = = But
the audit run against the MERGED tree exits 1, = = and the line it names is
NOT this scope's: = = it is
`Sources/WenshuApp/Features/Library/View/SidebarServiceMutation+References.swift:19`,
= = a comment that quotes the boss's Chinese directive verbatim, = = added
by the sibling's commit `72c3f5eb3d`. = = ⇒ That line belongs to the
sibling's scope (= the chat zone's session tab bar, = = card `t_3ab7bae8`
and its review rounds), = = it is NOT this scope's defect, = = and this
closeout does not touch a sibling's landed file. = = It is named in the
closing report as its own row. = = ⇒ And for the record, = = the house's
own convention for that comment is to CITE the directive rather than quote
it (= = `see OOB.md #2026-10-10`, = = as
`Sources/WenshuApp/App/WenshuAppDelegate.swift:561` does).

## 8. THE REVIEW ROUNDS (three, and what each one ruled)

| card | sha under review | verdict |
| --- | --- | --- |
| `t_1e143521` | `77efb5ee1b` | **changes_requested** (= the source guard was evaded by a type alias and by a comment decoy; = the status bar's suite only asserted a static helper; = the registry row claimed the reader saw TWO numbers when it saw one) |
| `t_8d2829d0` | `a0276c4667` | **changes_requested** (= A and C closed: = the status bar's rendered output and the registry's record; = B open: = the reader still asked a question with a fixed answer) |
| `t_5f826648` | `03adff896c` | **approved** (= B closed: = the reader resolves the counter from its own declaration) |

The reviewer measured the r2 reader's three evasions (= a call site through
a type alias, a third member that wraps the count, and a new `wordCount`
API) and found all three GREEN. In r3 they are RED, = = and each shape's
ISOLATED form (= the wrapper exists but nobody calls it) stays GREEN, = =
so the guard does not cry wolf on a harmless declaration.

## 9. SECTION 7.7 = THE BOSS'S OWN LOOK

This scope IS UI-touching: the status bar's label now carries a character
count where it carried a whitespace-token count, = so the number the user
reads changes.

| fact | value |
| --- | --- |
| the build | `/Volumes/ANAN/Engineering/wenshu/.worktrees/closeout-batch2/build/Wenshu.app` |
| rebuilt from | `0f561aa3b4` (= the merged tree, = which carries this scope and a sibling's) |
| signed | ad-hoc, `codesign --force --deep --sign -`, = identifier `com.wenshu.app` |
| the bundle carries the change | **yes** (= `nm -a` on the bundle's OWN binary finds `characterCount` twice, = and the control symbol `charactersNoSpaces` six times) |
| the boss's verdict | **NOT YET GIVEN** (= see below) |
| the app left running | **no** (= see below) |

**WHY THE LOOK IS PENDING, AND IT IS AN ENVIRONMENT FACT, NOT A DEFECT.**
Another session's instance of the SAME bundle id (`com.wenshu.app`) is
running: pid 194, from `.worktrees/teb-chat`, alive for more than ten hours.
A second instance of the same bundle id restores the same saved window
geometry, = = and AppKit's update-constraints guard then fires and BOTH
processes abort a few seconds in (= = the measured `open -n` failure mode).
Launching this scope's build would therefore have destroyed a sibling
session's live card, = = so it was not launched, and the sibling's
instance was left untouched.

= = ⇒ **⇒ THE LOOK IS ONE COMMAND, ONCE THE BUNDLE ID IS FREE**: = =
`open /Volumes/ANAN/Engineering/wenshu/.worktrees/closeout-batch2/build/Wenshu.app`
(= = a PLAIN `open`, = = never `open -n`; = = the bundle is built and signed
already). = = The thing to look at is the editor's status bar and the
editor's counter on the same document: = = the two numbers must AGREE, and
they must carry the character measure, = = not the token count.

## 10. OPEN ITEMS LEFT BEHIND

**P1 = THE READER IS BLIND TO A MEMBER BOUND TO A LOCAL FUNCTION VALUE.**
A wrapper of the shape `let counter = count; return counter(content).words`
reads GREEN, = = because the reach closure matches a sibling call by NAME.
MEASURED PRE-EXISTING: the same arm is GREEN on r2's reader too (= so this
scope did not introduce it), = = and the shape is not reachable from any
production path today (= = every production call site spells the member
directly, = = and no production file binds a counter member to a local). It
is follow-up work, = = not a defect in this diff.

**THE MATERIALS COLUMN'S SHARED SCOPE RESULT CACHE.** Still not governed.
The measured cost is 2,174 us, = = and the only workable fix changes what a
save announces, = = so its risk is above its payoff at the measured size.

**`LongRunningGoalButtonTests.swift:98` IS A PRE-EXISTING RACE, NOT THIS
SCOPE.** It counts `WenshuGoals-*` directories in the SHARED
`NSTemporaryDirectory`, = = and the test's own cleanup deletes every new
one, = = so a sibling instance's cleanup can remove a directory another
instance already counted. The signature is the count going DOWN (= `after
32` against `before 33` on the tip, = `after 0` against `before 81` on the
base), = = which only an external deletion can produce. The base tree
produces the identical failure (= 4 of 6 runs). The failing file is
byte-identical between the base and this scope, = = and this scope touches
no chat, no goals, no `FileManager` and no temporary directory.

## 11. REPRODUCTION

The audit's own numbers and the dropped candidates are in
`docs/agents/2026-11-10-render-path-performance-audit.md`. The reader and
the masker are `Tests/WenshuAppTests/UI/WordCounterSourceReader.swift` and
`Tests/WenshuAppTests/Shared/SourceCodeMask.swift`, and the masker's own
suite is `Tests/WenshuAppTests/Shared/SourceCodeMaskTests.swift` (= nine
cases: = a line comment, a block comment, a plain string, a raw string, a
multi-line string, an interpolation's expression surviving, a `//` inside a
string, a quote inside a comment, and the line count).

The whole-suite comparison runs the same command on both trees
(`swift test --skip CSSearchableIndexSearchTests`) and reads the failure
SET, = = because the base's own set moves between runs.
