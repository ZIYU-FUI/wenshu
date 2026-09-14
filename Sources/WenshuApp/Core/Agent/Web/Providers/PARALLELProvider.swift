//
//  PARALLELProvider.swift · Wenshu · v0.74 ticket 001-websearch-providers-stub
//
//  1:1 port of hermes web_search_provider.py PARALLELProvider.
//
//  Parallel Web Search API endpoint: https://api.parallel.ai/v1/search
//  Hermes counterpart: hermes/web_search_provider.py PARALLELProvider class
//  API key name: "parallel_api_key" (= read from ProviderKeychain)
//
//  Per AGENTS.md §11.1: NO third-party SDKs. URLSession only.
//  Per AGENTS.md §11: API key via ProviderKeychain.
//
//  Stub behavior: returns [] when API key missing.
//

import Foundation

public struct PARALLELProvider: WebSearchProvider, Sendable {

    public let name: String = "parallel"

    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }

    private let apiKey: String?

    public func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        guard let apiKey, !apiKey.isEmpty else {
            return []
        }

        guard let url = URL(string: "https://api.parallel.ai/v1/search") else {
            throw WebSearchError.providerFailure(name: name, underlying: "invalid PARALLEL endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let payload: [String: Any] = [
            "query": query,
            "max_results": limit
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

        // Parse Parallel response shape (= { "results": [{ "title", "url", "excerpt" }] }).
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
            let snippet = (item["excerpt"] as? String) ?? ""
            return WebSearchResult(title: title, snippet: snippet, url: resultURL)
        }
    }
}