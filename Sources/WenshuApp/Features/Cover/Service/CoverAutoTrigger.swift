//
//  Features/Cover/Service/CoverAutoTrigger.swift
//
//   : CoverAutoTrigger.
//  Gives a newly-arrived document its cover, without the user asking.
//
//  This is the INCREMENTAL half of the user's rule. The documents
//  that are already in the library get their covers from a batch the
//  user starts; the documents that arrive afterwards get theirs here.
//
//  The trigger asks the POLICY whether the document needs a cover, and
//  obeys the answer. The policy is what knows the difference between
//  "already there" and "comes later", so the trigger does not have to
//  know anything about time.
//
//  Two rules keep the allowance safe:
//
//  - The trigger fires ONCE per document. The generation service's
//    per-card lock covers the CONCURRENT case (two callers at once),
//    and the attempted set covers the SEQUENTIAL one (the document is
//    offered again on the next reload). Without the second rule, a
//    document whose generation FAILED would be offered again on every
//    reload, and each failure would spend another image call.
//  - The trigger never makes a VIDEO. The video allowance is a handful
//    of clips a day, and only the user may spend it.
//
//

import Foundation
import SwiftData
import WenshuData
import os

private let coverAutoTriggerLogger = Logger(subsystem: "com.wenshu", category: "coverautotrigger")

/// Gives a newly-arrived document its cover.
@MainActor
final class CoverAutoTrigger {

    /// The service that draws one cover.
    private let generationService: CoverGenerationService

    /// The cover store.
    private let coverService: CardCoverService

    /// Where the policy lives.
    ///
    /// A closure rather than the store itself, so a test can hand
    /// the trigger a policy without touching the user's defaults.
    private let policyProvider: () -> CoverAutoCoverPolicy

    /// The documents the trigger has already offered.
    ///
    /// The per-card lock in the generation service covers two callers
    /// at the SAME moment. This covers the other case: the document is
    /// offered again later, because the material zone reloads and
    /// offers what it sees.
    private var attemptedKeys: Set<String> = []

    init(
        modelContext: ModelContext,
        generationService: CoverGenerationService? = nil,
        policyProvider: @escaping () -> CoverAutoCoverPolicy = { CoverAutoCoverStore().policy }
    ) {
        self.coverService = CardCoverService(modelContext: modelContext)
        self.generationService = generationService ?? CoverGenerationService(modelContext: modelContext)
        self.policyProvider = policyProvider
    }

    /// The service over the library the app is running on.
    static func live() -> CoverAutoTrigger {
        CoverAutoTrigger(modelContext: WSPersistenceContainer.current.mainContext)
    }

    /// The stored policy.
    var policy: CoverAutoCoverPolicy {
        policyProvider()
    }

    /// Gives a document its cover, if the policy says it should have
    /// one.
    ///
    /// - Parameters:
    ///   - target: the card.
    ///   - subject: what the picture should show.
    ///   - createdAt: when the document was created.
    /// - Returns: whether a generation was started.
    @discardableResult
    func coverIfNeeded(
        for target: CardCoverTarget,
        subject: String,
        createdAt: Date,
        now: Date = .now
    ) async -> Bool {
        let hasCover = coverService.row(forKey: target.coverKey) != nil
        guard policy.shouldGenerateCover(
            createdAt: createdAt,
            hasCover: hasCover,
            kind: target.kind,
            now: now
        ) else {
            return false
        }

        // The document is offered once. The lock covers the
        // concurrent case; this covers the later one.
        guard attemptedKeys.insert(target.coverKey).inserted else {
            return false
        }

        coverAutoTriggerLogger.info(
            "[wenshu.cover] automatic cover for kind=\(target.kind, privacy: .public)"
        )
        await generationService.generateCover(for: target, subject: subject)
        return true
    }

    /// Gives every candidate that the policy approves a cover.
    ///
    /// The candidates are the documents the material zone can see.
    /// The policy decides which of them are automatic: a document
    /// created BEFORE the switch was turned on belongs to the batch,
    /// not here.
    ///
    /// - Parameters:
    ///   - candidates: the documents to consider.
    ///   - now: the current time, passed in so the decision is pure.
    /// - Returns: how many generations were started.
    @discardableResult
    func coverNewDocuments(
        _ candidates: [CoverCandidate],
        now: Date = .now
    ) async -> Int {
        var started = 0
        for candidate in candidates {
            let didStart = await coverIfNeeded(
                for: candidate.target,
                subject: candidate.subject,
                createdAt: candidate.createdAt,
                now: now
            )
            if didStart { started += 1 }
        }
        return started
    }

    /// Whether the trigger already offered this document.
    func hasAttempted(_ target: CardCoverTarget) -> Bool {
        attemptedKeys.contains(target.coverKey)
    }
}
