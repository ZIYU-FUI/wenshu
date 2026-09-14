//
//  WebSearchTool.swift · Wenshu · v0.74 ticket 003-websearch-tool-wire
//
//  LLM-facing wrapper for `Sources/WenshuApp/Core/Agent/Web/WebSearch.swift`
//  (= the 1:1 hermes port of `web_search.py` shipped in HERMES-INTERNAL-001
//  + v0.74 ticket 001 adding 5 provider classes). The actor was orphaned
//  from the LLM tool surface (= no Tool wrapper); this ticket wires it in.
//
//  Per AGENTS.md §11.3 wenshu-side wins pattern: this Tool is a thin
//  adapter that delegates to `WebSearch.shared`. We do NOT re-implement
//  provider rotation; the actor owns that.
//
//  Actions (= matches the spec):
//  - search(query, limit?, providers?)  — multi-provider rotation search
//  - research(query, limit?)            — search + local summary aggregation
//
//  Per Q42: reuse `WebSearch.shared` actor. NO duplicate resolver logic.
//  Per AGENTS.md §11.1: Apple Foundation only. NO third-party deps.
//  Per Q187-Q190: doc-only header preserved verbatim (English only).
//
//  Tool name: "web_search"  · toolset: "research"
//
//

import Foundation

// MARK: - Tool

/// LLM-facing wrapper around the canonical `WebSearch` actor.
///
/// Round-trips JSON envelopes (= matches the `SkillBundlesTool` pattern
/// from v0.73 ticket 001). The LLM sends `{"action": "search", "query": "..."}`
/// and receives a JSON envelope `{"ok": true, "results": [...]}`. Errors
/// come back as `{"ok": false, "error": "..."}`.
public final class WebSearchTool: Tool, @unchecked Sendable {

    /// Module-singleton (= matches `SkillBundlesTool.shared` pattern).
    public static let shared = WebSearchTool()

    private let engine: WebSearch

    /// Designated init (= allows tests to inject a `WebSearch` with
    /// custom provider list).
    public init(engine: WebSearch = WebSearch.shared) {
        self.engine = engine
    }

    public func execute(input: String) async throws -> String {
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

    // MARK: - Actions

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
                    dict["published_at"] = ISO8601DateFormatter().string(from: published)
                }
                return dict
            }
            return jsonOK(payload: [
                "query": query,
                "results": items,
                "count": items.count
            ])
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
                "generated_at": ISO8601DateFormatter().string(from: report.generatedAt)
            ])
        } catch let error as WebSearchError {
            return jsonError(action: "research", message: webSearchErrorMessage(error))
        } catch {
            return jsonError(action: "research", message: "unexpected error: \(error)")
        }
    }

    private func webSearchErrorMessage(_ error: WebSearchError) -> String {
        switch error {
        case .noProvidersConfigured:
            return "no search providers configured; user must populate API keys for at least one provider (= exa / tavily / brave / parallel / searxng)"
        case .emptyResults(let name):
            return "provider '\(name)' returned empty results; rotation tried all providers"
        case .providerFailure(let name, let underlying):
            return "provider '\(name)' failed: \(underlying)"
        }
    }

    // MARK: - JSON envelope (= matches SkillBundlesTool convention)

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

// MARK: - ToolRegistry bootstrap (= matches SkillBundlesTool pattern)

extension WebSearchTool {

    /// Module-load registration with `ToolRegistry.shared`. Idempotent.
    public static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.register(
                name: "web_search",
                toolset: "research",
                schema: ToolRegistrySchema(
                    name: "web_search",
                    description: """
                    Multi-provider web search with automatic rotation (= hermes-port \
                    `web_search.py` per HERMES-INTERNAL-001 + v0.74 ticket 001). Five \
                    providers configured: EXA / TAVILY / BRAVE / PARALLEL / SEARXNG. \
                    Actions: search / research. The `search` action rotates across \
                    configured providers (= tries each one in order, returns first \
                    non-empty result set). The `research` action calls search then \
                    synthesizes a local summary from the top hits (= NO LLM call). \
                    Providers are stubbed when API keys are missing (= returns empty \
                    results → rotation moves to next provider). Configure API keys via \
                    ProviderKeychain (= AGENTS.md §11) to enable real searches.
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
                description: """
                Multi-provider web search with automatic rotation. \
                Actions: search / research.
                """,
                emoji: "🔍"
            )
        }
    }()
}

// NOTE: Swift 6 forbids top-level expressions, so the static let
// `_registryBootstrap` initializer runs lazily on first type access
// (= Swift equivalent of Python module-load statement). Production code
// paths that touch this type (= e.g. ChatView constructing
// `SkillBundlesTool.shared`, WenshuConductor constructing
// `WebSearchTool.shared`) automatically trigger the bootstrap.