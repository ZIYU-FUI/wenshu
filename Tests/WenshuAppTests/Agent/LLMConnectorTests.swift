//
//  LLMConnectorTests.swift · Wenshu · v0.35 ticket 001 sub-step 2
//
//  Unit tests for the LLMConnector protocol + ConnectorCredentials struct
//  (= hermes-core-translation spec §3.1 + §6.4 + AGENTS.md §11.2).
//
//  Test surface:
//  1. LLMConnector protocol conformance (= MockConnector verifies protocol
//     can be conformed to by a non-Apple type)
//  2. LLMMessage / LLMResponse cross-connector wire format (= text + thinking
//     + tool_use content blocks + usage)
//  3. ConnectorCredentials resolves API key from existing ProviderKeychain
//     (= reuses ProviderKeychainStoring protocol verbatim per AGENTS.md §11.3
//     wenshu-side wins pattern)
//  4. ConnectorProfile.Provider integration (= existing Provider enum
//     extended with Gemini / DeepSeek / Ollama cases)
//
//  All tests use InMemoryKeychainStore backend (= test isolation per
//  existing ProviderKeychainTests pattern).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("LLMConnector (ticket 001 sub-step 2)")
struct LLMConnectorTests {

    // MARK: - Test 1: Protocol conformance

    @Test("LLMConnector protocol can be conformed by a test type")
    func testProtocolConformance() async throws {
        let mock = MockLLMConnector()
        let messages = [LLMMessage(role: .user, blocks: [.text("hi")])]
        let options = LLMCallOptions(model: "mock-model", maxTokens: 100)
        let response = try await mock.send(messages: messages, options: options)
        #expect(response.blocks.count == 1)
        if case .text(let s) = response.blocks[0] {
            #expect(s == "echo: hi")
        } else {
            Issue.record("expected text block, got \\(response.blocks[0])")
        }
    }

    // MARK: - Test 2: Cross-connector wire format

    @Test("LLMMessage / LLMResponse support text + thinking + tool_use")
    func testCrossConnectorWireFormat() throws {
        let textMsg = LLMMessage(role: .user, blocks: [.text("hello")])
        let toolMsg = LLMMessage(role: .assistant, blocks: [.toolUse(id: "t1", name: "ReadFile", input: "{}")])
        let toolResult = LLMMessage(role: .tool, blocks: [.toolResult(toolUseID: "t1", output: "file content")])
        #expect(textMsg.role == .user)
        #expect(toolMsg.role == .assistant)
        #expect(toolResult.role == .tool)

        let response = LLMResponse(
            id: "resp-1",
            model: "test-model",
            blocks: [
                .thinking(text: "reasoning", signature: nil),
                .text("answer"),
                .toolUse(id: "t2", name: "WriteFile", input: "{\"path\":\"/tmp/x\"}")
            ],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 10, outputTokens: 20)
        )
        #expect(response.blocks.count == 3)
        #expect(response.stopReason == .endTurn)
        #expect(response.usage.inputTokens == 10)
    }

    // MARK: - Test 3: ConnectorCredentials wenshu-side wins pattern

    @Test("ConnectorCredentials resolves API key from ProviderKeychain (= wenshu-side wins)")
    func testConnectorCredentialsWenshuSideWins() throws {
        // Use InMemoryKeychainStore for hermes (= per ProviderKeychainTests pattern)
        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk-test-12345", for: .anthropic)
        ProviderKeychain.setBackendForTesting(store)

        let creds = ConnectorCredentials.resolve(for: .anthropic)
        #expect(creds.apiKey == "sk-test-12345")
        #expect(creds.provider.slug == "anthropic")
    }

    @Test("ConnectorCredentials returns empty apiKey for Ollama (= no auth)")
    func testConnectorCredentialsOllamaNoAuth() throws {
        // Ollama = local, no key required (per AGENTS.md §11.2 P1)
        let creds = ConnectorCredentials.resolve(for: .ollama)
        #expect(creds.apiKey.isEmpty)
        #expect(creds.provider.slug == "ollama")
    }

    // MARK: - Test 4: Provider enum extended with Gemini / DeepSeek / Ollama

    @Test("Provider enum includes 7 connector profiles (= AGENTS.md §11.2)")
    func testProviderEnumHas7Connectors() {
        // Per AGENTS.md §11.2: 7 connector profiles
        // Existing: anthropic, openai (Codex), minimax, openrouter
        // New (v0.35): gemini, deepseek, ollama
        let sevenSlugs = ["anthropic", "openai-codex", "minimax-cn", "openrouter", "gemini", "deepseek", "ollama"]
        let allSlugs = Set(Provider.all.map(\.slug))
        for slug in sevenSlugs {
            #expect(allSlugs.contains(slug), "missing connector profile: \\(slug)")
        }
    }

    @Test("New Gemini / DeepSeek / Ollama providers have correct wire format")
    func testNewProvidersWireFormat() {
        #expect(Provider.gemini.apiMode == "google_genai")
        #expect(Provider.deepseek.apiMode == "anthropic_messages")
        #expect(Provider.ollama.apiMode == "openai_chat")
        #expect(Provider.ollama.defaultBaseURL == "http://localhost:11434/v1")
    }
}

// MARK: - Mock connector for test 1

private actor MockLLMConnector: LLMConnector {
    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        let userText: String
        if case .text(let s) = messages.last??.content {
            userText = s
        } else {
            userText = ""
        }
        return LLMResponse(
            id: "mock",
            model: options.model,
            blocks: [.text("echo: \\(userText)")],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 5, outputTokens: 5)
        )
    }
}