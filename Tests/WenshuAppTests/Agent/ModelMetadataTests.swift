//
//  ModelMetadataTests.swift · Wenshu · v0.35 ticket 008
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ModelMetadata (ticket 008)")
struct ModelMetadataTests {

    @Test("allProfiles includes 7 connector profiles")
    func testAll7Profiles() {
        #expect(WenshuModelCatalog.allProfiles.count == 7)
        let slugs = Set(WenshuModelCatalog.allProfiles.map { $0.provider.slug })
        for slug in ["anthropic", "openai-codex", "minimax-cn", "deepseek", "gemini", "ollama", "openrouter"] {
            #expect(slugs.contains(slug), "missing provider: \\(slug)")
        }
    }

    @Test("defaultModelsForProvider(.anthropic) returns anthropic's defaultModels")
    func testAnthropicDefaults() {
        let models = WenshuModelCatalog.defaultModelsForProvider(.anthropic)
        #expect(models.contains { $0.id == "claude-opus-4-20250514" })
    }

    @Test("contextWindow varies by provider")
    func testContextWindowVariation() {
        let anthropicWindow = WenshuModelCatalog.defaultModelsForProvider(.anthropic).first?.contextWindow
        let minimaxWindow = WenshuModelCatalog.defaultModelsForProvider(.minimaxCn).first?.contextWindow
        #expect(anthropicWindow == 200_000)
        #expect(minimaxWindow == 1_000_000)
    }
}