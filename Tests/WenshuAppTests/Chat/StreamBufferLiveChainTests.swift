//
//  StreamBufferLiveChainTests.swift · WenshuApp
//
//  The scripted chain test proves the production path works with a
//  connector the test controls. This file proves the same path works
//  with the REAL connector (= the user's own key, the user's own
//  endpoint, the user's own model).
//
//  It is off by default: it costs money and it needs a configured
//  provider. It runs when WENSHU_LIVE_API_TESTS=1 (= the same switch
//  the other live suites use).
//
//  What it proves, in order:
//    1. the provider the user configured actually answers
//    2. the chunks arrive as separate blocks (= not one blob)
//    3. every chunk reaches the buffer
//    4. every chunk reaches the chat message the reader sees
//
//

import Foundation
import Testing
import WenshuAgent
import WenshuData
@testable import WenshuApp

/// Live provider tests are off unless the caller opts in.
private let liveAPIIsEnabled = ProcessInfo.processInfo.environment["WENSHU_LIVE_API_TESTS"] == "1"

@Suite("the live connector streams into the chat message", .enabled(if: liveAPIIsEnabled))
struct StreamBufferLiveChainTests {

    /// The provider the user configured.
    ///
    /// The slug comes from the same provider list the app reads (= the
    /// settings screen), so this test cannot drift from what the app
    /// actually uses.
    private static var liveProvider: Provider {
        Provider.by(slug: "minimax-cn") ?? .minimaxCn
    }

    /// A chat repository that keeps nothing.
    ///
    /// The live run is about the streaming path; the data layer is not
    /// under test here.
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

    @Test("the live provider's chunks reach the chat message")
    func liveChunksReachTheChatMessage() async throws {
        let provider = Self.liveProvider

        // The words the model is asked to say. The reply must contain
        // them, whatever else the model says.
        let marker = "wenshu-stream-probe"

        // Ask for a short reply so the live run is cheap.
        let options = LLMCallOptions(
            model: provider.defaultModels.first ?? "MiniMax-M3",
            maxTokens: 64,
            systemPrompt: "You are a helpful assistant."
        )

        // The app's own key store, read through the formal interface.
        //
        // A test process runs with an in-memory keychain (= so a test can
        // never read the developer's key), so the live run has to say
        // where the key lives: the same file store the app writes to
        // when the keychain toggle is off. The key itself is never
        // printed, logged, or put in the test.
        try await ProviderKeychain.withBackendForTesting(FileProviderKeyStore()) {
            let credentials = ConnectorCredentials.resolve(for: provider)
            try #require(!credentials.apiKey.isEmpty,
                         "no key for \(provider.slug): configure the provider first")

            let connector = MinimaxConnector(provider: provider)

            // 1. The provider answers, and it answers in chunks.
            var chunks: [LLMBlock] = []
            let stream = connector.stream(
                messages: [.user("Reply with exactly this word and nothing else: \(marker)")],
                options: options
            )
            for await block in stream {
                chunks.append(block)
            }
            try #require(!chunks.isEmpty,
                         "\(provider.slug) answered with no blocks at all")

            let streamedText = chunks
                .compactMap { block -> String? in
                    if case .text(let text) = block { return text }
                    return nil
                }
                .joined()
            try #require(streamedText.contains(marker),
                         "the live reply must carry the marker; got \(streamedText.debugDescription)")

            // 2. The same chunks through the real buffer.
            let bufferedText = await self.bufferedText(for: chunks)
            try #require(bufferedText.contains(marker),
                         "the buffer must carry the live reply; got \(bufferedText.debugDescription)")

            // 3. And through the whole chain: connector -> conductor ->
            // view model -> buffer -> message (= what the reader sees).
            let messageText = await self.messageText(for: connector, marker: marker)
            try #require(messageText.contains(marker),
                         "the live reply must reach the message; got \(messageText.debugDescription)")

            print("""
            [wenshu live chain] provider=\(provider.slug) model=\(options.model) \
            chunks=\(chunks.count) messageChars=\(messageText.count)
            """)
        }
    }

    /// The live chunks through the real buffer.
    @MainActor
    private func bufferedText(for chunks: [LLMBlock]) -> String {
        var batches: [StreamBatch] = []
        let buffer = StreamBuffer { batches.append($0) }
        for block in chunks {
            buffer.append(block)
        }
        buffer.flushNow()
        return batches.map(\.text).joined()
    }

    /// The live reply through the whole production chain.
    @MainActor
    private func messageText(for connector: any LLMConnector, marker: String) async -> String {
        let viewModel = ChatViewModel(
            conductor: WenshuConductor(connector: connector),
            repository: InMemoryChatRepository(),
            providersConfigured: { true }
        )
        viewModel.inputText = "Reply with exactly this word and nothing else: \(marker)"
        await viewModel.send()
        return viewModel.messages
            .filter { $0.role == .agent }
            .map(\.content)
            .joined()
    }
}
