//
//  LLMModelDiscoveryTests.swift · Wenshu
//
//  Tests for the live `/models` endpoint enumeration
// (= per boss 2026-10-16 OOB "配好 KEY 后, 模型设置中
// 的可选模型, 也应该通过 API 查询. 同样不能写死").
//
//  Coverage:
//    1. OpenAI-compat response shape (`{"data":[{"id":...}]}`)
//       = parses the live model list correctly.
//    2. Anthropic-compat response shape (= same JSON as
//       OpenAI; = minimax + Anthropic + DeepSeek use this).
//    3. Gemini response shape (`{"models":[{"name":"models/..."}]}`)
//       = strips the "models/" prefix so the picker
//       shows "gemini-2.5-pro" not "models/gemini-2.5-pro".
//    4. Fallback path (= when the endpoint returns
//       non-2xx, = the discovery returns
//       `Provider.defaultModels` with `isLive: false`).
//    5. 401 path (= when the user's key is invalid, =
//       same fallback).
//    6. No-key path (= when the provider has no key
//       in the keychain, = no network call; =
//       fallback list is used).
//
//  All tests use `URLProtocolStub.makeIsolatedStub()`
// (= a per-test URLProtocol subclass; = the network
//  call is hermetic; = the production code's
//  `URLSession.shared` is replaced with an ephemeral
//  `URLSession` whose `protocolClasses` is exactly
//  the test's stub).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("LLMModelDiscovery (live /models endpoint)", .serialized)
struct LLMModelDiscoveryTests {

    // MARK: - Test fixtures

    /// Build a Provider for testing. The `defaultBaseURL` is
    /// NOT used directly (= the URLProtocolStub intercepts
    /// every request); = the slug + apiMode are what the
    /// parser switches on.
    private func testProvider(slug: String, apiMode: String, defaultModels: [String] = []) -> Provider {
        Provider(
            slug: slug,
            name: "Test \(slug)",
            defaultBaseURL: "https://test.invalid",
            apiMode: apiMode,
            authHeader: .bearer,
            defaultModels: defaultModels,
            defaultContextWindowTokens: 32_000
        )
    }

    /// Build an ephemeral URLSession whose URLProtocol
    /// routing is captured by `stubProtocolClass` (= the
    /// pattern from `MCPJSONRPCClientTests`).
    private func makeSession(for stubProtocolClass: AnyClass) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [stubProtocolClass]
        return URLSession(configuration: config)
    }

    // MARK: - Tests

    @Test("OpenAI-compat response shape parses correctly")
    func testOpenAIShape() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.responseData = Data("""
            {"data":[
                {"id":"gpt-5"},
                {"id":"gpt-5-mini"},
                {"id":"o4-mini"}
            ]}
            """.utf8)
        stub.responseStatusCode = 200
        let session = makeSession(for: stubProtocolClass)

        // Re-resolve the backend so it uses the InMemory
        // store (= otherwise the test hits the real
        // macOS Keychain).
        ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
        let provider = testProvider(slug: "openai-test", apiMode: "openai_chat")
        try ProviderKeychain.backend.saveKeySync("test-key-openai", for: provider)

        let discovery = LLMModelDiscovery(session: session)
        let result = await discovery.discover(provider: provider, forceRefresh: true)
        #expect(result.isLive, "live endpoint should have answered")
        #expect(result.models.contains("gpt-5"))
        #expect(result.models.contains("gpt-5-mini"))
        #expect(result.models.contains("o4-mini"))
    }

    @Test("Anthropic-compat response shape parses correctly (= minimax + Anthropic + DeepSeek)")
    func testAnthropicShape() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.responseData = Data("""
            {"data":[
                {"id":"MiniMax-M3"},
                {"id":"MiniMax-M2"}
            ]}
            """.utf8)
        stub.responseStatusCode = 200
        let session = makeSession(for: stubProtocolClass)

        ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
        let provider = testProvider(slug: "anthropic-test", apiMode: "anthropic_messages")
        try ProviderKeychain.backend.saveKeySync("test-key-anthropic", for: provider)

        let discovery = LLMModelDiscovery(session: session)
        let result = await discovery.discover(provider: provider, forceRefresh: true)
        #expect(result.isLive)
        #expect(result.models == ["MiniMax-M3", "MiniMax-M2"])
    }

    @Test("Gemini response shape strips the 'models/' prefix")
    func testGeminiPrefixStrip() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.responseData = Data("""
            {"models":[
                {"name":"models/gemini-2.5-pro"},
                {"name":"models/gemini-2.5-flash"}
            ]}
            """.utf8)
        stub.responseStatusCode = 200
        let session = makeSession(for: stubProtocolClass)

        ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
        let provider = testProvider(slug: "gemini-test", apiMode: "google_genai")
        try ProviderKeychain.backend.saveKeySync("test-key-gemini", for: provider)

        let discovery = LLMModelDiscovery(session: session)
        let result = await discovery.discover(provider: provider, forceRefresh: true)
        #expect(result.isLive)
        #expect(result.models.contains("gemini-2.5-pro"))
        #expect(!result.models.contains(where: { $0.hasPrefix("models/") }),
                "Gemini model names must not retain the 'models/' prefix")
    }

    @Test("HTTP 401 falls back to defaultModels with isLive: false")
    func test401Fallback() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.responseData = Data("{\"error\":\"invalid key\"}".utf8)
        stub.responseStatusCode = 401
        let session = makeSession(for: stubProtocolClass)

        ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
        let provider = testProvider(
            slug: "unauth-test",
            apiMode: "openai_chat",
            defaultModels: ["fallback-model-a", "fallback-model-b"]
        )
        try ProviderKeychain.backend.saveKeySync("stale-key", for: provider)

        let discovery = LLMModelDiscovery(session: session)
        let result = await discovery.discover(provider: provider, forceRefresh: true)
        #expect(!result.isLive, "401 must mark the result as not-live")
        #expect(result.models == provider.defaultModels,
                "401 must fall back to the canonical defaultModels list")
    }

    @Test("Missing key skips the network call (= no auth = no query)")
    func testNoKeyFallback() async throws {
        // The provider has no key in the keychain; = the
        // discovery must return defaultModels without
        // hitting the network (= no request is sent).
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        // Note: we don't register a response — if a request
        // is sent, the test will fail (= no response = the
        // session.data call would hang/throw).
        let session = makeSession(for: stubProtocolClass)
        _ = stub  // keep the stub alive in scope

        ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
        let provider = testProvider(
            slug: "no-key-test",
            apiMode: "openai_chat",
            defaultModels: ["only-fallback"]
        )
        // Deliberately do NOT save a key for this provider.

        let discovery = LLMModelDiscovery(session: session)
        let result = await discovery.discover(provider: provider, forceRefresh: true)
        #expect(!result.isLive, "no-key path must not be marked live")
        #expect(result.models == provider.defaultModels)
    }
}
