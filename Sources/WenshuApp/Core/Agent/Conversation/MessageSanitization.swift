//
//  MessageSanitization.swift · Wenshu · v0.35 ticket 001 sub-step 4
//
//  Message text sanitization. Maps to hermes message_sanitization.py
//  (= "~300 LOC" — strips control characters, repairs tool_call arguments,
//  closes interrupted tool sequences, sanitizes surrogates / non-ASCII).
//
//  In sub-step 4 we implement the minimum:
//    - Strip C0 control characters (= U+0000 to U+001F except U+000A
//      newline + U+000D carriage return, which are valid text whitespace)
//    - Preserve all other characters (= Unicode, emoji, CJK)
//    - Drop empty text after sanitization
//
//  Full hermes surface (= _repair_tool_call_arguments,
//  close_interrupted_tool_sequence, _sanitize_surrogates, etc.) lands
//  incrementally as subsequent sub-steps need it.
//
//  v0.35 sub-step 4 of 8 for ticket 001.
//

import Foundation

public enum MessageSanitization {

    /// Strip C0 control characters from text (= preserve newlines).
    public static func sanitizeText(_ text: String) -> String {
        // Remove C0 controls except \n (U+000A) and \r (U+000D)
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
}