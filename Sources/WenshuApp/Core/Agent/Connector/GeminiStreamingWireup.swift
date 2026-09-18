//
//  GeminiStreamingWireup.swift · Wenshu · T15-GEMINI-STREAM (2026-09-18)
//
//  EventSource adapter for Gemini's streaming endpoint
//  (= streamGenerateContent). Wraps mattt/EventSource 1.5.1 and
//  yields typed GeminiStreamingChunk events (= the wire format
//  itself is JSON-in-SSE because we append `?alt=sse` to the
//  endpoint URL; = each EventSource event's `data` field is one
//  JSON object to be parsed by GeminiStreamingParser).
//
//  URL shape: https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?alt=sse&key={API_KEY}
//  Method: POST (not GET; = Gemini requires POST with a JSON
//  body even for streaming).
//
//  Gemini is Anthropic/OpenAI-style POST-with-body streaming;
//  the mattt/EventSource constructor only accepts a URLRequest,
//  so we build one with .httpMethod = "POST" and let EventSource
//  send it.
//

import Foundation
import EventSource

/// Wraps EventSource (= mattt/EventSource 1.5.1) and yields typed
/// `GeminiStreamingChunk` events. The caller (= connector.stream)
/// forwards each chunk to `GeminiChunkToLLMBlockConverter.convert(...)`
/// to produce LLMBlocks for ChatView.
public final class GeminiStreamingConnection: @unchecked Sendable {
    private var eventSource: EventSource?

    /// Build the EventSource request for streamGenerateContent and
    /// return the connection. Caller invokes `start(handler:)` to
    /// actually open the connection.
    public static func makeConnection(
        apiKey: String,
        model: String,
        maxTokens: Int?,
        systemPrompt: String?,
        messages: [LLMMessage],
        baseURL: String = "https://generativelanguage.googleapis.com"
    ) -> (URLRequest, EventSource) {
        var components = URLComponents(string: "\(baseURL)/v1beta/models/\(model):streamGenerateContent")!
        components.queryItems = [
            URLQueryItem(name: "alt", value: "sse"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        let url = components.url!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildBody(
            messages: messages, maxTokens: maxTokens, systemPrompt: systemPrompt
        )
        return (request, EventSource(request: request))
    }

    /// Build Gemini's wire-format request body (= the `contents`
    /// + optional `systemInstruction` + `generationConfig`).
    /// Mirrors the body GeminiNativeConnector.send() constructs
    /// (= ticket-GEMINI-WIRE-001 shared via RequestHelpers).
    /// Inlined here for T15 scope (= extraction to
    /// RequestHelpers is a follow-up cleanup ticket).
    private static func buildBody(
        messages: [LLMMessage],
        maxTokens: Int?,
        systemPrompt: String?
    ) -> Data {
        var contents: [[String: Any]] = []
        for msg in messages {
            var parts: [[String: Any]] = []
            for block in msg.blocks {
                switch block {
                case .text(let s):
                    parts.append(["text": s])
                case .thinking:
                    continue  // Gemini client-side thinking isn't sent back
                case .toolUse(let id, let name, let input):
                    // Gemini tool_use from prior assistant -> not standard
                    // (Gemini sends tool calls in the assistant turn and
                    // = the client only sends back `functionResponse`).
                    // Skipped for now (= the LLM loop drops thinking on
                    // outbound for now too).
                    _ = id
                    _ = name
                    _ = input
                case .toolResult:
                    // Gemini expects functionResponse parts in the
                    // user turn (= map from the tool result id we
                    // synthesized). For T15 scope (= no aggregation
                    // test against live Gemini), skip the mapping.
                    continue
                }
            }
            if parts.isEmpty { continue }
            let role: String = (msg.role == .assistant) ? "model" : "user"
            contents.append(["role": role, "parts": parts])
        }
        var body: [String: Any] = ["contents": contents]
        if let systemPrompt, !systemPrompt.isEmpty {
            body["systemInstruction"] = ["parts": [["text": systemPrompt]]]
        }
        var generationConfig: [String: Any] = [:]
        if let maxTokens { generationConfig["maxOutputTokens"] = maxTokens }
        if !generationConfig.isEmpty {
            body["generationConfig"] = generationConfig
        }
        return (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
    }
}

/// Factory for opening Gemini streaming connections and
/// exposing the chunks as an AsyncStream<GeminiStreamingChunk>.
public enum GeminiStreamingWireupFactory {

    /// Open a Gemini SSE connection and yield parsed chunks.
    /// Returns an AsyncStream that finishes when the connection
    /// closes (= including on error).
    public static func streamingStream(
        apiKey: String,
        model: String,
        maxTokens: Int? = nil,
        systemPrompt: String? = nil,
        messages: [LLMMessage]
    ) -> AsyncStream<GeminiStreamingChunk> {
        AsyncStream { continuation in
            // Empty key + non-empty model = can't authenticate.
            if apiKey.isEmpty {
                continuation.finish()
                return
            }
            let (_, eventSource) = GeminiStreamingConnection.makeConnection(
                apiKey: apiKey,
                model: model,
                maxTokens: maxTokens,
                systemPrompt: systemPrompt,
                messages: messages
            )
            // Each EventSource event = one parsed GeminiStreamingChunk.
            // Parse failures (= malformed JSON / `[DONE]` markers) yield
            // nil = we ignore them = the connector continues until the
            // connection closes.
            eventSource.onMessage = { event in
                if let chunk = GeminiStreamingParser.parse(rawData: event.data) {
                    continuation.yield(chunk)
                }
            }
            eventSource.onError = { _ in
                continuation.finish()
            }
            // AsyncStream termination: caller dropped the stream
            // = clean up the EventSource. EventSource.close() is
            // actor-isolated; wrap in Task.
            continuation.onTermination = { @Sendable _ in
                Task { await eventSource.close() }
            }
        }
    }
}