# ADR-0034: The search layer's split — the system index recalls, the app measures its own ranking

> Status: accepted
> Date: 2026-11-23
> Decision-maker(s): pocock

## Context

The library's search answered from two halves, and only one of them worked.

The system half asked the system index with a metadata query string that matched a
literal substring of the title or the body. A question is not a substring of any
document, so for a natural-language question that half answered nothing, and the
answer the user saw came entirely from the app's own mirror.

The mirror half ranked with a token overlap: one token's contribution was capped
at two occurrences and the total was normalised by the query's token count. No
term was weighed by how rare it was, so a character that appears in every document
counted as much as one that appears in one. The tokenizer split Chinese text into
single characters, which is the granularity at which the distinction between a
common character and a rare one is smallest.

Nothing measured either half. The suites covered the tokenizer, the scorer, the
mirror round-trip and the view's behaviour; none of them asked whether the right
document came back. The retrieval-quality harness now answers that, over a
59-document fixture (19 answering, 40 noise) with 12 questions and one
unambiguous anchor per question:

| ranker | recall@1 | bridge@1 |
| --- | --- | --- |
| the production ranker (token overlap) | 0.67 | 0.67 |
| the same tokens, weighed by rarity | 0.83 | 1.00 |
| Apple's own Chinese word tokenizer, weighed by rarity | 0.92 | 1.00 |
| one independent query per term, interleaved | 0.42 | 0.00 |

The gap is the missing term weighting, and it is worth most on the bridge
questions, where the answer shares only a rare term with the question.

The last row is the shape another project's retriever uses, and it is the worst
of the six. One independent query per term gives every term the same weight, so
a common term's top answers take the front rows, and the interleaving puts them
there. The mechanism that makes that shape work is a seed selection and a
scoring of the terms it activates, and neither of those is free to copy.

Apple's own documentation states which attributes the system's semantic index
processes: the title and the text content. The app was putting the body in the
content description, so the body never reached the semantic index.

## Decision

The search layer splits into three parts, and each part has one owner.

1. **The system index recalls.** The index entry carries the title, the content
   description, the text content (the body, which is the attribute the system's
   semantic index processes), and the document's title as one whole keyword (so a
   coined name stays findable whatever the system's tokenizer does with it). The
   question reaches the system as the question itself, through `CSUserQuery`,
   with the system's own ranked order, and no model of any kind.
2. **The app's mirror answers the fallback.** It stays the half the app always
   has: a system index that is slow, off, or without query understanding costs
   latency, not the answer.
3. **The harness measures the app's own ranking.** The mirror's score is
   measured on every run against a recorded floor, so a change to the search path
   cannot lower the answer without the build saying so.

## Consequences

Easier: the system's half of the answer starts working for a natural-language
question wherever the system's query understanding is available; the app's own
ranking has a number behind it for the first time; a future change to the search
path has a gate to pass.

Harder: the system's half is ranked by the system, so the app cannot explain
that order in detail, and it needs the system's query understanding to be useful
for a question (a single term answers on its own; a whole sentence does not).

Locked in: the app's model layer stays provider-based, and the retrieval path
takes no model at all — the system's index answers the question, and the app's
model layer is not part of the retrieval path.

The index instance is still the default one. A named index is Apple's
recommendation for shipped content, and it needs a pass that re-donates every
document the app has already indexed, so it arrives with that pass and not
before it.

## Alternatives considered

- **A query-time expander that activates terms from the seeds and queries each
  one on its own.** Measured on the same fixture: recall@1 0.42 against the
  reference ranker's 0.92, and bridge@1 0.00 against 1.00. One independent
  query per term gives every term the same weight, so a common term's top
  answers take the front rows. The shape works in the design it came from
  because that design also selects the seeds and scores the terms it activates;
  copying the querying half alone is a loss, so the app does not build it.
- **Apple's Chinese word tokenizer as the app's tokenizer.** Measured: it wins
  on this corpus (0.92 against 0.83), and it loses on a corpus whose coined
  names it cannot know. It is not the app's tokenizer, because the app's corpus
  is made of coined names.
- **Apple's sentence embeddings as the app's ranker.** Measured: they do not
  separate a near-paraphrase from an unrelated sentence on this corpus, so they
  do not rank.
- **A full-text engine of the app's own** (the design another project uses).
  Barred by the storage rule: no SQLite, no FTS5, no GRDB.
