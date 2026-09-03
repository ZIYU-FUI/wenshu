//
//  AnthropicStreamingTests.swift · Wenshu · v0.37 Batch 2.2 sub-step 2
//
//  Tests for Anthropic streaming decoder, including v0.37 thinking_delta
//  support added in Batch 2.2 sub-step 1.
//
//  Per 老板 cadence 2026-09-03 '继续移植' + 'PO 全链路方法论执行,
//  不要跳步骤' + '翻译这个事做完一起验视觉和前端流程' + '1 RULE 1 commit'.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AnthropicStreaming (= L30 thinking + tool_use decoder)")
struct AnthropicStreamingTests {

    @Test("decode content_block_start with type=thinking")
    func decodeContentBlockStartThinking() {
        let data = """
        {
            "index": 0,
            "content_block": {
                "type": "thinking",
                "thinking": ""
            }
        }
        """
        let chunk = AnthropicSSEDecoder.decode(event: "content_block_start", data: data)
        #expect(chunk != nil)
        if case .contentBlockStart(let blockType, let blockIndex, let toolId, let toolName) = chunk?.kind {
            #expect(blockType == "thinking")
            #expect(blockIndex == 0)
            #expect(toolId == nil)
            #expect(toolName == nil)
        } else {
            Issue.record("expected contentBlockStart kind")
        }
    }

    @Test("decode content_block_delta with type=thinking_delta")
    func decodeThinkingDelta() {
        let data = """
        {
            "index": 0,
            "delta": {
                "type": "thinking_delta",
                "thinking": "Reasoning about the request..."
            }
        }
        """
        let chunk = AnthropicSSEDecoder.decode(event: "content_block_delta", data: data)
        #expect(chunk != nil)
        if case .contentBlockDelta(let blockIndex, let textDelta, let inputDelta, let thinkingDelta) = chunk?.kind {
            #expect(blockIndex == 0)
            #expect(textDelta == nil)
            #expect(inputDelta == nil)
            #expect(thinkingDelta == "Reasoning about the request...")
        } else {
            Issue.record("expected contentBlockDelta kind with thinking")
        }
    }

    @Test("decode content_block_delta with type=text_delta (text path)")
    func decodeTextDelta() {
        let data = """
        {
            "index": 1,
            "delta": {
                "type": "text_delta",
                "text": "Hello world"
            }
        }
        """
        let chunk = AnthropicSSEDecoder.decode(event: "content_block_delta", data: data)
        #expect(chunk != nil)
        if case .contentBlockDelta(_, let textDelta, let inputDelta, let thinkingDelta) = chunk?.kind {
            #expect(textDelta == "Hello world")
            #expect(inputDelta == nil)
            #expect(thinkingDelta == nil)
        } else {
            Issue.record("expected contentBlockDelta kind with text")
        }
    }

    @Test("decode content_block_delta with type=input_json_delta (tool path)")
    func decodeInputJsonDelta() {
        let data = """
        {
            "index": 2,
            "delta": {
                "type": "input_json_delta",
                "partial_json": "{\\"path\\":\\"/tmp/test.md\\"}"
            }
        }
        """
        let chunk = AnthropicSSEDecoder.decode(event: "content_block_delta", data: data)
        #expect(chunk != nil)
        if case .contentBlockDelta(_, let textDelta, let inputDelta, let thinkingDelta) = chunk?.kind {
            #expect(textDelta == nil)
            #expect(inputDelta == "{\"path\":\"/tmp/test.md\"}")
            #expect(thinkingDelta == nil)
        } else {
            Issue.record("expected contentBlockDelta kind with input_json")
        }
    }

    @Test("decode content_block_start with type=tool_use")
    func decodeContentBlockStartToolUse() {
        let data = """
        {
            "index": 0,
            "content_block": {
                "type": "tool_use",
                "id": "tool_123",
                "name": "ReadFile"
            }
        }
        """
        let chunk = AnthropicSSEDecoder.decode(event: "content_block_start", data: data)
        #expect(chunk != nil)
        if case .contentBlockStart(let blockType, _, let toolId, let toolName) = chunk?.kind {
            #expect(blockType == "tool_use")
            #expect(toolId == "tool_123")
            #expect(toolName == "ReadFile")
        } else {
            Issue.record("expected contentBlockStart kind with tool_use")
        }
    }

    @Test("decode content_block_stop")
    func decodeContentBlockStop() {
        let data = "{\"index\": 0}"
        let chunk = AnthropicSSEDecoder.decode(event: "content_block_stop", data: data)
        #expect(chunk != nil)
        if case .contentBlockStop(let blockIndex) = chunk?.kind {
            #expect(blockIndex == 0)
        } else {
            Issue.record("expected contentBlockStop kind")
        }
    }

    @Test("decode message_delta with stop_reason")
    func decodeMessageDelta() {
        let data = """
        {
            "delta": {
                "stop_reason": "end_turn"
            }
        }
        """
        let chunk = AnthropicSSEDecoder.decode(event: "message_delta", data: data)
        #expect(chunk != nil)
        if case .messageDelta(let stopReason) = chunk?.kind {
            #expect(stopReason == "end_turn")
        } else {
            Issue.record("expected messageDelta kind")
        }
    }

    @Test("decode message_stop")
    func decodeMessageStop() {
        let chunk = AnthropicSSEDecoder.decode(event: "message_stop", data: "")
        #expect(chunk != nil)
        if case .messageStop = chunk?.kind {
            // expected
        } else {
            Issue.record("expected messageStop kind")
        }
    }

    @Test("decode ping event")
    func decodePing() {
        let chunk = AnthropicSSEDecoder.decode(event: "ping", data: "")
        #expect(chunk != nil)
        if case .ping = chunk?.kind {
            // expected
        } else {
            Issue.record("expected ping kind")
        }
    }

    @Test("decode unknown event returns .unknown")
    func decodeUnknown() {
        let chunk = AnthropicSSEDecoder.decode(event: "unknown_event", data: "")
        #expect(chunk != nil)
        if case .unknown(let event) = chunk?.kind {
            #expect(event == "unknown_event")
        } else {
            Issue.record("expected unknown kind")
        }
    }

    @Test("decode invalid JSON returns nil")
    func decodeInvalidJSON() {
        let chunk = AnthropicSSEDecoder.decode(event: "content_block_start", data: "not json")
        #expect(chunk == nil)
    }
}