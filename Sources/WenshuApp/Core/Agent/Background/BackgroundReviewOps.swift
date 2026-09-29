// BackgroundReviewOps.swift · WenshuApp · v2.8c
//
// Consolidation ops for `BackgroundReview`. Unifies the manual +
// auto caller paths into a single façade:
//
// - manual = the operator clicks in the inspector's
//   BackgroundReview tab.
// - auto  = the agent's `ConversationLoop` detects a
//   background-worthy event and submits a proposal.
//
// Both paths go through the 4 entry points below.
//
// Standards axis:
//   S1 (Apple-API-first): pure Swift enum + actor delegation.
//       `BackgroundReview` actor (= declared in v0.36) is the
//       source of truth for the pending / decided queues (= the
//       Swift 6 strict-concurrency actor isolation pattern).
//   S3 (single source of truth): one set of entry points serves
//       both manual + auto callers.
//   S4 (typed errors): `BackgroundReviewError` wraps the actor's
//       throws (= manual callers receive a typed domain error).
//   S5 (no public surface): zero new public keywords.
//
// Wiring (v2.8c acceptance):
//   - `WenshuConductor.defaultToolNames` contains
//     "background_review".
//   - `BackgroundReviewTool.swift` wraps `BackgroundReviewOps.submit`
//     (= the manual LLM tool surface).
//   - `ConversationLoop` calls `BackgroundReviewOps.submit` in the
//     auto-call hook (= the agent's auto surface).

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