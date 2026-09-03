//
//  DynamicZoneMemoryPanelTests.swift · Wenshu · v0.35 (act-3-fix)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("DynamicZoneMemoryPanel (act-3-fix)")
struct DynamicZoneMemoryPanelTests {

    @Test("DynamicZoneMemoryPanel renders without crashing")
    func testViewRenders() {
        let view = DynamicZoneMemoryPanel()
        _ = view.body
    }

    @Test("Default entries is empty")
    func testDefaultEmpty() {
        let view = DynamicZoneMemoryPanel()
        #expect(view.entries.isEmpty)
    }

    @Test("Panel height customizable")
    func testPanelHeight() {
        let view = DynamicZoneMemoryPanel(panelHeight: 250)
        #expect(view.panelHeight == 250)
    }

    @Test("Custom entries displayed")
    func testCustomEntries() {
        let entry = MemoryAdapter.MemoryEntry(
            id: "m1",
            source: "/book/world.md",
            snippet: "Magic is forbidden in the southern kingdom",
            relevanceScore: 0.92
        )
        let view = DynamicZoneMemoryPanel(entries: [entry])
        #expect(view.entries.count == 1)
    }
}