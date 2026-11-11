#
#  2026-11-10 — the render path's measured audit (and what the real data changed)
#
#  The audit that started this work measured the app's render path against
#  a SYNTHETIC corpus (= 240 entities, = 84 documents). = Every number
#  below is re-measured against the USER'S OWN data
#  (= `~/Documents/anbaiqiang.ws`, = read-only), = and the two columns do
#  not always agree.
#
#  ⇒ ⇒ **⇒ AND THE DISAGREEMENT IS THE POINT.** = ⇒ The synthetic corpus
#  RESCALES a number (= up to 6x), = and it REORDERS the findings (= the
#  scan and the word count swapped places), = and for two findings it
#  turns a REAL defect into a NON-defect. = ⇒ ⇒ ⇒ So a finding measured
#  on a synthetic corpus is a SCENARIO, = and a card that ships it as a
#  defect ships a number the user will never see.
#
#  ⇒ ⇒ ⇒ ⇒ THE TABLE BELOW IS THE RECORD OF WHAT THE REAL DATA CHANGED,
#  = = because the changes are the lessons.
#

## The three columns

| finding | the audit's number | the real number | what changed |
| --- | --- | --- | --- |
| the pinyin SORT key | 48 ms per sort | 4,039.57 us (= 12 items) | same defect, = smaller |
| the pinyin SEARCH key | 261 us per pass, = the pinyin branch is 96% | 1,225.18 us per pass, = the decorate shape is **1.02x** and the ASCII fast path is **0.99x** | **DROPPED** (= every title in the real library is CJK, = so the fast path never fires) |
| the chat's markdown re-parse | 1.00 ms per message per body pass, = 5-15 ms per frame | **79.75 us** for the whole transcript, = **299.05 us** per frame at 15 visible messages | **DROPPED** (= below Apple's 500 us finding threshold, = on the user's own four messages) |
| the editor's word count | 2.05 ms per keystroke | **1,992.58 us** on the largest document | same defect, = confirmed |
| the materials column's footer scan | 6,234 us (= synthetic) | **2,174 us** | the defect holds, = but it is the SAME size as the word count, = not a 6x lead |

## ⇒ ⇒ The two findings the real data DROPPED, = = and why

⇒ ⇒ **THE CHAT'S MARKDOWN.** = ⇒ MEASURED on the user's OWN four chat
messages (= the `ZWSCHATMESSAGE` table of the user's own store, = lengths
6 / 20 / 29 / 532): = one message's body pass costs **5.08 / 5.71 / 7.52 /
61.44 us** (= the parse + every block's inline parse). = ⇒ The whole
transcript is **79.75 us per frame**, = and 15 visible messages read
**299.05 us per frame** (= Apple's finding threshold is 500 us, = the red
line is 1,000 us, = the 60fps frame budget is 16,700 us). = ⇒ The audit's
"5-15 ms per frame" came from a 4,731-character document, = and the real
transcript is **20-50x cheaper**. = ⇒ ⇒ ⇒ **⇒ SO IT IS NOT DONE.**

⇒ ⇒ **THE PINYIN SEARCH KEY.** = ⇒ MEASURED on the user's 32 markdown
documents: = the decorate-filter-undecorate shape reads **1,195.94 us**
against the current **1,225.18 us** (= **1.02x**), = and the ASCII fast
path (= skip the transliteration for a title that holds no non-ASCII)
reads **1,009.55 us** against **1,002.01 us** (= **0.99x**) = because
every title in the real library is CJK, = so the fast path never fires.
= ⇒ ⇒ ⇒ **⇒ SO IT IS NOT DONE ON ITS OWN.** = ⇒ Its real cost is that
the filter pass runs TWICE (= once for the grid, = once for the footer),
= and that belongs to the materials column's card.

## ⇒ ⇒ The two findings the real data CONFIRMED, = = and their shapes

⇒ ⇒ **THE EDITOR'S WORD COUNT.** = ⇒ The full count computes six fields
and five of them have no production consumer (= `grep` over
`Sources/WenshuApp` finds no read of `.words`, = `.sentences`, =
`.paragraphs`, = `.characters`, = or `.chineseChars` on a `WordCount`).
= ⇒ So every keystroke paid for the linguistic segmentation
(= `enumerateSubstrings(.byWords)`), = which serves only the unread
`words` field. = ⇒ MEASURED: = the full count **1,992.58 us** on the
largest document, = the fast path **137.63 us** (= **14.5x**).

⇒ ⇒ **⇒ AND THE UNIT IS THE CHARACTER, = = NOT THE SCALAR.** = ⇒ A
scalar scan disagrees with the production count on the emoji (= 10 vs
17), = on the combining sequence (= 5 vs 7), = and on the flag (= 7 vs
9), = and the character form agrees on all nine boundary cases and on all
32 real documents (= **zero mismatches**).

⇒ ⇒ **THE MATERIALS COLUMN'S FOOTER SCAN.** = ⇒ MEASURED on the user's
real library, = and DECOMPOSED (= each part measured on its own):

| part | cost |
| --- | --- |
| the shelf listing | 28.0 us |
| the shelf walk (= one listing per shelf) | 82.2 us |
| the folder listing per book | 78.9 us |
| **the file listing per folder** | **585.0 us** |
| **reading every .md in full** | **450.5 us** |
| the per-file `resourceValues` (= two stats per file) | 22.0 us |

⇒ ⇒ ⇒ **⇒ AND THE GRID WALKS THE SAME DISK A SECOND TIME.** = ⇒ The
footer calls `countCardsInScope` (= its own load + its own filter) and
the grid calls `searchFilteredEntities` (= its own load + its own filter),
= so the library is walked twice per layout change. = ⇒ ⇒ ⇒ ⇒ **⇒ AND
THE HEAD-ONLY CANDIDATE WAS MEASURED AND REJECTED**: = reading 4 KB per
file reads **529.15 us** against the whole file's **450.96 us** (= the
files are small (= the corpus is 28,616 characters over 20 files), = and
a `FileHandle`'s open costs more than the bytes it saves), = and it
introduces a UTF-8 boundary hazard (= a byte-prefix can split a
multi-byte character, = and `String(data:encoding:.utf8)` then returns
nil). = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ SO THE CANDIDATES THAT REMAIN ARE THE CACHE
(= the disk walk happens once per library change, = not twice per layout
change) and the SHARED COMPUTATION (= one walk, = two readers), = and
both need their INVALIDATION RULE measured before they are built.**

## ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ THE THREE RULES THIS AUDIT PAID FOR

1. **⇒ MEASURE ON THE USER'S DATA, = = AND SAY WHICH CORPUS THE NUMBER
   IS FROM.** = ⇒ Every number above names its corpus. = ⇒ A number
   without its corpus is a claim about nothing.
2. **⇒ A SHAPE CLAIM MEASURED ON A SAMPLE IS A HYPOTHESIS.** = ⇒ The
   log's outer chain is `All tests` in two of the five XCTest-bearing
   logs under `.gate-logs` and `Selected tests` in the other three, = and
   the false claim ("there is NO `All tests` level") came from three
   `/tmp` logs that no longer exist. = ⇒ ⇒ Measure the population, = or
   write the claim as a scenario.
3. **⇒ A FIXTURE MUST REACH THE STATEMENT UNDER TEST, = = AND THE
   MUTATION ARM IS WHAT PROVES IT.** = ⇒ A fixture that cannot hold the
   property proves nothing, = and a fixture that cannot reach it proves
   nothing either, = and both look like a green suite.
