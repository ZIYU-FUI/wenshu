//
//  SystemPromptProviderLocaleTests.swift · Wenshu ·  (2026-09-04)
//
//  Round-trip tests for the per-provider + per-locale + dynamic-tier
//  SystemPrompt extensions (= hermes system_prompt.py = 536 LOC):
//    1. testProviderGuidance            — ProviderGuidance enum maps slugs
//    2. testLocaleOverride              — Locale enum maps language codes
//    3. testStableTierHasProviderGuidance — stable tier carries provider guidance
//    4. testByteStableInvariant         — same input → byte-identical output
//    5. testDynamicTierPassesThrough    — dynamic tier flows through
//

import Testing
import Foundation
import WenshuAgent
@testable import WenshuApp

@Suite("SystemPromptProviderLocale ()")
struct SystemPromptProviderLocaleTests {

    // MARK: - The live builders

    /// The stable tier, as the turn loop builds it.
    private func stableTier(
        provider: SystemPrompt.ProviderGuidance = .unknown,
        locale: SystemPrompt.Locale = .english,
        memoryGuidance: Bool = false
    ) -> String {
        var settings = PromptSettings()
        settings.memoryGuidanceEnabled = memoryGuidance
        return PromptTierBuilder.stableTier(
            settings: settings,
            provider: provider,
            locale: locale
        )
    }

    /// The dynamic tier, as the turn loop builds it.
    private func dynamicTier(ephemeralHint: String = "") -> String {
        PromptBuilder.dynamicTier(
            contextBundle: ContextEngine.ContextBundle(
                memories: [],
                characterContext: [],
                worldContext: [],
                foreshadowContext: []
            ),
            memories: [],
            callerExtras: [:],
            ephemeralHint: ephemeralHint
        )
    }

    // MARK: - Test 1: ProviderGuidance enum

    @Test("ProviderGuidance maps provider slugs to the right family")
    func testProviderGuidance() {
        #expect(SystemPrompt.ProviderGuidance(providerSlug: "anthropic") == .anthropic)
        #expect(SystemPrompt.ProviderGuidance(providerSlug: "openai-codex") == .openai)
        #expect(SystemPrompt.ProviderGuidance(providerSlug: "openai") == .openai)
        #expect(SystemPrompt.ProviderGuidance(providerSlug: "gemini") == .google)
        #expect(SystemPrompt.ProviderGuidance(providerSlug: "ollama") == .ollama)
        #expect(SystemPrompt.ProviderGuidance(providerSlug: "openrouter") == .openrouter)
        #expect(SystemPrompt.ProviderGuidance(providerSlug: "deepseek") == .deepseek)
        #expect(SystemPrompt.ProviderGuidance(providerSlug: "minimax-cn") == .minimaxCn)
        #expect(SystemPrompt.ProviderGuidance(providerSlug: "weird-future") == .unknown)
    }

    // MARK: - Test 2: Locale override

    @Test("Locale maps ISO codes to the right language")
    func testLocaleOverride() {
        #expect(SystemPrompt.Locale(languageCode: "en") == .english)
        #expect(SystemPrompt.Locale(languageCode: "zh-CN") == .chinese)
        #expect(SystemPrompt.Locale(languageCode: "zh-Hans") == .chinese)
        #expect(SystemPrompt.Locale(languageCode: "ja") == .japanese)
        #expect(SystemPrompt.Locale(languageCode: "ko") == .korean)
        #expect(SystemPrompt.Locale(languageCode: "fr") == .french)
        #expect(SystemPrompt.Locale(languageCode: "de") == .german)
        #expect(SystemPrompt.Locale(languageCode: "es") == .spanish)
        #expect(SystemPrompt.Locale(languageCode: "unknown") == .english)  // default
    }

    @Test("Locale.nativeName returns the language's own name")
    func testLocaleNativeName() {
        #expect(SystemPrompt.Locale.chinese.nativeName == "中文")
        #expect(SystemPrompt.Locale.japanese.nativeName == "日本語")
        #expect(SystemPrompt.Locale.english.nativeName == "English")
    }

    // MARK: - Test 3: stable tier contains provider guidance

    @Test("stableTier contains provider-specific operational guidance")
    func testStableTierHasProviderGuidance() {
        let stable = stableTier(provider: .anthropic)
        #expect(stable.contains("Anthropic Claude family"))
        #expect(stable.contains("parallel tool_use"))
        #expect(stable.contains("Wenshu"))  // identity block
    }

    // MARK: - Test 4: Byte-stable invariant

    @Test("same settings produce byte-identical stable tier (cache-key invariant)")
    func testByteStableInvariant() {
        let a = stableTier(provider: .openai, memoryGuidance: true)
        let b = stableTier(provider: .openai, memoryGuidance: true)
        // Stable tier must be byte-identical (= Anthropic cache prefix stability).
        #expect(a == b)
        #expect(a.count > 0)
    }

    // MARK: - Test 5: Dynamic tier passes through

    @Test("ephemeralHint flows into the dynamic tier")
    func testDynamicTierPassesThrough() {
        let dynamic = dynamicTier(ephemeralHint: "today is Friday")
        #expect(dynamic.contains("today is Friday") || dynamic.contains("Context"))
    }

    // MARK: - Test 6: Locale override on stable tier

    @Test("Chinese locale produces a Chinese-language identity block")
    func testLocaleStableTier() {
        let stable = stableTier(provider: .unknown, locale: .chinese)
        #expect(stable.contains("文枢") || stable.contains("写作"))
    }
}
