//
//  AnthropicStreaming.swift · Wenshu · v0.35 ticket 004 sub-step 2 + 3
//
//  Anthropic SSE streaming + tool_use round-trip helpers for AnthropicConnector.
//  Originally ticket 004 sub-step 1 (AnthropicConnector.swift) shipped only
//  the synchronous send() path; SSE streaming and tool_use round-trip landed
//  here per Spec-axis (c)-2 finding (= ticket 004 L28-36 acceptance).
//
//  This file uses mattt/EventSource 1.5.1 (= already in Package.swift per
//  AGENTS.md §11.1 third-party library policy; macOS-first MIT, 116 stars).
//

import Foundation
import EventSource

/// Anthropic SSE streaming response chunk (= one Server-Sent Event).
/// Anthropic streams events with type="content_block_start" /
/// "content_block_delta" / "content_block_stop" / "message_delta" /
/// "message_stop".
public struct AnthropicStreamingChunk: Sendable {
    public enum Kind: Sendable {
        case contentBlockStart(blockType: String, blockIndex: Int, toolId: String?, toolName: String?)
        case contentBlockDelta(blockIndex: Int, textDelta: String?, inputDelta: String?, thinkingDelta: String?)
        case contentBlockStop(blockIndex: Int)
        case messageDelta(stopReason: String?)
        case messageStop
        case ping
        case unknown(String)
    }

    public let kind: Kind
}

/// Decode one Anthropic SSE event payload into a structured chunk.
/// Uses JSONSerialization (= Apple Foundation; wenshu §11 hard rule).
public enum AnthropicSSEDecoder {

    public static func decode(event: String, data: String) -> AnthropicStreamingChunk? {
        guard let payload = data.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            return nil
        }

        switch event {
            case "content_block_start":
                guard let index = json["index"] as? Int,
                      let block = json["content_block"] as? [String: Any],
                      let blockType = block["type"] as? String else { return nil }
                if blockType == "tool_use" {
                    let toolId = block["id"] as? String
                    let toolName = block["name"] as? String
                    return AnthropicStreamingChunk(kind: .contentBlockStart(
                        blockType: blockType,
                        blockIndex: index,
                        toolId: toolId,
                        toolName: toolName
                    ))
                }
                return AnthropicStreamingChunk(kind: .contentBlockStart(
                    blockType: blockType,
                    blockIndex: index,
                    toolId: nil,
                    toolName: nil
                ))

            case "content_block_delta":
                guard let index = json["index"] as? Int,
                      let delta = json["delta"] as? [String: Any] else { return nil }
                let deltaType = delta["type"] as? String
                let textDelta = deltaType == "text_delta" ? delta["text"] as? String : nil
                let inputDelta = deltaType == "input_json_delta" ? delta["partial_json"] as? String : nil
                let thinkingDelta = deltaType == "thinking_delta" ? delta["thinking"] as? String : nil
                return AnthropicStreamingChunk(kind: .contentBlockDelta(
                    blockIndex: index,
                    textDelta: textDelta,
                    inputDelta: inputDelta,
                    thinkingDelta: thinkingDelta
                ))

            case "content_block_stop":
                guard let index = json["index"] as? Int else { return nil }
                return AnthropicStreamingChunk(kind: .contentBlockStop(blockIndex: index))

            case "message_delta":
                let stopReason = (json["delta"] as? [String: Any])?["stop_reason"] as? String
                return AnthropicStreamingChunk(kind: .messageDelta(stopReason: stopReason))

            case "message_stop":
                return AnthropicStreamingChunk(kind: .messageStop)

            case "ping":
                return AnthropicStreamingChunk(kind: .ping)

            default:
                return AnthropicStreamingChunk(kind: .unknown(event))
        }
    }
}

/// Anthropic tool_use round-trip state machine.
/// Tracks in-progress tool calls (= received content_block_start with type=tool_use,
 /// collecting input deltas until content_block_stop), then emits a LLMBlock.toolUse
 /// for downstream ToolExecutor dispatch (= ticket 001 sub-step 5 ToolExecutor).
public actor AnthropicToolUseCollector {

    private struct PendingToolUse {
        var id: String
        var name: String
        var inputJSON: String
    }

    private var pendingByIndex: [Int: PendingToolUse] = [:]

    public init() {}

    /// Process one streaming chunk; return finalized LLMBlock.toolUse when
    /// content_block_stop arrives (= input fully collected).
    public func process(chunk: AnthropicStreamingChunk) -> LLMBlock? {
        switch chunk.kind {
            case .contentBlockStart(let blockType, let blockIndex, let toolId, let toolName):
                guard blockType == "tool_use",
                      let id = toolId,
                      let name = toolName else { return nil }
                pendingByIndex[blockIndex] = PendingToolUse(id: id, name: name, inputJSON: "")
                return nil

            case .contentBlockDelta(let blockIndex, _, let inputDelta, _):
                guard var pending = pendingByIndex[blockIndex],
                      let delta = inputDelta else { return nil }
                pending.inputJSON += delta
                pendingByIndex[blockIndex] = pending
                return nil

            case .contentBlockStop(let blockIndex):
                guard let pending = pendingByIndex.removeValue(forKey: blockIndex) else {
                    return nil
                }
                return .toolUse(id: pending.id, name: pending.name, input: pending.inputJSON)

            default:
                return nil
        }
    }
}