//
//  SSEClientEmptyLineRegressionTests.swift · Wenshu · WenshuAgent regression test
//
//  Regression for the 2026-10-16 "minimax chat (no reply)" bug:
//   The original SSEClient used `URLSession.bytes.lines`, which
//   SKIPS empty lines. The W3C SSE wire format uses an empty line
//   as the event boundary. The result = the parser never sees the
//   boundary = pendingEvent + pendingData stuck on the first event
//   = no yields ever = chat shows "(no reply)".
//
//  This test verifies the byte-level parser yields both events
//  when fed the canonical SSE wire format (with empty line at the
//  boundary between event 1 and event 2).
//
//  Created: 2026-10-16 (WenshuAgent P3.6 unit tests)
//

import Testing
import Foundation

@testable import WenshuApp

@Suite("SSEClient empty-line boundary regression (= 2026-10-16 (no reply) bug)")
struct SSEClientEmptyLineRegressionTests {

    @Test("byte-level parser yields both events across an empty-line boundary")
    func testEmptyLineBoundary() async throws {
        // The canonical W3C SSE wire format:
        //   event: foo\n
        //   data: {"a":1}\n
        //   \n                   <- empty line = event boundary
        //   event: bar\n
        //   data: {"b":2}\n
        //   \n                   <- trailing empty line
        let wire = "event: foo\ndata: {\"a\":1}\n\nevent: bar\ndata: {\"b\":2}\n\n"
        let bytes = Array(wire.utf8)

        // SSEClient.parseSSEBytes is the byte-level parser. We use the
        // public helper added in 317f1de32 (= the same code path that
        // fixed the original bug). If this is missing, the parser
        // regressed.
        let events = SSEClient.parseSSEBytes(bytes)
        #expect(events.count == 2)
        #expect(events[0].event == "foo")
        #expect(events[0].data == "{\"a\":1}")
        #expect(events[1].event == "bar")
        #expect(events[1].data == "{\"b\":2}")
    }

    @Test("byte-level parser handles CRLF line endings")
    func testCRLF() async throws {
        let wire = "event: a\r\ndata: 1\r\n\r\nevent: b\r\ndata: 2\r\n\r\n"
        let bytes = Array(wire.utf8)
        let events = SSEClient.parseSSEBytes(bytes)
        #expect(events.count == 2)
        #expect(events[0].event == "a")
        #expect(events[0].data == "1")
        #expect(events[1].event == "b")
        #expect(events[1].data == "2")
    }

    @Test("byte-level parser tolerates the final event without trailing newline")
    func testFinalEventNoTrailingNewline() async throws {
        let wire = "event: x\ndata: 1\n"   // no trailing blank line
        let bytes = Array(wire.utf8)
        let events = SSEClient.parseSSEBytes(bytes)
        #expect(events.count == 1)
        #expect(events[0].event == "x")
        #expect(events[0].data == "1")
    }
}
