# ADR-0034: The search layer's split — the app's own corpus answers, and the harness measures it

> Status: accepted
> Date: 2026-11-23
> Decision-maker(s): pocock

## Context

The library's search answered from its own corpus, and nothing measured it.

The ranking was `TokenOverlapRanking`: per-character tokens for Chinese, a
token overlap with no inverse document frequency, and — in the library's own
search — the title counted twice the body. A character that appears in every
document counts as much as one that appears in one. (= The amendment at the end
of this ADR records the day that stopped being true.)

Nothing asked whether the right document came back. The suites covered the
tokenizer, the scorer, the mirror round-trip and the view's behaviour; none of
them asked the question.

There is a second half to the story, and it is not the app's search. The app
publishes every document to the system search index (`CSSearchableIndexSearch`)
and then does not read it: the library's own search is deliberately not the
system index, for two reasons the code states (`ReferenceLibrarySearch.swift`):
the system index is a mirror of the session and is empty after a relaunch
until the documents are written again, and the system index answers by waiting
on Spotlight, which hangs the app when Spotlight is slow. So the app writes to
the system index and answers from its own corpus.

## Decision

Two things, and one thing that is explicitly not claimed.

1. **The harness measures the app's own search.** Over a synthetic corpus of 59
   documents (19 that answer a question, 40 that speak the question's own
   high-frequency words without answering it), 12 questions and one anchor
   token per question that occurs in exactly one document, the harness calls
   the app's own search functions and reads the recall off the gold:

   | ranker | recall@1 | recall@3 | bridge@1 |
   | --- | --- | --- | --- |
   | the production library search (`ReferenceLibrarySearch.search`) | 0.75 | 0.83 | 0.67 |
   | the production mirror search (`MirrorRanking.rank`) | 0.83 | 0.92 | 0.67 |
   | BM25 over the same per-character tokens | 0.83 | 0.92 | 1.00 |
   | BM25 over adjacent character pairs | 0.83 | 0.92 | 1.00 |
   | BM25 over Apple's own Chinese word tokenizer | 0.92 | 1.00 | 1.00 |
   | BM25 over the same bigrams, with the title searched too | 0.83 | 0.92 | 1.00 |
   | one independent query per term, interleaved | 0.42 | 0.67 | 0.00 |

   The first two rows call the app's functions. They do not re-declare them:
   the first version of this harness re-declared the ranking in the test file,
   and a change to the app's ranking left the table exactly where it was — the
   table measured the copy, and the copy even gave a different number (0.67
   against 0.75), because the copy's tie order was the copy's own. So the
   production ranking and the production tokenization now live where the
   harness can call them (`MirrorRanking`), and the floors in the harness are
   the numbers those functions produced.

2. **The gap the numbers name.** Weighing a term by how rare it is is worth
   most on the bridge questions — the ones whose answer shares only a rare term
   with the question: 0.67 → 1.00 there, against 0.75 → 0.83 overall. The gap
   is the missing inverse document frequency, and closing it is the next change,
   measured by the harness this branch lands.

3. **What is NOT claimed.** The system index is written by the app and is not
   read by it. The index entry now carries the document's text as `textContent`
   (the system's own header calls that attribute "the text content of the
   document" — `CSSearchableItemAttributeSet_Messaging.h`) and the document's
   title as one whole keyword, and the question reaches the index as a question
   through `CSUserQuery` with the system's own ranked order. **None of that
   changes what the user sees today**, because the library's own search answers
   from the corpus and not from the index. It is a foundation for the reader
   that does not exist yet (the agent's corpus retrieval), and this ADR does
   not count it as a gain.

## Consequences

Easier: the app's own search now has a number, and a floor that a change to the
ranking cannot cross without the build saying so; the system's index carries
the attributes it reads, and the question reaches it whole, so the later reader
does not have to start from a blank index.

Harder: the two production rows measure a synthetic corpus, not the user's
library, so they bound the ranking's behaviour rather than describe it; and the
system-index half of the app was still a write with no reader (= the amendment
at the end of this ADR records the day that stopped being true).

## Alternatives considered

- **A query-time expander that activates terms from the seeds and queries each
  one on its own.** Measured on the same fixture: recall@1 0.42 against the
  weighted query's 0.92, and bridge@1 0.00 against 1.00. One independent query
  per term gives every term the same weight, so a common term's top answers
  take the front rows. The shape works in the design it came from because that
  design also selects the seeds and scores the terms it activates; copying the
  querying half alone is a loss, so the app does not build it.
- **Apple's Chinese word tokenizer as the app's tokenizer.** Measured: it wins
  on this corpus (0.92 against 0.83), and it loses on a corpus whose coined
  names it cannot know. It is not the app's tokenizer, because the app's corpus
  is made of coined names.
- **A full-text engine of the app's own** (the design another project uses).
  Barred by the storage rule: no SQLite, no FTS5, no GRDB.
- **Reading the library's search from the system index.** Rejected on the two
  grounds the code already states (the index is empty after a relaunch; waiting
  on Spotlight can hang the app). The system's half earns its place at the
  agent's corpus retrieval, where a union with the app's own answer is worth
  more than either half alone (= the amendment at the end of this ADR records
  that union, and the merge's numbers).

## Amendment — 2026-11-24: the gap this ADR named is closed, with numbers

The change this file promised landed. `TokenOverlapRanking.score` now weighs
each query term by how many documents of the corpus the caller is searching
contain it (the inverse document frequency), and a term's contribution is
BM25's term-frequency term: saturation for repetition (`k1 = 1.2`) plus a
charge for the document's length against that corpus's average (`b = 0.75`).
The scoring left the index's file. That file is 556 lines at the base, of
which the two ranking types are 150; with this change's ranking in it the
single file would be 669 lines, over the 600-line cap. The scoring is now
`SearchRanking.swift` (286 lines) beside `CSSearchableIndexSearch.swift`
(411).

Measured by this file's own harness, on the same 59 documents and 12 questions.
In the three recall columns, "before" is the number the harness records as its
floor — which is also the number the base tree printed for that column, because
the floor was recorded from that same reading — and "after" is what this tree
prints. The bridge column carries no floor at all (the harness floors recall
only, and it records no bridge floor), so its cells are the base tree's reading
and this tree's reading, with an arrow where the two differ, and no assertion
in the suite would notice a change to them.

| the app's own row | recall@1 | recall@3 | recall@5 | bridge@1 |
| --- | --- | --- | --- | --- |
| the library search | 0.75 | 0.83 → 0.92 | 0.92 → 1.00 | 0.67 |
| the mirror search | 0.83 | 0.92 → 1.00 | 1.00 | 0.67 → 1.00 |

What the numbers say, and what they refuse to say:

- The mirror row — the answer the app gives when the system index is not
  available — gained recall@3 and its bridge@1. This is the row the ADR's own
  table could not read, because the table measured a copy of the ranking rather
  than this function.
- The library row gained recall@3 and recall@5; its recall@1 stayed at 0.75.
- The library row's bridge@1 stayed at 0.67, and the reason is not the missing
  weight. The question that loses holds a term occurring in exactly one
  document; the document that beats it puts a COMMON term in its TITLE, under
  the rule this file records as the product's own (the title counted twice).
  That is a title-weight question. It goes to its own card, and that card has
  to settle a bias first: in this fixture the gold documents' titles name
  entities and the noise documents' titles name topics, so a measurement of
  title weight here may be reading the fixture's shape rather than the rule's.
  This is stated as unsettled, not as measured.
- Saturation on its own is not the term, and that was measured rather than
  reasoned: the cut that capped repetition without charging length took the
  mirror row's recall@5 from 1.00 to 0.92 — a document that lists all twelve
  zodiac animals had paid nothing for its length, and it took the gold
  document's place. The floor was not lowered to hide that; the length term is
  what put it back, and every floor in the harness is unchanged by this
  amendment.
- Rarity is a property of the DOCUMENT and is computed over title and body
  together; length is a property of the FIELD and each field is normalised
  against its own average. Normalising a five-token title against a
  two-hundred-token body average would read "this title is short" as evidence
  and silently raise the title's weight, which is the one weight this file
  says the product owns.
- Nothing about the storage changed. This is the app's own scorer over the
  corpus it already holds: no SQLite, no FTS5, no GRDB, and the system index
  stays a write target.

## Amendment — 2026-11-24: the system index has its first reader

The line above — "the system index stays a write target" — was true of the tree
until this change, and this change is what makes it false. The agent's corpus
answer now reads the system index, and the index's ranking is merged with the
app's own ranking. The system index is no longer a write with no reader.

What the reader is. `reference_library` gained a read-only `search` action
(`ReferenceLibraryTool.swift`), and `find` keeps its own meaning: it locates a
document by title, and the agent's CRUD calls depend on that. The new action
answers one question over the whole library and returns, for each document that
answers it, the file the answer lives in and the sentences that hold it. The
fragments are the document's own sentences, read off the main actor's detached
task; the index contributes which documents and in what order, and the app
contributes the sentences themselves. The index's own snippet is a marked-up
64-character prefix — an artefact of a UI that renders it — and a fragment at
the sentence granularity the agent needs is not a prefix.

Where the reader sits. The corpus half answers from the documents the library
holds now. The index half answers from the documents the app indexed in EARLIER
sessions, and it is asked on its own task with its own length, and a failure in
it is dropped rather than raised: the corpus half is the one that always
answers, so an index that cannot answer must not fail the search the corpus
half can answer.

The merge rule, and the reason it is that rule. Two rankings of the same
documents become one ranking. The rule is: a document takes the best place
either half gave it; a tie goes to the document the other half also ranked; the
last tie goes to the index half's own order. The rule is read off RANKS and
never off scores, because the app's score is a token-overlap sum and the
index's score is Apple's relevance — a number the app cannot read at all, since
the index hands back positions and not scores.

The first version of this merge kept the corpus half's order and appended the
index half's documents behind it, and that version was measured, not assumed:
the corpus half names every document it matched — 19 to 41 of them on this
file's own fixture, measured over the twelve questions by the harness's own case
`the corpus half names more documents than the answer can carry`, which prints
the twelve counts — while the answer names at most eight, so the index half's
documents could not reach the answer at all. The harness said so and nobody
read it: the union row printed the library row's own numbers to the digit
(0.75 / 0.92 / 1.00 / 0.67) and every floor was green, because the union row's
floors were `0.0` — a floor of zero gates nothing. Two defects, one cause: a
floor that was a placeholder, and a merge that was a copy of one half.

What this tree measures, on this file's own harness, over the same 59 documents
and 12 questions. The union row is the app's own merge, called; the index half
is the index's own ranking (the mirror, which is what the index answers from
in-process) cut to the answer's length, which is the shape the agent's answer
has.

| the row | recall@1 | recall@3 | recall@5 | bridge@1 |
| --- | --- | --- | --- | --- |
| the library search | 0.75 | 0.92 | 1.00 | 0.67 |
| the mirror search | 0.83 | 1.00 | 1.00 | 1.00 |
| the union (= the merge) | 0.83 | 1.00 | 1.00 | 1.00 |

What the numbers say, and what they refuse to say:

- The union is a third order and not a copy of either half: measured over the
  twelve questions, its order equals the corpus half's order on none of them
  and the index half's order on none of them. The first version of the merge
  was the corpus half's order on twelve of twelve, and the harness could not
  see it. So the harness now carries that measurement as a test of its own
  (`the union is neither half's order`), and the union row's floors are the
  numbers the merge produced (10 of 12 at one, 12 of 12 at three and at five)
  instead of `0.0`. Which floors bit is worth stating too: under the corpus-first
  copy the floors that fired were recall@1 and recall@3. recall@5 did not,
  because the library row also reaches 1.00 at five — so the 12-of-12 floor at
  five gates a future regression and proved nothing in this round.
- The union matches the better of its two halves rather than beating both. The
  better half reaches 0.83 at one hit (the mirror; the library reaches 0.75),
  and the merge matches it at 0.83. The highest recall@1 anywhere in the table
  is 0.92 and it belongs to `bm25-apple-word`, which is neither half; the
  library's 0.92 is a recall@**3** number, and this file read it as a one-hit
  ceiling until the reviewer caught the column. The merge is a reading of two
  rankings, not a third opinion, and this file does not claim it is one.
- The union's gain over the library row is on the bridge shape (0.67 to 1.00),
  which is the shape this file's earlier amendment named: a question whose
  wording the app's own terms never met. That is the shape the index half
  exists to reach, and it is the shape the merge is for.
- On this fixture the two halves name the same documents (twelve of twelve
  questions), so what the union adds here is ORDER and not recall of new
  documents. The recall the index half adds in the app is the recall of the
  documents the app indexed in an earlier session and the corpus's terms never
  met, and this harness cannot measure that, because it reads no system index.
  The number here is the merge's ordering, and it is not a measurement of the
  index's recall.
- The harness's index half is the mirror, which is the index's own ranking in
  process. It is not a stand-in for Spotlight, and it does not claim to be one:
  it is the half of the index the app can call deterministically, and the merge
  that matters is the merge of two rankings.

Nothing about the storage changed. No SQLite, no FTS5, no GRDB, and the query
contract is the one this file already records: the question reaches the index as
a question, with the index's own entry carrying title, content description,
text content and keywords.



## Amendment — 2026-11-24: the glue list had to reach the app's own language

The reader this file records drops, before it answers, the words that carry no
question on their own: the glue. That list was written in English while the
library the feature serves is written in Chinese, and the two are not the same
claim. The tokenizer the search runs is character-level for CJK (one token per
character), so a Chinese question arrives as a bag of single characters and the
English list drops none of them. The Chinese copula and the possessive particle
sit in every sentence of every document the library holds.

Measured on the tree before the fix, with the new case added first and run
against it: a Chinese question about bronze-bell casting, put to a library
holding only documents about the land tax and about sea-borne silver, named
those documents. It named them because the question and the documents share
grammar, and nothing in the tree said that sharing grammar is not answering.

What changed. `ReferenceCorpusSearch` now carries a second, explicit list, the
same rule and the same visibility as the English one, of the Chinese characters
that carry no question on their own. It is function characters only: a character
that can carry a subject is deliberately absent, because dropping it would drop
the question with it. The list is a judgement, so it is written down where a
reader can disagree with it rather than hidden in a tokenizer.

And the sentence's evidence rule. A term is held by a sentence when the
sentence's own tokens contain it — the same tokenizer the ranking scored with —
and not when the term is a substring of the text. Those are different claims and
the tree had them in the same function: the comment said the match was the whole
term and the code asked whether the folded text contained the term. The
difference is not cosmetic. A substring lights a sentence up for a word the
ranking never scored, and the fragment then cites as evidence something the
answer did not use.

What the numbers in the previous amendment do NOT cover. The fixture is the
app's own language: 59 documents and 12 questions of Chinese (`RetrievalQuality
Corpus.swift`, whose titles, bodies and questions are all Chinese), so these rows
DO describe Chinese ranking behaviour over a Chinese corpus. What they do not
describe is the system index. The harness reads no system index: its index half
is the in-process mirror, and the recall the real index adds is the recall of
the documents the app indexed in an earlier session and the corpus's terms never
met. Nor do the rows cover the answer's fragment step: the two glue lists and
the held-term rule sit in `ReferenceCorpusSearch.search`, which the harness never
calls (measured twice: removing the character list leaves the table exactly
where it was), and that step is held by the two Chinese cases in the tool's own
suite.

And one claim this file carried and got wrong, retracted here so the next reader
does not inherit it: an earlier draft of this amendment said the fixture was
English and that the rows therefore said nothing about Chinese recall. It was
written from a grep of the ranker file, which carries no Chinese because it holds
the models and the table, not the corpus; the corpus lives in the file beside it,
and it is Chinese throughout. The claim was a guess about which file produced the
number, and it is the exact defect this lane exists to make expensive: a record
that misreads its own measurement.
