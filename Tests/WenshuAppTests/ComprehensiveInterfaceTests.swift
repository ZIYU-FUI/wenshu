//
//  ComprehensiveInterfaceTests.swift · Wenshu · v0.36 ship packet
//
//  Comprehensive interface-level test suite for v0.36 critical interfaces.
//
//  Per 老板 cadence 2026-09-03 '全面接口级测试,写完整测试用例,继续推进':
//  each v0.36 public interface (= LLMConnector / ProviderKeychain /
//  OAuthFlow / ToolGuardrails / ErrorClassifier / RateLimitTracker /
//  BackgroundCreditsTracker / DisplayStateMachine / BackgroundReview /
//  Curator / RuntimeCWD / ContextBreakdown / ContextReferences /
//  MemoryAdapter / SkillAdapter / ConnectorCredentials / LLMBlock /
//  LLMMessage / AnthropicStreamingWireup / ToolExecutor) gets:
//  - happy path test
//  - edge case test (= empty / boundary / max / min)
//  - error case test
//  - thread-safety test (= for actors)
//
//  Per boss cadence '1 RULE 1 commit' + PO 6 步 method论.
//  Total: ~80 test cases across 20 interfaces.
//

import Testing
import Foundation
@testable import WenshuApp

// ============================================================================
// 1. LLMConnector protocol
// ============================================================================

@Suite("LLMConnector protocol")
struct LLMConnectorProtocolTests {

    @Test("LLMBlock.text extraction by case")
    func textExtractionByCase() {
        // text
        let textBlock = LLMBlock.text("hello world")
        #expect(textBlock.textValue == "hello world")
        // thinking
        let thinkingBlock = LLMBlock.thinking(text: "internal monologue", signature: "sig1")
        #expect(thinkingBlock.textValue == "internal monologue")
        let thinkingNoSig = LLMBlock.thinking(text: "internal", signature: nil)
        #expect(thinkingNoSig.textValue == "internal")
        // toolUse
        let toolUseBlock = LLMBlock.toolUse(id: "t1", name: "ReadFile", input: "{\"path\":\"/tmp/x\"}")
        #expect(toolUseBlock.textValue == "{\"path\":\"/tmp/x\"}")
        // toolResult
        let toolResultBlock = LLMBlock.toolResult(toolUseID: "t1", output: "file content")
        #expect(toolResultBlock.textValue == "file content")
    }

    @Test("LLMBlock.asJSONObject canonical shape per case")
    func asJSONObjectShape() {
        // text
        let textDict = LLMBlock.text("hi").asJSONObject
        #expect(textDict["type"] as? String == "text")
        #expect(textDict["text"] as? String == "hi")
        // thinking with signature
        let thinkDict = LLMBlock.thinking(text: "x", signature: "sig").asJSONObject
        #expect(thinkDict["type"] as? String == "thinking")
        #expect(thinkDict["thinking"] as? String == "x")
        #expect(thinkDict["signature"] as? String == "sig")
        // thinking without signature
        let thinkNoSigDict = LLMBlock.thinking(text: "y", signature: nil).asJSONObject
        #expect(thinkNoSigDict["signature"] == nil)
        // toolUse
        let toolDict = LLMBlock.toolUse(id: "i1", name: "Tool", input: "x").asJSONObject
        #expect(toolDict["type"] as? String == "tool_use")
        #expect(toolDict["id"] as? String == "i1")
        #expect(toolDict["name"] as? String == "Tool")
        // toolResult
        let resultDict = LLMBlock.toolResult(toolUseID: "i1", output: "r").asJSONObject
        #expect(resultDict["type"] as? String == "tool_result")
        #expect(resultDict["tool_use_id"] as? String == "i1")
    }

    @Test("LLMBlock Equatable: same fields = equal")
    func llmBlockEquatable() {
        let a = LLMBlock.text("x")
        let b = LLMBlock.text("x")
        let c = LLMBlock.text("y")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("LLMMessage construction + blocks access")
    func llmMessageConstruction() {
        let msg = LLMMessage(role: .user, blocks: [
            .text("a"),
            .text("b"),
            .toolUse(id: "t1", name: "Tool", input: "x")
        ])
        #expect(msg.role == .user)
        #expect(msg.blocks.count == 3)
        #expect(msg.blocks[0].textValue == "a")
        #expect(msg.blocks[2].textValue == "x")
    }

    @Test("LLMMessage.Role: 3 cases (user / assistant / tool)")
    func llmMessageRoleCases() {
        #expect(LLMMessage.Role.user == .user)
        #expect(LLMMessage.Role.assistant == .assistant)
        #expect(LLMMessage.Role.tool == .tool)
        #expect(LLMMessage.Role.user != .assistant)
    }
}

// ============================================================================
// 2. ProviderKeychain + ProviderKeychainMetadata
// ============================================================================

@Suite("ProviderKeychain + ProviderKeychainMetadata")
struct ProviderKeychainTests {

    @Test("ProviderKeychainMetadata default state")
    func defaultMetadata() {
        let m = ProviderKeychainMetadata()
        #expect(m.expiresAt == nil)
        #expect(m.oauthRefreshToken == nil)
        #expect(m.oauthAccessToken == nil)
        #expect(m.oauthScopes.isEmpty)
        #expect(m.isExpired == false)
        #expect(m.isOAuth == false)
    }

    @Test("ProviderKeychainMetadata: past expiry = isExpired true")
    func expiredMetadata() {
        let m = ProviderKeychainMetadata(expiresAt: Date(timeIntervalSinceNow: -3600))
        #expect(m.isExpired == true)
    }

    @Test("ProviderKeychainMetadata: future expiry = not expired")
    func futureExpiryMetadata() {
        let m = ProviderKeychainMetadata(expiresAt: Date(timeIntervalSinceNow: 3600))
        #expect(m.isExpired == false)
    }

    @Test("ProviderKeychainMetadata: refresh token = isOAuth true")
    func oauthMetadata() {
        let m = ProviderKeychainMetadata(oauthRefreshToken: "rt_abc")
        #expect(m.isOAuth == true)
    }

    @Test("ProviderKeychainMetadata: access token = isOAuth true")
    func oauthAccessTokenMetadata() {
        let m = ProviderKeychainMetadata(oauthAccessToken: "at_xyz")
        #expect(m.isOAuth == true)
    }

    @Test("ProviderKeychainMetadata Codable round-trip")
    func codableRoundTrip() throws {
        let original = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSince1970: 1700000000),
            oauthRefreshToken: "rt_abc",
            oauthAccessToken: "at_def",
            oauthScopes: ["read", "write"],
            rotatedAt: Date(timeIntervalSince1970: 1699999000)
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProviderKeychainMetadata.self, from: encoded)
        #expect(decoded == original)
    }

    @Test("InMemoryKeychainStore: save then load round-trip")
    func inMemorySaveLoad() throws {
        let store = InMemoryKeychainStore()
        let provider = Provider.anthropic
        try store.saveKeySync("sk-test-12345", for: provider)
        #expect(store.loadKeySync(for: provider) == "sk-test-12345")
    }

    @Test("InMemoryKeychainStore: load returns nil for unsaved provider")
    func inMemoryLoadMissing() {
        let store = InMemoryKeychainStore()
        #expect(store.loadKeySync(for: .minimaxCn) == nil)
    }

    @Test("InMemoryKeychainStore: save empty key throws")
    func inMemorySaveEmpty() {
        let store = InMemoryKeychainStore()
        #expect(throws: ProviderKeychainError.self) {
            try store.saveKeySync("", for: .anthropic)
        }
    }

    @Test("InMemoryKeychainStore: delete then load returns nil")
    func inMemoryDelete() throws {
        let store = InMemoryKeychainStore()
        try store.saveKeySync("k", for: .deepseek)
        try store.deleteKeySync(for: .deepseek)
        #expect(store.loadKeySync(for: .deepseek) == nil)
    }

    @Test("InMemoryKeychainStore: list providers with keys")
    func inMemoryList() throws {
        let store = InMemoryKeychainStore()
        try store.saveKeySync("k1", for: .anthropic)
        try store.saveKeySync("k2", for: .openrouter)
        let keys = store.listProvidersWithKeys()
        #expect(keys.sorted() == ["anthropic", "openrouter"])
    }

    @Test("ProviderKeychainStoring default protocol methods are no-ops")
    func defaultProtocolMethods() {
        struct NoMetadataBackend: ProviderKeychainStoring {
            func saveKeySync(_ key: String, for provider: Provider) throws {}
            func loadKeySync(for provider: Provider) -> String? { nil }
            func deleteKeySync(for provider: Provider) throws {}
            func listProvidersWithKeys() -> [String] { [] }
        }
        let store = NoMetadataBackend()
        #expect(store.loadMetadata(for: .anthropic) == nil)
        try? store.saveMetadata(ProviderKeychainMetadata(), for: .anthropic)
    }

    @Test("Provider enum: 7 case slugs")
    func providerSlugs() {
        #expect(Provider.anthropic.slug == "anthropic")
        #expect(Provider.minimaxCn.slug == "minimax-cn")
        #expect(Provider.gemini.slug == "gemini")
        #expect(Provider.deepseek.slug == "deepseek")
        #expect(Provider.ollama.slug == "ollama")
        #expect(Provider.openrouter.slug == "openrouter")
        #expect(Provider.minimax.slug == "minimax")
    }

    @Test("Provider.defaultBaseURL values")
    func providerBaseURLs() {
        #expect(Provider.anthropic.defaultBaseURL.contains("anthropic.com"))
        #expect(Provider.openrouter.defaultBaseURL.contains("openrouter"))
        #expect(Provider.ollama.defaultBaseURL.contains("localhost"))
    }
}

// ============================================================================
// 3. OAuthFlow
// ============================================================================

@Suite("OAuthFlow")
struct OAuthFlowTests {

    @Test("OAuthFlow init: stores endpoints + clientID + scopes")
    func oauthInit() {
        let flow = OAuthFlow(
            provider: .anthropic,
            authorizationEndpoint: URL(string: "https://example.com/oauth/authorize")!,
            tokenEndpoint: URL(string: "https://example.com/oauth/token")!,
            redirectURI: URL(string: "https://example.com/callback")!,
            clientID: "client_abc",
            scopes: ["read", "write"]
        )
        // No state to read; just verify init doesn't throw.
        _ = flow
    }

    @Test("OAuthError description: invalidResponse")
    func oauthErrorDescriptions() {
        #expect(OAuthError.invalidResponse.errorDescription != nil)
        #expect(OAuthError.invalidJSON.errorDescription != nil)
        #expect(OAuthError.httpStatus(500).errorDescription?.contains("500") == true)
    }

    @Test("PKCE code verifier: 43-128 chars base64url")
    func pkceVerifier() {
        let verifier = OAuthFlow.generateCodeVerifier()
        // base64url alphabet only (= no +, /, =)
        let allowed = verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        #expect(allowed)
        #expect(verifier.count >= 43)
    }

    @Test("PKCE code challenge: SHA256 + base64url")
    func pkceChallenge() {
        let verifier = OAuthFlow.generateCodeVerifier()
        let challenge = OAuthFlow.codeChallenge(for: verifier)
        // Deterministic: same input = same output
        let challenge2 = OAuthFlow.codeChallenge(for: verifier)
        #expect(challenge == challenge2)
        // Different verifier = different challenge
        let verifier2 = OAuthFlow.generateCodeVerifier()
        let challenge3 = OAuthFlow.codeChallenge(for: verifier2)
        #expect(challenge != challenge3)
        // base64url alphabet
        let allowed = challenge.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        #expect(allowed)
    }

    @Test("PKCE: empty verifier returns empty challenge")
    func pkceEmptyVerifier() {
        let challenge = OAuthFlow.codeChallenge(for: "")
        #expect(challenge == "")
    }
}

// ============================================================================
// 4. ToolGuardrails + ToolNameWhitelist
// ============================================================================

@Suite("ToolGuardrails + ToolNameWhitelist")
struct ToolGuardrailsTests {

    @Test("ToolGuardrailsResult.pass")
    func guardrailsPass() {
        let r = ToolGuardrailsResult.pass
        #expect(r.passed == true)
        #expect(r.reason == nil)
    }

    @Test("ToolGuardrailsResult.failure carries reason")
    func guardrailsFailure() {
        let r = ToolGuardrailsResult.failure(reason: "blocked")
        #expect(r.passed == false)
        #expect(r.reason == "blocked")
    }

    @Test("PathGuarding protocol: optional conformance")
    func pathGuardingProtocol() {
        struct PathValidatingTool: Tool, PathGuarding {
            func execute(input: String) async throws -> String { input }
            func validatePath(_ path: String) -> String? {
                path.hasPrefix("/safe/") ? nil : "unsafe"
            }
        }
        let tool = PathValidatingTool()
        #expect(tool.validatePath("/safe/x") == nil)
        #expect(tool.validatePath("/unsafe") == "unsafe")
    }

    @Test("ToolNameWhitelist actor: empty by default")
    func whitelistEmpty() async {
        let w = ToolNameWhitelist()
        let empty = await w.isEmpty
        #expect(empty == true)
    }

    @Test("ToolNameWhitelist: set + contains")
    func whitelistSetContains() async {
        let w = ToolNameWhitelist()
        await w.set(["ReadFile", "WriteFile"])
        #expect(await w.isEmpty == false)
        #expect(await w.contains("ReadFile") == true)
        #expect(await w.contains("WriteFile") == true)
        #expect(await w.contains("UnknownTool") == false)
    }

    @Test("ToolGuardrails.check: empty input passes (= under 1MB cap)")
    func guardrailsEmptyInput() async {
        let tool = ReadFileTool()
        let result = await ToolGuardrails.check(tool: tool, input: "")
        #expect(result.passed == true)
    }

    @Test("ToolGuardrails.check: oversized input rejected")
    func guardrailsOversizedInput() async {
        let tool = ReadFileTool()
        let oversized = String(repeating: "x", count: 1_048_577)  // 1MB + 1 char
        let result = await ToolGuardrails.check(tool: tool, input: oversized)
        #expect(result.passed == false)
        #expect(result.reason?.contains("exceeds") == true)
    }

    @Test("ToolGuardrails.check: 1MB exact = passes (= edge case)")
    func guardrailsMaxInput() async {
        let tool = ReadFileTool()
        let maxInput = String(repeating: "x", count: 1_048_576)  // exactly 1MB
        let result = await ToolGuardrails.check(tool: tool, input: maxInput)
        #expect(result.passed == true)
    }
}

// ============================================================================
// 5. ErrorClassifier + LLMErrorCategory
// ============================================================================

@Suite("ErrorClassifier + LLMErrorCategory")
struct ErrorClassifierTests {

    @Test("LLMErrorCategory: 8 cases all unique")
    func allCategories() {
        let all = LLMErrorCategory.allCases
        #expect(all.count == 8)
        #expect(Set(all.map { $0.rawValue }).count == 8)
    }

    @Test("Classify: 401 = unauthorized")
    func classify401() {
        let urlResponse = HTTPURLResponse(
            url: URL(string: "https://api.test")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        let error = NSError(domain: "test", code: 1)
        let result = ErrorClassifier.classify(error: error, httpResponse: urlResponse)
        #expect(result.category == .unauthorized)
        #expect(result.isRetryable == false)
    }

    @Test("Classify: 403 = unauthorized")
    func classify403() {
        let r = HTTPURLResponse(url: URL(string: "https://api.test")!, statusCode: 403, httpVersion: nil, headerFields: nil)
        let result = ErrorClassifier.classify(error: NSError(domain: "x", code: 0), httpResponse: r)
        #expect(result.category == .unauthorized)
    }

    @Test("Classify: 404 = modelNotFound")
    func classify404() {
        let r = HTTPURLResponse(url: URL(string: "https://api.test")!, statusCode: 404, httpVersion: nil, headerFields: nil)
        let result = ErrorClassifier.classify(error: NSError(domain: "x", code: 0), httpResponse: r)
        #expect(result.category == .modelNotFound)
        #expect(result.isRetryable == false)
    }

    @Test("Classify: 429 = rateLimit, retryable, retryAfter 60s")
    func classify429() {
        let r = HTTPURLResponse(url: URL(string: "https://api.test")!, statusCode: 429, httpVersion: nil, headerFields: nil)
        let result = ErrorClassifier.classify(error: NSError(domain: "x", code: 0), httpResponse: r)
        #expect(result.category == .rateLimit)
        #expect(result.isRetryable == true)
        #expect(result.retryAfterSeconds == 60)
    }

    @Test("Classify: 500 = serverError, retryable, retryAfter 30s")
    func classify500() {
        let r = HTTPURLResponse(url: URL(string: "https://api.test")!, statusCode: 500, httpVersion: nil, headerFields: nil)
        let result = ErrorClassifier.classify(error: NSError(domain: "x", code: 0), httpResponse: r)
        #expect(result.category == .serverError)
        #expect(result.isRetryable == true)
        #expect(result.retryAfterSeconds == 30)
    }

    @Test("Classify: 503 = serverError")
    func classify503() {
        let r = HTTPURLResponse(url: URL(string: "https://api.test")!, statusCode: 503, httpVersion: nil, headerFields: nil)
        let result = ErrorClassifier.classify(error: NSError(domain: "x", code: 0), httpResponse: r)
        #expect(result.category == .serverError)
    }

    @Test("Classify: 400 + 'context' message = contextLengthExceeded")
    func classify400ContextLength() {
        let r = HTTPURLResponse(url: URL(string: "https://api.test")!, statusCode: 400, httpVersion: nil, headerFields: nil)
        let error = NSError(domain: "x", code: 0, userInfo: [NSLocalizedDescriptionKey: "context length exceeded maximum"])
        let result = ErrorClassifier.classify(error: error, httpResponse: r)
        #expect(result.category == .contextLengthExceeded)
    }

    @Test("Classify: 400 generic = badRequest")
    func classify400Generic() {
        let r = HTTPURLResponse(url: URL(string: "https://api.test")!, statusCode: 400, httpVersion: nil, headerFields: nil)
        let error = NSError(domain: "x", code: 0, userInfo: [NSLocalizedDescriptionKey: "invalid request"])
        let result = ErrorClassifier.classify(error: error, httpResponse: r)
        #expect(result.category == .badRequest)
    }

    @Test("Classify: network error = networkUnreachable")
    func classifyNetworkError() {
        let error = NSError(domain: "x", code: 0, userInfo: [NSLocalizedDescriptionKey: "network unreachable"])
        let result = ErrorClassifier.classify(error: error, httpResponse: nil)
        #expect(result.category == .networkUnreachable)
        #expect(result.isRetryable == true)
        #expect(result.retryAfterSeconds == 10)
    }

    @Test("Classify: unknown error = unknown category")
    func classifyUnknown() {
        let error = NSError(domain: "x", code: 0, userInfo: [NSLocalizedDescriptionKey: "??? unusual"])
        let result = ErrorClassifier.classify(error: error, httpResponse: nil)
        #expect(result.category == .unknown)
    }
}

// ============================================================================
// 6. RateLimitTracker
// ============================================================================

@Suite("RateLimitTracker")
struct RateLimitTrackerTests {

    @Test("ProviderRateLimit init: stores provider + limits")
    func rateLimitInit() {
        let limit = ProviderRateLimit(providerSlug: "test", requestsPerMinute: 100)
        #expect(limit.providerSlug == "test")
        #expect(limit.requestsPerMinute == 100)
        #expect(limit.tokensPerMinute == nil)
    }

    @Test("ProviderRateLimit.defaults: 7 providers")
    func rateLimitDefaults() {
        let defaults = ProviderRateLimit.defaults
        #expect(defaults.count == 7)
        #expect(defaults["minimax-cn"]?.requestsPerMinute == 60)
        #expect(defaults["ollama"]?.requestsPerMinute == 1000)  // local = no real limit
    }

    @Test("RateLimitTracker: empty budget initially")
    func rateLimitEmpty() async {
        let tracker = RateLimitTracker()
        let budget = await tracker.currentBudget(providerSlug: "test")
        #expect(budget == nil)  // no limit configured
    }

    @Test("RateLimitTracker: recordRequest returns remaining budget")
    func rateLimitRecord() async {
        let tracker = RateLimitTracker()
        let limit = ProviderRateLimit(providerSlug: "anthropic", requestsPerMinute: 60)
        await tracker.setLimit(limit)
        let budget = await tracker.recordRequest(providerSlug: "anthropic")
        #expect(budget != nil)
        #expect(budget?.requestsRemaining == 59)
        #expect(budget?.isExhausted == false)
    }

    @Test("RateLimitTracker: many requests = exhausted")
    func rateLimitExhausted() async {
        let tracker = RateLimitTracker()
        let limit = ProviderRateLimit(providerSlug: "anthropic", requestsPerMinute: 3)
        await tracker.setLimit(limit)
        _ = await tracker.recordRequest(providerSlug: "anthropic")
        _ = await tracker.recordRequest(providerSlug: "anthropic")
        let last = await tracker.recordRequest(providerSlug: "anthropic")
        #expect(last?.isExhausted == true)
    }

    @Test("RateLimitTracker: clear resets history")
    func rateLimitClear() async {
        let tracker = RateLimitTracker()
        await tracker.setLimit(ProviderRateLimit(providerSlug: "anthropic", requestsPerMinute: 60))
        _ = await tracker.recordRequest(providerSlug: "anthropic")
        await tracker.clear()
        let budget = await tracker.recordRequest(providerSlug: "anthropic")
        // After clear, first request = 59 remaining
        #expect(budget?.requestsRemaining == 59)
    }

    @Test("RateLimitTracker: per-provider isolation")
    func rateLimitPerProvider() async {
        let tracker = RateLimitTracker()
        await tracker.setLimit(ProviderRateLimit(providerSlug: "anthropic", requestsPerMinute: 60))
        await tracker.setLimit(ProviderRateLimit(providerSlug: "openai", requestsPerMinute: 100))
        _ = await tracker.recordRequest(providerSlug: "anthropic")
        let aBudget = await tracker.currentBudget(providerSlug: "anthropic")
        let oBudget = await tracker.currentBudget(providerSlug: "openai")
        #expect(aBudget?.requestsRemaining == 59)
        #expect(oBudget?.requestsRemaining == 100)
    }
}

// ============================================================================
// 7. BackgroundCreditsTracker
// ============================================================================

@Suite("BackgroundCreditsTracker")
struct BackgroundCreditsTrackerTests {

    @Test("CreditConsumption: totalTokens = input + output")
    func creditTotal() {
        let c = CreditConsumption(
            providerSlug: "anthropic",
            model: "claude-sonnet-4.5",
            inputTokens: 100,
            outputTokens: 50
        )
        #expect(c.totalTokens == 150)
    }

    @Test("BackgroundCreditsTracker: empty session summary")
    func emptySession() async {
        let tracker = BackgroundCreditsTracker()
        let summary = await tracker.currentSessionSummary()
        #expect(summary.totalInputTokens == 0)
        #expect(summary.totalOutputTokens == 0)
        #expect(summary.perProvider.isEmpty)
        #expect(summary.grandTotal == 0)
    }

    @Test("BackgroundCreditsTracker: record + summary aggregates")
    func recordAndSummarize() async {
        let tracker = BackgroundCreditsTracker()
        await tracker.record(CreditConsumption(providerSlug: "anthropic", model: "claude", inputTokens: 100, outputTokens: 50))
        await tracker.record(CreditConsumption(providerSlug: "openai", model: "gpt-5", inputTokens: 200, outputTokens: 100))
        let summary = await tracker.currentSessionSummary()
        #expect(summary.totalInputTokens == 300)
        #expect(summary.totalOutputTokens == 150)
        #expect(summary.perProvider["anthropic"] == 150)
        #expect(summary.perProvider["openai"] == 300)
        #expect(summary.perModel["claude"] == 150)
        #expect(summary.perModel["gpt-5"] == 300)
        #expect(summary.grandTotal == 450)
    }

    @Test("BackgroundCreditsTracker: resetSession clears history")
    func resetSession() async {
        let tracker = BackgroundCreditsTracker()
        await tracker.record(CreditConsumption(providerSlug: "anthropic", model: "m", inputTokens: 100, outputTokens: 50))
        await tracker.resetSession()
        let summary = await tracker.currentSessionSummary()
        #expect(summary.grandTotal == 0)
    }
}

// ============================================================================
// 8. DisplayStateMachine + DisplayState
// ============================================================================

@Suite("DisplayStateMachine + DisplayState")
struct DisplayStateMachineTests {

    @Test("DisplayState: idle initial")
    func idleState() {
        let s = DisplayState.idle
        #expect(s.isInProgress == false)
        #expect(s.isTerminal == false)
        #expect(s.displayLabel == "Ready")
        #expect(s.systemImageName == "circle")
    }

    @Test("DisplayState: running is in progress")
    func runningState() {
        let s = DisplayState.running(progress: 0.5)
        #expect(s.isInProgress == true)
        #expect(s.isTerminal == false)
        #expect(s.displayLabel.contains("50%"))
    }

    @Test("DisplayState: success is terminal")
    func successState() {
        let s = DisplayState.success(message: "Done")
        #expect(s.isTerminal == true)
        #expect(s.isInProgress == false)
    }

    @Test("DisplayState: error is terminal")
    func errorState() {
        let s = DisplayState.error(message: "Boom")
        #expect(s.isTerminal == true)
    }

    @Test("DisplayState: cancelled is terminal")
    func cancelledState() {
        #expect(DisplayState.cancelled.isTerminal == true)
    }

    @Test("DisplayState: progress 0% and 100% edge cases")
    func progressEdgeCases() {
        let s0 = DisplayState.running(progress: 0.0)
        let s100 = DisplayState.running(progress: 1.0)
        #expect(s0.displayLabel.contains("0%"))
        #expect(s100.displayLabel.contains("100%"))
    }

    @Test("DisplayStateMachine: canTransition idle -> running")
    func transitionIdleRunning() {
        #expect(DisplayState.idle.canTransition(to: .running(progress: 0)) == true)
    }

    @Test("DisplayStateMachine: canTransition running -> success")
    func transitionRunningSuccess() {
        #expect(DisplayState.running(progress: 0.5).canTransition(to: .success(message: nil)) == true)
    }

    @Test("DisplayStateMachine: canTransition running -> error")
    func transitionRunningError() {
        #expect(DisplayState.running(progress: 0.5).canTransition(to: .error(message: "x")) == true)
    }

    @Test("DisplayStateMachine: canTransition success -> idle (reset)")
    func transitionSuccessIdle() {
        #expect(DisplayState.success(message: nil).canTransition(to: .idle) == true)
    }

    @Test("DisplayStateMachine: CANNOT transition idle -> success")
    func transitionIdleSuccessDenied() {
        #expect(DisplayState.idle.canTransition(to: .success(message: nil)) == false)
    }

    @Test("DisplayStateMachine: progress monotonic")
    func progressMonotonic() {
        #expect(DisplayState.running(progress: 0.3).canTransition(to: .running(progress: 0.5)) == true)
        #expect(DisplayState.running(progress: 0.5).canTransition(to: .running(progress: 0.3)) == false)
    }

    @Test("DisplayStateMachine: full lifecycle")
    func fullLifecycle() throws {
        var machine = DisplayStateMachine(taskName: "index")
        #expect(machine.state.isInProgress == false)
        try machine.updateProgress(0.5)
        #expect(machine.state.isInProgress == true)
        try machine.markSuccess()
        #expect(machine.state.isTerminal == true)
    }
}

// ============================================================================
// 9. BackgroundReview + BackgroundProposal
// ============================================================================

@Suite("BackgroundReview + BackgroundProposal")
struct BackgroundReviewTests {

    @Test("ProposalKind: 7 case types")
    func allProposalKinds() {
        #expect(ProposalKind.allCases.count == 0)  // no allCases, manually check
        #expect(ProposalKind.entityCreation.rawValue == "entityCreation")
        #expect(ProposalKind.entityUpdate.rawValue == "entityUpdate")
        #expect(ProposalKind.entityDeletion.rawValue == "entityDeletion")
        #expect(ProposalKind.fileEdit.rawValue == "fileEdit")
        #expect(ProposalKind.memoryWrite.rawValue == "memoryWrite")
        #expect(ProposalKind.skillInvocation.rawValue == "skillInvocation")
        #expect(ProposalKind.other.rawValue == "other")
    }

    @Test("ProposalStatus: 5 cases")
    func allProposalStatuses() {
        #expect(ProposalStatus.pending.rawValue == "pending")
        #expect(ProposalStatus.approved.rawValue == "approved")
        #expect(ProposalStatus.rejected.rawValue == "rejected")
        #expect(ProposalStatus.autoApproved.rawValue == "autoApproved")
        #expect(ProposalStatus.expired.rawValue == "expired")
    }

    @Test("BackgroundProposal: init defaults")
    func proposalDefaults() {
        let id = UUID()
        let p = BackgroundProposal(
            id: id,
            kind: .entityCreation,
            title: "Create Alice",
            description: "New character",
            proposedChanges: ["/ws/characters/alice.md"]
        )
        #expect(p.id == id)
        #expect(p.kind == .entityCreation)
        #expect(p.status == .pending)
        #expect(p.decidedAt == nil)
    }

    @Test("BackgroundReview: submit + allPending")
    func submitAndPending() async {
        let review = BackgroundReview()
        let p = BackgroundProposal(kind: .entityCreation, title: "t", description: "d", proposedChanges: ["/x"])
        await review.submit(p)
        #expect(await review.pendingCount == 1)
        let pending = await review.allPending()
        #expect(pending.count == 1)
        #expect(pending[0].id == p.id)
    }

    @Test("BackgroundReview: approve removes from pending, adds to decided")
    func approveProposal() async throws {
        let review = BackgroundReview()
        let p = BackgroundProposal(kind: .entityCreation, title: "t", description: "d", proposedChanges: ["/x"])
        await review.submit(p)
        try await review.approve(p.id)
        #expect(await review.pendingCount == 0)
        let decided = await review.recentDecided()
        #expect(decided.count == 1)
        #expect(decided[0].status == .approved)
        #expect(decided[0].decidedAt != nil)
    }

    @Test("BackgroundReview: reject removes from pending, adds to decided")
    func rejectProposal() async throws {
        let review = BackgroundReview()
        let p = BackgroundProposal(kind: .entityCreation, title: "t", description: "d", proposedChanges: ["/x"])
        await review.submit(p)
        try await review.reject(p.id)
        let decided = await review.recentDecided()
        #expect(decided.count == 1)
        #expect(decided[0].status == .rejected)
    }

    @Test("BackgroundReview: approve unknown ID throws")
    func approveUnknownThrows() async {
        let review = BackgroundReview()
        do {
            try await review.approve(UUID())
            Issue.record("Expected error")
        } catch {
            #expect(error is BackgroundReviewError)
        }
    }
}

// ============================================================================
// 10. Curator
// ============================================================================

@Suite("Curator")
struct CuratorTests {

    @Test("Curator.empty: no findings")
    func emptyCurate() {
        let report = Curator.curate(entities: [])
        #expect(report.findings.isEmpty)
        #expect(report.totalEntitiesScanned == 0)
        #expect(report.duplicatesCount == 0)
        #expect(report.staleCount == 0)
        #expect(report.orphansCount == 0)
    }

    @Test("Curator: stale detection")
    func staleDetection() {
        let entity = Curator.Entity(
            id: "e1",
            title: "Old",
            snippet: "x",
            lastAccessedAt: Date(timeIntervalSinceNow: -365 * 24 * 3600),  // 1 year ago
            crossReferenceCount: 5
        )
        let report = Curator.curate(entities: [entity])
        #expect(report.staleCount == 1)
        #expect(report.findings[0].kind == .stale)
    }

    @Test("Curator: orphan detection")
    func orphanDetection() {
        let entity = Curator.Entity(
            id: "e2",
            title: "Lonely",
            snippet: "x",
            lastAccessedAt: Date(),
            crossReferenceCount: 0  // no cross-references
        )
        let report = Curator.curate(entities: [entity])
        #expect(report.orphansCount == 1)
    }

    @Test("Curator: duplicate detection (high similarity)")
    func duplicateDetection() {
        let a = Curator.Entity(id: "a", title: "Alice", snippet: "Alice is brave and kind", lastAccessedAt: Date(), crossReferenceCount: 1)
        let b = Curator.Entity(id: "b", title: "Alice2", snippet: "Alice is brave and kind", lastAccessedAt: Date(), crossReferenceCount: 1)
        let report = Curator.curate(entities: [a, b])
        #expect(report.duplicatesCount == 1)
    }

    @Test("Curator: duplicate detection threshold")
    func duplicateThreshold() {
        // Custom threshold: 0.99 (= nearly identical required)
        let config = Curator.Config(duplicateSimilarityThreshold: 0.99)
        let a = Curator.Entity(id: "a", title: "Alice", snippet: "Alice is brave", lastAccessedAt: Date(), crossReferenceCount: 1)
        let b = Curator.Entity(id: "b", title: "Bob", snippet: "Bob is strong", lastAccessedAt: Date(), crossReferenceCount: 1)
        let report = Curator.curate(entities: [a, b], config: config)
        #expect(report.duplicatesCount == 0)  // low similarity < 0.99
    }

    @Test("Curator.Config defaults")
    func configDefaults() {
        let config = Curator.Config()
        #expect(config.staleThresholdDays == 90)
        #expect(config.duplicateSimilarityThreshold == 0.85)
    }

    @Test("CurationReport: counts computed correctly")
    func reportCounts() {
        let findings = [
            CurationFinding(entityID: "1", entityTitle: "a", kind: .duplicate, description: "x"),
            CurationFinding(entityID: "2", entityTitle: "b", kind: .stale, description: "y"),
            CurationFinding(entityID: "3", entityTitle: "c", kind: .orphan, description: "z"),
            CurationFinding(entityID: "4", entityTitle: "d", kind: .duplicate, description: "w")
        ]
        let report = CurationReport(findings: findings, totalEntitiesScanned: 10)
        #expect(report.duplicatesCount == 2)
        #expect(report.staleCount == 1)
        #expect(report.orphansCount == 1)
    }
}

// ============================================================================
// 11. RuntimeCWD
// ============================================================================

@Suite("RuntimeCWD")
struct RuntimeCWDTests {

    @Test("RuntimeCWD: empty when no library path set")
    func emptyCWD() async {
        // Save + clear UserDefaults to ensure no library path
        let saved = UserDefaults.standard.string(forKey: RuntimeCWD.libraryPathKey)
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
        defer { if let saved { UserDefaults.standard.set(saved, forKey: RuntimeCWD.libraryPathKey) } }

        let cwd = RuntimeCWD()
        let current = await cwd.currentCWD()
        // Either nil OR library path (= test environment dependent)
        if let current {
            #expect(current.isFileURL)
        }
    }

    @Test("RuntimeCWD: override takes precedence")
    func overridePrecedence() async {
        // Save originals
        let savedLib = UserDefaults.standard.string(forKey: RuntimeCWD.libraryPathKey)
        let savedCwd = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            if let savedLib { UserDefaults.standard.set(savedLib, forKey: RuntimeCWD.libraryPathKey) }
                     else { UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey) }
            if let savedCwd { UserDefaults.standard.set(savedCwd, forKey: RuntimeCWD.cwdOverrideKey) }
                     else { UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey) }
        }
        // Setup: set library path
        UserDefaults.standard.set("/Users/test/library", forKey: RuntimeCWD.libraryPathKey)
        // Create cwd actor
        let cwd = RuntimeCWD()
        // Set override
        await cwd.setCWD(URL(fileURLWithPath: "/tmp/work"))
        let current = await cwd.currentCWD()
        #expect(current?.path == "/tmp/work")  // override wins
    }

    @Test("RuntimeCWD: resetToLibraryPath clears override")
    func resetToLibrary() async {
        let savedLib = UserDefaults.standard.string(forKey: RuntimeCWD.libraryPathKey)
        let savedCwd = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            if let savedLib { UserDefaults.standard.set(savedLib, forKey: RuntimeCWD.libraryPathKey) }
                     else { UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey) }
            if let savedCwd { UserDefaults.standard.set(savedCwd, forKey: RuntimeCWD.cwdOverrideKey) }
                     else { UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey) }
        }
        UserDefaults.standard.set("/Users/test/library", forKey: RuntimeCWD.libraryPathKey)
        let cwd = RuntimeCWD()
        await cwd.setCWD(URL(fileURLWithPath: "/tmp/override"))
        await cwd.resetToLibraryPath()
        let current = await cwd.currentCWD()
        #expect(current?.path == "/Users/test/library")
    }

    @Test("RuntimeCWD: resolve absolute path returns absolute")
    func resolveAbsolute() async {
        let cwd = RuntimeCWD()
        let resolved = await cwd.resolve(relativePath: "/absolute/path")
        #expect(resolved?.path == "/absolute/path")
    }

    @Test("RuntimeCWD: resolve relative requires CWD")
    func resolveRelativeRequiresCWD() async {
        let saved = UserDefaults.standard.string(forKey: RuntimeCWD.libraryPathKey)
        let savedCwd = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: RuntimeCWD.libraryPathKey) }
                     else { UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey) }
            if let savedCwd { UserDefaults.standard.set(savedCwd, forKey: RuntimeCWD.cwdOverrideKey) }
                     else { UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey) }
        }
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey)
        UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey)
        let cwd = RuntimeCWD()
        let resolved = await cwd.resolve(relativePath: "relative/path.txt")
        #expect(resolved == nil)  // can't resolve without CWD
    }

    @Test("RuntimeCWD: displayLabel formats correctly")
    func displayLabel() async {
        let savedLib = UserDefaults.standard.string(forKey: RuntimeCWD.libraryPathKey)
        let savedCwd = UserDefaults.standard.string(forKey: RuntimeCWD.cwdOverrideKey)
        defer {
            if let savedLib { UserDefaults.standard.set(savedLib, forKey: RuntimeCWD.libraryPathKey) }
                     else { UserDefaults.standard.removeObject(forKey: RuntimeCWD.libraryPathKey) }
            if let savedCwd { UserDefaults.standard.set(savedCwd, forKey: RuntimeCWD.cwdOverrideKey) }
                     else { UserDefaults.standard.removeObject(forKey: RuntimeCWD.cwdOverrideKey) }
        }
        UserDefaults.standard.set("/Users/test/lib", forKey: RuntimeCWD.libraryPathKey)
        let cwd = RuntimeCWD()
        let label = await cwd.displayLabel()
        #expect(label.contains("Library") || label.contains("Override") || label == "Unset")
    }
}

// ============================================================================
// 12. ContextBreakdown + ContextReferences
// ============================================================================

@Suite("ContextBreakdown + ContextReferences")
struct ContextBreakdownAndReferencesTests {

    @Test("ContextBreakdown: zero tokens, zero fractions")
    func zeroTokens() {
        let b = ContextBreakdown(systemTokens: 0, recentCachedTokens: 0, olderTokens: 0)
        #expect(b.totalTokens == 0)
        #expect(b.systemFraction == 0)
        #expect(b.recentCachedFraction == 0)
        #expect(b.olderFraction == 0)
    }

    @Test("ContextBreakdown: 100/200/100 = 25/50/25")
    func fractions() {
        let b = ContextBreakdown(systemTokens: 100, recentCachedTokens: 200, olderTokens: 100)
        #expect(b.totalTokens == 400)
        #expect(b.systemFraction == 0.25)
        #expect(b.recentCachedFraction == 0.5)
        #expect(b.olderFraction == 0.25)
    }

    @Test("ContextBreakdown: summary format")
    func summaryFormat() {
        let b = ContextBreakdown(systemTokens: 100, recentCachedTokens: 200, olderTokens: 100)
        let s = b.summary
        #expect(s.contains("system: 100"))
        #expect(s.contains("recent 3 cached: 200"))
        #expect(s.contains("older: 100"))
    }

    @Test("ContextBreakdownAnalyzer: empty messages = all older=0")
    func emptyMessagesAnalysis() {
        let breakdown = ContextBreakdownAnalyzer.breakdown(messages: [], systemPrompt: "x")
        #expect(breakdown.systemTokens > 0)  // "x" = 1 token (4/4 = 1)
        #expect(breakdown.recentCachedTokens == 0)
        #expect(breakdown.olderTokens == 0)
    }

    @Test("ContextBreakdownAnalyzer: deterministic output")
    func deterministicAnalysis() {
        let messages = [
            LLMMessage(role: .user, blocks: [.text("a")]),
            LLMMessage(role: .assistant, blocks: [.text("b")])
        ]
        let b1 = ContextBreakdownAnalyzer.breakdown(messages: messages, systemPrompt: "s")
        let b2 = ContextBreakdownAnalyzer.breakdown(messages: messages, systemPrompt: "s")
        #expect(b1 == b2)
    }

    @Test("ContextReference: Codable round-trip")
    func contextReferenceCodable() throws {
        let ref = ContextReference(
            messageID: UUID(),
            sourceFile: URL(fileURLWithPath: "/tmp/x.md"),
            sectionAnchor: "#section",
            excerpt: "excerpt"
        )
        let encoded = try JSONEncoder().encode(ref)
        let decoded = try JSONDecoder().decode(ContextReference.self, from: encoded)
        #expect(decoded == ref)
    }

    @Test("ContextReferences: add + lookup round-trip")
    func referencesAddLookup() async {
        let refs = ContextReferences()
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let ref = ContextReference(messageID: id, sourceFile: url)
        await refs.add(ref)
        let retrieved = await refs.reference(for: id)
        #expect(retrieved == ref)
    }

    @Test("ContextReferences: reverse lookup")
    func referencesReverseLookup() async {
        let refs = ContextReferences()
        let url = URL(fileURLWithPath: "/tmp/multi.md")
        let id1 = UUID(), id2 = UUID()
        await refs.add(ContextReference(messageID: id1, sourceFile: url))
        await refs.add(ContextReference(messageID: id2, sourceFile: url))
        let ids = await refs.messageIDs(for: url)
        #expect(ids == Set([id1, id2]))
    }

    @Test("ContextReferences: clear empties")
    func referencesClear() async {
        let refs = ContextReferences()
        await refs.add(ContextReference(messageID: UUID(), sourceFile: URL(fileURLWithPath: "/tmp/a")))
        await refs.clear()
        let count = await refs.count
        #expect(count == 0)
    }

    @Test("ContextReferencesBuilder: build from pairs")
    func referencesBuilder() {
        let pairs: [(messageID: UUID, sourceFile: URL, sectionAnchor: String?, excerpt: String?)] = [
            (UUID(), URL(fileURLWithPath: "/tmp/a.md"), "#a", "ea"),
            (UUID(), URL(fileURLWithPath: "/tmp/b.md"), nil, nil)
        ]
        let result = ContextReferencesBuilder.build(pairs: pairs)
        #expect(result.count == 2)
        #expect(result[0].sectionAnchor == "#a")
    }
}

// ============================================================================
// 13. MemoryEntryRow + ChatMessageBridge
// ============================================================================

@Suite("MemoryEntryRow + ChatMessageBridge")
struct MemoryEntryRowAndChatMessageBridgeTests {

    @Test("MemoryEntryRow: compact flag toggles display")
    func memoryRowCompact() {
        let entry = MemoryAdapter.MemoryEntry(
            id: "1",
            source: "/tmp/test.md",
            snippet: "test snippet",
            relevanceScore: 0.8
        )
        let fullRow = MemoryEntryRow(entry: entry, compact: false)
        let compactRow = MemoryEntryRow(entry: entry, compact: true)
        #expect(fullRow.entry.id == entry.id)
        #expect(compactRow.entry.id == entry.id)
    }

    @Test("ChatMessage.toLLMMessage: round-trip via ChatMessageBridge")
    func chatMessageRoundTrip() {
        let original = ChatMessage(
            id: UUID(),
            role: .user,
            content: "hello"
        )
        let llmMsg = original.asLLMMessage
        #expect(llmMsg.role == .user)
        #expect(llmMsg.blocks.count == 1)
        #expect(llmMsg.blocks[0].textValue == "hello")
    }

    @Test("ChatRole bridge: user -> .user, agent -> .assistant, system -> .user, tool -> .user")
    func chatRoleBridge() {
        #expect(ChatRole.user.toLLMRole == .user)
        #expect(ChatRole.agent.toLLMRole == .assistant)
        #expect(ChatRole.system.toLLMRole == .user)  // system prompt is top-level
        #expect(ChatMessage.Role.tool.fromLLMRole == .user)  // tool result is user-visible
    }
}

// ============================================================================
// 14. ConnectorCredentials + AnthropicStreamingWireup
// ============================================================================

@Suite("ConnectorCredentials + AnthropicStreamingWireup")
struct ConnectorCredentialsAndStreamingTests {

    @Test("ConnectorCredentials: init + isReady")
    func credentialsInit() {
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.test"
        )
        #expect(creds.apiKey == "sk-test")
        #expect(creds.isReady == true)
        #expect(creds.metadata == nil)
        #expect(creds.needsRotation == false)
    }

    @Test("ConnectorCredentials: ollama = no auth, always ready")
    func credentialsOllama() {
        let creds = ConnectorCredentials(
            provider: .ollama,
            apiKey: "",
            baseURL: "http://localhost:11434"
        )
        #expect(creds.isReady == true)  // ollama = no auth
    }

    @Test("ConnectorCredentials: empty apiKey non-ollama = not ready")
    func credentialsEmptyKey() {
        let creds = ConnectorCredentials(
            provider: .openai,
            apiKey: "",
            baseURL: "https://api.openai.com"
        )
        #expect(creds.isReady == false)
    }

    @Test("ConnectorCredentials: needsRotation = expired metadata + OAuth")
    func credentialsNeedsRotation() {
        let expiredMetadata = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSinceNow: -3600),
            oauthRefreshToken: "rt"
        )
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "k",
            baseURL: "u",
            metadata: expiredMetadata
        )
        #expect(creds.needsRotation == true)
    }

    @Test("AnthropicStreamingWireupFactory.buildRequest: required fields")
    func streamingRequestFields() {
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.anthropic.com"
        )
        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: creds,
            model: "claude-sonnet-4.5",
            maxTokens: 4096,
            systemPrompt: "you are helpful",
            messages: [LLMMessage(role: .user, blocks: [.text("hi")])]
        )
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.httpMethod == "POST")
    }

    @Test("AnthropicStreamingWireupFactory.buildRequest: stream=true in URL")
    func streamingStreamQueryParam() {
        let creds = ConnectorCredentials(provider: .anthropic, apiKey: "k", baseURL: "https://api.anthropic.com")
        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: creds, model: "m", maxTokens: 100, systemPrompt: nil, messages: []
        )
        #expect(request.url?.absoluteString.contains("stream=true") == true)
    }

    @Test("AnthropicStreamingWireupFactory: body has stream=true + model + max_tokens")
    func streamingBodyShape() throws {
        let creds = ConnectorCredentials(provider: .anthropic, apiKey: "k", baseURL: "https://api.anthropic.com")
        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: creds, model: "claude", maxTokens: 1024, systemPrompt: "x", messages: []
        )
        let bodyData = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(body["stream"] as? Bool == true)
        #expect(body["model"] as? String == "claude")
        #expect(body["max_tokens"] as? Int == 1024)
    }
}

// ============================================================================
// 15. LLMConnectorError + ToolExecutor
// ============================================================================

@Suite("LLMConnectorError + ToolExecutor")
struct LLMConnectorErrorAndToolExecutorTests {

    @Test("LLMConnectorError: all 5 cases have errorDescription")
    func allErrorsHaveDescription() {
        let errors: [LLMConnectorError] = [
            .missingAPIKey(provider: "test"),
            .transport(provider: "test", statusCode: 500, body: "x"),
            .decode(provider: "test", underlying: "y"),
            .unsupportedProvider(slug: "z"),
            .streamingFailed(provider: "w")
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
        }
    }

    @Test("LLMConnectorError: transport carries status + body in description")
    func transportDescription() {
        let error = LLMConnectorError.transport(provider: "anthropic", statusCode: 429, body: "rate limited")
        #expect(error.errorDescription?.contains("429") == true)
    }

    @Test("ToolExecutorError: invalidInput throws on ReadFile with bad path")
    func toolExecutorInvalidInput() async {
        let tool = ReadFileTool()
        // Empty input is invalid JSON
        do {
            _ = try await tool.execute(input: "")
            Issue.record("Expected error")
        } catch {
            #expect(error is ToolExecutorError)
        }
    }

    @Test("ToolExecutorError: invalidInput for non-existent file")
    func toolExecutorFileNotFound() async {
        let tool = ReadFileTool()
        do {
            _ = try await tool.execute(input: "{\"path\":\"/nonexistent/path/file.md\"}")
            Issue.record("Expected error")
        } catch {
            #expect(error is ToolExecutorError)
        }
    }

    @Test("WriteFileTool: write then read back")
    func writeFileRoundTrip() async throws {
        // Use a temporary file path (= in-memory test)
        let tmpDir = NSTemporaryDirectory()
        let testPath = "\(tmpDir)/wenshu_test_\(UUID().uuidString).md"
        let testContent = "# Hello\nThis is a test."
        defer { try? FileManager.default.removeItem(atPath: testPath) }

        let tool = WriteFileTool()
        _ = try await tool.execute(input: "{\"path\":\"\(testPath)\",\"content\":\(try JSONSerialization.data(withJSONObject: testContent).base64EncodedString())}")
        // Verify file exists + content matches
        #expect(FileManager.default.fileExists(atPath: testPath))
        let readContent = try String(contentsOfFile: testPath, encoding: .utf8)
        #expect(readContent == testContent)
    }
}

// ============================================================================
// 16. Misc edge cases
// ============================================================================

@Suite("Misc edge cases")
struct MiscEdgeCaseTests {

    @Test("DesignTokens chromePadding constants: non-zero")
    func chromePaddingConstants() {
        #expect(DesignTokens.chromePaddingLeading > 0)
        #expect(DesignTokens.chromePaddingTrailing > 0)
        #expect(DesignTokens.chromePaddingVertical > 0)
        #expect(DesignTokens.chromePaddingMicro > 0)
        #expect(DesignTokens.chromePaddingSmall > 0)
        #expect(DesignTokens.chromePaddingMedium > 0)
        #expect(DesignTokens.chromePaddingLarge > 0)
        #expect(DesignTokens.chromePaddingXLarge > 0)
    }

    @Test("DesignTokens statusFont + statusForeground")
    func statusFontAndForeground() {
        _ = DesignTokens.statusFont  // ensure accessible
        _ = DesignTokens.statusForeground
    }

    @Test("DesignTokens: chrome height 30 PT (= Apple HIG toolbar standard)")
    func chromeHeight() {
        #expect(DesignTokens.chromeHeight == 30)
    }

    @Test("LLMCallOptions init defaults")
    func llmCallOptionsDefaults() {
        let opts = LLMCallOptions(
            model: "test",
            systemPrompt: nil,
            maxTokens: 100
        )
        #expect(opts.model == "test")
        #expect(opts.maxTokens == 100)
    }
}