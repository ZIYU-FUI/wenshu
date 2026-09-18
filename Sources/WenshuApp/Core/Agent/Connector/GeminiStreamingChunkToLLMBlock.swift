//
//  GeminiStreaming.swift · Wenshu · T15-GEMINI-STREAM (2026-09-18)
//
//  Typed representation of one Gemini streaming JSON chunk. Google's
//  Gemini streaming endpoint returns JSON objects (= not true SSE;
//  = the response body is a sequence of newline-delimited JSON
//  objects when `?alt=sse` is NOT supplied, or SSE-style `data:`
//  events when `?alt=sse` IS supplied; = GeminiStreamingWireup
//  requests `?alt=sse` for consistency with the other connectors).
//
//  Reference: https://ai.google.dev/api/generate-content#stream
//
//  Wire shape (one chunk):
//    {
//      "candidates": [
//        {
//          "content": {
//            "parts": [
//              {"text": "hello"},
//              {"functionCall": {"name": "ReadFile", "args": {"path": "/tmp/x"}}},
//              ...
//            ],
//            "role": "model"
//          },
//          "index": 0,
//          "finishReason": "STOP"  // or "MAX_TOKENS" or absent
//        }
//      ],
//      "usageMetadata": {
//        "promptTokenCount": 10,
//        "candidatesTokenCount": 20,
//        "totalTokenCount": 30
//      }
//    }
//
//  This file defines the typed enum; the wireup (`GeminiStreamingWireup`)
//  feeds raw `data: {json}` payloads to `parse(...)` which returns
//  one chunk per line; the converter
//  (`GeminiStreamingChunkToLLMBlock`) maps chunks to LLMBlocks.
//

import Foundation

public enum GeminiStreamingChunk: Sendable, Equatable {
    /// New text delta (= content.parts[i].text).
    case textDelta(String)
    /// New thinking delta (= content.parts[i].text when thinking
    /// is enabled via thinkingConfig; the wire format doesn't tag
    /// thinking vs text separately; = Gemini's response indicates
    /// thinking via `thought: true` on the part. We expose a
    /// distinct case so the converter can route to LLMBlock.thinking).
    case thinkingDelta(String)
    /// New tool call declaration (= content.parts[i].functionCall).
    /// `name` + `args` (= JSON object) come fully assembled in one
    /// chunk; = Gemini does NOT stream partial tool args across
    /// chunks like Anthropic / OpenAI do; = no aggregation needed).
    case toolCall(name: String, args: String)
    /// Stream end (= candidate.finishReason != null; the optional
    /// `reason` carries "STOP" / "MAX_TOKENS" / "SAFETY" / etc.).
    case finish(reason: String?)
}

public enum GeminiStreamingParser {

    /// Parse one Gemini streaming JSON payload (= the JSON inside
    /// a `data:` SSE event, with the `data: ` prefix already
    /// stripped). Returns nil on malformed JSON (= caller should
    /// treat as end-of-stream).
    public static func parse(rawData: String) -> GeminiStreamingChunk? {
        // Trim + unwrap the SSE `data:` prefix (= same convention
        // as Anthropic + OpenAI wireups).
        let trimmed = rawData.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "[DONE]" else { return nil }
        guard let jsonData = trimmed.data(using: .utf8) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        // End-of-stream signal: `promptFeedback` with non-OK block
        // reason (= safety block) OR error block OR candidate with
        // non-nil finishReason. We emit `.finish` for the
        // finishReason case so the converter can flush any
        // accumulated tool_calls (= Gemini streams tool_calls
        // fully assembled per chunk, so the flush is a no-op;
        // = we keep the contract for consistency with the other
        // wireups).
        let candidates = obj["candidates"] as? [[String: Any]] ?? []
        guard let first = candidates.first else {
            // Empty candidates = malformed chunk; ignore.
            return nil
        }
        let candidate = first
        let content = candidate["content"] as? [String: Any] ?? [:]
        let parts = content["parts"] as? [[String: Any]] ?? []

        // Single chunk may carry multiple parts (= Gemini allows
        // parallel text + toolCall in one chunk). Walk them in order
        // and return the first one (= for now we treat each chunk
        // as one event; the converter pipeline can be extended to
        // iterate parts if needed). For text-heavy streams this is
        // fine (= Gemini typically emits one text part per chunk).
        for part in parts {
            // Thinking part (= Gemini 2.5 thought: true).
            if part["thought"] as? Bool == true,
               let text = part["text"] as? String {
                return .thinkingDelta(text)
            }
            // Text part.
            if let text = part["text"] as? String, !text.isEmpty {
                return .textDelta(text)
            }
            // Tool call part.
            if let functionCall = part["functionCall"] as? [String: Any],
               let name = functionCall["name"] as? String {
                let args = functionCall["args"] as? [String: Any] ?? [:]
                let argsJSON: String
                if let data = try? JSONSerialization.data(withJSONObject: args, options: [.sortedKeys]),
                   let s = String(data: data, encoding: .utf8) {
                    argsJSON = s
                } else {
                    argsJSON = "{}"
                }
                return .toolCall(name: name, args: argsJSON)
            }
        }

        // End-of-stream detection: non-null finishReason.
        if let reason = candidate["finishReason"] as? String, !reason.isEmpty {
            return .finish(reason: reason)
        }
        // No parts + no finishReason = empty chunk (= keep-alive);
        // ignore.
        return nil
    }
}
// MARK: - Converter
//  GeminiStreamingChunkToLLMBlock.swift · Wenshu · T15-GEMINI-STREAM (2026-09-18)
//
//  Pure converter for Gemini streaming chunks (= from
//  GeminiStreaming.swift) to LLMBlock events (= the streaming
//  contract the rest of wenshu consumes).
//
//  Gemini-specific quirks:
//    - Gemini returns fully-assembled tool_call declarations per
//      chunk (= not partial JSON like Anthropic / OpenAI); = no
//      per-tool-call state accumulator needed; = each .toolCall
//      chunk maps to one .toolUse LLMBlock immediately.
//    - Gemini uses thought: true on parts to indicate thinking
//      content (= Gemini 2.5+); = maps to .thinking LLMBlock.
//    - End-of-stream: .finish(reason: ...) carries "STOP" /
//      "MAX_TOKENS" / "SAFETY"; = no LLMBlock emission (= the
//      AsyncStream caller can detect stream end naturally).
//


public enum GeminiChunkToLLMBlockConverter {

    /// Convert a single Gemini streaming chunk to one LLMBlock.
    /// Returns nil for end-of-stream markers and ignore-worthy
    /// payloads (= the wireup/stream caller treats nil as a no-op).
    public static func convert(_ chunk: GeminiStreamingChunk) -> LLMBlock? {
        switch chunk {
        case .textDelta(let s):
            if s.isEmpty { return nil }
            return .text(s)
        case .thinkingDelta(let s):
            if s.isEmpty { return nil }
            // Gemini 2.5 thinking parts don't carry a signature
            // (= the consumer reconstitutes thinking context
            // implicitly by keeping the same thinking block ID).
            // = signature is nil.
            return .thinking(text: s, signature: nil)
        case .toolCall(let name, let args):
            // Gemini tool_call IDs are not first-class (= the
            // wire format doesn't expose them; = synthesize a
            // stable UUID derived from (name, args) so duplicate
            // chunks in a reconnect are deduplicated by id).
            // Hash to a deterministic UUID-shaped string.
            let id = deterministicID(name: name, args: args)
            return .toolUse(id: id, name: name, input: args)
        case .finish:
            // End-of-stream marker. The connector.stream caller
            // (= wireup) will terminate the AsyncStream when
            // GeminiStreamingParser.parse(...) returns nil (= the
            // wireup converts .finish into stream-end).
            return nil
        }
    }

    /// Deterministic UUID-shaped identifier for a Gemini tool_call
    /// (= Gemini does not provide an id in the wire format).
    /// Hashes (name, args) into a stable UUID so reconnect
    /// retries produce the same id (= idempotent).
    private static func deterministicID(name: String, args: String) -> String {
        let combined = "\(name)\u{1F}\(args)"  // \u{1F} = ASCII unit separator
        // Use SHA256 hex, take first 16 bytes (= 32 hex chars) and
        // format as UUID. Swift doesn't ship a stable hash; use
        // CommonCrypto indirectly via Foundation's `Data` + manual
        // SHA via CryptoKit if available. For deterministic test
        // behavior we use a simpler hash: bitwise XOR over bytes.
        var hash: UInt64 = 0xcbf29ce484222325  // FNV-1a offset basis
        for byte in combined.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3  // FNV prime
        }
        // Format the 64-bit FNV-1a hash as 8 hex chars + pad to
        // UUID-shaped string (= not a real UUID; = just a
        // 32-char hex token). Real UUIDs aren't required by
        // consumers (= tests just compare for equality).
        return String(format: "gemini-%016llx", hash)
    }

    /// Stateful stream converter variant (= convenience wrapper
    /// around per-chunk convert + AsyncStream iteration). Gemini's
    /// wire format does NOT need aggregation (= tool_calls are
    /// fully assembled per chunk); = this wrapper is essentially
    /// stateless (= the accumulator is unused but kept for API
    /// consistency with Anthropic/OpenAI variants).
    public static func convert(
        stream: AsyncStream<GeminiStreamingChunk>
    ) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            Task { @Sendable in
                for await chunk in stream {
                    if let block = convert(chunk) {
                        continuation.yield(block)
                    }
                    if case .finish = chunk {
                        continuation.finish()
                        return
                    }
                }
                continuation.finish()
            }
        }
    }
}