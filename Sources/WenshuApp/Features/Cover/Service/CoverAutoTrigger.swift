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
//  The trigger never makes a VIDEO. The video allowance is a handful
//  of clips a day, and only the user may spend it.
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
    private let policyStore: CoverAutoCoverStore

    init(
        modelContext: ModelContext,
        generationService: CoverGenerationService? = nil,
        policyStore: CoverAutoCoverStore = CoverAutoCoverStore()
    ) {
        self.coverService = CardCoverService(modelContext: modelContext)
        self.generationService = generationService ?? CoverGenerationService(modelContext: modelContext)
        self.policyStore = policyStore
    }

    /// The service over the library the app is running on.
    static func live() -> CoverAutoTrigger {
        CoverAutoTrigger(modelContext: WSPersistenceContainer.current.mainContext)
    }

    /// The stored policy.
    var policy: CoverAutoCoverPolicy {
        policyStore.policy
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

        coverAutoTriggerLogger.info(
            "[wenshu.cover] automatic cover for kind=\(target.kind, privacy: .public)"
        )
        await generationService.generateCover(for: target, subject: subject)
        return true
    }
}
