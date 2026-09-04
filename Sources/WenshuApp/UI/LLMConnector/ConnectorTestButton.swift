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

        // Build the right connector for this provider
        let connector: any LLMConnector
        switch provider.apiMode {
        case "anthropic_messages":
            connector = AnthropicConnector()
        case "openai_chat":
            connector = OpenAICompatibleConnector(provider: provider)
        case "google_genai":
            // Gemini native connector = ticket 007
            status = .failure("Gemini native connector lands in ticket 007")
            return
        default:
            status = .failure("Unsupported provider apiMode: \\(provider.apiMode)")
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