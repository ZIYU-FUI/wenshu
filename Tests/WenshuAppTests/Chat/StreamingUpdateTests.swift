//
//  StreamingUpdateTests.swift · WenshuApp
//
//  Guards the two properties that make a streamed reply read as one
//  continuous sentence rather than a series of jumps.
//
//  1. The streaming message is updated in place. Replacing the element
//     of the observed array would give the message a new timestamp on
//     every frame, and the message compares by value, so the row would
//     be redrawn from scratch on every frame (= the text jumps and the
//     animation restarts). The identity of the message, and its
//     timestamp, must stay put while the reply grows.
//
//  2. The buffer publishes at most once per frame. A thousand chunks
//     must not mean a thousand state changes (= the reader sees the
//     reply arrive in bursts).
//

import Testing
import Foundation
import WenshuAgent
@testable import WenshuApp

@MainActor
@Suite("the streamed reply is written once per frame")
struct StreamingUpdateTests {

    /// A view model with one agent message that is ready to receive a
    /// stream.
    private func makeViewModel() -> (ChatViewModel, UUID) {
        let viewModel = ChatViewModel()
        let id = UUID()
        viewModel.messages = [
            ChatMessage(id: id, role: .agent, source: .wenshu, content: "", isPlaceholder: true)
        ]
        return (viewModel, id)
    }

    @Test("the streaming message keeps its identity while the reply grows")
    func streamingMessageKeepsItsIdentity() {
        let (viewModel, id) = makeViewModel()
        let accumulator = StreamingAccumulator()

        viewModel.applyStreamBatch(
            StreamBatch(text: "First "),
            placeholderId: id,
            accumulator: accumulator
        )
        let firstTimestamp = viewModel.messages[0].timestamp
        let firstContent = viewModel.messages[0].content

        for index in 1...20 {
            viewModel.applyStreamBatch(
                StreamBatch(text: "chunk\(index) "),
                placeholderId: id,
                accumulator: accumulator
            )
        }

        #expect(viewModel.messages.count == 1,
                "the stream must not add messages")
        #expect(viewModel.messages[0].timestamp == firstTimestamp,
                "the message must keep its timestamp (= the message is updated, not rebuilt)")
        #expect(viewModel.messages[0].content != firstContent,
                "the message must carry the text that arrived after the first frame")
        #expect(viewModel.messages[0].content.hasPrefix("First "),
                "the earlier text must still be there (= the reply grows, it does not restart)")
        #expect(viewModel.messages[0].content.contains("chunk20"),
                "the last chunk must be in the message")
    }

    @Test("the text is the accumulated text, with nothing lost and nothing repeated")
    func streamingTextIsTheAccumulatedText() {
        let (viewModel, id) = makeViewModel()
        let accumulator = StreamingAccumulator()

        let chunks = ["The ", "quick ", "brown ", "fox ", "jumps."]
        for chunk in chunks {
            viewModel.applyStreamBatch(
                StreamBatch(text: chunk),
                placeholderId: id,
                accumulator: accumulator
            )
        }

        #expect(viewModel.messages[0].content == chunks.joined(),
                "the message must hold exactly the text that arrived, in order")
    }

    @Test("a burst of chunks is published at most once per frame")
    func burstPublishesAtMostOncePerFrame() async {
        var published: [String] = []
        let buffer = StreamBuffer { batch in
            published.append(batch.text)
        }

        for index in 0..<500 {
            buffer.append(.text("t\(index) "))
        }
        buffer.flushNow()

        #expect(published.count < 500,
                "five hundred chunks must not become five hundred state changes")
        #expect(published.joined() == (0..<500).map { "t\($0) " }.joined(),
                "no chunk may be lost by the coalescing")
    }
}
