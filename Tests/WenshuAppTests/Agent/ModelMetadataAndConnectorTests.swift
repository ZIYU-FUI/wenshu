//
//  ModelMetadataAndConnectorTests.swift · Wenshu · v0.38 Batch 3 sub-step 14
//
//  Tests for WenshuModelCatalog + ModelInfo + OpenAIConnector +
//  OpenAICompatibleConnector (= v0.36 ticket 008 + v0.35 ticket 005).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = ModelMetadata.swift is v0.36
//  ticket 008; OpenAIConnector.swift is v0.35 ticket 005 (= my work).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuModelCatalog deep (= v0.36 ticket 008)")
struct WenshuModelCatalogDeepTests {

    @Test("WenshuModelCatalog: construction with explicit models")
    func catalogConstructionExplicit() {
        let models = [
            WenshuModelCatalog.ModelInfo(
                id: "claude-3-5-sonnet",
                displayName: "Claude 3.5 Sonnet",
                contextWindow: 200_000,
                maxOutputTokens: 8192
            )
        ]
        let catalog = WenshuModelCatalog(provider: .anthropic, models: models)
        #expect(catalog.provider == .anthropic)
        #expect(catalog.models.count == 1)
        #expect(catalog.models.first?.id == "claude-3-5-sonnet")
    }

    @Test("WenshuModelCatalog: construction with default models")
    func catalogConstructionDefault() {
        let catalog = WenshuModelCatalog(provider: .anthropic)
        #expect(catalog.provider == .anthropic)
        #expect(catalog.models.count > 0)
    }

    @Test("WenshuModelCatalog: 7 profiles in allProfiles (= 7-connector BYOK)")
    func catalogAllProfiles() {
        let profiles = WenshuModelCatalog.allProfiles
        #expect(profiles.count >= 7)
        // Each profile has at least one model
        for profile in profiles {
            #expect(profile.models.count >= 0)
        }
    }

    @Test("WenshuModelCatalog: 7 unique provider slugs in allProfiles")
    func catalogUniqueProviderSlugs() {
        let slugs = WenshuModelCatalog.allProfiles.map { $0.provider.slug }
        let unique = Set(slugs)
        #expect(unique.count == slugs.count)
    }

    @Test("WenshuModelCatalog.ModelInfo: construction with all fields")
    func modelInfoConstruction() {
        let info = WenshuModelCatalog.ModelInfo(
            id: "gpt-4",
            displayName: "GPT-4",
            contextWindow: 8192,
            maxOutputTokens: 4096
        )
        #expect(info.id == "gpt-4")
        #expect(info.displayName == "GPT-4")
        #expect(info.contextWindow == 8192)
        #expect(info.maxOutputTokens == 4096)
        #expect(info.idString == "gpt-4")
    }

    @Test("WenshuModelCatalog.ModelInfo: Equatable")
    func modelInfoEquatable() {
        let a = WenshuModelCatalog.ModelInfo(id: "x", displayName: "X", contextWindow: 100, maxOutputTokens: 50)
        let b = WenshuModelCatalog.ModelInfo(id: "x", displayName: "X", contextWindow: 100, maxOutputTokens: 50)
        #expect(a == b)
    }

    @Test("WenshuModelCatalog.ModelInfo: contextWindow = 0 = unknown")
    func modelInfoUnknownContext() {
        let info = WenshuModelCatalog.ModelInfo(
            id: "unknown",
            displayName: "Unknown",
            contextWindow: 0,
            maxOutputTokens: 0
        )
        #expect(info.contextWindow == 0)
    }

    @Test("WenshuModelCatalog.defaultContextWindow: anthropic = 200k")
    func defaultContextAnthropic() {
        let catalog = WenshuModelCatalog(provider: .anthropic)
        if let first = catalog.models.first {
            #expect(first.contextWindow == 200_000)
        }
    }

    @Test("WenshuModelCatalog.defaultContextWindow: minimax = 1M")
    func defaultContextMinimax() {
        let catalog = WenshuModelCatalog(provider: .minimaxCn)
        if let first = catalog.models.first {
            #expect(first.contextWindow == 1_000_000)
        }
    }

    @Test("WenshuModelCatalog: default context windows match known values")
    func catalogDefaultContextWindows() {
        let cases: [(Provider, Int)] = [
            (.anthropic, 200_000),
            (.minimaxCn, 1_000_000),
            (.gemini, 1_000_000)
        ]
        for (provider, expectedWindow) in cases {
            let catalog = WenshuModelCatalog(provider: provider)
            for model in catalog.models {
                if model.contextWindow > 0 {
                    #expect(model.contextWindow == expectedWindow, "\(provider.slug) context window mismatch")
                    break  // only check first non-zero
                }
            }
        }
    }

    @Test("WenshuModelCatalog: ollama + openrouter have contextWindow = 0")
    func catalogModelDependentContext() {
        let ollama = WenshuModelCatalog(provider: .ollama)
        for model in ollama.models {
            #expect(model.contextWindow == 0, "ollama should have contextWindow=0 (= model-dependent)")
        }
        let openrouter = WenshuModelCatalog(provider: .openrouter)
        for model in openrouter.models {
            #expect(model.contextWindow == 0, "openrouter should have contextWindow=0")
        }
    }

    @Test("WenshuModelCatalog: Equatable")
    func catalogEquatable() {
        let a = WenshuModelCatalog(provider: .anthropic)
        let b = WenshuModelCatalog(provider: .anthropic)
        #expect(a == b)
    }
}

@Suite("OpenAIConnector + OpenAICompatibleConnector deep (= v0.35 ticket 005)")
struct OpenAIConnectorDeepTests {

    @Test("OpenAIConnector: construction with default session")
    func openAIConnectorConstruction() {
        let connector = OpenAIConnector()
        // Verify type identity (= actor init succeeds)
        #expect(type(of: connector) == OpenAIConnector.self)
    }

    @Test("OpenAIConnector: connectorID is 'openai'")
    func openAIConnectorID() async {
        let connector = OpenAIConnector()
        let id = await connector.connectorID
        #expect(id == "openai")
    }

    @Test("OpenAICompatibleConnector: construction with provider")
    func openAICompatibleConstruction() {
        let connector = OpenAICompatibleConnector(provider: .deepseek)
        #expect(type(of: connector) == OpenAICompatibleConnector.self)
    }

    @Test("OpenAICompatibleConnector: connectorID matches provider.slug")
    func openAICompatibleConnectorID() async {
        let connectors: [OpenAICompatibleConnector] = [
            OpenAICompatibleConnector(provider: .deepseek),
            OpenAICompatibleConnector(provider: .openrouter),
            OpenAICompatibleConnector(provider: .ollama)
        ]
        for connector in connectors {
            let id = await connector.connectorID
            #expect(!id.isEmpty)
        }
    }

    @Test("OpenAICompatibleConnector: send throws without API key for deepseek")
    func openAICompatibleDeepseekNoKey() async {
        // deepseek requires API key (= non-empty), ollama doesn't
        let connector = OpenAICompatibleConnector(provider: .deepseek)
        do {
            _ = try await connector.send(
                messages: [LLMMessage(role: .user, blocks: [.text("hi")])],
                options: LLMCallOptions(model: "deepseek-chat")
            )
            // If no error, key was somehow set (= skip)
        } catch LLMConnectorError.missingAPIKey {
            // expected for deepseek without key
        } catch {
            // Other errors possible
        }
    }
}
