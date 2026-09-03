//
//  ConnectorProfileRow.swift · Wenshu · v0.35 ticket 006
//
//  One row in LLMConnectorSettingsView (= one per provider).
//  Shows: provider name + protocol + auth field + endpoint + test button.
//

import SwiftUI

public struct ConnectorProfileRow: View {

    @Binding public var profile: ConnectorProfileState
    public let isActive: Bool
    public let onActivate: () -> Void

    public init(
        profile: Binding<ConnectorProfileState>,
        isActive: Bool,
        onActivate: @escaping () -> Void
    ) {
        self._profile = profile
        self.isActive = isActive
        self.onActivate = onActivate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: name + protocol + active badge
            HStack {
                Text(profile.provider.name)
                    .font(.headline)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(apiModeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isActive {
                    Text("Active")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2), in: Capsule())
                } else {
                    Button("Use") { onActivate() }
                        .buttonStyle(.borderless)
                }
            }

            // API key input (for non-Ollama)
            if profile.provider.slug != "ollama" {
                ConnectorAuthField(
                    apiKey: $profile.apiKey,
                    isConfigured: profile.isKeyConfigured,
                    provider: profile.provider
                )
            } else {
                Text("No key required (local)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Endpoint URL (= editable override)
            HStack {
                Text("Endpoint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $profile.endpointOverride)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }

            // Test button + status
            HStack {
                ConnectorTestButton(
                    provider: profile.provider,
                    apiKey: profile.apiKey,
                    endpoint: profile.endpointOverride,
                    status: $profile.lastTestStatus
                )
                Spacer()
                if case .failure(let msg) = profile.lastTestStatus {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isActive ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isActive ? 2 : 1)
                )
        )
    }

    private var apiModeLabel: String {
        switch profile.provider.apiMode {
        case "anthropic_messages": return "Anthropic Messages"
        case "openai_chat": return "OpenAI Chat"
        case "google_genai": return "Google GenAI"
        default: return profile.provider.apiMode
        }
    }
}