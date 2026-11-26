# Retrieval W4 — what the whole-corpus write contract holds, and where it stops

Lane: `wt/retrieval-w4-named-index-2026-11-25`, reviewed as `t_3fe00d0c` (r1,
`97ac0dfde5`), `t_5d07fc1c` (r2, `a95222dde8`), and this round as the r3 of that
same lane. This file is the citable acceptance contract for
`SpotlightIndexWriterTests`; the test comments point here because a quoted
requirement nobody can open cannot be audited.

## The five items, as they were scoped

1. **One index handle, defined once, no second call site with a different name.**
   Held. `SpotlightIndexName.makeHandle()` in `SpotlightIndexIdentity.swift` is the
   only `CSSearchableIndex(name:)` in `Sources/`; the name, the batch ceiling
   (`SpotlightIndexBatch.limit = 500`) and the readiness-token rule live in that one
   file.
   Held by: `indexHandleHasOneCreator`.

2. **Full and incremental donation share one write path; content survives a
   wipe-then-redonate.** This item is TWO claims and they are not held equally.

   - *One write path*: held. Both faces arrive at `indexItems(_:batched:)` and at
     `SpotlightIndexWriter.chunks(of:)`, and the batch transaction is serialised by
     `SpotlightIndexBatchGate`. Held by: `donatedCorpusIsReadable` (the corpus path
     through the production handle), `reIndexReplacesContent` (the save path through
     the same handle), `chunksRespectTheLimit` (the ceiling both paths share).
   - *Content survives a wipe-then-redonate*: **not held by any test.** The only pass
     that performs the wipe is `donateCorpus(_:)`, and its first act is
     `deleteSearchableItems(withDomainIdentifiers: [com.wenshu.docs])` — on a
     developer's machine that removes the app's own indexed documents, and because
     `bootstrap()` deliberately does not donate, nothing puts them back. The two tests
     r2 named here (`emptyCorpusDoesNotWipe`, `cursorRoundTripsThroughTheIndex`)
     perform no re-donation: the first proves a refused pass leaves content alone,
     the second proves the cursor, not the content. So the half stays a code-shape
     claim, and the arm that would hold it belongs with the enumeration-and-trigger
     card, where the wipe gets the corpus it is meant to be safe against.

3. **The query reads what the migrated write stored, and the recall floors do not
   move.** Held. `RetrievalQualityTests` passes unchanged on this lane, and
   `CSSearchableIndexSearchTests` runs 26/26 at the shipping sha.

4. **The new symbols are registered in `docs/agents/nfi.md`.** Held, and r3 closed
   the exception the reviewer recorded: the registry rows now exist for
   `SpotlightIndexReadiness.swift` and for this file.

5. **Build, the real-index suites, and the repo's own gates are green.** Held, and
   the gate named here is `pre_review_gate.py --base <lane-base>`, which includes
   `comment_lineage.py`.

## What this contract does NOT claim

- **There is no caller in production yet.** `CSSearchableIndexSearch.donate(corpus:)`
  runs `SpotlightIndexWriter.donateCorpus(_:)` and has no caller. Wiring it before the
  corpus enumeration (chapters, books, materials) is proven complete would be a
  data-loss path: a wipe scoped to the donate domain plus an incomplete enumeration
  deletes what the index already holds. The enumeration and its trigger are a separate
  card, and until that card lands, item 2 is a write-path property, not a live
  re-donation.
- **A readiness answer is about a document only when it is filtered to one.** The
  underlying query, `contentDescription == "*token*"c`, is a domain-wide containment
  test: it answers "some document in this domain carries this word", and it has no way
  to mean "this one". r2 shipped with the token-uniqueness rule as the only defence,
  which was not enough — `SpotlightReadinessToken.forCorpus(_:)` compares the first
  prose word of the last donated document with the first prose word of the earlier
  *donated* documents, so a document the donation never wrote, anywhere in the domain,
  could still answer for it. r3 filters the answer set itself: a hit counts only when
  its `uniqueIdentifier` is `CSSearchDomain.itemIdentifier(for: docId)`.
  `aForeignDocumentCarryingTheTokenCannotAnswerForTheSubject` is the arm that separates
  the two faces, and it is the reason the sentence above is no longer a caveat.
- **The batch gate's reclaim arm is untested.** A holder cancelled between `acquire()`
  and `release()` is not covered.

## Evidence this lane actually measured

- `beginBatch()` on the default handle raises `Batching not supported` and aborts the
  process (`Abort trap: 6`, rc 134); batching is a named-handle capability.
- A named handle and the default handle address the same physical store — a
  delete-by-domain issued through the default handle removes an item written through
  the named one. Client state is handle-bound, not store-shared.
- Two `beginBatch()` calls on one handle raise `Batch is already open` (rc 134); with
  the gate deleted, `SpotlightIndexWriterTests` aborted on that exception.
- One plain write call accepts 500 and 2000 items; at 75010 it fails with
  `CSIndexErrorDomain` code `-1001`.
- Two callsites each flushing one document, batched, concurrently: one wins and the
  other surfaces the failure.
- **Ingest latency, 60 rounds of one plain write followed by one containment read on
  the production handle:** the first readable answer arrived at p50 9 ms, p90 10 ms and
  worst case 130 ms after the write's own completion returned. A committed write is
  therefore not a readable document yet, which is what the suite's red arms were
  reporting as one (`visibilityBound` = 2 s, ~15x the worst measured latency).
- **The containment answer is per document, 3-item probe:** three documents written
  under one domain, all carrying one token, answered 3 hits, each carrying its own
  `uniqueIdentifier`; deleting one by identifier left 2 and the deleted document's
  identifier was gone from the answer. So the identifier filter closes the containment
  hole with the face that is measured to answer, and it does not need the
  `searchableItems(forIdentifiers:)` face, which is a delegate callback and not
  available on a live index handle.

## Round 3's own delta, stated plainly

- N1: two mechanisms, and the tally is what separated them.

  1. *Ingest latency.* The readiness face took the index's first word, and an index
     that has not ingested a committed write answers "no hits". It now waits for the
     direction the question asks about: `check` while a token becomes readable,
     `checkGone` while one stops being readable, `ask` for an arm that wants no
     waiting. That is a production fix, not a test fix — `donateCorpus` reports
     through the same face.
  2. *Batch transaction overlap.* Adding the 501-document batch arm turned 5 reds in
     25 runs into 5 reds in 12, all of them an arm reading a token another arm had
     written inside ITS open batch. A wait cannot fix that: the write is not on its
     way anywhere until the other batch commits. So the suite carries `.serialized`,
     and it is the load-bearing half for the test suite while the bound is the
     load-bearing half for the report. `--no-parallel` was not used as evidence —
     it is not what ships; `.serialized` is.

  After both: 12 consecutive `swift test --filter 'SpotlightIndexWriterTests'` runs,
  12 passed / 0 failed / 0 aborted.
- N2: the three claims the code refuted (the heading-led `notChecked` sentence, the
  chunk-order sentence, and "shared with another document in the domain") are rewritten
  to what the code does, in `SpotlightIndexWriter.swift`, this file, and the registry.
- N3: the identifier predicate is adopted, and two arms landed with it — the foreign
  document that cannot answer for the subject, and a 501-document run whose token lives
  in the final chunk alone.
- N4: the registry rows, item 2's evidence mapping, and the wrong symbol citation at
  `CSSearchableIndexSearch.swift:300` (`donate(corpus:)` is the search actor's face;
  `donateCorpus(_:)` is the writer's).
