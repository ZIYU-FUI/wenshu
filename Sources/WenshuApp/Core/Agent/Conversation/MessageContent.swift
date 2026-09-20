//
//  MessageContent.swift · Wenshu · v0.35 ticket 001 sub-step 4
//
//  Message block canonicalization. Maps to hermes message_content.py
//  (= "~400 LOC" — canonicalizes block lists: drops empty blocks, coalesces
//  adjacent text blocks, preserves non-text blocks in order).
//
//  Static utility (= no state). TurnFinalizer calls canonicalize at turn end;
//  callers can also use coalesceAdjacentText independently for streaming display.
//
//  v0.35 sub-step 4 of 8 for ticket 001.
//

import Foundation

public enum MessageContent {

    /// Canonicalize a block list: drop empty .text("") blocks,
    /// preserve all other blocks in order.
    public static func canonicalize(_ blocks: [LLMBlock]) -> [LLMBlock] {
        blocks.filter { block in
            switch block {
            case .text(let s):
                return !s.isEmpty
            case .thinking:
                return true  // always preserve
            case .toolUse:
                return true  // always preserve
            case .toolResult:
                return true  // always preserve
            }
        }
    }

    /// Coalesce adjacent .text blocks into one. Non-text blocks (= thinking,
    /// tool_use, tool_result) are NEVER coalesced (= they carry structured
    /// semantics that must be preserved).
    public static func coalesceAdjacentText(_ blocks: [LLMBlock]) -> [LLMBlock] {
        var result: [LLMBlock] = []
        for block in blocks {
            if case .text(let s) = block {
                if case .text(let prevS) = result.last {
                    // Replace last with coalesced version
                    result[result.count - 1] = .text(prevS + s)
                } else {
                    result.append(.text(s))
                }
            } else {
                result.append(block)
            }
        }
        return result
    }

    // MARK: - P11 Hermes-Python gap port (= 1:1 port of hermes
    //         `agent/message_content.py` flatten-message-text
    //         helpers).
    //
    // Wenshu-side wins (= per AGENTS.md §11.3):
    //
    // Direct port of hermes `agent/message_content.py` per
    // spec §3.1 #18 = TICKET-HERMES-PARTIAL-009 follow-up.
    // The target file already had `canonicalize` +
    // `coalesceAdjacentText` at 54 LOC (= the LLMBlock-level
    // canonicalization layer). This P11 ticket adds the 3
    // hermes pure helpers that operate on the raw content
    // shape (= dict / list / string):
    //
    //   1. _field (= hermes L11-L15)
    //   2. _text_from_part (= hermes L17-L32)
    //   3. flatten_message_text (= hermes L34-L50)
    //
    // Hermes Python line ranges cited in doc-comments below
    // (= for traceability back to
    // `/Volumes/ANAN/.hermes/agent/message_content.py`).
    //
    // Per AGENTS.md §11.3 wenshu-side wins:
    //   - Pre-existing canonicalize + coalesceAdjacentText
    //     preserved (= Q112 no regressions).
    //   - The hermes _NON_TEXT_PART_TYPES set (= image /
    //     image_url / input_image / audio / input_audio)
    //     preserved 1:1.
    //   - The hermes TEXT_KEYS tuple (= text / content /
    //     input_text / output_text / summary_text) preserved
    //     1:1.
    //   - The Mapping/duck-typed fallback (= hermes
    //     isinstance(value, Mapping) → value.get(key);
    //     else getattr(value, key, None)) preserved via
    //     Swift's Any + KVC-style pattern match.
    //   - The str() fallback for unknown content types
    //     (= hermes L48-L50) preserved.

    /// Internal helper: extract a field from a dict-like or
    /// object-like value (= hermes `_field` at
    /// `agent/message_content.py` L11-L15).
    ///
    /// - Parameters:
    ///   - value: The dict-like (= Swift `[String: Any]`) or
    ///     object-like value.
    ///   - key: The key to look up.
    /// - Returns: The field value (= or nil if neither
    ///   dict lookup nor attribute lookup succeeds).
    private static func field(_ value: Any, key: String) -> Any? {
        if let dict = value as? [String: Any] {
            return dict[key]
        }
        // Mirror hermes's getattr(value, key, None) fallback
        // for object-like content (= via Swift Mirror).
        let mirror = Mirror(reflecting: value)
        for child in mirror.children {
            if let label = child.label, label == key {
                return child.value
            }
        }
        return nil
    }

    /// Internal helper: extract text from a single content
    /// part (= hermes `_text_from_part` at
    /// `agent/message_content.py` L17-L32).
    ///
    /// Returns empty string for non-text part types (= image
    /// / image_url / input_image / audio / input_audio) or
    /// when the part has no recognized text field.
    private static func textFromPart(_ part: Any) -> String {
        if part is NSNull { return "" }
        if let str = part as? String { return str }

        let partTypeRaw = (field(part, key: "type") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        // Non-text part types return empty (= hermes L21-L23).
        let nonTextTypes: Set<String> = [
            "image", "image_url", "input_image", "audio", "input_audio",
        ]
        if nonTextTypes.contains(partTypeRaw) {
            return ""
        }

        // Walk the recognized text-key list (= hermes L25-L29).
        let textKeys = ["text", "content", "input_text", "output_text", "summary_text"]
        for key in textKeys {
            if let text = field(part, key: key) as? String {
                return text
            }
        }
        return ""
    }

    /// Pure-function: return the visible text from common
    /// chat/responses message content shapes (= hermes
    /// `flatten_message_text` at
    /// `agent/message_content.py` L34-L50).
    ///
    /// Handles 4 content shapes:
    /// - nil → empty string
    /// - string → returned verbatim
    /// - list of parts → text joined with `sep` (= empty
    ///   parts dropped)
    /// - dict or other → single-part text extraction, with
    ///   `str()` fallback for unknown types
    ///
    /// - Parameters:
    ///   - content: The raw content (= typically a string,
    ///     `[Any]` of parts, or `[String: Any]` dict).
    ///   - sep: The separator for joining list parts
    ///     (= default "\n"; = hermes default).
    /// - Returns: The extracted visible text (= never nil;
    ///   = empty string for unrecoverable content).
    public static func flattenMessageText(
        _ content: Any,
        sep: String = "\n"
    ) -> String {
        if content is NSNull { return "" }
        if let str = content as? String { return str }
        if let arr = content as? [Any] {
            let chunks = arr.map { textFromPart($0) }
                .filter { !$0.isEmpty }
            return chunks.joined(separator: sep)
        }
        // Single-part content (= dict or other). Detect image/audio
        // dicts early (= per nonTextTypes) and return empty; = else
        // let textFromPart walk the recognized text keys.
        if let dict = content as? [String: Any],
           let partTypeRaw = (dict["type"] as? String ?? "")
               .trimmingCharacters(in: .whitespaces)
               .lowercased() as String?,
           ["image", "image_url", "input_image", "audio", "input_audio"].contains(partTypeRaw) {
            return ""
        }
        let text = textFromPart(content)
        if !text.isEmpty { return text }
        // str() fallback for unknown content types (= hermes L48-L50).
        return String(describing: content)
    }
}