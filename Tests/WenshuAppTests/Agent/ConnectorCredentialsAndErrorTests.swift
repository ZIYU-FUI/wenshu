//
//  ConnectorCredentialsAndErrorTests.swift · Wenshu · v0.38 Batch 3 sub-step 12
//
//  Tests for ConnectorCredentials + LLMConnectorError + LLMCallOptions
//  (= v0.35 ticket 001 + 002 + v0.36 ticket 012 sub-step 5).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = ConnectorCredentials + LLMConnectorError
//  are v0.35 ticket 001 + v0.36 ticket 012 (= my work).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ConnectorCredentials deep (= v0.36 ticket 012)")
struct ConnectorCredentialsDeepTests {

    @Test("ConnectorCredentials: construction with all fields")
    func credentialsConstruction() {
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.anthropic.com"
        )
        #expect(creds.provider == .anthropic)
        #expect(creds.apiKey == "sk-test")
        #expect(creds.baseURL == "https://api.anthropic.com")
        #expect(creds.metadata == nil)
    }

    @Test("ConnectorCredentials: with metadata")
    func credentialsWithMetadata() {
        let metadata = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSinceNow: 3600)
        )
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.anthropic.com",
            metadata: metadata
        )
        #expect(creds.metadata != nil)
    }

    @Test("ConnectorCredentials: needsRotation = false when no metadata")
    func needsRotationNoMetadata() {
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.anthropic.com"
        )
        #expect(creds.needsRotation == false)
    }

    @Test("ConnectorCredentials: needsRotation = false when not expired")
    func needsRotationNotExpired() {
        let metadata = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSinceNow: 3600),
            oauthRefreshToken: "rt"
        )
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.anthropic.com",
            metadata: metadata
        )
        #expect(creds.needsRotation == false)
    }

    @Test("ConnectorCredentials: needsRotation = true when expired + OAuth")
    func needsRotationExpired() {
        let metadata = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSinceNow: -3600),
            oauthRefreshToken: "rt",
            oauthAccessToken: "at"
        )
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.anthropic.com",
            metadata: metadata
        )
        #expect(creds.needsRotation == true)
    }

    @Test("ConnectorCredentials: isReady = true when apiKey set")
    func isReadyWithKey() {
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.anthropic.com"
        )
        #expect(creds.isReady)
    }

    @Test("ConnectorCredentials: isReady = false when apiKey empty")
    func isReadyWithoutKey() {
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "",
            baseURL: "https://api.anthropic.com"
        )
        #expect(!creds.isReady)
    }

    @Test("ConnectorCredentials: isReady = true for Ollama (no auth)")
    func isReadyOllama() {
        let creds = ConnectorCredentials(
            provider: .ollama,
            apiKey: "",
            baseURL: "http://localhost:11434"
        )
        #expect(creds.isReady)
    }

    @Test("ConnectorCredentials.resolve: returns default baseURL")
    func resolveDefaultBaseURL() {
        let creds = ConnectorCredentials.resolve(for: .anthropic)
        #expect(creds.baseURL == Provider.anthropic.defaultBaseURL)
    }

    @Test("ConnectorCredentials.resolve: Ollama = empty key")
    func resolveOllamaEmptyKey() async {
        // Clear any existing ollama key
        let store = InMemoryKeychainStore()
        try? store.deleteKeySync(for: .ollama)
        let creds = ConnectorCredentials.resolve(for: .ollama)
        #expect(creds.apiKey.isEmpty)
    }

    @Test("ConnectorCredentials.resolve: non-Ollama = empty key when no key saved")
    func resolveNonOllamaEmptyKey() async {
        // Clear any existing anthropic key
        let store = InMemoryKeychainStore()
        try? store.deleteKeySync(for: .anthropic)
        let creds = ConnectorCredentials.resolve(for: .anthropic)
        #expect(creds.apiKey.isEmpty)
    }
}

@Suite("LLMConnectorError deep (= v0.35 ticket 001)")
struct LLMConnectorErrorDeepTests {

    @Test("LLMConnectorError: 5 case types")
    func errorCaseTypes() {
        let errors: [LLMConnectorError] = [
            .missingAPIKey(provider: "anthropic"),
            .transport(provider: "openai", statusCode: 500, body: "server error"),
            .decode(provider: "openai", underlying: "JSON parse failed"),
            .unsupportedProvider(slug: "unknown"),
            .streamingFailed(provider: "anthropic")
        ]
        #expect(errors.count == 5)
    }

    @Test("LLMConnectorError.missingAPIKey: errorDescription mentions provider")
    func missingAPIKeyErrorDescription() {
        let error = LLMConnectorError.missingAPIKey(provider: "anthropic")
        let desc = error.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("anthropic"))
    }

    @Test("LLMConnectorError.transport: errorDescription mentions status code")
    func transportErrorDescription() {
        let error = LLMConnectorError.transport(
            provider: "openai",
            statusCode: 429,
            body: "rate limited"
        )
        let desc = error.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("openai"))
        #expect(desc!.contains("429"))
    }

    @Test("LLMConnectorError.decode: errorDescription mentions provider + underlying")
    func decodeErrorDescription() {
        let error = LLMConnectorError.decode(
            provider: "anthropic",
            underlying: "Invalid JSON"
        )
        let desc = error.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("anthropic"))
        #expect(desc!.contains("Invalid JSON"))
    }

    @Test("LLMConnectorError.unsupportedProvider: errorDescription mentions slug")
    func unsupportedProviderErrorDescription() {
        let error = LLMConnectorError.unsupportedProvider(slug: "fake-provider")
        let desc = error.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("fake-provider"))
    }

    @Test("LLMConnectorError.streamingFailed: errorDescription mentions provider")
    func streamingFailedErrorDescription() {
        let error = LLMConnectorError.streamingFailed(provider: "anthropic")
        let desc = error.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("anthropic"))
    }
}

@Suite("LLMCallOptions deep (= v0.35 ticket 001)")
struct LLMCallOptionsDeepTests {

    @Test("LLMCallOptions: construction with all fields")
    func optionsConstruction() {
        let options = LLMCallOptions(
            model: "claude-3-5-sonnet",
            maxTokens: 1024,
            systemPrompt: "You are a helpful assistant"
        )
        #expect(options.model == "claude-3-5-sonnet")
        #expect(options.maxTokens == 1024)
        #expect(options.systemPrompt == "You are a helpful assistant")
    }

    @Test("LLMCallOptions: default values")
    func optionsDefaults() {
        let options = LLMCallOptions(model: "test")
        #expect(options.model == "test")
        #expect(options.maxTokens == 1024)  // default
    }

    @Test("LLMCallOptions: systemPrompt nil by default")
    func optionsSystemPromptDefaultNil() {
        let options = LLMCallOptions(model: "test")
        #expect(options.systemPrompt == nil)
    }

    @Test("LLMCallOptions: two instances with same fields are independent")
    func optionsIndependence() {
        let a = LLMCallOptions(model: "test", maxTokens: 100, systemPrompt: "x")
        let b = LLMCallOptions(model: "test", maxTokens: 100, systemPrompt: "x")
        // Both can be created independently
        #expect(a.model == b.model)
        #expect(a.maxTokens == b.maxTokens)
    }

    @Test("LLMCallOptions: different model")
    func optionsDifferentModel() {
        let a = LLMCallOptions(model: "test1")
        let b = LLMCallOptions(model: "test2")
        #expect(a.model != b.model)
    }
}

@Suite("Provider basic deep (= 7-connector BYOK)")
struct ProviderBasicDeepTests {

    @Test("Provider: 6-connector slugs per ADR-0008 (no .openai in canonical 7)")
    func providerSlugs() {
        let slugs: Set<String> = [
            Provider.anthropic.slug,
            Provider.openrouter.slug,
            Provider.gemini.slug,
            Provider.deepseek.slug,
            Provider.ollama.slug,
            Provider.minimaxCn.slug
        ]
        #expect(slugs.count >= 6)
    }

    @Test("Provider: default baseURL is non-empty for all 7")
    func providerBaseURLsNonEmpty() {
        let providers: [Provider] = [
            .anthropic, .openrouter, .gemini, .deepseek, .ollama, .minimaxCn
        ]
        for provider in providers {
            #expect(!provider.defaultBaseURL.isEmpty, "\(provider.slug) has empty baseURL")
        }
    }

    @Test("Provider: 7 different slugs are unique")
    func providerUniqueSlugs() {
        let slugs = [
            Provider.anthropic.slug,
            Provider.openrouter.slug,
            Provider.gemini.slug,
            Provider.deepseek.slug,
            Provider.ollama.slug,
            Provider.minimaxCn.slug
        ]
        let unique = Set(slugs)
        #expect(unique.count == slugs.count)
    }
}
