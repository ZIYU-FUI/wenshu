//
//  FileSystemReferenceStore+SearchIndex.swift
//
//  The reference library's half of the search index.
//
//  Why: a reference document (= an imported research dossier, a
//  document the agent wrote) is a constraint for the writing that
//  follows, and a constraint nobody can FIND is no constraint. The
//  chapter store has been publishing its documents to
//  `CSSearchableIndexSearch` since v1.55; the reference store did
//  not, so nothing the user imported and nothing the agent produced
//  was ever reachable by a word in it.
//
//  What: the same path the chapter store takes. A saved document is
//  indexed (= `index(docId:title:body:)`), a deleted one is removed
//  (= `remove(docId:)`), and the docId carries the `reference-`
//  prefix so a hit says which kind of document it is.
//
//  Timing: a save is synchronous (= the caller must not wait for the
//  system indexer) while an index write is asynchronous, so the write
//  is scheduled and `awaitSearchIndexWrites()` waits for it. A caller
//  that needs the document to be findable NOW (= the acceptance
//  check, = an agent that writes a document and searches for it in
//  the same breath) awaits it.
//

import Foundation
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "referencelibrary.searchindex")

extension FileSystemReferenceStore {

    /// Publish this document to the search index.
    ///
    /// The write is scheduled, not awaited (= the save path stays
    /// synchronous); `awaitSearchIndexWrites()` waits for it.
    func scheduleSearchIndex(reference: Reference, bodyMarkdown: String) {
        let docId = CSSearchDomain.referenceDocId(for: reference.id)
        let title = reference.title
        let index = searchIndex
        pendingSearchIndexWrites.schedule {
            do {
                try await index.index(docId: docId, title: title, body: bodyMarkdown)
            } catch {
                // The mirror inside the index is written before the
                // system write, so a failed system write still leaves
                // the document findable in this session. The failure
                // is logged, not swallowed: the system index is the
                // durable half.
                wenshuLogger.info(
                    "[wenshu.reference.searchindex] index write failed for docId=\(docId): \(String(describing: error))"
                )
            }
        }
    }

    /// Take this document out of the search index.
    func scheduleSearchIndexRemoval(id: UUID) {
        let docId = CSSearchDomain.referenceDocId(for: id)
        let index = searchIndex
        pendingSearchIndexWrites.schedule {
            do {
                try await index.remove(docId: docId)
            } catch {
                wenshuLogger.info(
                    "[wenshu.reference.searchindex] index removal failed for docId=\(docId): \(String(describing: error))"
                )
            }
        }
    }

    /// Wait until every scheduled index write has landed.
    ///
    /// The mirror inside the index is written as the write runs, so
    /// after this returns the document is findable by a word in it.
    func awaitSearchIndexWrites() async {
        await pendingSearchIndexWrites.awaitAll()
    }
}

/// The search-index writes a reference store has scheduled but not
/// yet awaited.
///
/// A reference save is synchronous (= the caller must not wait for the
/// system indexer) and an index write is asynchronous, so the write is
/// scheduled. This holds the scheduled work so a caller that needs the
/// document to be findable NOW can await it.
final class PendingSearchIndexWrites: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [Task<Void, Never>] = []

    /// Schedule one write.
    func schedule(_ operation: @escaping @Sendable () async -> Void) {
        let task = Task { await operation() }
        lock.withLock { tasks.append(task) }
    }

    /// Wait for every scheduled write, including the ones scheduled
    /// while the wait was running.
    func awaitAll() async {
        while true {
            let batch = takeBatch()
            guard !batch.isEmpty else { return }
            for task in batch {
                await task.value
            }
        }
    }

    /// Take the scheduled writes (= the list only holds the writes
    /// that nobody waited for yet, so a long session does not keep
    /// every finished task alive).
    private func takeBatch() -> [Task<Void, Never>] {
        lock.withLock {
            let batch = tasks
            tasks.removeAll()
            return batch
        }
    }
}
