//
//  ConnectorCredentials.swift · Wenshu · v0.35 ticket 001 sub-step 2
//
//  Thin resolver that delegates to existing wenshu ProviderKeychain
//  (= AGENTS.md §11.3 wenshu-side wins pattern: do not re-implement
//  keychain; reuse the existing ProviderKeychainStoring protocol verbatim).
//
//  Resolves the active connector profile (= Provider enum) to:
//    - apiKey: String (= "" for providers without auth, e.g.g. Ollama)
//    - baseURL: String (= Provider.defaultBaseURL, or user-customized via Settings)
//    - provider: Provider (= the source of truth for slug / auth / wire format)
//
//  This is the minimum credential surface needed by LLMConnector.send.
//  Full credential pool with OAuth flow + key rotation lands in ticket 006.
//
//  v0.35 sub-step 2 of 8 for ticket 001.
//

import Foundation

public struct ConnectorCredentials: Sendable {
    public let provider: Provider
    public let apiKey: String
    public let baseURL: String

    public init(provider: Provider, apiKey: String, baseURL: String) {
        self.provider = provider
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    /// Resolve credentials for a connector profile via existing ProviderKeychain.
    ///
    /// - Parameters:
    ///   - provider: The connector profile (= Provider enum from Core/Provider).
    /// - Returns: ConnectorCredentials with apiKey from Keychain (= "" for
    ///   no-auth providers like Ollama) and baseURL from Provider.defaultBaseURL.
    public static func resolve(for provider: Provider) -> ConnectorCredentials {
        let key: String
        // Ollama = local, no auth (= per AGENTS.md §11.2 P1 row "Ollama | None (local)")
        if provider.slug == "ollama" {
            key = ""
        } else {
            key = ProviderKeychain.loadKeySync(for: provider) ?? ""
        }
        return ConnectorCredentials(
            provider: provider,
            apiKey: key,
            baseURL: provider.defaultBaseURL
        )
    }
}