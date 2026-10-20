// SSEReaderLiveTests.swift
//
// The reader is only worth anything if the real provider streams through
// it. These tests talk to the configured provider and are skipped when no
// credential is present, so the suite stays runnable on a machine without
// one.
//
// They are the regression guard for the failure that motivated the reader:
// a provider that answers in under a second delivered its whole response
// before the callback-based library had installed one, so the stream opened,
// produced nothing, and the caller saw a hang.

import Foundation
import Testing
@testable import WenshuAgent

@Suite("SSE reading against the live provider", .enabled(if: LiveProviderProbe.isAvailable))
struct SSEReaderLiveTests {

    @Test("the provider's events all arrive")
    func providerEventsArrive() async throws {
        let request = LiveProviderProbe.request()
        var names: [String] = []
        var textLength = 0

        for try await event in SSEReader.events(for: request) {
            names.append(event.name ?? "message")
            if event.name == "content_block_delta" {
                textLength += event.data.count
            }
            if names.count > 200 { break }
        }

        #expect(!names.isEmpty, "the provider sent no events at all")
        #expect(names.contains("message_start"),
                "the provider's first event is message_start, got \(names.prefix(5))")
        #expect(textLength > 0, "the provider sent no content")
    }

    @Test("the Anthropic decoder turns the provider's events into chunks")
    func providerEventsDecode() async throws {
        let request = LiveProviderProbe.request()
        var chunks: [AnthropicStreamingChunk] = []

        for try await event in SSEReader.events(for: request) {
            let name = event.name ?? "message"
            if let chunk = AnthropicSSEDecoder.decode(event: name, data: event.data) {
                chunks.append(chunk)
            }
            if chunks.count > 200 { break }
        }

        #expect(!chunks.isEmpty, "no chunk decoded from the provider's stream")
        #expect(chunks.contains { chunk in
            if case .contentBlockDelta = chunk.kind { return true }
            return false
        }, "the provider's stream carries content deltas")
    }
    @Test("the full wire-up path streams the provider's blocks")
    func wireUpPathStreams() async throws {
        // The reader is only half the path. This exercises the same route
        // the connector takes: the request builder, the wire-up actor, the
        // reader, the decoder, and the block converter. A failure here
        // localises the problem to the wiring rather than to the reader.
        let key = LiveProviderProbe.credential() ?? ""
        let credentials = ConnectorCredentials(
            provider: Provider.minimaxCn,
            apiKey: key,
            baseURL: Provider.minimaxCn.defaultBaseURL
        )
        let stream = AnthropicStreamingWireupFactory.streamingStream(
            credentials: credentials,
            model: "MiniMax-M3.1-Flash",
            maxTokens: 64,
            systemPrompt: "You are a helpful assistant.",
            messages: [LLMMessage(role: .user, blocks: [.text("Reply with one short sentence.")])]
        )
        let blocks = AnthropicChunkToLLMBlockConverter.convert(
            stream: stream,
            accumulator: AnthropicChunkToLLMBlockConverter.ToolUseAccumulator()
        )
        var chunks: [LLMBlock] = []
        for await block in blocks {
            chunks.append(block)
            if chunks.count > 100 { break }
        }
        #expect(!chunks.isEmpty, "the wire-up produced no blocks")
    }

    @Test("the connector's stream ends on its own")
    func connectorStreamEnds() async throws {
        // A stream that never ends is worse than no stream: the caller
        // waits for it, and the reply never seals. This drives the
        // connector's own stream the way the conversation loop does, and
        // checks that the loop terminates.
        let connector = MinimaxConnector(provider: .minimaxCn)
        let stream = connector.stream(
            messages: [LLMMessage(role: .user, blocks: [.text("Reply with one short sentence.")])],
            options: LLMCallOptions(model: "MiniMax-M3.1-Flash", maxTokens: 64)
        )
        var count = 0
        let collector = Task { () -> Int in
            var seen = 0
            for await _ in stream {
                seen += 1
                if seen > 100 { break }
            }
            return seen
        }
        count = await collector.value
        #expect(count > 0, "the connector's stream produced no blocks")
    }
}

/// The live provider probe, kept apart so the availability check is in one
/// place.
struct LiveProviderProbe {
    init() {}
    /// Whether a credential is configured.
    ///
    /// The key is read the same way the app reads it: the file store during
    /// development, the keychain in a signed build.
    static var isAvailable: Bool {
        credential() != nil
    }

    /// A request that asks for a short reply.
    static func request() -> URLRequest {
        let key = credential() ?? ""
        var request = URLRequest(url: URL(string: "https://api.minimaxi.com/anthropic/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "MiniMax-M3.1-Flash",
            "max_tokens": 64,
            "stream": true,
            "messages": [["role": "user", "content": [["type": "text", "text": "Reply with one short sentence."]]]]
        ])
        return request
    }

    /// The configured key, when there is one.
    static func credential() -> String? {
        let path = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.wenshu.app/provider-keys.json")
        guard let data = try? Data(contentsOf: path),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let key = object["minimax-cn"], !key.isEmpty
        else { return nil }
        return key
    }

}
