//
//  WenshuLLMTypesTests.swift · Wenshu · v0.38 Batch 3 sub-step 13
//
//  Tests for WenshuLLMMessage + WenshuLLMRequest + WenshuLLMBlock +
//  WenshuLLMUsage + WenshuLLMResponse + WenshuLLMError (= v0.35 ticket 001).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = WenshuVerifier.swift is v0.35
//  ticket 001 (= my work, modified in v0.36 + v0.37 to add 7-connector
//  support and Union content block decode).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuLLM types deep (= v0.35 ticket 001)")
struct WenshuLLMTypesDeepTests {

    // MARK: - WenshuLLMMessage

    @Test("WenshuLLMMessage: construction with role + content")
    func messageConstruction() {
        let message = WenshuLLMMessage(role: "user", content: "Hello")
        #expect(message.role == "user")
        #expect(message.content == "Hello")
    }

    @Test("WenshuLLMMessage: Codable round-trip")
    func messageCodable() throws {
        let message = WenshuLLMMessage(role: "assistant", content: "Hi there")
        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(WenshuLLMMessage.self, from: encoded)
        #expect(decoded.role == "assistant")
        #expect(decoded.content == "Hi there")
    }

    // MARK: - WenshuLLMRequest

    @Test("WenshuLLMRequest: construction with all fields")
    func requestConstruction() {
        let request = WenshuLLMRequest(
            model: "claude-3-5-sonnet",
            max_tokens: 1024,
            messages: [
                WenshuLLMMessage(role: "user", content: "Hello")
            ]
        )
        #expect(request.model == "claude-3-5-sonnet")
        #expect(request.max_tokens == 1024)
        #expect(request.messages.count == 1)
    }

    @Test("WenshuLLMRequest: Codable round-trip")
    func requestCodable() throws {
        let request = WenshuLLMRequest(
            model: "test-model",
            max_tokens: 512,
            messages: [
                WenshuLLMMessage(role: "user", content: "Q1"),
                WenshuLLMMessage(role: "assistant", content: "A1")
            ]
        )
        let encoded = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(WenshuLLMRequest.self, from: encoded)
        #expect(decoded.model == "test-model")
        #expect(decoded.max_tokens == 512)
        #expect(decoded.messages.count == 2)
    }

    // MARK: - WenshuLLMBlock (= union content block)

    @Test("WenshuLLMBlock: text case construction")
    func blockTextCase() {
        let block = WenshuLLMBlock.text("Hello world")
        #expect(block == .text("Hello world"))
    }

    @Test("WenshuLLMBlock: thinking case construction")
    func blockThinkingCase() {
        let block = WenshuLLMBlock.thinking(text: "Reasoning here", signature: "sig-1")
        #expect(block == .thinking(text: "Reasoning here", signature: "sig-1"))
    }

    @Test("WenshuLLMBlock: toolUse case construction")
    func blockToolUseCase() {
        let block = WenshuLLMBlock.toolUse(id: "t1", name: "ReadFile", input: "{}")
        #expect(block == .toolUse(id: "t1", name: "ReadFile", input: "{}"))
    }

    @Test("WenshuLLMBlock: unknown case construction")
    func blockUnknownCase() {
        let block = WenshuLLMBlock.unknown(type: "future_block", raw: "raw content")
        #expect(block == .unknown(type: "future_block", raw: "raw content"))
    }

    @Test("WenshuLLMBlock: Codable round-trip text")
    func blockTextCodable() throws {
        let block = WenshuLLMBlock.text("Hello")
        let encoded = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(WenshuLLMBlock.self, from: encoded)
        #expect(decoded == block)
    }

    @Test("WenshuLLMBlock: Codable round-trip thinking")
    func blockThinkingCodable() throws {
        let block = WenshuLLMBlock.thinking(text: "Reasoning", signature: "sig")
        let encoded = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(WenshuLLMBlock.self, from: encoded)
        #expect(decoded == block)
    }

    @Test("WenshuLLMBlock: Codable round-trip toolUse")
    func blockToolUseCodable() throws {
        let block = WenshuLLMBlock.toolUse(id: "t1", name: "WriteFile", input: "{\"path\":\"/tmp/x\"}")
        let encoded = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(WenshuLLMBlock.self, from: encoded)
        #expect(decoded == block)
    }

    @Test("WenshuLLMBlock: 4 case types Equatable")
    func blockFourCases() {
        let a = WenshuLLMBlock.text("x")
        let b = WenshuLLMBlock.text("x")
        let c = WenshuLLMBlock.thinking(text: "x", signature: nil)
        let d = WenshuLLMBlock.toolUse(id: "t", name: "X", input: "{}")
        let e = WenshuLLMBlock.unknown(type: "x", raw: "y")
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
        #expect(a != e)
    }

    // MARK: - WenshuLLMUsage

    @Test("WenshuLLMUsage: construction with input + output tokens")
    func usageConstruction() {
        let usage = WenshuLLMUsage(input_tokens: 100, output_tokens: 50)
        #expect(usage.input_tokens == 100)
        #expect(usage.output_tokens == 50)
    }

    @Test("WenshuLLMUsage: Codable round-trip")
    func usageCodable() throws {
        let usage = WenshuLLMUsage(input_tokens: 100, output_tokens: 50)
        let encoded = try JSONEncoder().encode(usage)
        let decoded = try JSONDecoder().decode(WenshuLLMUsage.self, from: encoded)
        #expect(decoded == usage)
    }

    @Test("WenshuLLMUsage: Equatable")
    func usageEquatable() {
        let a = WenshuLLMUsage(input_tokens: 10, output_tokens: 5)
        let b = WenshuLLMUsage(input_tokens: 10, output_tokens: 5)
        #expect(a == b)
    }

    // MARK: - WenshuLLMResponse

    @Test("WenshuLLMResponse: construction with all fields")
    func responseConstruction() {
        let usage = WenshuLLMUsage(input_tokens: 10, output_tokens: 5)
        let response = WenshuLLMResponse(
            id: "msg-1",
            model: "claude-3-5-sonnet",
            role: "assistant",
            content: [WenshuLLMBlock.text("Hello")],
            stop_reason: "end_turn",
            usage: usage
        )
        #expect(response.id == "msg-1")
        #expect(response.model == "claude-3-5-sonnet")
        #expect(response.role == "assistant")
        #expect(response.content.count == 1)
        #expect(response.stop_reason == "end_turn")
        #expect(response.usage != nil)
    }

    @Test("WenshuLLMResponse: stop_reason defaults to nil")
    func responseStopReasonDefault() {
        let response = WenshuLLMResponse(
            id: "msg",
            model: "test",
            role: "assistant",
            content: []
        )
        #expect(response.stop_reason == nil)
    }

    @Test("WenshuLLMResponse: usage defaults to nil")
    func responseUsageDefault() {
        let response = WenshuLLMResponse(
            id: "msg",
            model: "test",
            role: "assistant",
            content: []
        )
        #expect(response.usage == nil)
    }
}

@Suite("WenshuLLMError deep (= v0.35 ticket 001)")
struct WenshuLLMErrorDeepTests {

    @Test("WenshuLLMError.errorDescription: missingAPIKey")
    func errorMissingAPIKey() {
        let error = WenshuLLMError.missingAPIKey
        let desc = error.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("API key") || desc!.contains("key"))
    }

    @Test("WenshuLLMError.errorDescription: invalidBaseURL")
    func errorInvalidBaseURL() {
        let error = WenshuLLMError.invalidBaseURL(url: "not a url")
        let desc = error.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("not a url"))
    }

    @Test("WenshuLLMError.errorDescription: httpError")
    func errorHttp() {
        let error = WenshuLLMError.httpError(statusCode: 500, body: "server error")
        let desc = error.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("500"))
    }
}
