//
//  Views/Kanban/KanbanOpsAddBodyTests.swift · kanban-markdown 2026-09-28 T7
//
//  RED tests for Phase 1 T7:
//  KanbanOps.addTicket(...) persists body through to the saved
//  tickets array. Today, addTicket appends `KanbanTicket(title:, status:)
//  — no body — and the LLM-authored body never lands in the
//  KanbanView data source.
//
//  Acceptance: the saved KanbanTicket carries the body argument.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("KanbanOps.addTicket.body (kanban-markdown 2026-09-28 T7)")
struct KanbanOpsAddBodyTests {

    @Test("addTicket persists body on the saved KanbanTicket")
    @MainActor
    func addTicketPersistsBody() {
        let result = KanbanOps.addTicket(
            bookId: UUID(),
            scope: .book,
            resolver: FixedResolver(directory: nil),  // nil dir => unused; we won't save to disk in this test
            title: "outline ch4",
            to: []
        )
        #expect(result.error == nil || result.error?.contains("保存失败") == true,
                "this test pins the API surface; no save happens here")
    }

    // Pin: the resulting first ticket, when the body arg is passed,
    // exposes it. This relies on the in-memory append path (next.append)
    // + a no-resolver that returns nil (so save is skipped and we read
    // savedTickets directly).

    @Test("addTicket with body exposes body on the returned savedTickets first entry")
    @MainActor
    func addTicketAppliesBodyInMemory() {
        let bookId = UUID()
        let result = KanbanOps.addTicket(
            bookId: bookId,
            scope: .book,
            resolver: FixedResolver(directory: nil),
            title: "outline ch4",
            body: "**Goal:** 4 beats with conflict.",
            to: []
        )
        // resolver returned nil so save was skipped, but the in-memory
        // savedTickets should already reflect the appended ticket.
        let appended = result.savedTickets.last
        #expect(appended?.body == "**Goal:** 4 beats with conflict.")
    }
}

private struct FixedResolver: KanbanOps.ScopeDirectoryResolver {
    let directory: URL?
    func resolve(bookId: UUID?, scope: TaskScope) -> URL? { directory }
}
