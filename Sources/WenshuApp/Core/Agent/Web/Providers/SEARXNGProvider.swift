//
//  SEARXNGProvider.swift · Wenshu · v0.74 ticket 001-websearch-providers-stub
//
//  1:1 port of hermes web_search_provider.py SEARXNGProvider.
//
//  SEARXNG endpoint: configurable (= per-instance; = not a single canonical URL).
//  Hermes counterpart: hermes/web_search_provider.py SEARXNGProvider class
//  API key: NONE for most instances (= public SEARXNG deployments).
//
//  Per AGENTS.md §11.1: NO third-party SDKs. URLSession only.
//  Per AGENTS.md §11: configurable endpoint URL via UserDefaults
//  (= wenshu user configures their own SEARXNG instance URL).
//
//  Stub behavior: returns [] when endpoint URL missing (= not configured).
//

import Foundation

public struct SEARXNGProvider: WebSearchProvider, Sendable {

    public let name: String = "searxng"

    public init(endpointURL: URL? = nil) {
        self.endpointURL = endpointURL
    }

    private let endpointURL: URL?

    public func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        guard let endpointURL else {
            return []
        }

        // SEARXNG uses GET with query parameters + format=json.
        var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "count", value: String(limit))
        ]
        guard let url = components?.url else {
            throw WebSearchError.providerFailure(name: name, underlying: "invalid SEARXNG endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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

        // Parse SEARXNG JSON response shape (= { "results": [{ "title", "url", "content" }] }).
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