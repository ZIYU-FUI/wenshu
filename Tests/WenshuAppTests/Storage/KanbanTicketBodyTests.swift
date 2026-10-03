//
//  Storage/KanbanTicketBodyTests.swift · kanban-markdown 2026-09-28 T6
//
//  KanbanCard actually renders). The SwiftData side (T1-T4)
//  carries body end-to-end now; KanbanView.swift reads from
//  `BookKanbanStore` (JSON file) so it sees `KanbanTicket` —
//  this test pins body on that JSON-side struct.
//
//  Without body, KanbanCard has no way to render agent-written
//  markdown — adding it here bridges the SwiftData path to the UI.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("KanbanTicket.body (kanban-markdown 2026-09-28 T6)")
struct KanbanTicketBodyTests {

    @Test("KanbanTicket init accepts body: String?")
    func initAcceptsBody() {
        let t = KanbanTicket(title: "x", status: .new, body: "**Goal:** ...")
        #expect(t.body == "**Goal:** ...")
    }

    @Test("KanbanTicket body defaults to nil")
    func bodyDefaultsToNil() {
        let t = KanbanTicket(title: "x")
        #expect(t.body == nil)
    }
}
