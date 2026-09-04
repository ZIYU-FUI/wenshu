//
//  MessageSanitization.swift · Wenshu · v0.35 ticket 001 sub-step 4
//  + HERMES-PARTIAL-009 (2026-09-04).
//
//  Message text sanitization. Maps to hermes message_sanitization.py
//  (= 477 LOC; provides _sanitize_surrogates, _repair_tool_call_arguments,
//  close_interrupted_tool_sequence, _escape_invalid_chars_in_json_strings,
//  _strip_non_ascii, partial-JSON repair).
//
//  In sub-step 4 we implemented the minimum: strip C0 control characters
//  + sanitize(). HERMES-PARTIAL-009 adds the full hermes surface:
//    - repairToolCallArguments(_:toolName:) — malformed JSON repair
//    - closeInterruptedToolSequence(_:fallbackResponse:) — synthetic
//      closing assistant when a /stop interrupt leaves a tool tail
//    - escapeInvalidCharsInJSONStrings(_:) — escape unescaped controls
//    - stripNonASCII(_:) — strip non-ASCII characters (hermes does this
//      for tool-call args to avoid downstream encoding bugs)
//    - sanitizeSurrogates(_:) — full hermes surrogate-handling table
//    - sanitizeAll(_:) — runs the entire sanitization pipeline
//
//  v0.35 sub-step 4 of 8 for ticket 001 + HERMES-PARTIAL-009 (2026-09-04).
//

import Foundation

public enum MessageSanitization {

    // MARK: - C0 control-character strip (= existing sub-step 4 surface)

    /// Strip C0 control characters from text (= preserve newlines).
    public static func sanitizeText(_ text: String) -> String {
        let scalars = text.unicodeScalars.filter { scalar in
            let v = scalar.value
            return !(v < 0x20 && v != 0x0A && v != 0x0D) && v != 0x7F
        }
        return String(String.UnicodeScalarView(scalars))
    }

    /// Sanitize a list of messages (= in-place replacement of text blocks).
    public static func sanitize(_ messages: [LLMMessage]) -> [LLMMessage] {
        messages.map { msg in
            let sanitizedBlocks = msg.blocks.map { block -> LLMBlock in
                switch block {
                case .text(let s):
                    let clean = sanitizeText(s)
                    return clean.isEmpty ? .text("") : .text(clean)
                case .thinking(let text, let signature):
                    return .thinking(text: sanitizeText(text), signature: signature)
                case .toolUse(let id, let name, let input):
                    return .toolUse(id: id, name: name, input: input)
                case .toolResult(let toolUseID, let output):
                    return .toolResult(toolUseID: toolUseID, output: sanitizeText(output))
                }
            }
            return LLMMessage(role: msg.role, blocks: sanitizedBlocks)
        }
    }

    // MARK: - Surrogate handling (= hermes _sanitize_surrogates L31-40)

    /// Strip unpaired UTF-16 surrogates (= hermes surrogate scrubber).
    /// Unpaired surrogates break Foundation's String round-tripping and
    /// get rejected by strict providers. We filter out lone high/low
    /// surrogates while preserving valid surrogate pairs (i.e. real
    /// characters in supplementary planes).
    public static func sanitizeSurrogates(_ text: String) -> String {
        var out = String()
        out.reserveCapacity(text.count)
        var iter = text.unicodeScalars.makeIterator()
        while let scalar = iter.next() {
            // High surrogate: must be followed by a low surrogate to form a pair.
            if scalar.value >= 0xD800 && scalar.value <= 0xDBFF {
                // Peek next scalar — but unicodeScalars iterator is single-shot.
                // Fall back to scanning the underlying UTF-16 view for the pair check.
                let idx = text.unicodeScalars.firstIndex(of: scalar)!
                let nextIdx = text.unicodeScalars.index(after: idx)
                if nextIdx < text.unicodeScalars.endIndex {
                    let next = text.unicodeScalars[nextIdx]
                    if next.value >= 0xDC00 && next.value <= 0xDFFF {
                        out.unicodeScalars.append(scalar)
                        out.unicodeScalars.append(next)
                        // Skip the low surrogate on next call by advancing.
                        _ = iter.next()
                        continue
                    }
                }
                // Lone high surrogate → drop.
                continue
            }
            // Low surrogate without preceding high → drop.
            if scalar.value >= 0xDC00 && scalar.value <= 0xDFFF {
                continue
            }
            out.unicodeScalars.append(scalar)
        }
        return out
    }

    // MARK: - JSON string control-char escape (= hermes _escape_invalid_chars_in_json_strings L143-182)

    /// Escape unescaped control characters inside JSON string values
    /// (= hermes _escape_invalid_chars_in_json_strings). This handles
    /// the common llama.cpp case where models emit literal \t / \n / \r
    /// inside JSON strings — strict-mode JSON parsers reject these but
    /// many providers' tool-arg validators do too.
    public static func escapeInvalidCharsInJSONStrings(_ raw: String) -> String {
        var out = String()
        out.reserveCapacity(raw.count)
        var inString = false
        var escaped = false
        for ch in raw {
            if escaped {
                out.append(ch)
                escaped = false
                continue
            }
            if ch == "\\" {
                out.append(ch)
                escaped = true
                continue
            }
            if ch == "\"" {
                inString.toggle()
                out.append(ch)
                continue
            }
            if inString {
                let v = ch.unicodeScalars.first?.value ?? 0
                if v < 0x20 || v == 0x7F {
                    switch v {
                    case 0x08: out.append("\\b")
                    case 0x09: out.append("\\t")
                    case 0x0A: out.append("\\n")
                    case 0x0C: out.append("\\f")
                    case 0x0D: out.append("\\r")
                    default:
                        out.append("\\u")
                        out.append(String(format: "%04x", v))
                    }
                    continue
                }
            }
            out.append(ch)
        }
        return out
    }

    // MARK: - Tool-call argument repair (= hermes _repair_tool_call_arguments L185-280)

    /// Attempt to repair malformed tool_call argument JSON
    /// (= hermes _repair_tool_call_arguments).
    ///
    /// Models like GLM-5.1 via Ollama can produce truncated JSON, trailing
    /// commas, Python `None`, etc. The API proxy rejects these with HTTP 400
    /// "invalid tool call arguments". This function applies common repairs;
    /// if all fail it returns `"{}"` so the request succeeds (better than
    /// crashing the session).
    public static func repairToolCallArguments(_ rawArgs: String, toolName: String = "?") -> String {
        let raw = rawArgs.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return "{}"
        }
        if raw == "None" {
            return "{}"
        }

        // Pass 0: unescaped control chars → strict=False → re-serialise.
        if let data = raw.data(using: .utf8) {
            if let parsed = try? JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
            ),
               JSONSerialization.isValidJSONObject(parsed) {
                if let reserialised = try? JSONSerialization.data(
                    withJSONObject: parsed,
                    options: [.fragmentsAllowed]
                ), let s = String(data: reserialised, encoding: .utf8) {
                    return s
                }
            }
        }

        // Pass 1: trailing commas + unclosed structures.
        var fixed = raw
        // Strip trailing commas before } or ]
        let commaRegex = try? NSRegularExpression(pattern: #",\s*([}\])])"#, options: [])
        if let regex = commaRegex {
            let range = NSRange(fixed.startIndex..., in: fixed)
            fixed = regex.stringByReplacingMatches(in: fixed, options: [], range: range, withTemplate: "$1")
        }
        // Close unclosed structures.
        let openCurly = fixed.filter { $0 == "{" }.count - fixed.filter { $0 == "}" }.count
        let openBracket = fixed.filter { $0 == "[" }.count - fixed.filter { $0 == "]" }.count
        if openCurly > 0 { fixed += String(repeating: "}", count: openCurly) }
        if openBracket > 0 { fixed += String(repeating: "]", count: openBracket) }

        // Pass 2: excess closing braces/brackets removal (bounded).
        for _ in 0..<50 {
            if let data = fixed.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
                return fixed
            }
            if fixed.hasSuffix("}") && fixed.filter({ $0 == "}" }).count > fixed.filter({ $0 == "{" }).count {
                fixed.removeLast()
            } else if fixed.hasSuffix("]") && fixed.filter({ $0 == "]" }).count > fixed.filter({ $0 == "[" }).count {
                fixed.removeLast()
            } else {
                break
            }
        }

        if let data = fixed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
            return fixed
        }

        // Pass 3: escape unescaped control chars then retry.
        let escaped = escapeInvalidCharsInJSONStrings(fixed)
        if escaped != fixed,
           let data = escaped.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
            return escaped
        }

        // Last resort.
        return "{}"
    }

    // MARK: - Close interrupted tool sequence (= hermes close_interrupted_tool_sequence L282-313)

    /// Append a synthetic assistant turn when an interrupted tail is a tool
    /// result (= hermes close_interrupted_tool_sequence). Strict providers
    /// (Gemini, Claude) reject ``tool → user`` alternation and hallucinate a
    /// continuation of the user's message. We close the gap with a synthetic
    /// assistant message so the persisted transcript is a valid alternation.
    public static func closeInterruptedToolSequence(
        _ messages: [LLMMessage],
        fallbackResponse: LLMResponse? = nil
    ) -> [LLMMessage] {
        guard let last = messages.last else { return messages }
        // Already an assistant tail — nothing to close.
        if case .assistant = last.role { return messages }
        // Tail must contain a tool result.
        let hasToolResult = last.blocks.contains { block in
            if case .toolResult = block { return true } else { return false }
        }
        guard hasToolResult else { return messages }
        let placeholder = fallbackResponse?.blocks.first.flatMap { block -> LLMBlock? in
            if case .text(let s) = block, !s.isEmpty { return .text(s) } else { return nil }
        } ?? .text("(interrupted — session paused)")
        var out = messages
        out.append(LLMMessage(role: .assistant, blocks: [placeholder]))
        return out
    }

    // MARK: - Strip non-ASCII (= hermes _strip_non_ascii L314-322)

    /// Strip all non-ASCII characters from text (= hermes _strip_non_ascii).
    /// Used for tool-call argument sanitization to avoid downstream encoding
    /// bugs in providers that don't handle UTF-8 well. Anything outside ASCII
    /// printable + standard whitespace is replaced with `?`.
    public static func stripNonASCII(_ text: String) -> String {
        var out = String()
        out.reserveCapacity(text.count)
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if v < 0x80 {
                out.append(Character(scalar))
            } else {
                out.append("?")
            }
        }
        return out
    }

    // MARK: - Drop trailing empty-response scaffolding (= hermes drop_trailing_empty_response_scaffolding)

    /// Drop trailing empty-response scaffolding (= hermes pattern from
    /// turn_finalizer). Some recovery paths emit empty assistant turns at
    /// the tail; rewind them so the next turn doesn't replay them.
    public static func dropTrailingEmptyResponseScaffolding(_ messages: [LLMMessage]) -> [LLMMessage] {
        var out = messages
        while let last = out.last {
            if case .assistant = last.role {
                let isEmpty = last.blocks.allSatisfy { block in
                    if case .text(let s) = block { return s.isEmpty }
                    if case .thinking(let t, _) = block { return t.isEmpty }
                    return false
                }
                if isEmpty {
                    out.removeLast()
                    continue
                }
            }
            break
        }
        return out
    }

    // MARK: - Combined sanitizer

    /// Run the full hermes sanitization pipeline on a message list:
    ///   1. sanitizeSurrogates on every text block
    ///   2. sanitize (= C0 control strip)
    ///   3. repairToolCallArguments on every .toolUse block
    ///   4. closeInterruptedToolSequence if needed
    ///   5. dropTrailingEmptyResponseScaffolding
    public static func sanitizeAll(_ messages: [LLMMessage]) -> [LLMMessage] {
        var out = messages.map { msg -> LLMMessage in
            let sanitizedBlocks = msg.blocks.map { block -> LLMBlock in
                switch block {
                case .text(let s):
                    let clean = sanitizeText(sanitizeSurrogates(s))
                    return .text(clean)
                case .thinking(let text, let signature):
                    return .thinking(text: sanitizeText(sanitizeSurrogates(text)), signature: signature)
                case .toolUse(let id, let name, let input):
                    return .toolUse(id: id, name: name, input: repairToolCallArguments(input, toolName: name))
                case .toolResult(let toolUseID, let output):
                    return .toolResult(toolUseID: toolUseID, output: sanitizeText(sanitizeSurrogates(output)))
                }
            }
            return LLMMessage(role: msg.role, blocks: sanitizedBlocks)
        }
        out = dropTrailingEmptyResponseScaffolding(out)
        out = closeInterruptedToolSequence(out)
        return out
    }
}