//
//  WebSearchTool.swift · Wenshu
//
//  LLM-facing wrapper over WebSearch.shared. Uses the keyless ring
//  (= Parallel / Exa / Keenable anonymous free tier). No API key needed.
//  JSON envelope shape matches the hermes search_ok / search_fail contract.
//
//

import Foundation

final class WebSearchTool: Tool, @unchecked Sendable {

    static let shared = WebSearchTool()

    private let engine: WebSearch

    /// Designated init (= allows tests to inject a `WebSearch` with
    /// custom ring).
    init(engine: WebSearch = WebSearch.shared) {
        self.engine = engine
    }

    func execute(input: String) async throws -> String {
        let payload = parseJSON(input)
        let action = (payload["action"] as? String ?? "").lowercased()

        switch action {
        case "search":
            return await handleSearch(payload: payload)
        case "research":
            return await handleResearch(payload: payload)
        case "":
            return jsonError(action: nil, message: "missing required field: action")
        default:
            return jsonError(action: action, message: "unknown action '\(action)'; expected one of: search, research")
        }
    }

    private func handleSearch(payload: [String: Any]) async -> String {
        guard let query = payload["query"] as? String, !query.isEmpty else {
            return jsonError(action: "search", message: "missing required field: query")
        }
        let limit = (payload["limit"] as? Int) ?? 10
        do {
            let results = try await engine.search(query: query, limit: limit)
            let items = results.map { result -> [String: Any] in
                var dict: [String: Any] = [
                    "title": result.title,
                    "url": result.url.absoluteString,
                    "snippet": result.snippet
                ]
                if let published = result.publishedAt {
                    dict["published_at"] = published.formatted(.iso8601)
                }
                return dict
            }
            return jsonOK(payload: [
                "query": query,
                "results": items,
                "count": items.count
            ])
        } catch let error as KeylessRing.RingError {
            return jsonError(action: "search", message: error.errorDescription ?? "search failed")
        } catch let error as WebSearchError {
            return jsonError(action: "search", message: webSearchErrorMessage(error))
        } catch {
            return jsonError(action: "search", message: "unexpected error: \(error)")
        }
    }

    private func handleResearch(payload: [String: Any]) async -> String {
        guard let query = payload["query"] as? String, !query.isEmpty else {
            return jsonError(action: "research", message: "missing required field: query")
        }
        let limit = (payload["limit"] as? Int) ?? 5
        do {
            let report = try await engine.research(query: query, limit: limit)
            let sources = report.sources.map { result -> [String: Any] in
                [
                    "title": result.title,
                    "url": result.url.absoluteString,
                    "snippet": result.snippet
                ]
            }
            return jsonOK(payload: [
                "query": report.query,
                "summary": report.summary,
                "sources": sources,
                "generated_at": report.generatedAt.formatted(.iso8601)
            ])
        } catch let error as KeylessRing.RingError {
            return jsonError(action: "research", message: error.errorDescription ?? "research failed")
        } catch let error as WebSearchError {
            return jsonError(action: "research", message: webSearchErrorMessage(error))
        } catch {
            return jsonError(action: "research", message: "unexpected error: \(error)")
        }
    }

    private func webSearchErrorMessage(_ error: WebSearchError) -> String {
        switch error {
        case .noProvidersConfigured:
            return "no search providers configured"
        case .providerFailure(let name, let underlying):
            return "provider '\(name)' failed: \(underlying)"
        }
    }

    private func parseJSON(_ input: String) -> [String: Any] {
        guard let data = input.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return obj
    }

    private func jsonOK(payload: [String: Any]) -> String {
        var envelope = payload
        envelope["ok"] = true
        return jsonString(envelope)
    }

    private func jsonError(action: String?, message: String) -> String {
        var envelope: [String: Any] = ["ok": false, "error": message]
        if let a = action { envelope["action"] = a }
        return jsonString(envelope)
    }

    private func jsonString(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ) else {
            return "{\"ok\":false,\"error\":\"internal: failed to encode envelope\"}"
        }
        return String(data: data, encoding: .utf8) ?? "{\"ok\":false,\"error\":\"internal: non-utf8 envelope\"}"
    }
}

extension WebSearchTool {

    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "web_search",
                toolset: "research",
                schema: ToolRegistrySchema(
                    name: "web_search",
                    description: """
                    Web search via the keyless anonymous public free tier ring \
                    (= Parallel / Exa / Keenable, in that order). No API key \
                    or configuration is needed; works on first launch. \
                    Actions: search (= multi-vendor ring with rate-limit failover), \
                    research (= search + local summary aggregation). \
                    Returns ranked results with title / url / snippet.
                    """,
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The web_search operation to perform.",
                            enumValues: ["search", "research"]
                        ),
                        "query": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Search query string (= required)."
                        ),
                        "limit": ToolRegistrySchemaProperty(
                            type: "integer",
                            description: "Maximum number of results to return (= default 10 for search, 5 for research)."
                        )
                    ],
                    required: []
                ),
                handler: WebSearchTool.shared,
                description: "Web search via the keyless anonymous free tier ring.",
                emoji: "🔍"
            )
        }
    }()
}