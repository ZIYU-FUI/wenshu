//
//  ExaKeylessProvider.swift · Wenshu
//
//  Anonymous free tier web search via the Exa MCP server.
//
//  1:1 port of hermes plugins/web/keyless_mcp.py exa_search_keyless.
//  Endpoint: https://mcp.exa.ai/mcp
//  Transport: MCP Streamable HTTP JSON-RPC 2.0 (= MCPJSONRPCClient primitive).
//  Tool: "web_search_exa". Arguments: { query, numResults }.
//  Response: PLAIN TEXT, not JSON. Parsed block-by-block on
//  "Title:" / "URL:" / "Published:" / "Author:" / "Highlights:" labels,
//  blocks separated by a line containing only "\n---\n".
//
//  No API key, no OAuth, no signup (= Keyless mode per exa docs).
//

import Foundation

struct ExaKeylessProvider: WebSearchProvider, Sendable {

    let name: String = "exa"

    private let client: MCPJSONRPCClient

    init() {
        self.client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.exa.ai/mcp")!,
            userAgent: "wenshu",
            timeout: 30
        )
    }

    /// Designated init for tests (= custom MCPJSONRPCClient).
    init(client: MCPJSONRPCClient) {
        self.client = client
    }

    private static let labels: [String] = [
        "Title:", "URL:", "Highlights:", "Published:", "Author:"
    ]

    func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        let text = try await client.call(
            tool: "web_search_exa",
            arguments: ["query": query, "numResults": max(1, limit)]
        )

        var results: [WebSearchResult] = []
        let blocks = text.components(separatedBy: "\n---\n")
        for block in blocks {
            guard let parsed = Self.parseBlock(block) else { continue }
            guard let url = URL(string: parsed.urlString), !parsed.urlString.isEmpty else {
                continue
            }
            results.append(WebSearchResult(
                title: parsed.title,
                snippet: parsed.highlights.joined(separator: " "),
                url: url
            ))
            if limit > 0 && results.count >= limit { break }
        }
        return results
    }

    /// Parse one block of Exa response text.
    /// Returns the parsed title / urlString / highlights, or nil if the
    /// block is empty / whitespace-only (= skip silently).
    private static func parseBlock(_ block: String) -> (title: String, urlString: String, highlights: [String])? {
        let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBlock.isEmpty { return nil }

        var title = ""
        var urlString = ""
        var highlights: [String] = []
        var inHighlights = false

        for raw in block.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("Title:") {
                title = Self.after(line, prefix: "Title:")
                inHighlights = false
            } else if line.hasPrefix("URL:") {
                urlString = Self.after(line, prefix: "URL:")
                inHighlights = false
            } else if line.hasPrefix("Published:") {
                _ = Self.after(line, prefix: "Published:")
                inHighlights = false
            } else if line.hasPrefix("Author:") {
                _ = Self.after(line, prefix: "Author:")
                inHighlights = false
            } else if line.hasPrefix("Highlights:") {
                inHighlights = true
            } else if inHighlights && !labels.contains(where: { line.hasPrefix($0) }) {
                highlights.append(line)
            }
        }
        return (title: title, urlString: urlString, highlights: highlights)
    }

    private static func after(_ line: String, prefix: String) -> String {
        guard line.hasPrefix(prefix) else { return line }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }
}