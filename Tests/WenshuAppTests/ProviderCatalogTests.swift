//
//  ProviderCatalogTests.swift · v0.21 ticket 01
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ProviderCatalog (Hermes 范式)")
struct ProviderCatalogTests {

    @Test("Provider.by 返已知 provider")
    func testBy() {
        #expect(Provider.by(slug: "openrouter")?.name == "OpenRouter")
        #expect(Provider.by(slug: "minimax-cn")?.name == "MiniMax (China)")
        #expect(Provider.by(slug: "nous")?.apiMode == "openai_chat")
        #expect(Provider.by(slug: "anthropic")?.authHeader == .xApiKey)
        #expect(Provider.by(slug: "nonexistent") == nil)
    }

    @Test("Provider.all 至少 11 provider")
    func testAll() {
        #expect(Provider.all.count >= 11)
        let slugs = Set(Provider.all.map { $0.slug })
        #expect(slugs.contains("openrouter"))
        #expect(slugs.contains("nous"))
        #expect(slugs.contains("minimax"))
        #expect(slugs.contains("minimax-cn"))
        #expect(slugs.contains("anthropic"))
        #expect(slugs.contains("custom"))
    }

    @Test("Provider 都需要 non-empty name + baseURL 或 custom")
    func testSanity() {
        for p in Provider.all {
            #expect(!p.name.isEmpty)
            if p.slug != "custom" {
                #expect(!p.defaultBaseURL.isEmpty)
                #expect(!p.defaultModels.isEmpty)
            }
        }
    }

    @Test("OAuth providers 标记 requiresOAuth")
    func testOAuthFlag() {
        #expect(Provider.openaiCodex.requiresOAuth == true)
        #expect(Provider.copilot.requiresOAuth == true)
        #expect(Provider.xaiOauth.requiresOAuth == true)
        #expect(Provider.minimax.requiresOAuth == false)
        #expect(Provider.openrouter.requiresOAuth == false)
    }

    @Test("ProviderCatalog.defaultModels 返 curated 列表")
    func testDefaultModels() {
        let models = ProviderCatalog.defaultModels(for: "minimax-cn")
        #expect(models.contains("MiniMax-M3"))
    }

    @Test("ProviderCatalog.provider fallback 到 minimax-cn")
    func testProviderFallback() {
        let p = ProviderCatalog.provider(slug: "unknown")
        #expect(p.slug == "minimax-cn")
    }
}
