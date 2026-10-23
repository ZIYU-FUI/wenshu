// PromptCacheTests.swift
//
// The prompt cache, measured end to end.
//
// These tests drive the RUNTIME CONSUMERS, not the value types:
//   - the response parser, fed a body that carries the provider's cache
//     counters (= the counters have to survive the trip)
//   - the request builder, fed a route and a model (= the marker has to
//     reach the wire, and only where the wire speaks it)
//   - the recorder, fed the usage a turn reported (= the saving has to
//     accumulate per conversation)

import Foundation
import Testing
@testable import WenshuAgent

@Suite("Prompt cache counters")
struct PromptCacheCounterTests {

    /// The Anthropic shape: the counts sit beside the input count.
    @Test("the Anthropic response parser carries the cache counts")
    func anthropicParserCarriesCacheCounts() throws {
        let body = """
        {
          "id": "msg_1",
          "model": "claude-sonnet-4-5",
          "content": [{"type": "text", "text": "hi"}],
          "usage": {
            "input_tokens": 1000,
            "output_tokens": 120,
            "cache_read_input_tokens": 800,
            "cache_creation_input_tokens": 200
          }
        }
        """
        let response = try RequestHelpers.decodeAnthropicResponse(
            data: Data(body.utf8),
            model: "claude-sonnet-4-5",
            providerID: "anthropic"
        )
        #expect(response.usage.cacheReadTokens == 800)
        #expect(response.usage.cacheCreationTokens == 200)
        #expect(response.usage.inputTokens == 1000)
        #expect(response.usage.outputTokens == 120)
    }

    /// The OpenAI-compatible shape: the cached count is nested inside the
    /// prompt-token details, so the parser has to walk it.
    @Test("the OpenAI response parser carries the nested cache count")
    func openaiParserCarriesNestedCacheCount() throws {
        let body = """
        {
          "id": "cmpl_1",
          "model": "anthropic/claude-sonnet-4-5",
          "choices": [{"index": 0, "message": {"role": "assistant", "content": "hi"}, "finish_reason": "stop"}],
          "usage": {
            "prompt_tokens": 1000,
            "completion_tokens": 120,
            "prompt_tokens_details": {"cached_tokens": 640}
          }
        }
        """
        let response = try RequestHelpers.decodeOpenAIResponse(
            data: Data(body.utf8),
            model: "anthropic/claude-sonnet-4-5",
            providerID: "openrouter"
        )
        #expect(response.usage.cacheReadTokens == 640)
        #expect(response.usage.inputTokens == 1000)
        #expect(response.usage.outputTokens == 120)
    }

    /// The cached prefix is counted by the provider INSIDE the input
    /// count, so the two must never be added together.
    @Test("the cached count is never folded into the input count")
    func cachedCountIsNotFoldedIntoInput() throws {
        let body = """
        {
          "id": "msg_1",
          "model": "claude-sonnet-4-5",
          "content": [{"type": "text", "text": "hi"}],
          "usage": {
            "input_tokens": 1000,
            "output_tokens": 120,
            "cache_read_input_tokens": 800,
            "cache_creation_input_tokens": 200
          }
        }
        """
        let response = try RequestHelpers.decodeAnthropicResponse(
            data: Data(body.utf8),
            model: "claude-sonnet-4-5",
            providerID: "anthropic"
        )
        #expect(response.usage.inputTokens == 1000)
        #expect(response.usage.totalTokens == 1120)
        #expect(response.usage.inputTokens != 1800)
    }

    /// A provider that sends no cache field reports no cache count
    /// (= the parser does not invent one).
    @Test("a response without cache counters reports none")
    func missingCacheCountersStayZero() throws {
        let body = """
        {
          "id": "cmpl_1",
          "model": "gpt-5",
          "choices": [{"index": 0, "message": {"role": "assistant", "content": "hi"}, "finish_reason": "stop"}],
          "usage": {"prompt_tokens": 100, "completion_tokens": 10}
        }
        """
        let response = try RequestHelpers.decodeOpenAIResponse(
            data: Data(body.utf8),
            model: "gpt-5",
            providerID: "openai-codex"
        )
        #expect(response.usage.cacheReadTokens == 0)
        #expect(response.usage.cacheCreationTokens == 0)
    }
}

@Suite("Prompt cache markers")
struct PromptCacheMarkerTests {

    private func bodyJSON(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// A router route reached with a cache-capable model carries the
    /// marker on the message envelope.
    @Test("a router route marks its messages for a Claude-family model")
    func routerRouteMarksClaudeFamilyModel() throws {
        let body = try RequestHelpers.buildOpenAIRequest(
            model: "anthropic/claude-sonnet-4-5",
            messages: [
                LLMMessage.user("first"),
                LLMMessage.assistant("second"),
                LLMMessage.user("third")
            ],
            maxTokens: 1024,
            systemPrompt: "system prompt",
            providerSlug: "openrouter"
        )
        let json = try bodyJSON(body)
        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.count == 4)

        // The system message carries the marker (= the first breakpoint).
        let system = try #require(messages.first?["cache_control"] as? [String: Any])
        #expect(system["type"] as? String == "ephemeral")

        // The last three messages carry it too (= the stable prefix rule
        // the Anthropic path uses).
        let marked = messages.filter { $0["cache_control"] != nil }
        #expect(marked.count == 4)
    }

    /// A first-party route has no cache field on its wire, so it never
    /// pretends to cache.
    @Test("a first-party route sends no marker")
    func firstPartyRouteSendsNoMarker() throws {
        let body = try RequestHelpers.buildOpenAIRequest(
            model: "deepseek-chat",
            messages: [LLMMessage.user("hello")],
            maxTokens: 1024,
            systemPrompt: "system prompt",
            providerSlug: "deepseek"
        )
        let json = try bodyJSON(body)
        let messages = try #require(json["messages"] as? [[String: Any]])
        for message in messages {
            #expect(message["cache_control"] == nil)
        }
    }

    /// The route is not enough: the model decides whether its family
    /// honours the marker.
    @Test("a router route sends no marker for a model that does not cache")
    func routerRouteWithoutCacheCapableModelSendsNoMarker() throws {
        let body = try RequestHelpers.buildOpenAIRequest(
            model: "deepseek/deepseek-v4-pro",
            messages: [LLMMessage.user("hello")],
            maxTokens: 1024,
            systemPrompt: "system prompt",
            providerSlug: "openrouter"
        )
        let json = try bodyJSON(body)
        let messages = try #require(json["messages"] as? [[String: Any]])
        for message in messages {
            #expect(message["cache_control"] == nil)
        }
    }

    /// The local-model connector is a thin wrapper over the OpenAI path,
    /// and a local model's caching is the server's own key-value reuse,
    /// so no marker goes on that wire.
    @Test("the local-model route sends no marker")
    func localModelRouteSendsNoMarker() throws {
        let body = try RequestHelpers.buildOpenAIRequest(
            model: "llama3.3",
            messages: [LLMMessage.user("hello")],
            maxTokens: 1024,
            systemPrompt: "system prompt",
            providerSlug: "ollama"
        )
        let json = try bodyJSON(body)
        let messages = try #require(json["messages"] as? [[String: Any]])
        for message in messages {
            #expect(message["cache_control"] == nil)
        }
    }

    /// The Gemini-native wire has no per-message cache field, so it
    /// cannot carry a marker.
    @Test("the Gemini-native builder sends no marker")
    func geminiNativeSendsNoMarker() throws {
        let body = try RequestHelpers.buildGeminiRequest(
            model: "gemini-2.5-pro",
            messages: [LLMMessage.user("hello")],
            maxTokens: 1024,
            systemPrompt: "system prompt"
        )
        let json = try bodyJSON(body)
        let contents = try #require(json["contents"] as? [[String: Any]])
        for content in contents {
            #expect(content["cache_control"] == nil)
        }
    }
}

/// The cache totals and the TTL tier.
///
/// The suite is serialized because the TTL tier lives in the app's
/// defaults (= one process-wide key), so two tests that read and write
/// it must not run at the same time: one test's cleanup would remove
/// the value the other is asserting on.
@Suite("Prompt cache totals", .serialized)
struct PromptCacheRecorderTests {

    /// The recorder keeps a running total per conversation.
    @Test("the recorder totals the cache counts per conversation")
    func recorderTotalsPerConversation() async {
        let recorder = PromptCacheRecorder()
        await recorder.record(
            conversationId: "a",
            usage: LLMUsage(
                inputTokens: 1000,
                outputTokens: 100,
                cacheReadTokens: 800,
                cacheCreationTokens: 200
            )
        )
        await recorder.record(
            conversationId: "a",
            usage: LLMUsage(
                inputTokens: 1200,
                outputTokens: 150,
                cacheReadTokens: 1000,
                cacheCreationTokens: 0
            )
        )
        await recorder.record(
            conversationId: "b",
            usage: LLMUsage(
                inputTokens: 500,
                outputTokens: 50,
                cacheReadTokens: 400,
                cacheCreationTokens: 100
            )
        )

        let a = await recorder.totals(conversationId: "a")
        #expect(a.cacheReadTokens == 1800)
        #expect(a.cacheCreationTokens == 200)
        #expect(a.savedInputTokens == 1800)
        #expect(a.callCount == 2)

        let b = await recorder.totals(conversationId: "b")
        #expect(b.cacheReadTokens == 400)
        #expect(b.callCount == 1)

        #expect(await recorder.totals(conversationId: "missing").callCount == 0)
    }

    /// The TTL tier follows the pace of the session.
    @Test("the auto tier resolves by the pace of the session")
    func autoTierResolvesBySource() {
        #expect(
            PromptCachePolicy.effectiveTTL(.auto, source: .interactive) == "1h"
        )
        #expect(
            PromptCachePolicy.effectiveTTL(.auto, source: .machinePaced) == "5m"
        )
        #expect(
            PromptCachePolicy.effectiveTTL(.short, source: .interactive) == "5m"
        )
        #expect(
            PromptCachePolicy.effectiveTTL(.long, source: .machinePaced) == "1h"
        )
    }

    /// The tier resolves from the user's setting, not from a constant
    /// baked into the code.
    ///
    /// The setting is read from the app's defaults at the moment the
    /// request is built, so a tier the user changes is picked up by the
    /// next request without a restart.
    @Test("the TTL tier resolves from the user's setting")
    func ttlTierResolvesFromTheStoredSetting() {
        let setting = PromptCacheTTLSetting()
        let key = PromptCacheTTLSetting.defaultsKey
        let previous = UserDefaults.standard.string(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        // No stored tier = the tier follows the pace (= `auto`).
        UserDefaults.standard.removeObject(forKey: key)
        #expect(setting.ttl == .auto)
        #expect(setting.effectiveTTL == "1h")

        // The stored tier wins over the default.
        UserDefaults.standard.set("5m", forKey: key)
        #expect(setting.ttl == .short)
        #expect(setting.effectiveTTL == "5m")

        UserDefaults.standard.set("1h", forKey: key)
        #expect(setting.ttl == .long)
        #expect(setting.effectiveTTL == "1h")

        // A tier the user has not chosen (= `auto`) follows the pace.
        UserDefaults.standard.set("auto", forKey: key)
        #expect(setting.ttl == .auto)
        #expect(setting.effectiveTTL == "1h")

        // A value the settings surface does not know = `auto`, never a
        // tierless marker.
        UserDefaults.standard.set("nonsense", forKey: key)
        #expect(setting.ttl == .auto)
    }

    /// The setting writes the tier through, so the user's choice
    /// survives a restart.
    @Test("the TTL setting writes the tier through")
    func ttlSettingWritesTheTierThrough() {
        let setting = PromptCacheTTLSetting()
        let key = PromptCacheTTLSetting.defaultsKey
        let previous = UserDefaults.standard.string(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        setting.set(.short)
        #expect(UserDefaults.standard.string(forKey: key) == "5m")
        #expect(setting.ttl == .short)
    }
}
