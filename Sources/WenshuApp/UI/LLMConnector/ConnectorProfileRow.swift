//
//  ConnectorProfileRow.swift · Wenshu · v0.35 ticket 006
//
//  One row in LLMConnectorSettingsView (= one per provider).
//  Shows: provider name + protocol + auth field + endpoint + test button.
//
//  Iron rule 6 compliance: layout/spacing uses DesignTokens. Active-badge
//  highlight + card border use Apple HIG canonical system colors.
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
        VStack(alignment: .leading, spacing: DesignTokens.settingsRowSpacing) {
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
                    Text(WenshuI18n.t("settings.connector.row.active"))
                        .font(.caption)
                        .padding(.horizontal, DesignTokens.chromePaddingSmall)
                        .padding(.vertical, DesignTokens.badgePaddingVertical)
                        .background(
                            Color.accentColor.opacity(DesignTokens.surfaceActiveTintAlpha),
                            in: RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusBadge, style: .continuous)
                        )
                } else {
                    Button(WenshuI18n.t("settings.connector.row.use")) { onActivate() }
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
                Text(WenshuI18n.t("settings.connector.noKeyRequired"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Endpoint URL (= editable override)
            HStack {
                Text(WenshuI18n.t("settings.connector.field.endpoint"))
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
        .padding(DesignTokens.chromePaddingMedium)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusCard, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusCard, style: .continuous)
                        .stroke(
                            isActive ? Color.accentColor : Color.gray.opacity(DesignTokens.surfaceInactiveBorderAlpha),
                            lineWidth: isActive ? DesignTokens.surfaceActiveBorderWidth : DesignTokens.surfaceInactiveBorderWidth
                        )
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