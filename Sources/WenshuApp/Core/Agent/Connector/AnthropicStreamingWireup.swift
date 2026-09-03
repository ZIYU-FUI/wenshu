//
//  AnthropicStreamingWireup.swift · Wenshu · v0.35 ticket 004 sub-step 4
//
//  Wires EventSource 1.5.1 (= mattt/EventSource, already in Package.swift)
//  into AnthropicConnector for SSE streaming (= ticket 004 L31 acceptance).
//
//  Per /code-review Spec re-review, prior attempts hit Swift6 strict
//  concurrency blockers (= @Sendable (Event) async -> Void callback vs
//  AsyncThrowingStream init closure). This file solves via:
//  1. EventSource nonisolated onMessage setter (= internally wraps in
//     Task { await self.setOnMessageCallback(newValue) })
//  2. AnthropicStreamingWireup is its own actor (= thread-safe state)
//  3. Returning AsyncStream (= Swift-native async sequence, non-throwing
//     variant of AsyncThrowingStream, simpler init closure = avoids
//     @Sendable capture issue)
//
//  Per ADR-0009 (wenshu-side wins) + §11.3: this is a thin adapter over
//  EventSource. No duplicate SSE parser (= EventSource.Parser is the
//  canonical byte-level SSE parser).
//
//  v0.35 ticket 004 sub-step 4 of N.
//

import Foundation
import EventSource

/// Anthropic SSE streaming wire-up (= AsyncStream producer).
/// Wraps EventSource (= mattt/EventSource 1.5.1) and yields
/// AnthropicStreamingChunk via AnthropicSSEDecoder.
public actor AnthropicStreamingWireup {

    private var eventSource: EventSource?
    private var continuation: AsyncStream<AnthropicStreamingChunk>.Continuation?

    public init() {}

    /// Connect to Anthropic Messages API streaming endpoint and yield decoded chunks.
    /// - Parameters:
    ///   - request: URLRequest (= AnthropicStreamingRequest.buildRequest output)
    /// - Returns: AsyncStream of AnthropicStreamingChunk (= consumer terminates
    ///   the stream by calling onTermination handler).
    public func connect(request: URLRequest) -> AsyncStream<AnthropicStreamingChunk> {
        AsyncStream { continuation in
            self.continuation = continuation
            let eventSource = EventSource(request: request)
            self.eventSource = eventSource

            // EventSource 1.5.1 onMessage callback signature:
            // @Sendable (Event) async -> Void
            // Event struct fields: id / event / data / retry
            eventSource.onMessage = { [weak self] event in
                let eventType = event.event ?? "message"
                guard let chunk = AnthropicSSEDecoder.decode(event: eventType, data: event.data) else {
                    return
                }
                Task { [weak self] in
                    await self?.forward(chunk:chunk)
                }
                if case .messageStop = chunk.kind {
                    Task { [weak self] in
                        await self?.finish()
                    }
                }
            }

            eventSource.onError = { [weak self] error in
                let streamError = error ?? LLMConnectorError.streamingFailed(provider: "anthropic")
                Task { [weak self] in
                    await self?.finish(error: streamError)
                }
            }

            // AsyncStream termination: caller dropped stream = clean up EventSource.
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.close()
                }
            }
        }
    }

    /// Forward a decoded chunk to the AsyncStream consumer.
    private func forward(chunk: AnthropicStreamingChunk) {
        continuation?.yield(chunk)
    }

    /// Finish the stream (= normal completion = nonisolated; eventSource.close
    /// is its own actor call, await needed).
    private nonisolated func finish() {
        Task { await self.finishStream() }
    }

    /// Finish the stream with an error (= nonisolated; same as above).
    private nonisolated func finish(error: Error) {
        Task { await self.finishStream() }
    }

    /// Internal finish helper (= actor-isolated; safe to touch mutable props).
    private func finishStream() async {
        continuation?.finish()
        await close()  // direct await within actor-isolated method
    }

    /// Public close (= Swift 6 actor-isolated).
    public func close() {
        // eventSource.close() is on a third-party actor (mattt/EventSource);
        // needs await even though we just want synchronous-style cleanup.
        // We avoid blocking by firing-and-forgetting; cleanup completes
        // asynchronously but the actor state is reset synchronously below.
        let source = eventSource
        eventSource = nil
        continuation = nil
        Task { await source?.close() }
    }
}

// MARK: - Convenience factory (= single entry point for AnthropicConnector)

public enum AnthropicStreamingWireupFactory {

    /// Build a streaming URLRequest and wire it up (= returns AsyncStream).
    /// - Parameters:
    ///   - credentials: ConnectorCredentials (= baseURL + apiKey)
    ///   - model: model identifier (= e.g. "claude-sonnet-4.5")
    ///   - maxTokens: max output tokens
    ///   - systemPrompt: top-level system prompt
    ///   - messages: conversation history
    /// - Returns: AsyncStream of AnthropicStreamingChunk
    public static func streamingStream(
        credentials: ConnectorCredentials,
        model: String,
        maxTokens: Int,
        systemPrompt: String?,
        messages: [LLMMessage]
    ) -> AsyncStream<AnthropicStreamingChunk> {
        let request = buildRequest(
            credentials: credentials,
            model: model,
            maxTokens: maxTokens,
            systemPrompt: systemPrompt,
            messages: messages
        )
        let wireup = AnthropicStreamingWireup()
        // connect() is actor-isolated; AsyncStream.init is sync nonisolated.
        // Bridge via a small async shim.
        let stream: AsyncStream<AnthropicStreamingChunk> = AsyncStream { continuation in
            Task { @Sendable in
                let inner = await wireup.connect(request: request)
                Task { @Sendable in
                    for await chunk in inner {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                }
            }
        }
        return stream
    }

    /// Pure URLRequest builder (= extracted for Sendable capture in factory).
    public static func buildRequest(
        credentials: ConnectorCredentials,
        model: String,
        maxTokens: Int,
        systemPrompt: String?,
        messages: [LLMMessage]
    ) -> URLRequest {
        // Inline URLRequest builder (= ticket 004 sub-step 4; the
        // AnthropicStreamingRequest helper was scoped to ticket 004
        // sub-step 2+3 = uncommitted AnthropicStreaming.swift. Inlining
        // here keeps the wire-up self-contained per sub-step 4 scope.)
        var url = URL(string: "\(credentials.baseURL)/v1/messages")!
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = (components.queryItems ?? []) + [
                URLQueryItem(name: "stream", value: "true")
            ]
            if let composed = components.url { url = composed }
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(credentials.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "system": [
                "type": "text",
                "text": systemPrompt ?? ""
            ],
            "messages": messages.map { llmMessage -> [String: Any] in
                [
                    "role": llmMessage.role == .assistant ? "assistant" : "user",
                    "content": llmMessage.blocks.map { $0.asJSONObject }
                ]
            }
        ]
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: body,
            options: [.sortedKeys]
        )
        return request
    }
}

