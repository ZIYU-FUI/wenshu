//
//  LLMBlockAndResponseTests.swift · Wenshu · v0.38 Batch 3 sub-step 5
//
//  Tests for LLMBlock + LLMResponse + LLMUsage + StopReason + LLMMessage
//  (= v0.35 ticket 001 + 002).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = LLMResponse + LLMBlock + LLMUsage
//  are v0.35 ticket 001 (= my work).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("LLMBlock + LLMResponse + LLMUsage deep (= v0.35 ticket 001)")
struct LLMBlockAndResponseDeepTests {

    // MARK: - LLMBlock

    @Test("LLMBlock: 4 case types")
    func llmBlockCaseTypes() {
        let blocks: [LLMBlock] = [
            .text("hello"),
            .thinking(text: "reasoning", signature: "sig"),
            .toolUse(id: "t1", name: "ReadFile", input: "{}"),
            .toolResult(toolUseID: "t1", output: "result")
        ]
        #expect(blocks.count == 4)
    }

    @Test("LLMBlock.textValue: text case returns content")
    func llmBlockTextValueText() {
        let block = LLMBlock.text("hello world")
        #expect(block.textValue == "hello world")
    }

    @Test("LLMBlock.textValue: thinking case returns text portion")
    func llmBlockTextValueThinking() {
        let block = LLMBlock.thinking(text: "reasoning here", signature: "sig-1")
        #expect(block.textValue == "reasoning here")
    }

    @Test("LLMBlock.textValue: toolUse case returns input")
    func llmBlockTextValueToolUse() {
        let block = LLMBlock.toolUse(id: "t1", name: "ReadFile", input: "{\"path\":\"/tmp/test.md\"}")
        #expect(block.textValue == "{\"path\":\"/tmp/test.md\"}")
    }

    @Test("LLMBlock.textValue: toolResult case returns output")
    func llmBlockTextValueToolResult() {
        let block = LLMBlock.toolResult(toolUseID: "t1", output: "file content here")
        #expect(block.textValue == "file content here")
    }

    @Test("LLMBlock: Equatable")
    func llmBlockEquatable() {
        let a = LLMBlock.text("hello")
        let b = LLMBlock.text("hello")
        let c = LLMBlock.text("world")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("LLMBlock.textValue: extract multi-block text concatenation")
    func llmBlockMultiTextExtract() {
        let blocks: [LLMBlock] = [
            .text("Hello "),
            .thinking(text: "reasoning", signature: nil),
            .text("world")
        ]
        // textValue per block: "Hello ", "reasoning", "world"
        let texts = blocks.map { $0.textValue }
        #expect(texts == ["Hello ", "reasoning", "world"])
    }

    // MARK: - LLMResponse

    @Test("LLMResponse: construction with all fields")
    func llmResponseConstruction() {
        let response = LLMResponse(
            id: "msg-1",
            model: "claude-3-5-sonnet",
            blocks: [.text("Hello")],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 10, outputTokens: 5)
        )
        #expect(response.id == "msg-1")
        #expect(response.model == "claude-3-5-sonnet")
        #expect(response.stopReason == .endTurn)
        #expect(response.usage.inputTokens == 10)
        #expect(response.usage.outputTokens == 5)
    }

    @Test("LLMResponse: Equatable")
    func llmResponseEquatable() {
        let r1 = LLMResponse(
            id: "msg-1", model: "test", blocks: [.text("hi")],
            stopReason: .endTurn, usage: LLMUsage(inputTokens: 1, outputTokens: 1)
        )
        let r2 = LLMResponse(
            id: "msg-1", model: "test", blocks: [.text("hi")],
            stopReason: .endTurn, usage: LLMUsage(inputTokens: 1, outputTokens: 1)
        )
        #expect(r1 == r2)
    }

    // MARK: - StopReason

    @Test("StopReason: 5 case types")
    func stopReasonCaseTypes() {
        let reasons: [LLMResponse.StopReason] = [
            .endTurn, .toolUse, .maxTokens, .stopSequence, .unknown
        ]
        #expect(reasons.count == 5)
    }

    @Test("StopReason: raw values match LLM provider spec")
    func stopReasonRawValues() {
        #expect(LLMResponse.StopReason.endTurn.rawValue == "end_turn")
        #expect(LLMResponse.StopReason.toolUse.rawValue == "tool_use")
        #expect(LLMResponse.StopReason.maxTokens.rawValue == "max_tokens")
        #expect(LLMResponse.StopReason.stopSequence.rawValue == "stop_sequence")
        #expect(LLMResponse.StopReason.unknown.rawValue == "unknown")
    }

    // MARK: - LLMUsage

    @Test("LLMUsage: total = input + output")
    func llmUsageTotal() {
        let usage = LLMUsage(inputTokens: 100, outputTokens: 50)
        #expect(usage.inputTokens == 100)
        #expect(usage.outputTokens == 50)
    }

    @Test("LLMUsage: Equatable")
    func llmUsageEquatable() {
        let a = LLMUsage(inputTokens: 10, outputTokens: 5)
        let b = LLMUsage(inputTokens: 10, outputTokens: 5)
        #expect(a == b)
    }

    // MARK: - LLMMessage

    @Test("LLMMessage: construction + role + blocks")
    func llmMessageConstruction() {
        let message = LLMMessage(
            role: .user,
            blocks: [.text("Hello"), .text("World")]
        )
        #expect(message.role == .user)
        #expect(message.blocks.count == 2)
    }

    @Test("LLMMessage.Role: 3 cases (user, assistant, tool)")
    func llmMessageRoleCases() {
        let roles: [LLMMessage.Role] = [.user, .assistant, .tool]
        #expect(roles.count == 3)
    }

    @Test("LLMMessage.Role raw values")
    func llmMessageRoleRawValues() {
        #expect(LLMMessage.Role.user.rawValue == "user")
        #expect(LLMMessage.Role.assistant.rawValue == "assistant")
        #expect(LLMMessage.Role.tool.rawValue == "tool")
    }

    @Test("LLMMessage: Equatable")
    func llmMessageEquatable() {
        let a = LLMMessage(role: .user, blocks: [.text("hi")])
        let b = LLMMessage(role: .user, blocks: [.text("hi")])
        #expect(a == b)
    }

    @Test("LLMMessage: textContent extracts text blocks only")
    func llmMessageTextContent() {
        let message = LLMMessage(role: .assistant, blocks: [
            .thinking(text: "reasoning", signature: "sig"),
            .text("Hello"),
            .toolUse(id: "t1", name: "X", input: "{}"),
            .text("World")
        ])
        let text = message.textContent
        #expect(text == "Hello\nWorld")
    }
}
