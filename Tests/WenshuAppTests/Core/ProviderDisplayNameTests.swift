//
//  ProviderDisplayNameTests.swift · Wenshu · T27-CONNECTOR-DISPLAY (2026-09-18)
//
//  Verifies the connector slug -> display name mapping used by
//  ChatPlanPartView. The mapping is owned by the Provider enum
//  (= static let blocks define name per slug).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Provider display name lookup (T27)")
struct ProviderDisplayNameTests {

    /// T27 contract: Provider.by(slug: "anthropic")?.name returns
    /// "Anthropic" (= the user-friendly display name).
    @Test func anthropic_display_name() {
        #expect(Provider.by(slug: "anthropic")?.name == "Anthropic")
    }

    /// T27 contract: OpenAI Codex provider.
    @Test func openai_codex_display_name() {
        #expect(Provider.by(slug: "openai-codex")?.name == "OpenAI Codex")
    }

    /// T27 contract: MiniMax cn provider (= the v1 default).
    @Test func minimax_cn_display_name() {
        #expect(Provider.by(slug: "minimax-cn")?.name == "MiniMax (China)")
    }

    /// T27 contract: Gemini provider.
    @Test func gemini_display_name() {
        #expect(Provider.by(slug: "gemini")?.name == "Gemini")
    }

    /// T27 contract: DeepSeek provider.
    @Test func deepseek_display_name() {
        #expect(Provider.by(slug: "deepseek")?.name == "DeepSeek")
    }

    /// T27 contract: Ollama provider.
    @Test func ollama_display_name() {
        #expect(Provider.by(slug: "ollama")?.name == "Ollama (local)")
    }

    /// T27 contract: OpenRouter provider.
    @Test func openrouter_display_name() {
        #expect(Provider.by(slug: "openrouter")?.name == "OpenRouter")
    }

    /// T27 contract: unknown slug returns nil (= forward-compat
    /// for future connectors = caller falls back to the raw slug).
    @Test func unknown_slug_returns_nil() {
        #expect(Provider.by(slug: "future-connector-3000") == nil)
    }
}