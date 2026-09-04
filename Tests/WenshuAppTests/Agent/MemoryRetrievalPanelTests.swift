//
//  MemoryRetrievalPanelTests.swift · Wenshu · v0.35 ticket 009
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("MemoryRetrievalPanel (ticket 009)")
struct MemoryRetrievalPanelTests {

    @Test("MemoryRetrievalPanel renders without crashing (smoke test)")
    func testViewRenders() {
        let view = MemoryRetrievalPanel()
        _ = view.body
    }

    @Test("Default entries is empty")
    func testDefaultEmpty() {
        let view = MemoryRetrievalPanel()
        #expect(view.entries.isEmpty)
    }

    @Test("Custom entries accepted")
    func testCustomEntries() {
        let entry = MemoryAdapter.MemoryEntry(
            id: "m1",
            source: "/book/world.md",
            snippet: "Magic is forbidden",
            relevanceScore: 0.92
        )
        let view = MemoryRetrievalPanel(entries: [entry])
        #expect(view.entries.count == 1)
        #expect(view.entries[0].source == "/book/world.md")
    }
}