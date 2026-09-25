//
//  WebSearch.swift · Wenshu
//
//  Actor that owns the keyless search ring.
//  Pool = KeylessRing.defaultProviders() (= Parallel / Exa / Keenable).
//  Zero configuration: works on first launch with no API key.
//
//

import Foundation

struct WebSearchResult: Sendable, Codable, Equatable {
    let title: String
    let snippet: String
    let url: URL
    let publishedAt: Date?

    init(title: String, snippet: String, url: URL, publishedAt: Date? = nil) {
        self.title = title
        self.snippet = snippet
        self.url = url
        self.publishedAt = publishedAt
    }
}

protocol WebSearchProvider: Sendable {
    var name: String { get }
    func search(query: String, limit: Int) async throws -> [WebSearchResult]
}

actor WebSearch {
    /// Module-singleton with the canonical keyless ring
    /// (= Parallel / Exa / Keenable). No configuration: works on
    /// first launch.
    static let shared: WebSearch = WebSearch(ring: KeylessRing.defaultRing())

    private let ring: KeylessRing

    init(ring: KeylessRing) {
        self.ring = ring
    }

    func search(query: String, limit: Int = 10) async throws -> [WebSearchResult] {
        try await ring.search(query: query, limit: limit)
    }

    func research(query: String, limit: Int = 5) async throws -> ResearchReport {
        let sources = try await search(query: query, limit: limit)
        return ResearchReport(
            query: query,
            sources: sources,
            summary: Self.summarize(query: query, sources: sources),
            generatedAt: Date()
        )
    }

    /// Internal: returns the configured ring for assertion in tests.
    /// (= hermes does not expose this; = wenshu-side test helper.)
    func ringSnapshot() -> KeylessRing {
        ring
    }

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

struct ResearchReport: Sendable, Equatable {
    let query: String
    let sources: [WebSearchResult]
    let summary: String
    let generatedAt: Date

    init(query: String, sources: [WebSearchResult], summary: String, generatedAt: Date) {
        self.query = query
        self.sources = sources
        self.summary = summary
        self.generatedAt = generatedAt
    }
}

enum WebSearchError: Error, Sendable, Equatable, LocalizedError {
    case noProvidersConfigured
    case providerFailure(name: String, underlying: String)

    var errorDescription: String? {
        switch self {
        case .noProvidersConfigured:
            return "No web search providers are configured."
        case .providerFailure(let name, let underlying):
            return "Provider \(name) failed: \(underlying)"
        }
    }
}