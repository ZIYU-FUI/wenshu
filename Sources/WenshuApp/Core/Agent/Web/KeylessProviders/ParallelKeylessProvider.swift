//
//  ParallelKeylessProvider.swift · Wenshu
//
//  Anonymous free tier web search via the Parallel Search MCP server.
//
//  1:1 port of hermes plugins/web/keyless_mcp.py parallel_search_keyless.
//  Endpoint: https://search.parallel.ai/mcp
//  Transport: MCP Streamable HTTP JSON-RPC 2.0 (= MCPJSONRPCClient primitive).
//  Tool: "web_search". Arguments: { objective, search_queries, session_id }.
//  Response: JSON text payload, parsed into [{url, title, excerpts}].
//
//  No API key, no OAuth, no signup (= anonymous free tier; = the
//  session_id is a per-process UUID for free-tier rate-limit correlation).
//
//

import Foundation

struct ParallelKeylessProvider: WebSearchProvider, Sendable {

    let name: String = "parallel"

    private let client: MCPJSONRPCClient

    /// Default init: per-process UUID = hermes 1:1.
    init(sessionID: String = UUID().uuidString.lowercased()) {
        self.client = MCPJSONRPCClient(
            endpoint: URL(string: "https://search.parallel.ai/mcp")!,
            userAgent: "wenshu",
            timeout: 30
        )
        self.sessionID = sessionID
    }

    /// Designated init for tests (= custom session + optional explicit sessionID).
    init(client: MCPJSONRPCClient, sessionID: String = UUID().uuidString.lowercased()) {
        self.client = client
        self.sessionID = sessionID
    }

    private let sessionID: String

    func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        let text = try await client.call(
            tool: "web_search",
            arguments: [
                "objective": query,
                "search_queries": [query],
                "session_id": sessionID
            ]
        )
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]]
        else {
            throw WebSearchError.providerFailure(
                name: name,
                underlying: "Parallel returned non-JSON or missing 'results' field"
            )
        }
        let cap = max(limit, 0)
        let sliced = cap > 0 ? Array(results.prefix(cap)) : results
        return sliced.enumerated().compactMap { (idx, r) -> WebSearchResult? in
            guard let urlString = r["url"] as? String,
                  let url = URL(string: urlString)
            else { return nil }
            let title = (r["title"] as? String) ?? ""
            let excerpts = (r["excerpts"] as? [String]) ?? []
            let snippet = excerpts.joined(separator: " ")
            return WebSearchResult(title: title, snippet: snippet, url: url)
        }
    }
}