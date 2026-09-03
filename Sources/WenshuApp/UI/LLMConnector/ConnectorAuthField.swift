//
//  ConnectorAuthField.swift · Wenshu · v0.35 ticket 006
//
//  API key input field (= SecureField for password-style entry).
//  Replaces v0.34's popover pattern (= inline secure text field per
//  boss 2026-08-22 ticket 15 directive "modify the Settings page to
//  replace the key-input popover with an inline secure text field").
//

import SwiftUI

public struct ConnectorAuthField: View {

    @Binding public var apiKey: String
    public let isConfigured: Bool
    @State private var isRevealed: Bool = false
    public let provider: Provider  // passed from parent (ConnectorProfileRow)

    public init(
        apiKey: Binding<String>,
        isConfigured: Bool,
        provider: Provider
    ) {
        self._apiKey = apiKey
        self.isConfigured = isConfigured
        self.provider = provider
    }

    public var body: some View {
        HStack {
            Text("API key")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            Group {
                if isRevealed {
                    TextField("", text: $apiKey)
                } else {
                    SecureField("", text: $apiKey)
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.caption)
            .onSubmit {
                saveKey()
            }

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)

            if isConfigured {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .help("Key saved to Keychain")
            }
        }
    }

    private func saveKey() {
        guard !apiKey.isEmpty else { return }
        do {
            try ProviderKeychain.saveKeySync(apiKey, for: provider)
        } catch {
            // Logged but not surfaced (= keychain errors are infra-level)
            NSLog("[wenshu.connector] failed to save key: %@", error.localizedDescription)
        }
    }
}