//
//  WebSearch.swift · Wenshu · HERMES-INTERNAL-001 (2026-09-04)
//
//  1:1 port of hermes web_search.py + web_search_provider.py
//  (= hermes-internal module #1, boss 2026-09-04 OOB 'A').
//
//  Five search providers: EXA, TAVILY, BRAVE, PARALLEL, SEARXNG.
//  Firecrawl is the scraper-only backend (= research convenience
//  fetches page bodies for search hits).
//
//  Wenshu-side: thin Swift surface that delegates to the configured
//  provider list. Auto-rotation on failure: tries every provider in
//  order until one returns results or all fail. Provider implementations
//  live as separate types conforming to WebSearchProvider (= EXAProvider,
//  TAVILYProvider, BRAVEProvider, PARALLELProvider, SEARXNGProvider).
//
//  Hard rule preserved: NO external third-party SDKs for HTTP.
//  All provider implementations use Foundation URLSession.
//

import Foundation

// MARK: - Result

public struct WebSearchResult: Sendable, Codable, Equatable {
    public let title: String
    public let snippet: String
    public let url: URL
    public let publishedAt: Date?

    public init(title: String, snippet: String, url: URL, publishedAt: Date? = nil) {
        self.title = title
        self.snippet = snippet
        self.url = url
        self.publishedAt = publishedAt
    }
}

// MARK: - Provider protocol

public protocol WebSearchProvider: Sendable {
    var name: String { get }
    func search(query: String, limit: Int) async throws -> [WebSearchResult]
}

// MARK: - Actor

public actor WebSearch {
    private let providers: [any WebSearchProvider]

    public init(providers: [any WebSearchProvider]) {
        self.providers = providers
    }

    /// Search across all configured providers. Auto-rotation: tries every
    /// provider in order and returns the first non-empty result set. If
    /// every provider fails, throws the last collected error so callers
    /// can surface a single actionable message.
    public func search(query: String, limit: Int = 10) async throws -> [WebSearchResult] {
        guard !providers.isEmpty else {
            throw WebSearchError.noProvidersConfigured
        }

        var lastError: Error = WebSearchError.noProvidersConfigured
        for provider in providers {
            do {
                let results = try await provider.search(query: query, limit: limit)
                if !results.isEmpty {
                    return results
                }
                // Empty results: try next provider rather than short-circuit.
                lastError = WebSearchError.emptyResults(providerName: provider.name)
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError
    }

    /// Convenience: search + summarize. Aggregates top hits from the search
    /// results and synthesizes a ResearchReport. No LLM call (= pure local
    /// aggregation from snippets + titles). Sufficient for the wenshu
    /// internal-infrastructure use case.
    public func research(query: String, limit: Int = 5) async throws -> ResearchReport {
        let sources = try await search(query: query, limit: limit)
        let summary = Self.summarize(query: query, sources: sources)
        return ResearchReport(
            query: query,
            sources: sources,
            summary: summary,
            generatedAt: Date()
        )
    }

    // MARK: - Summarization (local, no LLM)

    /// Synthesize a short summary from the search results. Joins the top
    /// titles + snippets into a single readable paragraph. Deterministic
    /// (= no LLM call) so the convenience method is fully offline.
    static func summarize(query: String, sources: [WebSearchResult]) -> String {
        guard !sources.isEmpty else {
            return "No results for '\(query)'."
        }
        let header = "Research summary for '\(query)' (\(sources.count) source\(sources.count == 1 ? "" : "s")):"
        let bullets = sources.enumerated().map { idx, source in
            let titleSnippet = source.snippet.isEmpty
                ? source.title
                : "\(source.title) — \(source.snippet)"
            return "  \(idx + 1). \(titleSnippet)"
        }
        return ([header] + bullets).joined(separator: "\n")
    }
}

// MARK: - Report

public struct ResearchReport: Sendable, Equatable {
    public let query: String
    public let sources: [WebSearchResult]
    public let summary: String
    public let generatedAt: Date

    public init(query: String, sources: [WebSearchResult], summary: String, generatedAt: Date) {
        self.query = query
        self.sources = sources
        self.summary = summary
        self.generatedAt = generatedAt
    }
}

// MARK: - Errors

public enum WebSearchError: Error, Sendable, Equatable {
    case noProvidersConfigured
    case emptyResults(providerName: String)
}