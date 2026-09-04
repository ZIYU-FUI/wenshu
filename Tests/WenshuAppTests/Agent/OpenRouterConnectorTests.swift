//
//  OpenRouterConnectorTests.swift · Wenshu · §11.2 connector-profile gap-fill
//
//  Unit tests for OpenRouterConnector (= §11.2 OpenRouter profile).
//
//  OpenRouter is a multi-provider router (= Anthropic, OpenAI, Google, Meta,
//  DeepSeek etc.) behind a single OpenAI-compatible chat completions endpoint
//  at https://openrouter.ai/api/v1/chat/completions with Bearer auth.
//
//  These tests assert the connector-profile identity contract (= 3 round-trip
//  assertions per AGENTS.md §11.2 acceptance):
//    1. connectorID identity (= "openrouter")
//    2. Protocol conformance + Provider.slug == "openrouter" (= delegates
//       to OpenAICompatibleConnector(provider: .openrouter))
//    3. Provider.defaultBaseURL + defaultModels contract (= multi-provider
//       router exposing Anthropic + DeepSeek models per AGENTS.md §11.2)
//
//  HTTP transport tests for the OpenAI-compatible shared path are covered
//  in OpenAIConnectorTests.swift. The §11.2 gap-fill tests focus on the
//  *profile identity* (= slug + protocol conformance + provider catalog
//  contract) since OpenRouterConnector is a thin typed wrapper.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("OpenRouterConnector (§11.2 gap-fill)")
struct OpenRouterConnectorTests {

    @Test("OpenRouterConnector.connectorID == 'openrouter' (per AGENTS.md §11.2 profile slug)")
    func testConnectorIDIdentity() async throws {
        let connector = OpenRouterConnector()
        #expect(connector.connectorID == "openrouter")
    }

    @Test("OpenRouterConnector conforms to LLMConnector protocol")
    func testProtocolConformance() async throws {
        let connector: any LLMConnector = OpenRouterConnector()
        #expect(connector.connectorID == "openrouter")
    }

    @Test("OpenRouterConnector: Provider catalog contract (= multi-provider router base URL + default models)")
    func testProviderCatalogContract() async throws {
        // Per AGENTS.md §11.2 row "OpenRouter | Multi-provider router":
        // base URL = https://openrouter.ai/api/v1 + Bearer auth.
        // Default models surface Anthropic + DeepSeek routes so the user
        // can pick either via a single OpenRouter key.
        let provider = Provider.openrouter
        #expect(provider.slug == "openrouter")
        #expect(provider.defaultBaseURL == "https://openrouter.ai/api/v1")
        #expect(provider.authHeader == .bearer)
        // Multi-provider default models surface Anthropic + DeepSeek routes.
        let models = provider.defaultModels
        #expect(models.contains(where: { $0.hasPrefix("anthropic/") }))
        #expect(models.contains(where: { $0.hasPrefix("deepseek/") }))
    }
}
