//
//  WebSearchTests.swift · Wenshu · HERMES-INTERNAL-001 (2026-09-04)
//
//  Round-trip tests for WebSearch (= hermes web_search.py port).
//
//  Tests covered:
//    1. testSearch_basic               — returns first provider's results
//    2. testSearch_providerRotation    — second provider hit when first returns empty
//    3. testSearch_allProvidersFail    — throws last error
//    4. testResearch_summarize         — research convenience produces report
//

import Testing
import Foundation
@testable import WenshuApp

// MARK: - Test provider stubs

struct StubProvider: WebSearchProvider {
    let name: String
    let results: [WebSearchResult]

    func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        Array(results.prefix(limit))
    }
}

struct FailingProvider: WebSearchProvider {
    let name: String
    let error: Error

    func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        throw error
    }
}

// MARK: - Suite

@Suite("WebSearch (HERMES-INTERNAL-001)")
struct WebSearchTests {

    @Test("search returns the first provider's non-empty results")
    func testSearch_basic() async throws {
        let hit = WebSearchResult(
            title: "Wenshu",
            snippet: "Apple-first writing tool",
            url: URL(string: "https://example.com/wenshu")!
        )
        let provider = StubProvider(
            name: "stub",
            results: [hit]
        )
        let web = WebSearch(providers: [provider])
        let results = try await web.search(query: "wenshu", limit: 5)
        #expect(results.count == 1)
        #expect(results[0] == hit)
    }

    @Test("search rotates to second provider when first returns empty")
    func testSearch_providerRotation() async throws {
        let empty = StubProvider(name: "empty-stub", results: [])
        let real = StubProvider(
            name: "real-stub",
            results: [
                WebSearchResult(
                    title: "Backup",
                    snippet: "Hermes-internal port",
                    url: URL(string: "https://example.com/a")!
                )
            ]
        )
        let web = WebSearch(providers: [empty, real])
        let results = try await web.search(query: "query", limit: 5)
        #expect(results.count == 1)
        #expect(results[0].title == "Backup")
    }

    @Test("search throws last error when every provider fails")
    func testSearch_allProvidersFail() async throws {
        let err1 = WebSearchError.emptyResults(providerName: "p1")
        let err2 = WebSearchError.emptyResults(providerName: "p2")
        let web = WebSearch(
            providers: [
                FailingProvider(name: "p1", error: err1),
                FailingProvider(name: "p2", error: err2),
            ]
        )
        await #expect(throws: WebSearchError.self) {
            _ = try await web.search(query: "anything", limit: 5)
        }
    }

    @Test("research returns a populated report even without an LLM call")
    func testResearch_summarize() async throws {
        let results = [
            WebSearchResult(
                title: "First",
                snippet: "one",
                url: URL(string: "https://example.com/1")!
            ),
            WebSearchResult(
                title: "Second",
                snippet: "two",
                url: URL(string: "https://example.com/2")!
            ),
        ]
        let web = WebSearch(providers: [StubProvider(name: "ok", results: results)])
        let report = try await web.research(query: "research-test", limit: 5)
        #expect(report.query == "research-test")
        #expect(report.sources.count == 2)
        #expect(report.summary.contains("Research summary"))
        #expect(report.summary.contains("First"))
    }
}