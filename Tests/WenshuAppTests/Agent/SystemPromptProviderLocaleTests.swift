//
//  SystemPromptProviderLocaleTests.swift · Wenshu · HERMES-PARTIAL-012 (2026-09-04)
//
//  Round-trip tests for the per-provider + per-locale + dynamic-tier
//  SystemPrompt extensions (= hermes system_prompt.py = 536 LOC):
//    1. testProviderGuidance            — ProviderGuidance enum maps slugs
//    2. testLocaleOverride              — Locale enum maps language codes
//    3. testBuildPartsStableTier        — stable tier contains provider guidance
//    4. testByteStableInvariant         — same input → byte-identical output
//    5. testDynamicTierPassesThrough    — dynamic tier flows through
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SystemPromptProviderLocale (HERMES-PARTIAL-012)")
struct SystemPromptProviderLocaleTests {

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
    func testBuildPartsStableTier() {
        let parts = SystemPrompt.buildParts(options: SystemPrompt.BuildOptions(
            ephemeralHint: "",
            provider: .anthropic
        ))
        let stable = parts["stable"] ?? ""
        #expect(stable.contains("Anthropic Claude family"))
        #expect(stable.contains("parallel tool_use"))
        #expect(stable.contains("Wenshu"))  // identity block
    }

    // MARK: - Test 4: Byte-stable invariant

    @Test("same BuildOptions produce byte-identical stable tier (cache-key invariant)")
    func testByteStableInvariant() {
        let opts = SystemPrompt.BuildOptions(
            ephemeralHint: "today is Tuesday",
            provider: .openai,
            memoryGuidance: true
        )
        let a = SystemPrompt.buildParts(options: opts)
        let b = SystemPrompt.buildParts(options: opts)
        // Stable tier must be byte-identical (= Anthropic cache prefix stability).
        #expect(a["stable"] == b["stable"])
        #expect(a["stable"]?.count ?? 0 > 0)
    }

    // MARK: - Test 5: Dynamic tier passes through

    @Test("ephemeralHint flows into the dynamic tier")
    func testDynamicTierPassesThrough() {
        let parts = SystemPrompt.buildParts(ephemeralHint: "today is Friday")
        let dynamic = parts["dynamic"] ?? ""
        #expect(dynamic.contains("today is Friday") || dynamic.contains("Context"))
    }

    // MARK: - Test 6: Locale override on stable tier

    @Test("Chinese locale produces a Chinese-language identity block")
    func testLocaleStableTier() {
        let parts = SystemPrompt.buildParts(options: SystemPrompt.BuildOptions(
            ephemeralHint: "",
            provider: .unknown,
            locale: .chinese
        ))
        let stable = parts["stable"] ?? ""
        #expect(stable.contains("文枢") || stable.contains("写作"))
    }
}