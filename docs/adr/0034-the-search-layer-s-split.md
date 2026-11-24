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
system-index half of the app is still a write with no reader.

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
  more than either half alone.

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
