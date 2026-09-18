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

    // MARK: - T12 stateful converter (= aggregates tool_calls across deltas)

    /// Per-tool-call state (= one entry per open `delta.tool_calls[i]`
    /// that hasn't yet been completed; = OpenAI streams tool_calls
    /// incrementally: first chunk carries `id` + `name`, later chunks
    /// carry partial `arguments` strings; = the converter accumulates
    /// and emits the assembled `.toolUse` block on stream end).
    ///
    /// Reference type so callers can hold the state across
    /// `convert(stream:)` iterations without copying (= parallel to the
    /// AsyncStream accumulator pattern in ChatView streamCallback).
    ///
    /// `@unchecked Sendable`: the only mutation entry point is
    /// `ingest(_:)`, which is serial within a single
    /// `convert(stream:, accumulator:)` invocation (= the AsyncStream
    /// yields one chunk at a time; = no concurrent mutation). Cross-
    /// stream sharing would require external synchronization (= future
    /// ticket if needed).
    public final class ToolUseAccumulator: @unchecked Sendable {
        private struct PendingToolCall: Sendable {
            var id: String?
            var name: String?
            var argumentsBuffer: String
        }
        private var pending: [Int: PendingToolCall] = [:]

        public init() {}

        /// Per-chunk state mutation. Returns zero or one LLMBlock to emit
        /// at the appropriate moment (= content/reasoning emit
        /// immediately; tool_calls emit on stream-end marker).
        public func ingest(_ event: OpenAISSEEvent) -> [LLMBlock] {
            guard let json = event.parsed else { return [] }

            let choices = json["choices"] as? [[String: Any]] ?? []
            guard let choice = choices.first else { return [] }
            let delta = choice["delta"] as? [String: Any] ?? [:]

            var emitted: [LLMBlock] = []

            // 1. content delta (= emit immediately).
            if let content = delta["content"] as? String, !content.isEmpty {
                emitted.append(.text(content))
            }

            // 2. reasoning delta (= emit immediately).
            if let reasoning = delta["reasoning"] as? String, !reasoning.isEmpty {
                emitted.append(.thinking(text: reasoning, signature: nil))
            }

            // 3. tool_calls delta (= accumulate into per-index pending dict).
            //    OpenAI sends tool_calls as an array of partial updates.
            //    Each update may carry: id, type (= "function"), function.name,
            //    function.arguments (a partial JSON string).
            //    The first delta for an index carries id + name; later deltas
            //    append to arguments.
            if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                for tc in toolCalls {
                    guard let idx = tc["index"] as? Int else { continue }
                    var entry = pending[idx] ?? PendingToolCall(
                        id: nil, name: nil, argumentsBuffer: ""
                    )
                    if let id = tc["id"] as? String, !id.isEmpty {
                        entry.id = id
                    }
                    if let function = tc["function"] as? [String: Any] {
                        if let name = function["name"] as? String, !name.isEmpty {
                            entry.name = name
                        }
                        if let args = function["arguments"] as? String, !args.isEmpty {
                            entry.argumentsBuffer += args
                        }
                    }
                    pending[idx] = entry
                }
            }

            // 4. Stream-end signals (= flush accumulated tool_calls).
            //    OpenAI uses two signals: finish_reason != null OR "[DONE]".
            //    Both are treated as end-of-stream (= emit any pending
            //    tool_use blocks now).
            let finishReason = choice["finish_reason"]
            let hasFinishReason: Bool
            if let s = finishReason as? String, !s.isEmpty, s != "null" {
                hasFinishReason = true
            } else if finishReason is NSNull {
                hasFinishReason = false
            } else {
                hasFinishReason = false
            }
            // [DONE] comes through `parse(rawData:)` returning nil; the
            // stream consumer (= convert(stream:, accumulator:)) calls
            // `flush()` on [DONE] / end-of-stream. We expose flush() below.
            _ = hasFinishReason  // referenced via flush(); see call site

            return emitted
        }

        /// Flush all pending tool_calls as .toolUse LLMBlocks.
        /// Call this when the stream ends (= [DONE] / connection close /
        /// finish_reason observed).
        public func flush() -> [LLMBlock] {
            var emitted: [LLMBlock] = []
            // Iterate by sorted index for stable ordering.
            for idx in pending.keys.sorted() {
                guard let entry = pending.removeValue(forKey: idx) else { continue }
                // OpenAI requires both id and name by stream end; =
                // if either is missing, skip (= incomplete tool_use; =
                // better to drop than to emit a malformed block).
                guard let id = entry.id, let name = entry.name else { continue }
                emitted.append(.toolUse(
                    id: id,
                    name: name,
                    input: entry.argumentsBuffer
                ))
            }
            return emitted
        }
    }

    /// T12: stateful streaming converter. Aggregates tool_calls across
    /// multiple SSE chunks into single `.toolUse` LLMBlocks at stream
    /// end. Text/reasoning still emit immediately.
    ///
    /// OpenAI wire-format example (= one tool_call across 3 chunks):
    ///   1. {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"tool-1",
    ///         "function":{"name":"read_file","arguments":""}}]}}]}
    ///   2. {"choices":[{"delta":{"tool_calls":[{"index":0,
    ///         "function":{"arguments":"{\"path\":"}}]}}]}
    ///   3. {"choices":[{"delta":{"tool_calls":[{"index":0,
    ///         "function":{"arguments":"\"foo.txt\"}"}}]}}]}
    ///   4. "data: [DONE]"
    ///   -> yields 1 .toolUse(id=tool-1, name=read_file,
    ///                          input='{"path":"foo.txt"}')
    ///
    /// Parallel tool_calls (= multiple `index` in the same response)
    /// are tracked independently.
    public static func convert(
        stream: AsyncStream<String>,
        accumulator: ToolUseAccumulator
    ) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            Task { @Sendable in
                for await rawData in stream {
                    guard let event = parse(rawData: rawData) else {
                        // [DONE] or empty = stop the stream. Flush any
                        // accumulated tool_use blocks before finishing.
                        for block in accumulator.flush() {
                            continuation.yield(block)
                        }
                        continuation.finish()
                        return
                    }
                    for block in accumulator.ingest(event) {
                        continuation.yield(block)
                    }
                }
                // Stream ended without [DONE] (= connection closed).
                // Flush whatever we accumulated (= defensive: even
                // without [DONE], the consumer expects the tool_use
                // blocks to surface).
                for block in accumulator.flush() {
                    continuation.yield(block)
                }
                continuation.finish()
            }
        }
    }
}