// BackgroundReview.swift
//
// Background review workflow. When a background task proposes
// changes (= entity creation, file edits, etc.), the user reviews
// the diff and approves or rejects. BackgroundReview captures the
// proposal lifecycle (= pending → approved / rejected /
// auto-approved) and ensures no background modification happens
// without user consent.
//
// Per wenshu §11 product-positioning: wenshu is a writing tool, NOT
// an LLM platform. Background review is purely for the user's
// own visibility (= what changes their LLM-driven agents proposed).
//
// ADR-0011 + §11 hard rule: pure Swift, no LLM calls.

import Foundation

/// Type of background proposal (= what kind of change is being proposed).
enum ProposalKind: String, Sendable, Equatable, Codable {
    // v2.8c (B8): auto-call hook = ConversationLoop submits a
    // .turnSummary proposal per turn (= the operator reviews the
    // turn in the inspector's BackgroundReview tab).
    case turnSummary        // auto-call hook: agent submits turn summary
    case entityCreation       // create new reference-library entity
    case entityUpdate         // modify existing entity
    case entityDeletion       // remove entity
    case fileEdit             // edit a .md file
    case memoryWrite          // add to memory subsystem
    case skillInvocation      // invoke a skill (= already gated by other guardrails)
    case other
}

/// Status of a background proposal (= where it is in the approval lifecycle).
enum ProposalStatus: String, Sendable, Equatable, Codable {
    case pending
    case approved
    case rejected
    case autoApproved         // = trust level builtin or pre-approved by user
    case expired              // = proposal aged out without action
}

/// A single background proposal (= candidate change awaiting review).
struct BackgroundProposal: Sendable, Equatable, Codable, Identifiable {
    let id: UUID
    let kind: ProposalKind
    let title: String
    let description: String
    let proposedChanges: [String]  // = list of file paths / entity refs
    let submittedAt: Date
    var status: ProposalStatus
    var decidedAt: Date?

    init(
        id: UUID = UUID(),
        kind: ProposalKind,
        title: String,
        description: String,
        proposedChanges: [String],
        submittedAt: Date = Date(),
        status: ProposalStatus = .pending
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.description = description
        self.proposedChanges = proposedChanges
        self.submittedAt = submittedAt
        self.status = status
        self.decidedAt = nil
    }
}

/// BackgroundReview actor (= thread-safe pending proposal queue).
/// Per ADR-0009 (= wenshu-side wins, no duplicate approval engine;
/// delegates to existing wenshu approval flow via Notification).
actor BackgroundReview {

    /// v2.8c (B8): canonical shared instance (= the consolidation
    /// surface for both manual + auto callers via
    /// `BackgroundReviewOps`).
    static let shared = BackgroundReview()

    private var pending: [UUID: BackgroundProposal] = [:]
    private var decided: [BackgroundProposal] = []
    // (maxPendingAge removed 2026-10 in q99-spec-p0-batch2 — verify-dead.py
    //  confirmed 0 external callers; = the actor-private 7-day TTL
    //  for pending proposals was retained as the "auto-expire stale
    //  proposals" affordance (= hermes-port background_review._expire_stale)
    //  but the trim path only runs against decided history (= see
    //  trimDecidedHistory + maxDecidedHistory below); = the TTL
    //  constant was declared but never wired into a Timer/Task that
    //  would call submit(.expired) on aged entries. See
    //  wenshu-pocock-workflow references/v3.0-design-system-rule.md
    //  + wenshu-dead-code-cleanup SKILL.md.)
    private let maxDecidedHistory: Int = 100

    init() {}

    /// Submit a new proposal (= background task calls this when it
    /// wants to make a change the user should review).
    func submit(_ proposal: BackgroundProposal) {
        pending[proposal.id] = proposal
    }

    /// Get all pending proposals (= UI calls this to show the review list).
    func allPending() -> [BackgroundProposal] {
        return Array(pending.values).sorted { $0.submittedAt < $1.submittedAt }
    }

    /// Get recent decided history (= UI shows last N decisions).
    func recentDecided(limit: Int = 50) -> [BackgroundProposal] {
        return Array(decided.suffix(limit)).sorted { $0.decidedAt ?? Date.distantPast > $1.decidedAt ?? Date.distantPast }
    }

    /// Approve a proposal (= user clicked Approve in UI).
    func approve(_ proposalID: UUID) throws {
        guard var proposal = pending[proposalID] else {
            throw BackgroundReviewError.proposalNotFound(id: proposalID)
        }
        proposal.status = .approved
        proposal.decidedAt = Date()
        decided.append(proposal)
        pending.removeValue(forKey: proposalID)
        trimDecidedHistory()
    }

    /// Reject a proposal (= user clicked Reject in UI).
    func reject(_ proposalID: UUID) throws {
        guard var proposal = pending[proposalID] else {
            throw BackgroundReviewError.proposalNotFound(id: proposalID)
        }
        proposal.status = .rejected
        proposal.decidedAt = Date()
        decided.append(proposal)
        pending.removeValue(forKey: proposalID)
        trimDecidedHistory()
    }
    /// Trim decided history to maxDecidedHistory (= prevents unbounded growth).
    private func trimDecidedHistory() {
        if decided.count > maxDecidedHistory {
            decided.removeFirst(decided.count - maxDecidedHistory)
        }
    }

    /// Pending count (= for UI badge).
    var pendingCount: Int {
        return pending.count
    }
}

enum BackgroundReviewError: Error, LocalizedError {
    case proposalNotFound(id: UUID)

    var errorDescription: String? {
        switch self {
            case .proposalNotFound(let id):
                return "BackgroundProposal \(id) not found (= may have been decided already)"
        }
    }
}
