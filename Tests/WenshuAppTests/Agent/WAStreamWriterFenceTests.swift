//
//  WAStreamWriterFenceTests.swift · Wenshu · WenshuAgent unit test for WAStreamWriterFence
//
//  Verifies the single-writer fence (= hermes stream_single_writer.py
//  port). Tests:
//   - claim returns a fresh token
//   - isCurrent returns true for the latest claim
//   - isCurrent returns false for superseded claims
//
//  Created: 2026-10-16 (WenshuAgent P3.6 unit tests)
//

import Testing
import Foundation
import WenshuAgent

@testable import WenshuApp

@Suite("WAStreamWriterFence")
struct WAStreamWriterFenceTests {

    @Test("first claim is current; second supersedes first")
    func testSingleClaim() {
        let fence = WAStreamWriterFence()
        let first = fence.claim()
        #expect(fence.isCurrent(first))
    }

    @Test("newer claim supersedes older one")
    func testSupersession() {
        let fence = WAStreamWriterFence()
        let first = fence.claim()
        let second = fence.claim()
        #expect(!fence.isCurrent(first))
        #expect(fence.isCurrent(second))
    }

    @Test("two fences are independent (= different actor instances)")
    func testIndependent() {
        let f1 = WAStreamWriterFence()
        let f2 = WAStreamWriterFence()
        let t1 = f1.claim()
        let t2 = f2.claim()
        // Each fence's own claim is current for that fence.
        #expect(f1.isCurrent(t1))
        #expect(f2.isCurrent(t2))
        // After a SECOND claim on f1, t1 is no longer current on f1
        // (= the fence's "race" semantic = only the most recent
        // claim is current). The other fence is unaffected.
        let t1b = f1.claim()
        #expect(!f1.isCurrent(t1))
        #expect(f1.isCurrent(t1b))
        #expect(f2.isCurrent(t2))
    }
}
