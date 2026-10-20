// SSEReaderTests.swift
//
// The reader exists because the callback-based library could lose a whole
// response: it connects from its initializer and installs the message
// callback on a second, unordered task, so a fast provider's entire
// response could arrive — and be dropped — before the callback existed.
//
// These tests pin the behaviour that matters: every event the server sends
// is delivered, in order, including when the server is fast enough to
// answer before a callback would have been installed.
//
// The tests feed bytes rather than running a server. The parsing is where
// the behaviour lives, and a byte fixture exercises it without a socket.

import Foundation
import Testing
@testable import WenshuAgent

@Suite("SSE reading")
struct SSEReaderTests {

    private func bytes(_ text: String) -> [UInt8] { Array(text.utf8) }

    @Test("every event is delivered")
    func everyEventIsDelivered() async {
        let wire = "event: message_start\ndata: {\"type\":\"message_start\"}\n\n"
            + "event: content_block_delta\ndata: {\"type\":\"content_block_delta\"}\n\n"
            + "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"
        var parser = SSEByteParser()
        let events = await parser.consume(bytes(wire))
        #expect(events.map(\.name) == ["message_start", "content_block_delta", "message_stop"])
    }

    @Test("a fast burst does not lose events")
    func fastBurstDoesNotLoseEvents() async {
        // The whole response arrives in one burst. This is the case the
        // callback-based library lost: the events exist before anything is
        // ready to receive them.
        let wire = (0..<20).map { "event: tick\ndata: {\"i\":\($0)\"}\n\n" }.joined()
        var parser = SSEByteParser()
        let events = await parser.consume(bytes(wire))
        #expect(events.count == 20, "expected 20 events, got \(events.count)")
    }

    @Test("a multi-line payload is joined")
    func multiLinePayloadIsJoined() async {
        var parser = SSEByteParser()
        let events = await parser.consume(bytes("event: note\ndata: first\ndata: second\n\n"))
        #expect(events.count == 1)
        #expect(events.first?.data == "first\nsecond")
    }

    @Test("an event with no name reads as the default message type")
    func unnamedEventReadsAsMessage() async {
        var parser = SSEByteParser()
        let events = await parser.consume(bytes("data: plain\n\n"))
        #expect(events.count == 1)
        #expect(events.first?.name == nil)
    }

    @Test("a final event without a trailing blank line is still delivered")
    func finalEventWithoutBlankLineIsDelivered() async {
        // The server may close the connection right after the last line.
        var parser = SSEByteParser()
        _ = await parser.consume(bytes("event: message_stop\ndata: {\"type\":\"message_stop\"}"))
        let events = await parser.finish()
        #expect(events.count == 1, "the last event was held back")
        #expect(events.first?.name == "message_stop")
    }

    @Test("an empty stream produces nothing")
    func emptyStreamProducesNothing() async {
        var parser = SSEByteParser()
        let events = await parser.consume(bytes(""))
        #expect(events.isEmpty)
    }

    @Test("a field with no value is still an event")
    func fieldWithNoValueIsStillAnEvent() async {
        var parser = SSEByteParser()
        let events = await parser.consume(bytes("data\n\n"))
        #expect(events.count == 1)
    }
}
