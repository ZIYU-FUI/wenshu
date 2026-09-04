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
}