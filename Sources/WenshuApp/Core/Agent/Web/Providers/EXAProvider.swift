//
//  EXAProvider.swift · Wenshu · v0.74 ticket 001-websearch-providers-stub
//
//  1:1 port of hermes web_search_provider.py EXAProvider (= one of the 5
//  hermes search providers per HERMES-INTERNAL-001 + spec §3.1).
//
//  EXA API endpoint: https://api.exa.ai/search
//  Hermes counterpart: hermes/web_search_provider.py EXAProvider class
//  API key name: "exa_api_key" (= read from ProviderKeychain)
//
//  Per AGENTS.md §11.1: NO third-party SDKs for HTTP. URLSession only.
//  Per AGENTS.md §11: API key via ProviderKeychain. NO plaintext.
//  Per Q42: thin adapter over URLSession; = NO duplicate provider logic.
//
//  Stub behavior: returns [] (= empty success) when the API key is
//  missing (= "config not yet set"). This lets the WebSearch actor's
//  rotation path execute (= empty result → try next provider) without
//  throwing on first call. Real HTTP request is wired in a future
//  ticket once API keys are populated by the user.
//

import Foundation

public struct EXAProvider: WebSearchProvider, Sendable {

    public let name: String = "exa"

    /// Designated init. Reads the API key from `ProviderKeychain`
    /// (= AGENTS.md §11). If the key is absent, the provider returns
    /// empty results (= signals "not configured" without throwing).
    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }

    /// Stored API key. `nil` = not configured (= stub behavior).
    private let apiKey: String?

    public func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        // Stub: API key not yet populated by the user (= common dev state).
        // Returning empty triggers the WebSearch actor's rotation logic
        // (= try next provider) without surfacing an error to the LLM.
        guard let apiKey, !apiKey.isEmpty else {
            return []
        }

        // Real HTTP request path (= future ticket when API keys ship).
        // Reserved for the v0.75 ticket "WebSearch provider real HTTP".
        guard let url = URL(string: "https://api.exa.ai/search") else {
            throw WebSearchError.providerFailure(name: name, underlying: "invalid EXA endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 15

        let payload: [String: Any] = [
            "query": query,
            "numResults": limit
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WebSearchError.providerFailure(name: name, underlying: "non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw WebSearchError.providerFailure(
                name: name,
                underlying: "HTTP \(http.statusCode)"
            )
        }

        // Parse EXA response shape (= { "results": [{ "title", "url", "text", ... }] }).
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else {
            throw WebSearchError.providerFailure(name: name, underlying: "unexpected response shape")
        }

        return results.compactMap { item in
            guard let title = item["title"] as? String,
                  let urlString = item["url"] as? String,
                  let resultURL = URL(string: urlString)
            else {
                return nil
            }
            let snippet = (item["text"] as? String) ?? (item["snippet"] as? String) ?? ""
            return WebSearchResult(title: title, snippet: snippet, url: resultURL)
        }
    }
}