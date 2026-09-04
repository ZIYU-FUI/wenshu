//
//  ContextEngineTests.swift · Wenshu · v0.35 ticket 003 sub-step 3
//
//  Unit tests for ContextEngine (= hermes context_engine.py ABC port,
//  wenshu-side wins thin facade over Core/Memory/* subsystem).
//
//  Sub-step 3 returns empty ContextBundle (= wiring lands in ticket 009).
//  Tests verify the API contract + formatContextBundle rendering.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ContextEngine (ticket 003 sub-step 3)")
struct ContextEngineTests {

    @Test("aggregateContextForTurn returns empty bundle in sub-step 3 (= ticket 009 wires Core/Memory)")
    func testAggregateReturnsEmpty() async {
        let engine = ContextEngine()
        let bundle = await engine.aggregateContextForTurn(bookId: nil, userMessage: "test")
        #expect(bundle.isEmpty)
    }

    @Test("formatContextBundle handles empty bundle (= no system-prompt dynamic tier added)")
    func testFormatEmptyBundle() async {
        let engine = ContextEngine()
        let bundle = await engine.aggregateContextForTurn(bookId: nil, userMessage: "test")
        let formatted = await engine.formatContextBundle(bundle)
        #expect(formatted.isEmpty)
    }

    @Test("formatContextBundle renders memories section")
    func testFormatMemories() async {
        let engine = ContextEngine()
        let bundle = ContextEngine.ContextBundle(
            memories: [
                ContextEngine.MemoryEntry(
                    source: "/book/world/character.md",
                    snippet: "Alice is the protagonist"
                )
            ],
            characterContext: [],
            worldContext: [],
            foreshadowContext: []
        )
        let formatted = await engine.formatContextBundle(bundle)
        #expect(formatted.contains("Relevant memories"))
        #expect(formatted.contains("Alice is the protagonist"))
        #expect(formatted.contains("/book/world/character.md"))
    }

    @Test("formatContextBundle combines all sections with --- separator")
    func testFormatAllSections() async {
        let engine = ContextEngine()
        let bundle = ContextEngine.ContextBundle(
            memories: [ContextEngine.MemoryEntry(source: "x.md", snippet: "x")],
            characterContext: ["Alice is brave"],
            worldContext: ["Magic is forbidden"],
            foreshadowContext: ["Alice will betray Bob"]
        )
        let formatted = await engine.formatContextBundle(bundle)
        #expect(formatted.contains("Relevant memories"))
        #expect(formatted.contains("Characters"))
        #expect(formatted.contains("World"))
        #expect(formatted.contains("Foreshadowing"))
        #expect(formatted.contains("---"))
    }
}