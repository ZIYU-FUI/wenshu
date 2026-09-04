//
//  ReasonScrubberTests.swift · Wenshu · HERMES-INTERNAL-003 (2026-09-04)
//
//  Round-trip tests for ReasonScrubber (= hermes think_scrubber.py port).
//
//  Tests covered:
//    1. testScrub_basicMarkers       — <think>, <reasoning>, etc. all removed
//    2. testScrub_noReasoning         — plain prose unchanged
//    3. testScrubPreservingIntent     — preserves marker labels in logs
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ReasonScrubber (HERMES-INTERNAL-003)")
struct ReasonScrubberTests {

    @Test("scrub strips every reasoning/thinking block variant")
    func testScrub_basicMarkers() {
        let input = """
        Before
        <think>private thought</think>
        Middle
        <reasoning>another secret</reasoning>
        End
        <thinking>yet another</thinking>
        """
        let scrubbed = ReasonScrubber.scrub(input)
        #expect(!scrubbed.contains("private thought"))
        #expect(!scrubbed.contains("another secret"))
        #expect(!scrubbed.contains("yet another"))
        #expect(!scrubbed.contains("<think>"))
        #expect(!scrubbed.contains("</reasoning>"))
        #expect(scrubbed.contains("Before"))
        #expect(scrubbed.contains("Middle"))
        #expect(scrubbed.contains("End"))
    }

    @Test("scrub leaves plain prose unchanged")
    func testScrub_noReasoning() {
        let input = "Just a normal sentence about cooking recipes and such."
        let scrubbed = ReasonScrubber.scrub(input)
        #expect(scrubbed == input)
    }

    @Test("scrubPreservingIntent keeps a short marker instead of raw content")
    func testScrubPreservingIntent() {
        let input = "Visible<think>hidden reasoning</think>still visible"
        let scrubbed = ReasonScrubber.scrubPreservingIntent(input)
        #expect(!scrubbed.contains("hidden reasoning"))
        #expect(scrubbed.contains("[reasoning: think]"))
        #expect(scrubbed.contains("Visible"))
        #expect(scrubbed.contains("still visible"))
    }
}