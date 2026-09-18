//
//  OpenAIStreamingChunkToLLMBlock.swift · Wenshu · T10-OPENAI-STREAMING-WIRE (2026-09-18)
//
//  Pure converter from OpenAI-compatible SSE chunks (= the wire format
//  shared by OpenAI native, DeepSeek, Ollama, OpenRouter, plus all
//  OpenAI-compatible providers behind the OpenAICompatibleConnector)
//  to cross-connector LLMBlock events. Bridges the gap between the
//  OpenAI SSE stream and ConversationLoop's streamCallback contract.
//
//  OpenAI SSE wire format:
//    data: {"id":"...","object":"chat.completion.chunk",
//           "choices":[{"delta":{"content":"...","reasoning":"...",
//                                    "tool_calls":[...]},
//                       "index":0,"finish_reason":null}]}\n\n
//    data: [DONE]\n\n
//
//  Conversion rules:
//    • delta.content != ""        → .text(content)
//    • delta.reasoning != ""      → .thinking(text: reasoning, signature: nil)
//    • delta.tool_calls (any)     → NOT handled (= tool_use streams need
//      more state tracking = delta.tool_calls[0].id arrives BEFORE
//      delta.tool_calls[0].function.name; = T11 ticket scope; = for
//      now we drop these on the floor; = full response will still
//      carry the tool_use blocks via RequestHelpers.decodeOpenAIResponse
//      in the non-streaming path)
//    • delta.role, delta.name etc  → skipped (= no LLMBlock equivalent)
//    • finish_reason != null       → skipped (= ConversationLoop handles
//      stream end differently)
//    • [DONE]                     → skipped (= stream end marker)
//    • unknown event / parse error → skipped (= ChatView sees graceful
//      empty stream end)
//
//  Pattern: T6-ANTHROPIC-STREAMING-THINKING = parallel work for OpenAI.
//  Just like T6, this converter is wired into OpenAICompatibleConnector
//  in this same ticket (= T10) so a future ticket only has to mock
//  EventSource for end-to-end happy-path testing.
//
//  Threading: pure synchronous function (= no actor isolation needed
//  beyond what EventSource already enforces; = trivially Sendable).
//

import Foundation

public enum OpenAIChunkToLLMBlockConverter {

    /// Single SSE event payload from OpenAI's chat completions streaming
    /// endpoint (= one `data: { ... }` line, with the `data: ` prefix
    /// already stripped by EventSource).
    ///
    /// `parsed` is `[String: Any]` (= JSON dict) which is NOT Sendable;
    /// = this struct is non-Sendable. Convert to Sendable types
    /// (= String, [String: String], etc.) before crossing actor
    /// boundaries. The converter below does this synchronously
    /// inside the same Task that reads the EventSource stream.
    public struct OpenAISSEEvent {
        public let rawData: String
        public let parsed: [String: Any]?

        public init(rawData: String, parsed: [String: Any]?) {
            self.rawData = rawData
            self.parsed = parsed
        }
    }

    /// Parse one SSE `data: {...}` payload into a structured event.
    /// Returns nil for "[DONE]" markers (= stream end), empty payloads,
    /// or malformed JSON (= graceful skip).
    public static func parse(rawData: String) -> OpenAISSEEvent? {
        let trimmed = rawData.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "[DONE]" {
            return nil
        }
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return OpenAISSEEvent(rawData: trimmed, parsed: nil)
        }
        return OpenAISSEEvent(rawData: trimmed, parsed: json)
    }

    /// Convert one OpenAI SSE event to zero or more LLMBlock events.
    /// Returns [] (= no blocks) for stream-end markers, malformed
    /// payloads, or chunks that carry no user-visible content.
    public static func convert(_ event: OpenAISSEEvent) -> [LLMBlock] {
        guard let json = event.parsed else { return [] }

        // choices[0].delta.{content, reasoning, ...}
        let choices = json["choices"] as? [[String: Any]] ?? []
        guard let choice = choices.first else { return [] }
        let delta = choice["delta"] as? [String: Any] ?? [:]

        // finish_reason != null (= "stop" / "tool_calls" / "length")
        // = stream-end marker convention. Skip content blocks (= the
        // consumer treats this as end-of-stream; = ChatView doesn't
        // surface a duplicate trailing chunk).
        let finishReason = choice["finish_reason"]
        let hasFinishReason: Bool
        if let s = finishReason as? String, !s.isEmpty, s != "null" {
            hasFinishReason = true
        } else if finishReason is NSNull {
            hasFinishReason = false
        } else {
            hasFinishReason = false
        }
        if hasFinishReason {
            return []
        }

        var blocks: [LLMBlock] = []

        // 1. content (= standard text delta)
        if let content = delta["content"] as? String, !content.isEmpty {
            blocks.append(.text(content))
        }

        // 2. reasoning (= OpenAI o1 / o3 / o4 style; = Anthropic thinking
        // counterpart). Some OpenAI-compatible providers (= DeepSeek R1)
        // also use this field.
        if let reasoning = delta["reasoning"] as? String, !reasoning.isEmpty {
            // OpenAI's reasoning field carries plain text (= no signature
            // = simpler than Anthropic's extended-thinking blocks; = the
            // signature pairing is a future T11 ticket scope).
            blocks.append(.thinking(text: reasoning, signature: nil))
        }

        // 3. tool_calls (= T11 scope; = not handled here. We drop them on
        // the floor for now = the full response still carries tool_use
        // blocks via the non-streaming send(...) path. Emitting
        // incomplete tool_use from stream would corrupt ChatPartView.)

        return blocks
    }

    /// Convert an AsyncStream of raw SSE `data:` payloads (= one per
    /// EventSource message) to an AsyncStream of LLMBlock events.
    /// Drops chunks that don't produce user-visible blocks.
    public static func convert(
        stream: AsyncStream<String>
    ) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            Task {
                for await rawData in stream {
                    guard let event = parse(rawData: rawData) else {
                        // [DONE] or empty = stop the stream
                        continuation.finish()
                        return
                    }
                    for block in convert(event) {
                        continuation.yield(block)
                    }
                }
                continuation.finish()
            }
        }
    }

    /// Synthetic error stream (= T9 pattern: missing-key path).
    public static func errorStream(_ message: String, provider: String) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            continuation.yield(.text("[stream error] \(message) provider=\(provider)"))
            continuation.finish()
        }
    }
}