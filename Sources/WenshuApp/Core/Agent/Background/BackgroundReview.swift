//
//  BackgroundReview.swift · Wenshu · v0.36 ticket 016 sub-step 3
//
//  Background review workflow (= spec §3.1 L227-231 Background/
//  sub-directory, file 2 of 4).
//
//  When a background task proposes changes (= entity creation, file
//  edits, etc.), the user reviews the diff and approves or rejects.
//  BackgroundReview captures the proposal lifecycle (= pending →
//  approved / rejected / auto-approved) and ensures no background
//  modification happens without user consent.
//
//  Per wenshu §11 product-positioning: wenshu is a writing tool, NOT
//  an LLM platform. Background review is purely for the user's
//  own visibility (= what changes their LLM-driven agents proposed).
//
//  Per ADR-0011 + §11 hard rule: pure Swift, no LLM calls.
//
//  v0.36 sub-step 3 of 4 for ticket 016.
//

import Foundation

/// Type of background proposal (= what kind of change is being proposed).
public enum ProposalKind: String, Sendable, Equatable, Codable {
    case entityCreation       // create new reference-library entity
    case entityUpdate         // modify existing entity
    case entityDeletion       // remove entity
    case fileEdit             // edit a .md file
    case memoryWrite          // add to memory subsystem
    case skillInvocation      // invoke a skill (= already gated by other guardrails)
    case other
}

/// Status of a background proposal (= where it is in the approval lifecycle).
public enum ProposalStatus: String, Sendable, Equatable, Codable {
    case pending
    case approved
    case rejected
    case autoApproved         // = trust level builtin or pre-approved by user
    case expired              // = proposal aged out without action
}

/// A single background proposal (= candidate change awaiting review).
public struct BackgroundProposal: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public let kind: ProposalKind
    public let title: String
    public let description: String
    public let proposedChanges: [String]  // = list of file paths / entity refs
    public let submittedAt: Date
    public var status: ProposalStatus
    public var decidedAt: Date?

    public init(
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
public actor BackgroundReview {

    private var pending: [UUID: BackgroundProposal] = [:]
    private var decided: [BackgroundProposal] = []
    private let maxPendingAge: TimeInterval = 7 * 24 * 3600  // 7 days
    private let maxDecidedHistory: Int = 100

    public init() {}

    /// Submit a new proposal (= background task calls this when it
    /// wants to make a change the user should review).
    public func submit(_ proposal: BackgroundProposal) {
        pending[proposal.id] = proposal
    }

    /// Get all pending proposals (= UI calls this to show the review list).
    public func allPending() -> [BackgroundProposal] {
        return Array(pending.values).sorted { $0.submittedAt < $1.submittedAt }
    }

    /// Get recent decided history (= UI shows last N decisions).
    public func recentDecided(limit: Int = 50) -> [BackgroundProposal] {
        return Array(decided.suffix(limit)).sorted { $0.decidedAt ?? Date.distantPast > $1.decidedAt ?? Date.distantPast }
    }

    /// Approve a proposal (= user clicked Approve in UI).
    public func approve(_ proposalID: UUID) throws {
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
    public func reject(_ proposalID: UUID) throws {
        guard var proposal = pending[proposalID] else {
            throw BackgroundReviewError.proposalNotFound(id: proposalID)
        }
        proposal.status = .rejected
        proposal.decidedAt = Date()
        decided.append(proposal)
        pending.removeValue(forKey: proposalID)
        trimDecidedHistory()
    }

    /// Expire old pending proposals (= called periodically).
    public func expireOldProposals() -> Int {
        let now = Date()
        let cutoff = now.addingTimeInterval(-maxPendingAge)
        var expired = 0
        for (id, var proposal) in pending {
            if proposal.submittedAt < cutoff {
                proposal.status = .expired
                proposal.decidedAt = now
                decided.append(proposal)
                pending.removeValue(forKey: id)
                expired += 1
            }
        }
        return expired
    }

    /// Trim decided history to maxDecidedHistory (= prevents unbounded growth).
    private func trimDecidedHistory() {
        if decided.count > maxDecidedHistory {
            decided.removeFirst(decided.count - maxDecidedHistory)
        }
    }

    /// Pending count (= for UI badge).
    public var pendingCount: Int {
        return pending.count
    }
}

public enum BackgroundReviewError: Error, LocalizedError {
    case proposalNotFound(id: UUID)

    public var errorDescription: String? {
        switch self {
            case .proposalNotFound(let id):
                return "BackgroundProposal \(id) not found (= may have been decided already)"
        }
    }
}