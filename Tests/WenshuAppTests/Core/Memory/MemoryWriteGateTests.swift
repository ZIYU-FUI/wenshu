//
//  MemoryWriteGateTests.swift · Wenshu · v0.23 ticket 013.001 (hermes gap 1)
//
//  Boss 2026-08-23 拍: hermes _apply_write_gate parity.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("MemoryWriteGate (hermes _apply_write_gate parity)")
struct MemoryWriteGateTests {

    // MARK: - evaluateAdd

    @Test("evaluateAdd: empty content → block")
    func testAddEmptyBlocked() {
        if case .block = MemoryWriteGate.evaluateAdd(content: "") {
            // expected
        } else {
            Issue.record("expected .block for empty content")
        }
    }

    @Test("evaluateAdd: short content → allow")
    func testAddShortAllowed() {
        let decision = MemoryWriteGate.evaluateAdd(content: "主角是孤儿")
        #expect(decision == .allow)
    }

    @Test("evaluateAdd: > 500 chars content → stageForApproval")
    func testAddLongStagedForApproval() {
        let long = String(repeating: "x", count: 501)
        let decision = MemoryWriteGate.evaluateAdd(content: long)
        if case .stageForApproval = decision {
            // expected
        } else {
            Issue.record("expected .stageForApproval for 501-char content")
        }
    }

    @Test("evaluateAdd: exactly 500 chars → allow (boundary)")
    func testAddExactly500Allowed() {
        let exact500 = String(repeating: "x", count: 500)
        let decision = MemoryWriteGate.evaluateAdd(content: exact500)
        #expect(decision == .allow)
    }

    // MARK: - evaluateReplace

    @Test("evaluateReplace: empty oldText → block")
    func testReplaceEmptyOldTextBlocked() {
        if case .block = MemoryWriteGate.evaluateReplace(content: "new", oldText: "") {
            // expected
        } else {
            Issue.record("expected .block for empty oldText")
        }
    }

    @Test("evaluateReplace: minor change → allow")
    func testReplaceMinorChangeAllowed() {
        // Both start with same prefix, similar length — minor change.
        let decision = MemoryWriteGate.evaluateReplace(
            content: "主角是捕快出身的孤儿",
            oldText: "主角是捕快"
        )
        #expect(decision == .allow)
    }

    @Test("evaluateReplace: significant change → stageForApproval")
    func testReplaceSignificantChangeStaged() {
        // Different prefix → significant
        let decision = MemoryWriteGate.evaluateReplace(
            content: "完全不同内容",
            oldText: "主角是捕快"
        )
        if case .stageForApproval = decision {
            // expected
        } else {
            Issue.record("expected .stageForApproval for totally different content")
        }
    }

    // MARK: - evaluateRemove

    @Test("evaluateRemove: ALWAYS requires approval (destructive)")
    func testRemoveAlwaysRequiresApproval() {
        let decision = MemoryWriteGate.evaluateRemove()
        if case .stageForApproval = decision {
            // expected
        } else {
            Issue.record("expected .stageForApproval for remove")
        }
    }

    // MARK: - Decision equality

    @Test("MemoryWriteDecision: Equatable conformance")
    func testDecisionEquatable() {
        #expect(MemoryWriteDecision.allow == .allow)
        #expect(MemoryWriteDecision.block(reason: "x") == .block(reason: "x"))
        #expect(MemoryWriteDecision.block(reason: "x") != .block(reason: "y"))
        #expect(MemoryWriteDecision.stageForApproval == .stageForApproval)
    }
}