//
//  Features/Cover/Service/CoverBatchService.swift
//
//   : CoverBatchService.
//  Makes covers for many documents, one at a time.
//
//  The batch is a DELIBERATE act. The user has a library with
//  hundreds of documents and does not want to click each one, so they
//  start a run and stop it when they want.
//
//  Four rules:
//
//  - ONE document at a time, never a burst. A burst of twenty
//    parallel requests would burn the image allowance and hit rate
//    limits, and the user could not stop it.
//  - A document that already has a cover is SKIPPED, and a document
//    whose last attempt failed is RETRIED on the next run, so a
//    failure does not skip a document forever.
//  - The stop takes effect at the next DOCUMENT boundary, never
//    mid-generation: a half-made cover is worse than a slow stop.
//  - The batch makes NO VIDEOS. It covers documents with still
//    pictures only. The video allowance is a handful of clips a day
//    and only the user may spend it.
//
//  The service is @Observable, so the progress the runner writes is
//  a change the material zone can draw. A progress value nobody can
//  see is a progress value that does not exist.
//
//

import Foundation
import Observation
import SwiftData
import WenshuData
import os

private let coverBatchLogger = Logger(subsystem: "com.wenshu", category: "coverbatch")

/// A document in a batch run.
typealias CoverBatchItem = CoverCandidate

/// How far a batch run has got.
struct CoverBatchProgress: Equatable, Sendable {
    /// How many documents the run was given.
    var total: Int = 0
    /// How many have a cover now.
    var completed: Int = 0
    /// How many were skipped (= they already had a cover).
    var skipped: Int = 0
    /// How many failed.
    var failed: Int = 0
    /// Whether the user asked to stop.
    var isStopped: Bool = false
}

/// Makes covers for many documents, one at a time.
@MainActor
@Observable
final class CoverBatchService {

    /// The service that draws one cover.
    private let generationService: CoverGenerationService

    /// The cover store.
    private let coverService: CardCoverService

    /// Whether the user asked to stop.
    private var isStopped = false

    /// The progress, for the UI to show.
    private(set) var progress = CoverBatchProgress()

    init(generationService: CoverGenerationService? = nil) {
        self.coverService = CardCoverService()
        self.generationService = generationService ?? CoverGenerationService()
    }

    /// The service over the library the app is running on.
    static func live() -> CoverBatchService {
        CoverBatchService()
    }

    /// Asks the run to stop.
    ///
    /// The stop takes effect at the next DOCUMENT boundary, never
    /// mid-generation: a half-made cover is worse than a slow stop.
    func stop() {
        isStopped = true
        progress.isStopped = true
    }

    /// Cancels the run.
    ///
    /// This is the cancellation HANDLE: the runner does not outlive
    /// the work that asked for it. A batch whose owning view went
    /// away must not keep spending the image allowance, so the
    /// cancellation is checked BETWEEN documents, exactly like the
    /// manual stop.
    func cancel() {
        isStopped = true
        progress.isStopped = true
    }

    /// Runs the batch.
    ///
    /// The run stops when the user asks it to, and when the task
    /// running it is cancelled. A batch whose owning view went away
    /// must not keep spending the image allowance.
    ///
    /// - Parameter items: the documents to cover.
    func run(for items: [CoverBatchItem]) async {
        isStopped = false
        progress = CoverBatchProgress(total: items.count)

        for item in items {
            // The stop check is BETWEEN documents, so a generation
            // already under way is never cut off.
            if isStopped || Task.isCancelled { break }

            // A document that already has a cover is skipped, so the
            // run does not spend the allowance on work already done.
            //
            // A cover in the OLD shape is not skipped: the card is a
            // different shape now, and the old picture is trimmed by
            // it. The rule is self-limiting (= the new picture has the
            // new shape), so it costs one picture per document, once.
            if coverService.coverImageURL(for: item.target.coverKey) != nil,
               coverService.coverPictureIsCurrent(forKey: item.target.coverKey) {
                progress.skipped += 1
                continue
            }

            await generationService.generateCover(
                for: item.target,
                subject: item.subject
            )

            // The generation either stored a cover or it did not. A
            // failure leaves the document without one, so the NEXT
            // run tries it again.
            if coverService.coverImageURL(for: item.target.coverKey) != nil {
                progress.completed += 1
            } else {
                progress.failed += 1
            }
        }

        coverBatchLogger.info(
            "[wenshu.cover] batch finished completed=\(self.progress.completed) skipped=\(self.progress.skipped) failed=\(self.progress.failed)"
        )
    }
}
