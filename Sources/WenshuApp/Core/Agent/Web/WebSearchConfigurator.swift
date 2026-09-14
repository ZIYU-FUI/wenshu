//
//  WebSearchConfigurator.swift · Wenshu · v0.76 ticket 001
//
//  Resolves web search API keys from user config (= UserDefaults for dev;
//  future ticket will move to AppleKeychain per AGENTS.md §11) and
//  constructs a populated `WebSearch` actor with the configured providers.
//
//  Hermes counterpart: hermes web_search_provider.py reads API keys from
//  env vars at construction time. Wenshu uses UserDefaults (= Apple HIG
//  canonical for app config) + AppleKeychain is the future per §11.
//
//  Public API:
//    - WebSearchConfigurator.configuredEngine() -> WebSearch
//    - WebSearchConfigurator.searchAPIKeysEnabled() -> Set<String>
//    - WebSearchConfigurator.searchAPIKeyName(for: String) -> String
//      (= translates "exa" → "exa_api_key")
//

import Foundation

/// Resolves web search API key names from provider names.
///
/// Each provider type has a canonical key name (= e.g. `EXAProvider` reads
/// from "exa_api_key"). The key name is what we look up in the user
/// config store (= UserDefaults for now; AppleKeychain in future ticket).
public enum WebSearchConfigurator {

    /// The set of provider names (= EXA / TAVILY / BRAVE / PARALLEL / SEARXNG)
    /// that this configurator knows how to build.
    public static let supportedProviders: [String] = [
        "exa", "tavily", "brave", "parallel", "searxng"
    ]

    /// Returns the canonical API key name for a given provider name.
    /// (= "exa" → "exa_api_key")
    public static func searchAPIKeyName(for providerName: String) -> String? {
        switch providerName {
        case "exa": return "exa_api_key"
        case "tavily": return "tavily_api_key"
        case "brave": return "brave_api_key"
        case "parallel": return "parallel_api_key"
        case "searxng": return nil  // = SEARXNG typically has no API key (= user-supplied URL)
        default: return nil
        }
    }

    /// The UserDefaults key prefix for web search API keys.
    /// (= the user-config keys are stored under "wenshu.search.<provider_name>").
    public static let userDefaultsKeyPrefix = "wenshu.search."

    /// Read API keys from `SearchAPIKeychain` (= Apple Keychain in production
    /// per AGENTS.md §11; = InMemorySearchKeychainStore in tests via
    /// `SearchAPIKeychain.setBackendForTesting(...)`).
    ///
    /// First-launch migration: if `wenshu.search.<key_name>` exists in
    /// UserDefaults (= legacy v0.76 dev path), it is moved into the
    /// SearchAPIKeychain (= Apple Keychain) and the UserDefaults entry
    /// is deleted. The migration runs once per key on first access; = after
    /// the first launch the UserDefaults entries are empty.
    public static func configuredEngine() -> WebSearch {
        let providers: [any WebSearchProvider] = supportedProviders.compactMap { name in
            guard let keyName = searchAPIKeyName(for: name) else {
                // SEARXNG: needs endpoint URL, not API key
                // (= skipped here; = future ticket when user supplies URL)
                return nil
            }

            // Migration from UserDefaults (= v0.76 dev path) to
            // SearchAPIKeychain (= production path per §11).
            let defaultsKey = userDefaultsKeyPrefix + keyName
            if let legacyKey = UserDefaults.standard.string(forKey: defaultsKey),
               !legacyKey.isEmpty
            {
                do {
                    try SearchAPIKeychain.saveKey(legacyKey, for: name)
                    UserDefaults.standard.removeObject(forKey: defaultsKey)
                } catch {
                    // Migration failure = fall back to legacy key in this session
                    // (= next launch will retry the migration).
                    return provider(for: name, apiKey: legacyKey)
                }
                return provider(for: name, apiKey: legacyKey)
            }

            guard let apiKey = SearchAPIKeychain.loadKey(for: name),
                  !apiKey.isEmpty
            else {
                return nil
            }

            return provider(for: name, apiKey: apiKey)
        }

        return WebSearch(providers: providers)
    }

    /// Return the set of provider names (= not key names) that currently
    /// have a configured API key in the SearchAPIKeychain.
    /// Used for UI affordances (= show the user which providers are enabled
    /// without exposing the key).
    public static func searchAPIKeysEnabled() -> Set<String> {
        let configured = SearchAPIKeychain.listConfiguredProviders()
        var enabled: Set<String> = []
        for name in supportedProviders {
            guard searchAPIKeyName(for: name) != nil else { continue }
            if configured.contains(name) {
                enabled.insert(name)
            }
        }
        return enabled
    }

    // MARK: - Private

    /// Build the provider instance for a given name (= returns nil for
    /// unknown names; = matches the "unknown provider" silent-skip pattern).
    private static func provider(for name: String, apiKey: String) -> (any WebSearchProvider)? {
        switch name {
        case "exa": return EXAProvider(apiKey: apiKey)
        case "tavily": return TAVILYProvider(apiKey: apiKey)
        case "brave": return BRAVEProvider(apiKey: apiKey)
        case "parallel": return PARALLELProvider(apiKey: apiKey)
        case "searxng":
            // SEARXNG uses endpoint URL not API key (= handled by future ticket)
            return nil
        default: return nil
        }
    }
}