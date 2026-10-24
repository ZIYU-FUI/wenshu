//
//  StreamBufferChainTests.swift · WenshuApp
//
//  The buffer is only worth having if the words a provider streams reach
//  the message the reader sees. This suite drives the REAL chain:
//
//    connector -> conversation loop -> conductor -> stream callback ->
//    buffer -> chat message
//
//  The connector is the only scripted part: it hands the loop a fixed
//  list of blocks the way a provider's SSE stream would. Everything
//  downstream is the production path (= the real conversation loop, the
//  real conductor, the real stream buffer, and the real chat view
//  model).
//
//  The proof this file exists for: a chunk that arrives must be visible
//  in the message, and no chunk may be missing from the final message.
//

import Foundation
import Testing
import WenshuAgent
import WenshuData
@testable import WenshuApp

@MainActor
@Suite("the streamed reply travels from the connector to the message")
struct StreamBufferChainTests {

    /// A chat repository that keeps nothing.
    ///
    /// The real one writes to the SwiftData store, which is the data
    /// layer's business; this file is about the streaming path.
    private final class InMemoryChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
        func append(_ message: ChatMessage, sessionId: SessionID, bookID: BookID?) async throws {}
        func loadMessages(sessionId: SessionID, bookID: BookID?) async throws -> [ChatMessage] { [] }
        func summarizeIfNeeded(
            sessionId: SessionID,
            lastN: Int,
            threshold: Int,
            verifier: WenshuVerifier,
            bookID: BookID?
        ) async throws {}
        func copyChatUpload(sourceURL: URL, intoLibraryAt path: String) async throws -> String? { nil }
    }

    /// A connector that streams a fixed list of blocks.
    ///
    /// It records what it was asked and yields the blocks one at a time,
    /// the way a provider's SSE stream does.
    private final class ScriptedStreamConnector: LLMConnector, @unchecked Sendable {
        let connectorID = "scripted-stream"
        let contextWindow = 32_000

        private let blocks: [LLMBlock]
        private let lock = NSLock()
        private var sentMessages: [[LLMMessage]] = []

        init(blocks: [LLMBlock]) {
            self.blocks = blocks
        }

        var askedMessages: [[LLMMessage]] {
            lock.lock()
            defer { lock.unlock() }
            return sentMessages
        }

        func send(
            messages: [LLMMessage],
            options: LLMCallOptions
        ) async throws -> LLMResponse {
            LLMResponse(blocks: [.text("unused")])
        }

        nonisolated func stream(
            messages: [LLMMessage],
            options: LLMCallOptions
        ) -> AsyncStream<LLMBlock> {
            lock.lock()
            sentMessages.append(messages)
            lock.unlock()
            let scripted = blocks
            return AsyncStream { continuation in
                for block in scripted {
                    continuation.yield(block)
                }
                continuation.finish()
            }
        }
    }

    /// The words the scripted connector streams, split into chunks.
    private static let chunks = [
        "The ", "library ", "has ", "no ", "cards ", "yet."
    ]

    /// The reply the reader ends up with.
    private func replyText(in viewModel: ChatViewModel) -> String {
        viewModel.messages
            .filter { $0.role == .agent }
            .map(\.content)
            .joined()
    }

    @Test("every streamed chunk reaches the chat message")
    func everyStreamedChunkReachesTheMessage() async {
        let connector = ScriptedStreamConnector(
            blocks: Self.chunks.map { LLMBlock.text($0) }
        )
        let conductor = WenshuConductor(connector: connector)
        let viewModel = ChatViewModel(
            conductor: conductor,
            repository: InMemoryChatRepository(),
            providersConfigured: { true }
        )

        viewModel.inputText = "what is in the library?"
        await viewModel.send()

        let text = replyText(in: viewModel)
        for chunk in Self.chunks {
            #expect(text.contains(chunk),
                    "the chunk \(chunk.debugDescription) must reach the message; got \(text.debugDescription)")
        }
        #expect(text.contains("The library has no cards yet."),
                "the whole reply must reach the message; got \(text.debugDescription)")
    }

    @Test("the streamed text is visible while the reply is still arriving")
    func theStreamedTextIsVisibleWhileTheReplyArrives() async {
        // The connector streams its blocks and then holds the turn open, so
        // the turn cannot end before the message has been read. If the
        // buffer only published at the end of the turn, the message would
        // still be empty here.
        final class HoldingStreamConnector: LLMConnector, @unchecked Sendable {
            let connectorID = "holding-stream"
            let contextWindow = 32_000

            private let words: [String]
            let gate = AsyncGate()

            init(words: [String]) {
                self.words = words
            }

            func send(
                messages: [LLMMessage],
                options: LLMCallOptions
            ) async throws -> LLMResponse {
                LLMResponse(blocks: [.text("unused")])
            }

            nonisolated func stream(
                messages: [LLMMessage],
                options: LLMCallOptions
            ) -> AsyncStream<LLMBlock> {
                let scripted = words
                let gate = self.gate
                return AsyncStream { continuation in
                    let task = Task {
                        for word in scripted {
                            continuation.yield(.text(word))
                        }
                        // The turn stays open until the test lets it end.
                        await gate.wait()
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
        }

        let connector = HoldingStreamConnector(words: Self.chunks)
        let conductor = WenshuConductor(connector: connector)
        let viewModel = ChatViewModel(
            conductor: conductor,
            repository: InMemoryChatRepository(),
            providersConfigured: { true }
        )

        viewModel.inputText = "what is in the library?"
        let turn = Task { await viewModel.send() }

        // Wait for the streamed words to show up. The turn is still open
        // (= the gate is shut), so anything visible here was published by
        // the buffer while the reply was still arriving.
        //
        // The wait is generous because the turn's own start-up (the prompt
        // assembly and the tool exposure) is slow when the whole suite
        // runs at once, and the words arrive only after it.
        var midTurn = ""
        let deadline = ContinuousClock.now + .seconds(120)
        while ContinuousClock.now < deadline {
            midTurn = replyText(in: viewModel)
            if midTurn.contains("library") { break }
            try? await Task.sleep(for: .milliseconds(200))
        }
        #expect(midTurn.contains("library"),
                "the streamed words must be visible before the turn ends; got \(midTurn.debugDescription)")

        // Let the turn end and check the whole reply survived.
        connector.gate.open()
        await turn.value
        let finalText = replyText(in: viewModel)
        #expect(finalText.contains("The library has no cards yet."),
                "the whole reply must reach the message; got \(finalText.debugDescription)")
    }
}

/// A one-shot gate: `wait` suspends until `open` is called.
private final class AsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func open() {
        lock.lock()
        isOpen = true
        let resumed = waiters
        waiters = []
        lock.unlock()
        for waiter in resumed {
            waiter.resume()
        }
    }

    func wait() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if isOpen {
                lock.unlock()
                continuation.resume()
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }
}
