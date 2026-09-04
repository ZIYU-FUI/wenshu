//
//  AnthropicAdapter.swift · Wenshu · HERMES-PARTIAL-006 (2026-09-04)
//
//  Anthropic Messages API adapter extensions. Direct port of hermes
//  agent/anthropic_adapter.py (= 2,789 LOC; provides redacted_thinking
//  propagation, multi-content image + document blocks, signature
//  propagation, image_source_from_openai_url conversion, etc.).
//
//  The base AnthropicConnector (= Sources/WenshuApp/Core/Agent/Connector/
//  AnthropicConnector.swift) ships the cache control + thinking blocks +
//  tool_use + SSE streaming surface per TICKET-HERMES-GAP-002. This file
//  adds the rest of hermes anthropic_adapter.py:
//    - redacted_thinking propagation (= hermes L1888-1890:
//      "redacted_thinking" blocks carry a `data` field that must round-
//      trip across turns; we propagate verbatim).
//    - Multi-content image + document blocks (= hermes L1699-1853:
//      image_source_from_openai_url converts OpenAI-style image URLs /
//      data URLs into Anthropic image sources; document blocks for PDFs
//      / txt / md files; tool_result images for tool outputs).
//    - Signature propagation (= hermes L1885-1886 + L2161-2172:
//      thinking blocks carry an Anthropic-computed signature; we
//      preserve the signature on round-trip so prompt-cache prefix
//      survives).
//    - Signature invalidation tracking (= hermes
//      _manage_thinking_signatures + _thinking_signature_invalidated:
//      when an orphan-strip demotes a thinking block, we mark the
//      surviving prev block with _thinking_signature_invalidated so
//      the next turn rebuilds the signature).
//
//  Per spec §2.1+§2.2 thin-port mandate, the rich wire-format helpers
//  stay here (= they don't fit the existing AnthropicConnector's send()
//  entry-point contract); AnthropicConnector calls into these helpers
//  when assembling the request body.
//
//  v0.35 ticket 004 sub-step 1 + HERMES-PARTIAL-006 (2026-09-04).
//

import Foundation

public enum AnthropicAdapter {

    /// Wire-format content block (= hermes L1812+ _convert_anthropic_content_block).
    /// One of: text / thinking / redacted_thinking / image / document / tool_use / tool_result.
    public enum ContentBlock: Sendable, Equatable {
        case text(String)
        case thinking(text: String, signature: String?)
        case redacted_thinking(data: String)
        case image(source: ImageSource)
        case document(source: DocumentSource)
        case toolUse(id: String, name: String, input: String)
        case toolResult(toolUseID: String, content: [ContentBlock], isError: Bool)

        public struct ImageSource: Sendable, Equatable {
            public enum Kind: Sendable, Equatable { case base64, url }
            public let kind: Kind
            public let mediaType: String
            public let data: String
            public init(kind: Kind, mediaType: String, data: String) {
                self.kind = kind
                self.mediaType = mediaType
                self.data = data
            }

            /// JSON shape for the Anthropic request body.
            public var asJSON: [String: Any] {
                switch kind {
                case .base64:
                    return ["type": "base64", "media_type": mediaType, "data": data]
                case .url:
                    return ["type": "url", "url": data]
                }
            }
        }

        public struct DocumentSource: Sendable, Equatable {
            public enum Kind: Sendable, Equatable { case base64, url }
            public let kind: Kind
            public let mediaType: String
            public let data: String
            public init(kind: Kind, mediaType: String, data: String) {
                self.kind = kind
                self.mediaType = mediaType
                self.data = data
            }

            public var asJSON: [String: Any] {
                switch kind {
                case .base64:
                    return ["type": "base64", "media_type": mediaType, "data": data]
                case .url:
                    return ["type": "url", "url": data]
                }
            }
        }

        /// JSON shape for the Anthropic request body.
        public var asJSON: [String: Any] {
            switch self {
            case .text(let s):
                return ["type": "text", "text": s]
            case .thinking(let text, let signature):
                var dict: [String: Any] = ["type": "thinking", "thinking": text]
                if let sig = signature { dict["signature"] = sig }
                return dict
            case .redacted_thinking(let data):
                return ["type": "redacted_thinking", "data": data]
            case .image(let src):
                return ["type": "image", "source": src.asJSON]
            case .document(let src):
                return ["type": "document", "source": src.asJSON]
            case .toolUse(let id, let name, let input):
                return ["type": "tool_use", "id": id, "name": name, "input": input]
            case .toolResult(let toolUseID, let content, let isError):
                return [
                    "type": "tool_result",
                    "tool_use_id": toolUseID,
                    "is_error": isError,
                    "content": content.map { $0.asJSON }
                ]
            }
        }
    }

    /// Convert an OpenAI-style image URL / data URL into an Anthropic
    /// image source (= hermes _image_source_from_openai_url L1699-1730).
    public static func imageSourceFromOpenAIURL(_ url: String) -> ContentBlock.ImageSource {
        if url.hasPrefix("data:") {
            // data:<mediatype>;base64,<data>
            let stripped = String(url.dropFirst("data:".count))
            let parts = stripped.split(separator: ",", maxSplits: 1)
            let mediaType = String(parts.first ?? "image/jpeg")
            let data = parts.count > 1 ? String(parts[1]) : ""
            return ContentBlock.ImageSource(kind: .base64, mediaType: mediaType, data: data)
        }
        return ContentBlock.ImageSource(kind: .url, mediaType: "image/jpeg", data: url)
    }

    /// Convert an OpenAI-style message list into the Anthropic wire format
    /// (= hermes _convert_anthropic_messages L1700+). Maps:
    ///   - {"role": "user", "content": [{"type": "text", "text": "..."}]}
    ///     → Anthropic user message with text block.
    ///   - {"role": "user", "content": [{"type": "image_url", "image_url": {"url": "..."}}]}
    ///     → Anthropic user message with image block (= image_source_from_openai_url).
    ///   - {"role": "user", "content": [{"type": "input_image", ...}]}
    ///     → Anthropic user message with image block.
    ///   - {"role": "assistant", "content": [{"type": "thinking", "thinking": "...", "signature": "..."}]}
    ///     → Anthropic thinking block with signature.
    ///   - {"role": "assistant", "content": [{"type": "redacted_thinking", "data": "..."}]}
    ///     → Anthropic redacted_thinking block with data.
    public static func convertOpenAIMessagesToAnthropic(_ messages: [[String: Any]]) -> [[String: Any]] {
        var out: [[String: Any]] = []
        for m in messages {
            guard let role = m["role"] as? String else { continue }
            var converted: [ContentBlock] = []
            if let content = m["content"] as? String {
                // Simple text message.
                converted.append(.text(content))
            } else if let contentList = m["content"] as? [[String: Any]] {
                for part in contentList {
                    converted.append(convertOpenAIPart(part))
                }
            }
            // Drop empty content (= hermes pattern).
            if converted.isEmpty { continue }
            // Add a "_thinking_signature_invalidated" flag if marked.
            var messageDict: [String: Any] = [
                "role": role,
                "content": converted.map { $0.asJSON }
            ]
            if let invalidated = m["_thinking_signature_invalidated"] as? Bool, invalidated {
                messageDict["_thinking_signature_invalidated"] = true
            }
            out.append(messageDict)
        }
        return out
    }

    /// Convert a single OpenAI content part into an Anthropic content block.
    private static func convertOpenAIPart(_ part: [String: Any]) -> ContentBlock {
        let ptype = (part["type"] as? String) ?? ""
        switch ptype {
        case "text":
            return .text((part["text"] as? String) ?? "")
        case "image_url", "input_image":
            let imageValue = part["image_url"] ?? part
            let url: String
            if let dict = imageValue as? [String: Any] {
                url = (dict["url"] as? String) ?? ""
            } else if let str = imageValue as? String {
                url = str
            } else {
                url = ""
            }
            let src = imageSourceFromOpenAIURL(url)
            return .image(source: src)
        case "document":
            let documentValue = part["document"] ?? part
            if let dict = documentValue as? [String: Any] {
                let url = (dict["url"] as? String) ?? ""
                let mediaType = (dict["media_type"] as? String) ?? "application/pdf"
                if url.hasPrefix("data:") {
                    let stripped = String(url.dropFirst("data:".count))
                    let parts = stripped.split(separator: ",", maxSplits: 1)
                    let mt = String(parts.first ?? mediaType)
                    let data = parts.count > 1 ? String(parts[1]) : ""
                    return .document(source: ContentBlock.DocumentSource(
        kind: .base64, mediaType: mt, data: data
                    ))
                }
                return .document(source: ContentBlock.DocumentSource(
        kind: .url, mediaType: mediaType, data: url
                ))
            }
            return .text("")
        case "thinking":
            let text = (part["thinking"] as? String) ?? ""
            let sig = part["signature"] as? String
            return .thinking(text: text, signature: sig)
        case "redacted_thinking":
            let data = (part["data"] as? String) ?? ""
            return .redacted_thinking(data: data)
        case "tool_use":
            let id = (part["id"] as? String) ?? ""
            let name = (part["name"] as? String) ?? ""
            let input = part["input"]
            let inputStr: String
            if let s = input as? String {
                inputStr = s
            } else if let d = input {
                inputStr = String(data: try! JSONSerialization.data(
                    withJSONObject: d,
                    options: [.fragmentsAllowed]
                ), encoding: .utf8) ?? "{}"
            } else {
                inputStr = "{}"
            }
            return .toolUse(id: id, name: name, input: inputStr)
        case "tool_result":
            let toolUseID = (part["tool_use_id"] as? String) ?? ""
            let isError = (part["is_error"] as? Bool) ?? false
            let contentBlocks: [ContentBlock]
            if let arr = part["content"] as? [[String: Any]] {
                contentBlocks = arr.map { convertOpenAIPart($0) }
            } else if let s = part["content"] as? String {
                contentBlocks = [.text(s)]
            } else {
                contentBlocks = [.text("")]
            }
            return .toolResult(toolUseID: toolUseID, content: contentBlocks, isError: isError)
        default:
            return .text("")
        }
    }

    /// Propagate redacted_thinking across turns (= hermes L1888-1890 +
    /// L2026-2027). The redacted_thinking block is a special Anthropic
    /// block type that carries a `data` blob. On the wire, we pass it
    /// through verbatim; on parse-back we re-emit a .thinking case with
    /// the data folded into the signature so it survives in our LLMBlock
    /// enum.
    public static func propagateRedactedThinking(data: String) -> (text: String, signature: String) {
        return (text: "", signature: "redacted:" + data)
    }

    /// Mark a message's thinking signature as invalidated (= hermes
    /// L2169-2173 _thinking_signature_invalidated). When the orphan-strip
    /// demotes a thinking block to the previous turn's signature, we mark
    /// the surviving prev block with this flag so the next turn rebuilds
    /// the signature rather than reusing the now-stale one.
    public static func markSignatureInvalidated(_ message: inout [String: Any]) {
        message["_thinking_signature_invalidated"] = true
    }

    /// Check whether a model is Claude-family (= hermes _is_claude_model).
    public static func isClaudeModel(_ model: String?) -> Bool {
        guard let m = model?.lowercased() else { return false }
        return m.hasPrefix("claude-") || m.hasPrefix("claude_") || m.contains("claude")
    }

    /// Whether a model supports adaptive thinking (= hermes _supports_adaptive_thinking).
    public static func supportsAdaptiveThinking(_ model: String) -> Bool {
        let m = model.lowercased()
        return m.contains("opus-4") || m.contains("sonnet-4")
    }

    /// Whether a model forbids sampling params (= hermes _forbids_sampling_params).
    /// Some Anthropic variants reject `temperature` + `top_p` together.
    public static func forbidsSamplingParams(_ model: String) -> Bool {
        // Conservative: only apply to the documented restricted variants.
        let m = model.lowercased()
        return m.contains("opus-4-1") || m.contains("extended-thinking")
    }

    /// Get Anthropic max-output for a model (= hermes _get_anthropic_max_output).
    public static func maxOutputTokens(for model: String) -> Int {
        let m = model.lowercased()
        if m.contains("opus-4") { return 32_000 }
        if m.contains("sonnet-4") { return 64_000 }
        if m.contains("haiku") { return 8_192 }
        if m.contains("opus-3") { return 4_096 }
        if m.contains("sonnet-3") { return 8_192 }
        return 4_096
    }
}