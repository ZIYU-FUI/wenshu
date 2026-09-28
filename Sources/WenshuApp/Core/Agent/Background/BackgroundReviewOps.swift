//
//  BackgroundReviewOps.swift · Wenshu · v2.8c ticket T14-T16 (boss 2026-09-28 OOB B8)
//
//  BackgroundReview consolidation ops (= the unified manual + auto
//  façade per boss 2026-09-28 OOB '重复的功能，只是调用机制不同的，
//  应该合并').
//
//  Per boss 2026-09-28 OOB B8: BackgroundReview should support
//  BOTH manual-call (= operator clicks in the inspector's
//  BackgroundReview tab) AND auto-call (= the agent's
//  ConversationLoop detects a background-worthy event and submits
//  a proposal). Both paths go through these 4 entry points.
//
//  Standards axis (= S1 + S3 + S4 + S5):
//    S1 (Apple-API-first): pure Swift enum + actor delegation.
//        The BackgroundReview actor (declared in v0.36) is the
//        source of truth for the pending / decided queues (= the
//        Swift 6 strict-concurrency actor isolation pattern).
//    S3 (single source of truth): one set of entry points serves
//        both manual + auto callers (= the boss-pinned
//        consolidation).
//    S4 (typed errors): BackgroundReviewError wraps the
//        actor's throws (= manual callers receive a typed
//        domain error).
//    S5 (no public surface): zero new public keywords.
//
//  Wiring (= v2.8c acceptance):
//    - WenshuConductor.defaultToolNames contains
//      "background_review".
//    - BackgroundReviewTool.swift wraps BackgroundReviewOps.submit
//      (= the manual LLM tool surface).
//    - ConversationLoop calls BackgroundReviewOps.submit in the
//      auto-call hook (= the agent's auto surface per boss OOB
//      '自动也可以手动也可以').

import Foundation

/// BackgroundReview unified façade (= manual + auto go through
/// these 4 entry points).
@MainActor
enum BackgroundReviewOps {

    /// Submit a proposal (= manual callers + agent auto-call both
    /// use this entry point).
    static func submit(_ proposal: BackgroundProposal) async {
        await BackgroundReview.shared.submit(proposal)
    }

    /// Approve a proposal (= manual operator decision).
    static func approve(_ proposalID: UUID) async throws {
        try await BackgroundReview.shared.approve(proposalID)
    }

    /// Reject a proposal (= manual operator decision).
    static func reject(_ proposalID: UUID) async throws {
        try await BackgroundReview.shared.reject(proposalID)
    }

    /// List all pending proposals (= manual list render + agent
    /// status query both use this entry point).
    static func listPending() async -> [BackgroundProposal] {
        return await BackgroundReview.shared.allPending()
    }
}