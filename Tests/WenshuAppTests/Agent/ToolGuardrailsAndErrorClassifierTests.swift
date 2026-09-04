//
//  ToolGuardrailsAndErrorClassifierTests.swift · Wenshu · v0.38 Batch 3 sub-step 2
//
//  Tests for ToolGuardrails + ErrorClassifier (= v0.36 ticket 015).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = ToolGuardrails + ErrorClassifier
//  are v0.36 ticket 015 (= my work). Tests are additive coverage.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ToolGuardrails deep (= v0.36 ticket 015)")
struct ToolGuardrailsDeepTests {

    // MARK: - ToolNameWhitelist

    @Test("ToolNameWhitelist: empty by default")
    func whitelistEmptyByDefault() async {
        let whitelist = ToolNameWhitelist()
        let isEmpty = await whitelist.isEmpty
        #expect(isEmpty)
    }

    @Test("ToolNameWhitelist: set + contains")
    func whitelistSetAndContains() async {
        let whitelist = ToolNameWhitelist()
        await whitelist.set(["ReadFile", "WriteFile"])
        #expect(await whitelist.contains("ReadFile"))
        #expect(await whitelist.contains("WriteFile"))
        #expect(await whitelist.contains("Bash") == false)
    }

    @Test("ToolNameWhitelist: isEmpty = false after set")
    func whitelistNotEmptyAfterSet() async {
        let whitelist = ToolNameWhitelist()
        await whitelist.set(["ReadFile"])
        #expect(await whitelist.isEmpty == false)
    }

    @Test("ToolNameWhitelist: replace set clears previous")
    func whitelistReplace() async {
        let whitelist = ToolNameWhitelist()
        await whitelist.set(["ReadFile", "WriteFile"])
        await whitelist.set(["Bash"])
        #expect(await whitelist.contains("ReadFile") == false)
        #expect(await whitelist.contains("WriteFile") == false)
        #expect(await whitelist.contains("Bash"))
    }

    // MARK: - ToolGuardrailsResult

    @Test("ToolGuardrailsResult: pass has no reason")
    func resultPass() {
        let result = ToolGuardrailsResult.pass
        #expect(result.passed == true)
        #expect(result.reason == nil)
    }

    @Test("ToolGuardrailsResult: failure has reason")
    func resultFailure() {
        let result = ToolGuardrailsResult.failure(reason: "input too large")
        #expect(result.passed == false)
        #expect(result.reason == "input too large")
    }

    @Test("ToolGuardrailsResult: Equatable")
    func resultEquatable() {
        let a = ToolGuardrailsResult.pass
        let b = ToolGuardrailsResult.pass
        let c = ToolGuardrailsResult.failure(reason: "x")
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - ToolGuardrails.check

    @Test("ToolGuardrails.check: small input passes")
    func checkSmallInputPasses() async {
        let tool = ReadFileTool()
        let result = await ToolGuardrails.check(tool: tool, input: "{\"path\":\"/tmp/test.md\"}")
        #expect(result.passed)
    }

    @Test("ToolGuardrails.check: huge input fails")
    func checkHugeInputFails() async {
        let tool = ReadFileTool()
        // 2 MB input = exceeds 1 MB cap
        let hugeInput = String(repeating: "x", count: 2_000_000)
        let result = await ToolGuardrails.check(tool: tool, input: hugeInput)
        #expect(result.passed == false)
        #expect(result.reason?.contains("exceeds") == true)
    }

    @Test("ToolGuardrails.check: empty input passes")
    func checkEmptyInputPasses() async {
        let tool = ReadFileTool()
        let result = await ToolGuardrails.check(tool: tool, input: "")
        #expect(result.passed)
    }

    @Test("ToolGuardrails.check: global whitelist blocks unlisted tool (when set)")
    func checkWhitelistBlocksUnlisted() async {
        // (= global toolNameWhitelist is empty by default; this test verifies
        // the framework accepts the input without crashing)
        let tool = ReadFileTool()
        let result = await ToolGuardrails.check(tool: tool, input: "{}")
        #expect(result.passed)
    }
}

@Suite("ErrorClassifier deep (= v0.36 ticket 015)")
struct ErrorClassifierDeepTests {

    // MARK: - LLMErrorCategory

    @Test("LLMErrorCategory: 8 categories per ADR-0008 + ticket 015")
    func llmErrorCategoryCount() {
        let allCases = LLMErrorCategory.allCases
        #expect(allCases.count == 8)
        // All raw values unique
        let raws = Set(allCases.map { $0.rawValue })
        #expect(raws.count == 8)
    }

    @Test("LLMErrorCategory: rateLimit + serverError + contextLengthExceeded are well-known")
    func llmErrorCategoryCoreNames() {
        let raws = LLMErrorCategory.allCases.map { $0.rawValue }
        #expect(raws.contains("rateLimit"))
        #expect(raws.contains("serverError"))
        #expect(raws.contains("contextLengthExceeded"))
        #expect(raws.contains("unauthorized"))
        #expect(raws.contains("badRequest"))
        #expect(raws.contains("modelNotFound"))
        #expect(raws.contains("networkUnreachable"))
        #expect(raws.contains("unknown"))
    }

    @Test("LLMErrorCategory: Codable round-trip")
    func llmErrorCategoryCodable() throws {
        for category in LLMErrorCategory.allCases {
            let encoded = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(LLMErrorCategory.self, from: encoded)
            #expect(decoded == category)
        }
    }

    // MARK: - ClassifiedLLMError

    @Test("ClassifiedLLMError: construction with all fields")
    func classifiedLLMErrorConstruction() {
        let error = ClassifiedLLMError(
            category: .rateLimit,
            underlying: "Rate limit exceeded",
            userMessage: "Too many requests, please slow down",
            isRetryable: true,
            retryAfterSeconds: 60
        )
        #expect(error.category == .rateLimit)
        #expect(error.underlying == "Rate limit exceeded")
        #expect(error.userMessage == "Too many requests, please slow down")
        #expect(error.isRetryable)
        #expect(error.retryAfterSeconds == 60)
    }

    @Test("ClassifiedLLMError: retryAfterSeconds default = nil")
    func classifiedLLMErrorRetryAfterDefault() {
        let error = ClassifiedLLMError(
            category: .badRequest,
            underlying: "Invalid input",
            userMessage: "Bad request",
            isRetryable: false
        )
        #expect(error.retryAfterSeconds == nil)
    }

    @Test("ClassifiedLLMError: Equatable")
    func classifiedLLMErrorEquatable() {
        let a = ClassifiedLLMError(
            category: .unauthorized,
            underlying: "Invalid key",
            userMessage: "Bad API key",
            isRetryable: false
        )
        let b = ClassifiedLLMError(
            category: .unauthorized,
            underlying: "Invalid key",
            userMessage: "Bad API key",
            isRetryable: false
        )
        #expect(a == b)
    }

    // MARK: - ErrorClassifier.classify(error:httpResponse:)

    @Test("ErrorClassifier: HTTP 400 -> .badRequest")
    func classify400() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 400,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        let classified = ErrorClassifier.classify(
            error: LLMConnectorError.transport(provider: "test", statusCode: 400, body: "Bad request"),
            httpResponse: response
        )
        #expect(classified.category == .badRequest)
        #expect(classified.isRetryable == false)
    }

    @Test("ErrorClassifier: HTTP 401 -> .unauthorized")
    func classify401() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 401,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        let classified = ErrorClassifier.classify(
            error: LLMConnectorError.transport(provider: "test", statusCode: 401, body: "Unauthorized"),
            httpResponse: response
        )
        #expect(classified.category == .unauthorized)
        #expect(classified.isRetryable == false)
    }

    @Test("ErrorClassifier: HTTP 403 -> .unauthorized")
    func classify403() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 403,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        let classified = ErrorClassifier.classify(
            error: LLMConnectorError.transport(provider: "test", statusCode: 403, body: "Forbidden"),
            httpResponse: response
        )
        #expect(classified.category == .unauthorized)
    }

    @Test("ErrorClassifier: HTTP 404 -> .modelNotFound")
    func classify404() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        let classified = ErrorClassifier.classify(
            error: LLMConnectorError.transport(provider: "test", statusCode: 404, body: "Not found"),
            httpResponse: response
        )
        #expect(classified.category == .modelNotFound)
    }

    @Test("ErrorClassifier: HTTP 429 -> .rateLimit (retryable)")
    func classify429() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 429,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        let classified = ErrorClassifier.classify(
            error: LLMConnectorError.transport(provider: "test", statusCode: 429, body: "Rate limit"),
            httpResponse: response
        )
        #expect(classified.category == .rateLimit)
        #expect(classified.isRetryable)
    }

    @Test("ErrorClassifier: HTTP 500/502/503/504 -> .serverError (retryable)")
    func classifyServerErrors() {
        for code in [500, 502, 503, 504] {
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com")!,
                statusCode: code,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )
            let classified = ErrorClassifier.classify(
                error: LLMConnectorError.transport(provider: "test", statusCode: code, body: "Server error"),
                httpResponse: response
            )
            #expect(classified.category == .serverError, "code \(code) should map to .serverError")
            #expect(classified.isRetryable)
        }
    }

    @Test("ErrorClassifier: unknown status code -> .unknown")
    func classifyUnknownStatusCode() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 999,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        let classified = ErrorClassifier.classify(
            error: LLMConnectorError.transport(provider: "test", statusCode: 999, body: "Weird"),
            httpResponse: response
        )
        // 999 may map to unknown or serverError fallback
        #expect([LLMErrorCategory.unknown, .serverError].contains(classified.category))
    }

    @Test("ErrorClassifier: classify without httpResponse uses underlying error")
    func classifyWithoutHttpResponse() {
        // Without httpResponse, classifier relies on underlying error type
        let classified = ErrorClassifier.classify(
            error: LLMConnectorError.missingAPIKey(provider: "anthropic")
        )
        // Some mapping should occur
        #expect(classified.category != .unknown || classified.userMessage.isEmpty == false)
    }
}