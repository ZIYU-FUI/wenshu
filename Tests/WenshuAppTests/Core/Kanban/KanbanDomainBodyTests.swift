//
//  Core/Kanban/KanbanDomainBodyTests.swift · Wenshu · kanban-markdown 2026-09-28
//
//  RED tests for Phase 1 T2:
//  KanbanTask domain struct grows a body: String? field that
//  mirrors WSKanbanTask.body (= the persistence column added
//  in T1). Without it, domain mapping in WSKanbanRepository
//  cannot pass through body and the LLM's body arg drops on
//  the floor.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("KanbanTask.body (kanban-markdown 2026-09-28 T2)")
struct KanbanDomainBodyTests {

    @Test("KanbanTask init accepts body: String?")
    func initAcceptsBody() {
        let task = KanbanTask(
            title: "Summarize chapter 3",
            body: "**Goal:** extract 3 themes."
        )
        #expect(task.body == "**Goal:** extract 3 themes.")
    }

    @Test("KanbanTask body defaults to nil")
    func bodyDefaultsToNil() {
        let task = KanbanTask(title: "no body here")
        #expect(task.body == nil)
    }

    @Test("KanbanTask equality considers body")
    func equalityIncludesBody() {
        let a = KanbanTask(title: "t", body: "x")
        let b = KanbanTask(title: "t", body: "x")
        let c = KanbanTask(title: "t", body: "y")
        #expect(a == b)
        #expect(a != c)
    }
}
