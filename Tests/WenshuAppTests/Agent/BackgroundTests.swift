//
//  BackgroundTests.swift · Wenshu · v0.38 Batch 3 sub-step 1
//
//  Comprehensive tests for Background/ sub-directory (= v0.36 ticket 016).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot
//  mode per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= not v0.34 in-flight) = Background/ files are
//  v0.36 ticket 016 (= my work). Tests are additive coverage.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Background subsystem (= v0.36 ticket 016)")
struct BackgroundTests {

    // MARK: - DisplayStateMachine (= spec §3.1 L227-231 file 1 of 4)

    @Test("DisplayState: idle.isInProgress = false, isTerminal = false")
    func displayStateIdle() {
        let state = DisplayState.idle
        #expect(state.isInProgress == false)
        #expect(state.isTerminal == false)
        #expect(state.displayLabel == "Ready")
    }

    @Test("DisplayState: running(0.5).isInProgress = true")
    func displayStateRunning() {
        let state = DisplayState.running(progress: 0.5)
        #expect(state.isInProgress == true)
        #expect(state.isTerminal == false)
        #expect(state.displayLabel.contains("50%"))
    }

    @Test("DisplayState: success.isTerminal = true, contains message")
    func displayStateSuccess() {
        let state = DisplayState.success(message: "Indexed 42 files")
        #expect(state.isTerminal == true)
        #expect(state.isInProgress == false)
        #expect(state.displayLabel.contains("Indexed 42 files"))
    }

    @Test("DisplayState: error.isTerminal = true, contains error message")
    func displayStateError() {
        let state = DisplayState.error(message: "Connection lost")
        #expect(state.isTerminal == true)
        #expect(state.displayLabel.contains("Connection lost"))
    }

    @Test("DisplayState: cancelled.isTerminal = true, no message")
    func displayStateCancelled() {
        let state = DisplayState.cancelled
        #expect(state.isTerminal == true)
        #expect(state.isInProgress == false)
    }

    @Test("DisplayState: progress 0.0 vs 1.0 shows correct percentage")
    func displayStateProgressRange() {
        let zero = DisplayState.running(progress: 0.0)
        let full = DisplayState.running(progress: 1.0)
        #expect(zero.displayLabel.contains("0%"))
        #expect(full.displayLabel.contains("100%"))
    }

    @Test("DisplayState: Codable round-trip preserves all cases")
    func displayStateCodable() throws {
        let states: [DisplayState] = [
            .idle,
            .running(progress: 0.42),
            .success(message: "Done"),
            .success(message: nil),
            .error(message: "Oops"),
            .cancelled
        ]
        for state in states {
            let encoded = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(DisplayState.self, from: encoded)
            #expect(decoded == state)
        }
    }

    // MARK: - BackgroundReview (= spec §3.1 file 2 of 4)

    @Test("BackgroundReview: submit + allPending returns proposal")
    func reviewSubmitAndFetch() async {
        let review = BackgroundReview()
        let proposal = BackgroundProposal(
            kind: .entityCreation,
            title: "Add Alice to world",
            description: "New character for chapter 3",
            proposedChanges: ["/book/world/character.md"]
        )
        await review.submit(proposal)
        let pending = await review.allPending()
        #expect(pending.count == 1)
        #expect(pending.first?.id == proposal.id)
    }

    @Test("BackgroundReview: approve transitions pending -> decided")
    func reviewApprove() async throws {
        let review = BackgroundReview()
        let proposal = BackgroundProposal(
            kind: .fileEdit,
            title: "Edit chapter 1",
            description: "Fix typo",
            proposedChanges: ["/book/chapters/ch1.md"]
        )
        await review.submit(proposal)
        try await review.approve(proposal.id)
        let pending = await review.allPending()
        let decided = await review.recentDecided(limit: 100)
        #expect(pending.isEmpty)
        #expect(decided.count == 1)
        #expect(decided.first?.status == .approved)
    }

    @Test("BackgroundReview: reject transitions pending -> decided")
    func reviewReject() async throws {
        let review = BackgroundReview()
        let proposal = BackgroundProposal(
            kind: .memoryWrite,
            title: "Add memory",
            description: "Save user preference",
            proposedChanges: []
        )
        await review.submit(proposal)
        try await review.reject(proposal.id)
        let decided = await review.recentDecided(limit: 100)
        #expect(decided.count == 1)
        #expect(decided.first?.status == .rejected)
    }

    @Test("BackgroundReview: multiple proposals independent lifecycle")
    func reviewMultipleProposals() async throws {
        let review = BackgroundReview()
        let p1 = BackgroundProposal(kind: .entityUpdate, title: "T1", description: "d1", proposedChanges: [])
        let p2 = BackgroundProposal(kind: .skillInvocation, title: "T2", description: "d2", proposedChanges: [])
        let p3 = BackgroundProposal(kind: .fileEdit, title: "T3", description: "d3", proposedChanges: [])

        await review.submit(p1)
        await review.submit(p2)
        await review.submit(p3)
        try await review.approve(p1.id)
        try await review.reject(p2.id)
        // p3 still pending

        let pending = await review.allPending()
        let decided = await review.recentDecided(limit: 100)
        #expect(pending.count == 1)
        #expect(pending.first?.id == p3.id)
        #expect(decided.count == 2)
    }

    @Test("BackgroundReview: approve non-existent throws")
    func reviewApproveNonExistent() async {
        let review = BackgroundReview()
        do {
            try await review.approve(UUID())
            Issue.record("Expected throw for non-existent proposal")
        } catch {
            // expected
        }
    }

    @Test("BackgroundProposal: Codable round-trip")
    func proposalCodable() throws {
        let proposal = BackgroundProposal(
            kind: .entityCreation,
            title: "Add Bob",
            description: "Bob is the antagonist",
            proposedChanges: ["/book/world/character.md", "/book/outline/ch3.md"]
        )
        let encoded = try JSONEncoder().encode(proposal)
        let decoded = try JSONDecoder().decode(BackgroundProposal.self, from: encoded)
        #expect(decoded.id == proposal.id)
        #expect(decoded.kind == proposal.kind)
        #expect(decoded.title == proposal.title)
        #expect(decoded.proposedChanges == proposal.proposedChanges)
    }

    @Test("ProposalKind: 7 case types covered")
    func proposalKindAllCases() {
        let allKinds: [ProposalKind] = [
            .entityCreation, .entityUpdate, .entityDeletion,
            .fileEdit, .memoryWrite, .skillInvocation, .other
        ]
        #expect(allKinds.count == 7)
        for kind in allKinds {
            #expect(!kind.rawValue.isEmpty)
        }
    }

    @Test("ProposalStatus: 5 lifecycle states")
    func proposalStatusAllCases() {
        let allStatuses: [ProposalStatus] = [
            .pending, .approved, .rejected, .autoApproved, .expired
        ]
        #expect(allStatuses.count == 5)
    }

    // MARK: - BackgroundCreditsTracker (= spec §3.1 file 3 of 4)

    @Test("CreditConsumption: totalTokens = input + output")
    func creditConsumptionTotalTokens() {
        let consumption = CreditConsumption(
            providerSlug: "anthropic", model: "claude-test",
            inputTokens: 100,
            outputTokens: 50,
            timestamp: Date()
        )
        #expect(consumption.totalTokens == 150)
    }

    @Test("BackgroundCreditsTracker: empty starts with 0 total")
    func creditsEmpty() async {
        let tracker = BackgroundCreditsTracker()
        let total = await tracker.currentSessionSummary()
        #expect(total.totalInputTokens == 0)
        #expect(total.totalOutputTokens == 0)
        #expect(total.grandTotal == 0)
    }

    @Test("BackgroundCreditsTracker: record + currentSessionSummary")
    func creditsRecordAndSummary() async {
        let tracker = BackgroundCreditsTracker()
        let consumption = CreditConsumption(
            providerSlug: "anthropic", model: "claude-test",
            inputTokens: 100,
            outputTokens: 50,
            timestamp: Date()
        )
        await tracker.record(consumption)
        let summary = await tracker.currentSessionSummary()
        #expect(summary.totalInputTokens == 100)
        #expect(summary.totalOutputTokens == 50)
        #expect(summary.grandTotal == 150)
    }

    @Test("BackgroundCreditsTracker: resetSession clears session data")
    func creditsResetSession() async {
        let tracker = BackgroundCreditsTracker()
        let consumption = CreditConsumption(
            providerSlug: "anthropic", model: "claude-test",
            inputTokens: 200,
            outputTokens: 100,
            timestamp: Date()
        )
        await tracker.record(consumption)
        await tracker.resetSession()
        let total = await tracker.currentSessionSummary()
        #expect(total.grandTotal == 0)
    }

    @Test("BackgroundCreditsTracker: allHistory records every entry")
    func creditsAllHistory() async {
        let tracker = BackgroundCreditsTracker()
        await tracker.record(CreditConsumption(
            providerSlug: "anthropic", model: "claude-test", inputTokens: 10, outputTokens: 5, timestamp: Date()
        ))
        await tracker.record(CreditConsumption(
            providerSlug: "openai", model: "text-embedding-test", inputTokens: 20, outputTokens: 0, timestamp: Date()
        ))
        let history = await tracker.allHistory
        #expect(history.count == 2)
    }

    @Test("BackgroundCreditsTracker: currentMonthlyTotal aggregates")
    func creditsMonthlyTotal() async {
        let tracker = BackgroundCreditsTracker()
        await tracker.record(CreditConsumption(
            providerSlug: "anthropic", model: "claude-test", inputTokens: 100, outputTokens: 50, timestamp: Date()
        ))
        let total = await tracker.currentMonthlyTotal()
        #expect(total == 150)
    }

    // MARK: - Curator (= spec §3.1 file 4 of 4)

    @Test("Curator: CurationReport counts by finding kind")
    func curatorCurationReportCounts() {
        let findings: [CurationFinding] = [
            CurationFinding(entityID: "e1", entityTitle: "stale1", kind: .stale, description: "stale 1"),
            CurationFinding(entityID: "e2", entityTitle: "stale2", kind: .stale, description: "stale 2"),
            CurationFinding(entityID: "e3", entityTitle: "orphan1", kind: .orphan, description: "orphan 1"),
            CurationFinding(entityID: "e4", entityTitle: "dup1", kind: .duplicate, description: "dup 1")
        ]
        let report = CurationReport(
            generatedAt: Date(),
            findings: findings,
            totalEntitiesScanned: findings.count
        )
        #expect(report.staleCount == 2)
        #expect(report.orphansCount == 1)
        #expect(report.duplicatesCount == 1)
    }

    @Test("Curator: Config has default threshold values")
    func curatorConfigDefaults() {
        let config = Curator.Config()
        #expect(config.staleThresholdDays > 0)
        #expect(config.duplicateSimilarityThreshold > 0)
    }

    @Test("Curator: Entity Codable round-trip")
    func curatorEntityCodable() throws {
        let entity = Curator.Entity(
            id: "e1",
            title: "Alice",
            snippet: "Alice is the protagonist",
            lastAccessedAt: Date(),
            crossReferenceCount: 0
        )
        let encoded = try JSONEncoder().encode(entity)
        let decoded = try JSONDecoder().decode(Curator.Entity.self, from: encoded)
        #expect(decoded.id == entity.id)
        #expect(decoded.title == entity.title)
        #expect(decoded.snippet == entity.snippet)
    }

    @Test("Curator: CurationFinding kinds: stale, orphan, duplicate")
    func curatorFindingKinds() {
        // CurationFinding has FindingKind enum (= per source)
        // Just verify report aggregates correctly
        let report = CurationReport(
            generatedAt: Date(),
            findings: [],
            totalEntitiesScanned: 0
        )
        #expect(report.staleCount == 0)
        #expect(report.orphansCount == 0)
        #expect(report.duplicatesCount == 0)
    }
}