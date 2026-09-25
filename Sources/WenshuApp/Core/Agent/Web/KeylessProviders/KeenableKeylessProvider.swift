//
//  KeenableKeylessProvider.swift · Wenshu
//
//  Anonymous free tier web search via Keenable's public REST endpoint.
//
//  1:1 port of hermes plugins/web/keyless_mcp.py keenable_search_keyless.
//  Endpoint: https://api.keenable.ai/v1/search/public
//  Transport: plain REST POST (NOT MCP).
//  Headers: X-Keenable-Title = <app-name> (= mandatory; = server rejects
//           without it as 'Missing app identifier').
//  Body: { query, max_results }
//  Response: { results: [{url, title, snippet, description}] }.
//
//  No API key, no signup (= keyless public pool; = rate-limited per IP;
//  = consume no credits).
//
//

import Foundation

struct KeenableKeylessProvider: WebSearchProvider, Sendable {

    let name: String = "keenable"

    let endpoint: URL
    let appTitle: String
    private let session: URLSession

    init(appTitle: String = "wenshu", session: URLSession = .shared) {
        self.endpoint = URL(string: "https://api.keenable.ai/v1/search/public")!
        self.appTitle = appTitle
        self.session = session
    }

    func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appTitle, forHTTPHeaderField: "X-Keenable-Title")
        request.timeoutInterval = 30
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "query": query,
                "max_results": max(1, limit)
            ])
        } catch {
            throw WebSearchError.providerFailure(
                name: name,
                underlying: "failed to encode request body: \(error)"
            )
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw WebSearchError.providerFailure(
                name: name,
                underlying: "transport failure: \(error)"
            )
        }
        guard let http = response as? HTTPURLResponse else {
            throw WebSearchError.providerFailure(
                name: name,
                underlying: "non-HTTP response"
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let preview = String(body.prefix(200))
            throw WebSearchError.providerFailure(
                name: name,
                underlying: "HTTP \(http.statusCode): \(preview)"
            )
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else {
            throw WebSearchError.providerFailure(
                name: name,
                underlying: "Keenable returned non-JSON or missing 'results' field"
            )
        }
        let cap = max(limit, 0)
        let sliced = cap > 0 ? Array(results.prefix(cap)) : results
        return sliced.enumerated().compactMap { (idx, r) -> WebSearchResult? in
            guard let urlString = r["url"] as? String,
                  let url = URL(string: urlString)
            else { return nil }
            let title = (r["title"] as? String) ?? ""
            let snippet = (r["snippet"] as? String) ?? (r["description"] as? String) ?? ""
            return WebSearchResult(title: title, snippet: snippet, url: url)
        }
    }
}