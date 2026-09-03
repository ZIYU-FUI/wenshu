//
//  LLMConnectorSettingsView.swift · Wenshu · v0.35 ticket 006
//
//  Settings pane for the 7 LLM connector profiles (= AGENTS.md §11.2).
//  User picks an active profile + supplies credentials; wenshu stores
//  in macOS Keychain via existing ProviderKeychain (= §11.3 wenshu-side wins).
//
//  v0.35 ticket 006 (= 🟥 must-UI per spec §6.4).
//

import SwiftUI

/// Main settings pane (= used as a child view in Settings弹窗).
/// Renders 7 ConnectorProfileRow cards (Anthropic, OpenAI, minimax cn,
/// DeepSeek, Gemini, Ollama, OpenRouter).
public struct LLMConnectorSettingsView: View {

    @State public var activeConnectorID: String
    @State public var profiles: [ConnectorProfileState]

    public init(
        activeConnectorID: String = "anthropic",
        profiles: [ConnectorProfileState] = ConnectorProfileState.allDefaults
    ) {
        self._activeConnectorID = State(initialValue: activeConnectorID)
        self._profiles = State(initialValue: profiles)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("LLM Connector")
                    .font(.headline)
                Text("Pick an active LLM provider + supply credentials. Wenshu is BYOK (= bring your own key).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Divider()

            // 7 profile rows (= one per connector)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($profiles) { $profile in
                        ConnectorProfileRow(
                            profile: $profile,
                            isActive: profile.connectorID == activeConnectorID,
                            onActivate: {
                                activeConnectorID = profile.connectorID
                                profile.markActive()
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// Mutable state for one connector profile (= key + active flag + test status).
public struct ConnectorProfileState: Identifiable, Sendable {
    public let provider: Provider
    public var apiKey: String  // user-entered; never logged
    public var isKeyConfigured: Bool  // true after user saves successfully
    public var lastTestStatus: TestStatus
    public var endpointOverride: String  // for non-default base URLs

    public var id: String { provider.slug }
    public var connectorID: String { provider.slug }

    public enum TestStatus: Sendable, Equatable {
        case notTested
        case testing
        case success
        case failure(String)
    }

    public init(provider: Provider) {
        self.provider = provider
        self.apiKey = ""
        self.isKeyConfigured = false
        self.lastTestStatus = .notTested
        self.endpointOverride = provider.defaultBaseURL
    }

    public mutating func markActive() {
        // Persist to UserDefaults (= active connector selection)
        UserDefaults.standard.set(provider.slug, forKey: "wenshu.llm.activeConnector")
    }

    /// All 7 connector profile defaults (= AGENTS.md §11.2).
    public static let allDefaults: [ConnectorProfileState] = [
        ConnectorProfileState(provider: .anthropic),
        ConnectorProfileState(provider: .openaiCodex),
        ConnectorProfileState(provider: .minimaxCn),
        ConnectorProfileState(provider: .deepseek),
        ConnectorProfileState(provider: .gemini),
        ConnectorProfileState(provider: .ollama),
        ConnectorProfileState(provider: .openrouter)
    ]
}