# The corpus-search arm of the retrieval-quality fixture · acceptance

Item: the archived card `t_b1dbd63e`, re-entered as one review card per the 2026-11-26
board directive (= an open item returns as a review card from the implementing session,
after the commit).

Branch `wt/t_b1dbd63e` · base `7637ebba35`, which this lane did not move. The tip is
named in the review card and printed by `git rev-parse HEAD` in the worktree; this file
cannot quote it truthfully, because committing it moves it. (= the merge-base
with `main`, and `main` was not moved by this card).

## What the card asked for

The retrieval-quality fixture measured the ranking half of the library's
answer and never called `ReferenceCorpusSearch.search`, which is the function
that owns the app's two Chinese rules: the glue list and the held-term rule.
A change to either rule moved the app's answers and left the fixture exactly
where it was. The card asked for a Chinese arm that calls the corpus search
directly, asserts both rules in the open, and goes red when either changes.

The card did NOT ask for a change of behaviour, and none was made. Every
number the closed card measured is still the number it measured.

## What was added

One file, `Tests/WenshuAppTests/Library/Search/RetrievalQualityTests+CorpusSearch.swift`
(256 LOC), five rows, members of the existing `RetrievalQualityTests` @Suite reached
through an extension (= the same shape `CitationHonestyTests+Teeth.swift`
uses), so `swift test --filter RetrievalQualityTests` runs the arm and no
other filter was widened.

Five rows. Each calls `ReferenceCorpusSearch.search` over a corpus built the
way the library builds it (= `RankerTable.libraryCorpus`, one `Reference` per
document, and a `bodyOf` that hands back the body and the file it was read
from, the signature production asks for).

| row | the rule it holds |
| --- | --- |
| a Chinese question made only of glue answers with nothing | the glue list's membership, and what that membership buys |
| the glue list empties a question the library cannot answer and leaves the ones it can alone | the same list must not over-drop; the five characters the production comment refuses to carry (= 上, 下, 中, 有, 缺) are asserted absent |
| a fragment holds the word the ranking scored, and not a piece of a longer word | token membership and not substring containment |
| the document that shares only the question's grammar is not the answer | the first-sentence fallback is held behind a title that carries a word of the question |
| every fragment the corpus search cites holds a word of the question | the shape of the answer across all twelve fixture questions |

## Why two of the rows carry their own documents

The 59-document fixture is Chinese-only: it holds 0 ASCII letters (measured),
and the tokenizer cuts CJK one character per token, so for any Chinese text a
character is a substring of a sentence exactly when it is a token of it. The
token-vs-substring distinction is therefore invisible in that corpus, and a
row asserting it there would be asserting the tokenizer's CJK rule twice. The
two documents the file carries (= `银路账目`, `关税旧档`) exist so that one
sentence holds `PDF` as its own token and the next holds `PDFs`, which contains
it as a piece; and so that one document shares a question's grammar and none of
its content. The fixture's own 59 documents were not touched: adding to them
would move the measured floor, which is not what this card is for.

## Measurements

Baseline, this tree, before the arm: `Test run with 17 tests in 1 suite passed`.
With the arm: `Test run with 22 tests in 1 suite passed after 0.478 seconds`
(+5 rows, 1 suite, the filter the card names).

The two rules' load-bearing facts, read off the corpus search's own output:

- `这个是什么` over the 59-document fixture: **the ranking names 11 documents,
  the corpus search answers with 0.** That gap is the glue list's entire effect
  on the answer. Without the list the question is answered by every document
  that merely shares its grammar.
- All twelve fixture questions: answered 12/12, gold document named 12/12,
  and **0 of the cited fragments hold nothing of the question besides glue.**
  Fragment counts per answer sit at 7-8 against `defaultLimit = 8`.
- `白银的 PDF 存在哪里` over the arm's two documents: one answer, one fragment
  (= `白银的账目存成 PDF`). The sentence holding `PDFs` is not cited, and the
  document holding no content word of the question is not named at all,
  although an occurrence-counting ranking puts it in front of the reader.

## The mutation matrix

Each rule was changed on its own and the arm was re-run. A row that stays
green over the change to the rule it names measures nothing, so the failing
expectation's file:line is recorded.

| mutation | where | result |
| --- | --- | --- |
Every row below was run after the arm took its final formatting, so the line numbers
are the shipped file's. No code line moved after these four runs: what came after was
this document's own text.

| mutation | where | result |
| --- | --- | --- |
| `"是"` deleted from `commonCharacters` | `ReferenceCorpusSearch.swift:126` | 22 tests, 3 issues, all in the first row: `commonCharacters.isSuperset(of: tokenize(question))` at arm line 122, `contentTerms(of: question).isEmpty` at 128, the empty answer at 132. No other row moved. |
| `"中"` appended to `commonCharacters` | `ReferenceCorpusSearch.swift:130` | 22 tests, 1 issue: `refused.isDisjoint(with: commonCharacters)` at arm line 180. Nothing else moved. |
| `termsHeld` read as substring containment instead of token intersection | `ReferenceSentenceExcerpt.swift:148` | 22 tests, 1 issue: `hits.first?.fragments == [latinHeldSentence]` at arm line 200. Nothing else moved. |
| `titleHeld` forced to `true` (= the pre-amendment fallback, the first sentence always offered) | `ReferenceSentenceExcerpt.swift:124` | 22 tests, 3 issues: `hits.count == 1` at arm line 196, the grammar-only document at 217, and the twelve-question sweep `glueOnly == 0` at 254. |

All four were reverted before this document was written; the tree carries one
untracked file (= the arm) and nothing else.

The fourth mutation is the one that matters most for the card's own claim: it
turns red not only the small corpus's rows but the sweep over the fixture's
real questions (= the 0 glue-only fragments number). The rule is what keeps
the answer honest on the corpus the card was told not to move.

## Gates, all measured on the shipped tip

- `swift test --filter RetrievalQualityTests`: PASS, 22 tests in 1 suite
  (17 before the arm, same filter).
- `bash Tools/wenshu-devtool/tests/run-suites.sh`: exit 0, `suites=44 red=0
  known-red=0`.
- `python3 Tools/wenshu-devtool/pre_review_gate.py --base 7637ebba35 --filter
  'RetrievalQualityTests'`: rc 0, every instrument green, including
  `comment-lineage: exit 0 (offending: 0 rows / 0 files (P0=0, P1=0))`,
  `ci_change_gate --check formatting`, and `nfi-loc-check`.

## The one thing not in this tree

`docs/agents/nfi.md` owes two rows for this lane. They are not committed: the shared
register was reserved at 13:21:59 by session `local-c286bc3215dad814e50c04aabf0b07296c400dcaf58da8a054d1f08638ebc25f`
(pid 27054, dead, never renewed, self-expires 14:51:59), and `nfi_lock.py release
--force` is documented as a human call. The rows are in `stash@{0}` of this worktree and
reproduced with landing commands in
`/Volumes/ANAN/.hermes/profiles/pocock/pending-cards/2026-11-26-corpus-search-arm/nfi-rows.md`.
`nfi-loc-check` measured exit 0 WITHOUT them, so the per-change gate does not charge a
new file that has no row: they are history, not a gate this tree fails.

## What this card does NOT do

It does not change the corpus search's behaviour. It does not change the
measured floor. It does not add a sixth rule or widen the ranking's own rows.
The recall floor cards stay as closed, and the W4 named-index lane is
untouched by this tree.
