//
//  TAVILYProvider.swift · Wenshu · v0.74 ticket 001-websearch-providers-stub
//
//  1:1 port of hermes web_search_provider.py TAVILYProvider.
//
//  TAVILY API endpoint: https://api.tavily.com/search
//  Hermes counterpart: hermes/web_search_provider.py TAVILYProvider class
//  API key name: "tavily_api_key" (= read from ProviderKeychain)
//
//  Per AGENTS.md §11.1: NO third-party SDKs. URLSession only.
//  Per AGENTS.md §11: API key via ProviderKeychain.
//  Per Q42: thin adapter. NO duplicate provider logic.
//
//  Stub behavior: returns [] when API key missing.
//

import Foundation

public struct TAVILYProvider: WebSearchProvider, Sendable {

    public let name: String = "tavily"

    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }

    private let apiKey: String?

    public func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        guard let apiKey, !apiKey.isEmpty else {
            return []
        }

        guard let url = URL(string: "https://api.tavily.com/search") else {
            throw WebSearchError.providerFailure(name: name, underlying: "invalid TAVILY endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")  // TAVILY uses "Bearer" prefix OR raw key per docs
        request.timeoutInterval = 15

        let payload: [String: Any] = [
            "query": query,
            "max_results": limit,
            "include_answer": false
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

        // Parse TAVILY response shape (= { "results": [{ "title", "url", "content" }] }).
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
            let snippet = (item["content"] as? String) ?? ""
            return WebSearchResult(title: title, snippet: snippet, url: resultURL)
        }
    }
}