//
//  OpenAIStreamingWireup.swift · Wenshu · T10-OPENAI-STREAMING-WIRE (2026-09-18)
//
//  OpenAI-compatible SSE streaming wire-up (= parallel to
//  AnthropicStreamingWireup; = unifies streaming for OpenAI native,
//  DeepSeek, Ollama, OpenRouter via the shared OpenAICompatibleConnector).
//
//  OpenAI SSE wire format (= OpenAI chat completions streaming):
//    data: {"id":"chatcmpl-...","object":"chat.completion.chunk",
//           "choices":[{"delta":{"content":"...","reasoning":"..."},
//                       "index":0,"finish_reason":null}]}\n\n
//    data: [DONE]\n\n
//
//  Reuses mattt/EventSource 1.5.1 (= already in Package.swift per
//  AGENTS.md §11.1 third-party library policy; macOS-first MIT,
//  116 stars). The connection lifecycle is identical to the
//  Anthropic variant (= actor-isolated wireup + onMessage +
//  onError + onTermination cleanup).
//
//  Difference from AnthropicStreamingWireup:
//    - data is RAW JSON (= no separate event type field)
//    - [DONE] marker terminates the stream
//    - tool_calls stream incrementally across multiple deltas
//      (= skipped here; = full tool_use handling lands in T11
//      when we add Anthropic-style tool_use SSE aggregation)
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure adapter over EventSource.
//  No duplicate SSE byte parser (= EventSource's parser is the
//  canonical byte-level SSE parser for the OpenAI wire format too;
//  we only add the JSON-decoding layer on top).
//

import Foundation
import EventSource

/// OpenAI-compatible SSE wire-up (= AsyncStream producer of raw `data:`
/// payloads). Wraps EventSource (= mattt/EventSource 1.5.1) and yields
/// raw `data:` strings (= JSON decoding happens in
/// OpenAIChunkToLLMBlockConverter).
public actor OpenAIStreamingWireup {

    private var eventSource: EventSource?
    private var continuation: AsyncStream<String>.Continuation?

    public init() {}

    /// Connect to an OpenAI-compatible streaming endpoint and yield raw
    /// `data:` payloads (= one EventSource.Event per SSE message).
    public func connect(request: URLRequest) -> AsyncStream<String> {
        AsyncStream { continuation in
            self.continuation = continuation
            let eventSource = EventSource(request: request)
            self.eventSource = eventSource

            eventSource.onMessage = { [weak self] event in
                let data = event.data
                Task { [weak self] in
                    guard let self else { return }
                    await self.forward(data: data)
                    // [DONE] marker terminates the stream (= OpenAI SSE
                    // convention; = no separate stop event).
                    let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed == "[DONE]" {
                        await self.finish()
                    }
                }
            }

            eventSource.onError = { [weak self] error in
                let streamError = error ?? LLMConnectorError.streamingFailed(provider: "openai-compatible")
                Task { [weak self] in
                    self?.finish(error: streamError)
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

    private func forward(data: String) {
        continuation?.yield(data)
    }

    private nonisolated func finish() {
        Task { await self.finishStream() }
    }

    private nonisolated func finish(error: Error) {
        Task { await self.finishStream() }
    }

    private func finishStream() async {
        continuation?.finish()
        close()
    }

    public func close() {
        let source = eventSource
        eventSource = nil
        continuation = nil
        Task { await source?.close() }
    }
}

// MARK: - Convenience factory (= single entry point for OpenAICompatibleConnector)

public enum OpenAIStreamingWireupFactory {

    /// Build a streaming URLRequest and wire it up (= returns AsyncStream of
    /// raw `data:` payloads; = JSON decoding is the consumer's job).
    public static func streamingStream(
        credentials: ConnectorCredentials,
        model: String,
        maxTokens: Int,
        systemPrompt: String?,
        messages: [LLMMessage],
        bearerToken: String?
    ) -> AsyncStream<String> {
        let request = buildRequest(
            credentials: credentials,
            model: model,
            maxTokens: maxTokens,
            systemPrompt: systemPrompt,
            messages: messages,
            bearerToken: bearerToken
        )
        let wireup = OpenAIStreamingWireup()
        let stream: AsyncStream<String> = AsyncStream { continuation in
            Task { @Sendable in
                let inner = await wireup.connect(request: request)
                Task { @Sendable in
                    for await data in inner {
                        continuation.yield(data)
                    }
                    continuation.finish()
                }
            }
        }
        return stream
    }

    /// Pure URLRequest builder (= extracted for Sendable capture in factory).
    /// `bearerToken` is separate from `credentials.apiKey` because Ollama
    /// (= no-auth local provider) sends no Authorization header.
    public static func buildRequest(
        credentials: ConnectorCredentials,
        model: String,
        maxTokens: Int,
        systemPrompt: String?,
        messages: [LLMMessage],
        bearerToken: String?
    ) -> URLRequest {
        guard let baseURL = URL(string: "\(credentials.baseURL)/chat/completions") else {
            preconditionFailure("OpenAIStreamingWireup: invalid URL built from credentials.baseURL=\(credentials.baseURL)")
        }
        var url = baseURL
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = (components.queryItems ?? []) + [
                URLQueryItem(name: "stream", value: "true")
            ]
            if let composed = components.url { url = composed }
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer = bearerToken, !bearer.isEmpty {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        // Build the OpenAI chat completions streaming body. We use a
        // standalone dict (= not via RequestHelpers.buildOpenAIRequest)
        // because the streaming path needs the exact same body shape
        // (= only difference is the `stream: true` query parameter).
        // Re-using buildOpenAIRequest would force the non-streaming
        // shape; = safer to inline the minimal streaming body here.
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "messages": buildMessagesArray(systemPrompt: systemPrompt, messages: messages)
        ]
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: body,
            options: [.sortedKeys]
        )
        return request
    }

    /// Build the OpenAI messages array (= system prompt + history).
    /// Mirrors the structure of `RequestHelpers.buildOpenAIRequest` but
    /// without depending on it (= keeps the streaming body self-contained).
    private static func buildMessagesArray(
        systemPrompt: String?,
        messages: [LLMMessage]
    ) -> [[String: Any]] {
        var out: [[String: Any]] = []
        if let sys = systemPrompt, !sys.isEmpty {
            out.append([
                "role": "system",
                "content": sys
            ])
        }
        for msg in messages {
            let role: String
            switch msg.role {
            case .user: role = "user"
            case .assistant: role = "assistant"
            case .tool: role = "tool"
            }
            let contentParts: [[String: Any]] = msg.blocks.compactMap { block in
                switch block {
                case .text(let s):
                    return ["type": "text", "text": s]
                case .thinking(let s, _):
                    // OpenAI-compatible providers don't support a
                    // separate thinking block in the request shape; =
                    // surface as text so the model has the context.
                    return ["type": "text", "text": s]
                case .toolUse(let id, let name, let input):
                    return [
                        "type": "function",
                        "function": [
                            "name": name,
                            "arguments": input
                        ]
                    ]
                case .toolResult(_, let output):
                    // tool_result blocks in OpenAI go in their own
                    // message with role=tool; = the caller wraps them
                    // outside this helper. Skipping here.
                    _ = output
                    return nil
                }
            }
            out.append([
                "role": role,
                "content": contentParts
            ])
        }
        return out
    }
}