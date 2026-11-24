//
//  ReferenceLibraryActor+Search.swift
//
//  The agent's corpus answer, in one call.
//
//  Why: the agent had no way to ASK the library a question. = It could
//  `find` a document by title (= one document, = and only if the agent
//  already knew the title), = and then `read` it (= the whole body). =
//  So a question that spans documents cost one round trip per
//  document, = and the agent had to guess titles to start.
//
//  What: `searchReferences` answers one question over the whole
//  library and returns, for each document that answers it, the file
//  the answer lives in and the sentences that hold it.
//
//  **⇒ THE READS ARE OFF THE MAIN ACTOR.** = A library is a folder of
//  files, = and reading N of them on the main actor while the agent
//  waits is a frozen app. = The metadata is read here (= cheap, = and
//  the store is main-actor isolated), = and the bodies are read on a
//  detached task (= the same shape the library's own search view runs,
//  = so the two answer the same question the same way).
//
//  **⇒ THE SYSTEM INDEX IS ASKED, = AND ITS ANSWER IS UNIONED IN.**
//  = The index is the app's own writing, = and it holds the documents
//  this app indexed in EARLIER sessions (= the in-process mirror does
//  not survive a relaunch). = So it can name a document the corpus
//  half missed. = **⇒ But it cannot answer on its own**: = the index
//  is empty until something is written, = and the corpus half is the
//  one that always answers. = **⇒ So the two halves are MERGED, = and
//  the merge reads the best place either half gave a document** (= and
//  not the corpus half's order, = which would put every document the
//  index named behind the corpus half's own (= 19 to 41) documents,
//  = which is past the answer's limit). = The rule is one sentence
//  and it lives in `ReferenceRankFusion`.
//
//  **⇒ A FAILING INDEX IS NOT A FAILING ANSWER.** = The index half is
//  a bonus, = so an index that cannot answer (= Spotlight off, = slow,
//  = erroring) must not fail the search the corpus half can answer.
//  = The corpus answer is the answer; = the index half is added to it
//  when it works.
//
//

import Foundation

extension ReferenceLibraryActor {
    /// Answer one question over the library.
    ///
    /// - Parameters:
    ///   - query: The question.
    ///   - limit: How many documents to name at most.
    /// - Returns: The documents that hold the answer, = each with the
    ///   path of its body and the sentences that hold the answer.
    /// - Throws: When the library cannot be read. = **⇒ A LIBRARY THAT
    ///   COULD NOT BE READ IS NOT A LIBRARY WITH NO ANSWER.** = The
    ///   agent reads this reply as "the library holds nothing that
    ///   answers", = and it would go and write a document the library
    ///   already holds. = So the read failure is reported.
    func searchReferences(
        query: String,
        limit: Int = ReferenceCorpusSearch.defaultLimit
    ) async throws -> [ReferenceCorpusHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // The corpus (= the documents the library holds). = The store
        // is main-actor isolated, = so the METADATA is read here.
        //
        // **⇒ THE READ IS THE STRICT ONE.** = The strict read says a
        // layer it could not decode, = and the forgiving one says an
        // empty library. = For a question (= "what does the library
        // know about X?") = the second answer is a lie, = because the
        // library may hold the answer in a layer that failed to load.
        let references: [Reference]
        do {
            references = try loadCorpusReportingFailure()
        } catch {
            throw ReferenceLibraryError.from(error)
        }
        guard !references.isEmpty else { return [] }

        // The index half, = asked on its own task, = and its failure
        // dropped (= it is a bonus over the corpus half).
        let indexTask = Task.detached(priority: .userInitiated) { () -> [CSSearchResult] in
            (try? await CSSearchableIndexSearch.shared.search(query: trimmed, limit: limit)) ?? []
        }

        // The bodies, = off the main actor, = and the answer.
        let root = referenceLibraryRoot
        let indexHits = await indexTask.value
        return await Task.detached(priority: .userInitiated) { () -> [ReferenceCorpusHit] in
            ReferenceCorpusSearch.search(
                query: trimmed,
                references: references,
                bodyOf: { reference in
                    ReferenceBodyStore.readSource(
                        id: reference.id,
                        layer: reference.layer,
                        referenceLibraryRoot: root
                    )
                },
                indexHits: indexHits,
                limit: limit
            )
        }.value
    }
}
