//
//  KanbanRoleTests.swift · Wenshu · v0.23 ticket 013.006 (hermes gap 6)
//
//  Boss 2026-08-23 拍: hermes _require_orchestrator_tool parity.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("KanbanRole (hermes orchestrator/worker parity)")
struct KanbanRoleTests {

    // MARK: - KanbanRole capabilities

    @Test("orchestrator can create (hermes _require_orchestrator_tool allow)")
    func testOrchestratorCanCreate() {
        let role = KanbanRole.orchestrator
        #expect(role.canCreate == true)
    }

    @Test("worker cannot create (hermes _require_orchestrator_tool block)")
    func testWorkerCannotCreate() {
        let role = KanbanRole.worker(taskId: "abc-123")
        #expect(role.canCreate == false)
    }

    @Test("orchestrator can requestReview")
    func testOrchestratorCanRequestReview() {
        #expect(KanbanRole.orchestrator.canRequestReview == true)
    }

    @Test("worker cannot requestReview")
    func testWorkerCannotRequestReview() {
        #expect(KanbanRole.worker(taskId: "x").canRequestReview == false)
    }

    @Test("orchestrator can delete")
    func testOrchestratorCanDelete() {
        #expect(KanbanRole.orchestrator.canDelete == true)
    }

    @Test("worker cannot delete")
    func testWorkerCannotDelete() {
        #expect(KanbanRole.worker(taskId: "x").canDelete == false)
    }

    @Test("orchestrator can transition any task")
    func testOrchestratorCanTransition() {
        #expect(KanbanRole.orchestrator.canTransitionOwnedTask == true)
    }

    @Test("worker can transition their own task (kanban_complete / kanban_block)")
    func testWorkerCanTransitionOwnTask() {
        #expect(KanbanRole.worker(taskId: "abc").canTransitionOwnedTask == true)
    }

    // MARK: - KanbanRoleGuard checkPermission

    @Test("orchestrator can create (guard passes)")
    func testGuardOrchestratorCreate() {
        let result = KanbanRoleGuard.checkPermission(role: .orchestrator, op: .create)
        #expect(result == nil)
    }

    @Test("worker cannot create (guard blocks)")
    func testGuardWorkerCreateBlocked() {
        let result = KanbanRoleGuard.checkPermission(role: .worker(taskId: "x"), op: .create)
        #expect(result != nil)
        #expect(result?.contains("orchestrator-only") == true)
    }

    @Test("worker cannot delete (guard blocks)")
    func testGuardWorkerDeleteBlocked() {
        let result = KanbanRoleGuard.checkPermission(role: .worker(taskId: "x"), op: .delete)
        #expect(result != nil)
        #expect(result?.contains("orchestrator-only") == true)
    }

    @Test("worker cannot requestReview (guard blocks)")
    func testGuardWorkerRequestReviewBlocked() {
        let result = KanbanRoleGuard.checkPermission(role: .worker(taskId: "x"), op: .requestReview)
        #expect(result != nil)
    }

    @Test("worker can transition own task (guard passes)")
    func testGuardWorkerTransitionPasses() {
        let result = KanbanRoleGuard.checkPermission(role: .worker(taskId: "x"), op: .transitionOwned)
        #expect(result == nil)
    }

    // MARK: - Display name

    @Test("displayName: orchestrator")
    func testDisplayOrchestrator() {
        #expect(KanbanRole.orchestrator.displayName == "orchestrator")
    }

    @Test("displayName: worker with taskId prefix")
    func testDisplayWorker() {
        let role = KanbanRole.worker(taskId: "abcdefgh-1234")
        #expect(role.displayName == "worker(abcdefgh)")
    }

    // MARK: - Equatable

    @Test("KanbanRole Equatable")
    func testEquatable() {
        #expect(KanbanRole.orchestrator == .orchestrator)
        #expect(KanbanRole.worker(taskId: "x") == KanbanRole.worker(taskId: "x"))
        #expect(KanbanRole.worker(taskId: "x") != KanbanRole.worker(taskId: "y"))
        #expect(KanbanRole.orchestrator != KanbanRole.worker(taskId: "z"))
    }
}