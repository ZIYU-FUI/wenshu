// StreamBufferTests.swift
//
// The buffer is the reason a reply reads as continuous rather than as a
// series of jumps.
//
// Every chunk used to enqueue its own MainActor task that rebuilt the whole
// message, so a long reply meant hundreds of queued tasks and hundreds of
// full message replacements, and the display rendered whatever state
// survived the queue. The buffer changes the contract: many chunks in, one
// publish out.

import Foundation
import Testing
@testable import WenshuApp

@Suite("Stream buffering")
@MainActor
struct StreamBufferTests {

    @Test("many chunks produce one publish")
    func manyChunksCoalesce() async {
        var batches: [StreamBatch] = []
        let buffer = StreamBuffer { batches.append($0) }

        for index in 0..<50 {
            buffer.append(.text("chunk\(index) "))
        }
        // Let the scheduled flush run.
        try? await Task.sleep(for: .milliseconds(40))

        #expect(batches.count <= 3,
                "50 chunks must not produce 50 publishes; got \(batches.count)")
        let combined = batches.map(\.text).joined()
        #expect(combined.contains("chunk0 "))
        #expect(combined.contains("chunk49 "))
    }

    @Test("every chunk is preserved")
    func noChunkIsLost() async {
        var batches: [StreamBatch] = []
        let buffer = StreamBuffer { batches.append($0) }

        let expected = (0..<20).map { "t\($0)" }
        for token in expected {
            buffer.append(.text(token))
        }
        try? await Task.sleep(for: .milliseconds(40))

        let combined = batches.map(\.text).joined()
        for token in expected {
            #expect(combined.contains(token), "\(token) must survive the coalescing")
        }
    }

    @Test("a terminal flush publishes what is still pending")
    func flushNowPublishesTheRemainder() {
        var batches: [StreamBatch] = []
        let buffer = StreamBuffer { batches.append($0) }

        buffer.append(.text("tail"))
        #expect(buffer.hasPending)

        buffer.flushNow()
        #expect(!buffer.hasPending)
        #expect(batches.count == 1)
        #expect(batches.first?.text == "tail")
    }

    @Test("a flush with nothing pending does nothing")
    func flushWithoutPendingIsANoOp() {
        var batches: [StreamBatch] = []
        let buffer = StreamBuffer { batches.append($0) }
        buffer.flushNow()
        #expect(batches.isEmpty)
    }

    @Test("reasoning and text stay apart")
    func reasoningAndTextAreSeparate() async {
        var batches: [StreamBatch] = []
        let buffer = StreamBuffer { batches.append($0) }

        buffer.append(.thinking(text: "thinking...", signature: nil))
        buffer.append(.text("answer"))
        try? await Task.sleep(for: .milliseconds(40))

        let combined = batches.reduce(into: StreamBatch()) { total, batch in
            total.text += batch.text
            total.reasoning += batch.reasoning
        }
        #expect(combined.text == "answer")
        #expect(combined.reasoning == "thinking...")
    }

    @Test("tool calls are never merged away")
    func toolCallsStayDiscrete() async {
        var batches: [StreamBatch] = []
        let buffer = StreamBuffer { batches.append($0) }

        buffer.append(.toolUse(id: "a", name: "read", input: "{}"))
        buffer.append(.toolUse(id: "b", name: "write", input: "{}"))
        try? await Task.sleep(for: .milliseconds(40))

        let toolBlocks = batches.flatMap(\.blocks)
        #expect(toolBlocks.count == 2,
                "two tool calls must stay two events; got \(toolBlocks.count)")
    }

    @Test("an empty chunk is ignored")
    func emptyChunkIsIgnored() {
        var batches: [StreamBatch] = []
        let buffer = StreamBuffer { batches.append($0) }
        buffer.append(.text(""))
        #expect(!buffer.hasPending)
        buffer.flushNow()
        #expect(batches.isEmpty)
    }
}