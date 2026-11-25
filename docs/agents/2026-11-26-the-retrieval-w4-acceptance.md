# Retrieval W4 — what the whole-corpus write contract holds, and where it stops

Lane: `wt/retrieval-w4-named-index-2026-11-25`, reviewed as `t_3fe00d0c`.
This file is the citable acceptance contract for `SpotlightIndexWriterTests`; the
test comments point here because a quoted requirement nobody can open cannot be
audited.

## The five items, as they were scoped

1. **One index handle, defined once, no second call site with a different name.**
   Held. `SpotlightIndexName.makeHandle()` in `SpotlightIndexIdentity.swift` is the
   only `CSSearchableIndex(name:)` in `Sources/`; the name and the batch ceiling
   (`SpotlightIndexBatch.limit = 500`) live in that one file.
   Held by: `indexHandleHasOneCreator`.

2. **Full and incremental donation share one write path; content survives a
   wipe-then-redonate.** Held as a code shape: both go through the same handle, the
   same item seam (`indexItems(_:batched:)`) and the same slice function, and the
   batch transaction is serialised by `SpotlightIndexBatchGate`.
   Held by: `emptyCorpusDoesNotWipe`, `cursorRoundTripsThroughTheIndex`.

3. **The query reads what the migrated write stored, and the recall floors do not
   move.** Held. `RetrievalQualityTests` passes unchanged on this lane.

4. **The new symbols are registered in `docs/agents/nfi.md`.** Held.

5. **Build, the real-index suites, and the repo's own gates are green.** Held, and
   the gate named here is `pre_review_gate.py --base <lane-base>`, which includes
   `comment_lineage.py`.

## What this contract does NOT claim

- **There is no caller in production yet.** `donate(corpus:)` is not wired into
  launch. Wiring it before the corpus enumeration (chapters, books, materials) is
  proven complete would be a data-loss path: a wipe scoped to the donate domain plus
  an incomplete enumeration deletes what the index already holds. The enumeration and
  its trigger are a separate card, and until that card lands, item 2 is a write-path
  property, not a live re-donation.
- **Readiness proves a document landed only when the document can be named uniquely.**
  The underlying query is a domain-wide containment test. A token shared with any other
  document in the domain — including one this donation never wrote — answers `found`
  regardless of this donation. `SpotlightReadinessToken.forCorpus(_:)` therefore returns nil for a shared
  token and the report says `notChecked`. Measured reason: with a markdown corpus the
  first whitespace-delimited word of an H1 is `#`, and the probe read `found` after
  both probe documents had been deleted.
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
