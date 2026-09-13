//
//  MemoryAdapterTests.swift · Wenshu · v0.35 ticket 009
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("MemoryAdapter (ticket 009)")
struct MemoryAdapterTests {

    @Test("retrieve returns empty list in sub-step 1 stub")
    @MainActor
    func testRetrieveStub() async {
        let adapter = MemoryAdapter()
        let entries = adapter.retrieve(forUserMessage: "test")
        #expect(entries.isEmpty)
    }

    @Test("write is a no-op in sub-step 1 stub")
    @MainActor
    func testWriteStub() async {
        let adapter = MemoryAdapter()
        adapter.write(snippet: "test", source: "/test.md")
        // No assertion (= smoke test only)
    }
}