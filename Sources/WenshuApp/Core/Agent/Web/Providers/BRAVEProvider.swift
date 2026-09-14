//
//  BRAVEProvider.swift · Wenshu · v0.74 ticket 001-websearch-providers-stub
//
//  1:1 port of hermes web_search_provider.py BRAVEProvider.
//
//  BRAVE Search API endpoint: https://api.search.brave.com/res/v1/web/search
//  Hermes counterpart: hermes/web_search_provider.py BRAVEProvider class
//  API key name: "brave_api_key" (= read from ProviderKeychain)
//
//  Per AGENTS.md §11.1: NO third-party SDKs. URLSession only.
//  Per AGENTS.md §11: API key via ProviderKeychain.
//
//  Stub behavior: returns [] when API key missing.
//

import Foundation

public struct BRAVEProvider: WebSearchProvider, Sendable {

    public let name: String = "brave"

    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }

    private let apiKey: String?

    public func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        guard let apiKey, !apiKey.isEmpty else {
            return []
        }

        // BRAVE uses GET with query parameters (= differs from EXA / TAVILY POST).
        var components = URLComponents(string: "https://api.search.brave.com/res/v1/web/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(limit))
        ]
        guard let url = components?.url else {
            throw WebSearchError.providerFailure(name: name, underlying: "invalid BRAVE endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        request.timeoutInterval = 15

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

        // Parse BRAVE response shape (= { "web": { "results": [{ "title", "url", "description" }] } }).
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let web = json["web"] as? [String: Any],
              let results = web["results"] as? [[String: Any]]
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
            let snippet = (item["description"] as? String) ?? ""
            return WebSearchResult(title: title, snippet: snippet, url: resultURL)
        }
    }
}