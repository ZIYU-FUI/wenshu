//
//  ConnectorTestButton.swift · Wenshu · v0.35 ticket 006
//
//  Smoke-test button for connector credentials.
//  Sends a minimal request via the active connector's LLMConnector.send
//  and reports success/failure. Validates the key + endpoint without
//  polluting the chat history.
//

import SwiftUI


public struct ConnectorTestButton: View {

    public let provider: Provider
    public let apiKey: String
    public let endpoint: String
    @Binding public var status: ConnectorProfileState.TestStatus

    public init(
        provider: Provider,
        apiKey: String,
        endpoint: String,
        status: Binding<ConnectorProfileState.TestStatus>
    ) {
        self.provider = provider
        self.apiKey = apiKey
        self.endpoint = endpoint
        self._status = status
    }

    public var body: some View {
        Button {
            Task { await runTest() }
        } label: {
            label
        }
        .buttonStyle(.bordered)
        .disabled(isDisabled)
    }

    @ViewBuilder
    private var label: some View {
        switch status {
        case .testing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text(WenshuI18n.t("settings.connector.status.testing"))
            }
        case .success:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                Text(WenshuI18n.t("settings.connector.status.passed"))
            }
        case .failure:
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                Text(WenshuI18n.t("settings.connector.status.retry"))
            }
        case .notTested:
            Text(WenshuI18n.t("settings.connector.field.test"))
        }
    }

    private var isDisabled: Bool {
        if case .testing = status { return true }
        if provider.slug != "ollama" && apiKey.isEmpty { return true }
        return false
    }

    /// Run a smoke test against the provider's API (= sends minimal
    /// request, checks for 2xx response).
    private func runTest() async {
        status = .testing

        // v0.40 apple-001 + boss real-device test (2026-09-07) fix:
        // The connectors read the API key from the keychain
        // (= `WenshuAppDelegate.activeLLMConnector()` reads
        // `wenshu.llm.<provider>-key` from keychain, = the active
        // provider's key, NOT the per-row key). When the user types
        // a key in the per-row field but doesn't press Enter, the
        // typed value is in-memory only (= `profile.apiKey` is set,
        // but keychain still has the OLD value or empty for that
        // provider). Clicking "Test connection" then constructs an
        // AnthropicConnector / OpenAICompatibleConnector (= no apiKey
        // param = reads keychain) and calls `.send`, which then reads
        // the wrong (= stale / empty) key from the active slot.
        //
        // Bug reproduction (boss 2026-09-07): user has minimax active
        // (= wenshu.llm.activeConnector = "minimax"). User types
        // minimax key in the row's field. User clicks Test connection
        // on the row. Connector reads wenshu.llm.anthropic-key
        // (= active provider's key, = empty for the user) and fails
        // with "Missing API key for provider 'anthropic'".
        //
        // Fix: save the typed key to the keychain BEFORE constructing
        // the connector, so the connector reads the right (= just-typed)
        // key. The key is saved with the row's provider slug (= the
        // row being tested), NOT the active provider.
        if !apiKey.isEmpty {
            do {
                try ProviderKeychain.saveKeySync(apiKey, for: provider)
            } catch {
                status = .failure("Failed to save key: \(error.localizedDescription)")
                return
            }
        }

        // Build the right connector for this provider
        let connector: any LLMConnector
        switch provider.apiMode {
        case "anthropic_messages":
            connector = AnthropicConnector()
        case "openai_chat":
            connector = OpenAICompatibleConnector(provider: provider)
        case "google_genai":
            // Gemini native connector = ticket 007
            status = .failure(WenshuI18n.t("connector.gemini_unavailable"))
            return
        default:
            status = .failure("Unsupported provider apiMode: \(provider.apiMode)")
            return
        }

        // Smoke test: minimal 1-token request
        let testMessages = [LLMMessage.user("hi")]
        let options = LLMCallOptions(
            model: provider.defaultModels.first ?? "unknown",
            maxTokens: 1
        )

        do {
            _ = try await connector.send(messages: testMessages, options: options)
            status = .success
        } catch let error as LLMConnectorError {
            status = .failure(error.errorDescription ?? "Unknown error")
        } catch {
            status = .failure(error.localizedDescription)
        }
    }
}