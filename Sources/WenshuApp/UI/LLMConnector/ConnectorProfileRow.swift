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

// File-scope constants (= Apple HIG card / badge standards not in
// DesignTokens default catalog; documented as feature constants per
// iron rule 6 = no magic numbers in view code).
private let cardCornerRadius: CGFloat = 8
private let badgeCornerRadius: CGFloat = 8
private let badgePaddingHorizontal: CGFloat = 6
private let badgePaddingVertical: CGFloat = 2
private let activeBadgeAlpha: CGFloat = 0.2
private let inactiveStrokeAlpha: CGFloat = 0.2
private let activeStrokeWidth: CGFloat = 2
private let inactiveStrokeWidth: CGFloat = 1
private let rowSpacing: CGFloat = 8

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
        VStack(alignment: .leading, spacing: rowSpacing) {
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
                        .padding(.horizontal, badgePaddingHorizontal)
                        .padding(.vertical, badgePaddingVertical)
                        .background(
                            Color.accentColor.opacity(activeBadgeAlpha),
                            in: RoundedRectangle(cornerRadius: badgeCornerRadius, style: .continuous)
                        )
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
        .padding(DesignTokens.chromePaddingMedium)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(
                            isActive ? Color.accentColor : Color.gray.opacity(inactiveStrokeAlpha),
                            lineWidth: isActive ? activeStrokeWidth : inactiveStrokeWidth
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