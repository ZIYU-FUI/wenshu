//
//  StreamBufferFrameWindowTests.swift · WenshuApp
//
//  The frame window is anchored at the arrival of the words, not at the
//  moment the scheduler happens to run the flush.
//
//  The buffer used to sleep for one frame inside the flush task, so the
//  window it measured started when the main actor dequeued that task. A
//  busy main actor (= a full parallel test run, or a busy app) pushed
//  the sleep back by however long the queue was deep, and the frame
//  published whole frames after the words had arrived. The words were not
//  lost; they arrived at the message far later than the frame they
//  belonged to, which reads as a stalled sentence.
//
//  The case below occupies the main actor on purpose, so the failure is
//  reproducible on demand rather than only under load.
//
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp

@MainActor
@Suite("the stream buffer's frame window is measured from the arrival")
struct StreamBufferFrameWindowTests {

    /// Occupy the main actor for a while.
    ///
    /// The flush task cannot start until the main actor is free, so this
    /// is what a busy main actor looks like to the buffer: the words
    /// arrive, and the task that would publish them waits.
    private func congestMainActor(for duration: Duration) async {
        let deadline = ContinuousClock.now + duration
        while ContinuousClock.now < deadline {
            // Spin on the main actor: this is the congestion.
        }
    }

    @Test("a frame publishes in the first turn after the main actor frees")
    func framePublishesInTheFirstTurnAfterTheActorFrees() async throws {
        var batches: [StreamBatch] = []
        var publishedAt: ContinuousClock.Instant?
        var markerAt: ContinuousClock.Instant?
        let buffer = StreamBuffer { batch in
            batches.append(batch)
            publishedAt = ContinuousClock.now
        }

        // Occupy the main actor so the flush task cannot even start.
        let occupancy = Task { @MainActor in
            let deadline = ContinuousClock.now + .milliseconds(60)
            while ContinuousClock.now < deadline {
                // Spin on the main actor: this is the congestion.
            }
        }

        // The words arrive while the main actor is busy. The frame they
        // belong to is due one frame after their arrival (= long before
        // the actor frees), so the frame is already overdue by the time
        // the flush task gets a turn.
        buffer.append(.text("The library "))

        // A marker queued behind the flush task. Whatever the flush task
        // does when it finally runs, it must not still be sleeping a
        // frame afterwards: the frame was due before the actor freed.
        let marker = Task { @MainActor in
            markerAt = ContinuousClock.now
        }

        await occupancy.value
        await marker.value

        let published = try #require(publishedAt, "the frame must publish")
        let markerTime = try #require(markerAt, "the marker must run")
        #expect(published <= markerTime,
                """
                the frame must publish in the turn the main actor frees, not a frame \
                later; published at \(published), marker ran at \(markerTime)
                """)
    }

    @Test("many chunks survive a congested main actor")
    func manyChunksSurviveCongestion() async {
        var batches: [StreamBatch] = []
        let buffer = StreamBuffer { batches.append($0) }

        let expected = (0..<20).map { "t\($0)" }
        for token in expected {
            buffer.append(.text(token))
        }

        await congestMainActor(for: .milliseconds(60))
        try? await Task.sleep(for: .milliseconds(120))

        let combined = batches.map(\.text).joined()
        for token in expected {
            #expect(combined.contains(token),
                    "\(token) must survive the coalescing; got \(combined.debugDescription)")
        }
    }

    @Test("the reasoning and the text stay apart under congestion")
    func reasoningAndTextStayApartUnderCongestion() async {
        var batches: [StreamBatch] = []
        let buffer = StreamBuffer { batches.append($0) }

        buffer.append(.thinking(text: "thinking...", signature: nil))
        buffer.append(.text("answer"))

        await congestMainActor(for: .milliseconds(60))
        try? await Task.sleep(for: .milliseconds(120))

        let combined = batches.reduce(into: StreamBatch()) { total, batch in
            total.text += batch.text
            total.reasoning += batch.reasoning
        }
        #expect(combined.text == "answer",
                "the text must arrive intact; got \(combined.text.debugDescription)")
        #expect(combined.reasoning == "thinking...",
                "the reasoning must arrive intact; got \(combined.reasoning.debugDescription)")
    }

    @Test("a congested main actor does not multiply the frames")
    func congestionDoesNotMultiplyFrames() async {
        var batches: [StreamBatch] = []
        let buffer = StreamBuffer { batches.append($0) }

        for index in 0..<50 {
            buffer.append(.text("chunk\(index) "))
        }

        await congestMainActor(for: .milliseconds(60))
        try? await Task.sleep(for: .milliseconds(120))

        #expect(batches.count <= 3,
                "fifty chunks must not become fifty publishes; got \(batches.count)")
        let combined = batches.map(\.text).joined()
        #expect(combined.contains("chunk0 "))
        #expect(combined.contains("chunk49 "))
    }

    @Test("the words reach the message even when the main actor was busy when they arrived")
    func wordsReachTheMessageAfterTheMainActorFrees() async {
        var batches: [StreamBatch] = []
        let buffer = StreamBuffer { batches.append($0) }

        // This is the shape of the failure the full parallel run hit: the
        // words arrive, the main actor is busy, and the flush task only
        // starts once the actor frees. If the frame window is measured
        // from the task's start (= the old behaviour), the words are still
        // sleeping one more frame when the actor is free, and a reader
        // that looks right then sees an empty message.
        //
        // The reader here waits for the actor to free and then looks.
        let occupancy = Task { @MainActor in
            let deadline = ContinuousClock.now + .milliseconds(60)
            while ContinuousClock.now < deadline {
                // Spin on the main actor: this is the congestion.
            }
        }

        // The words arrive while the main actor is busy.
        buffer.append(.text("The library has no cards yet."))

        await occupancy.value

        // The actor is free now. The frame the words belong to must have
        // been published (= the words must not be sleeping another frame).
        let combined = batches.map(\.text).joined()
        #expect(combined.contains("The library has no cards yet."),
                "the words must be visible as soon as the main actor frees; got \(combined.debugDescription)")
    }
}
