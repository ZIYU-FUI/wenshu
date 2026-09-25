//
//  WebSearchTests.swift · Wenshu
//
//  Round-trip tests for WebSearch (= actor wrapping KeylessRing).
//
//  Tests:
//    1. testSearch_basic          — first non-empty result returned
//    2. testSearch_emptyProvider  — empty first → next vendor wins
//    3. testSearch_ringEmpty      — ring returns empty (= no exception)
//    4. testResearch_summarize    — research convenience synthesizes summary
//    5. testSummarize_noResults   — empty results produce the sentinel summary
//    6. testSummarize_singular    — singular "source" wording when count == 1
//    7. testSummarize_plural      — plural "sources" wording when count > 1
//

import Testing
import Foundation
@testable import WenshuApp

// MARK: - Test provider stubs (= KeylessRing-prefixed to avoid
//  colliding with private types in KeylessRingTests.swift)

struct WebSearchStubProvider: WebSearchProvider {
    let name: String
    let results: [WebSearchResult]

    func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        Array(results.prefix(limit))
    }
}

struct WebSearchFailingProvider: WebSearchProvider {
    let name: String
    let error: Error

    func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        throw error
    }
}

// MARK: - Suite

@Suite("WebSearch")
struct WebSearchTests {

    @Test("search returns the first provider's non-empty results")
    func testSearch_basic() async throws {
        let hit = WebSearchResult(
            title: "Wenshu",
            snippet: "Apple-first writing tool",
            url: URL(string: "https://example.com/wenshu")!
        )
        let web = WebSearch(ring: KeylessRing(providers: [
            WebSearchStubProvider(name: "stub", results: [hit])
        ]))
        let results = try await web.search(query: "wenshu", limit: 5)
        #expect(results.count == 1)
        #expect(results[0] == hit)
    }

    @Test("search rotates to next provider when first returns empty")
    func testSearch_emptyProvider() async throws {
        let real = WebSearchStubProvider(name: "real-stub", results: [
            WebSearchResult(
                title: "Backup",
                snippet: "Hermes-internal port",
                url: URL(string: "https://example.com/a")!
            )
        ])
        let web = WebSearch(ring: KeylessRing(providers: [
            WebSearchStubProvider(name: "empty-stub", results: []),
            real
        ]))
        let results = try await web.search(query: "query", limit: 5)
        #expect(results.count == 1)
        #expect(results[0].title == "Backup")
    }

    @Test("search throws allProvidersThrottled when every provider is empty")
    func testSearch_ringEmpty() async throws {
        let web = WebSearch(ring: KeylessRing(providers: [
            WebSearchStubProvider(name: "p1", results: []),
            WebSearchStubProvider(name: "p2", results: []),
        ]))
        await #expect(throws: KeylessRing.RingError.self) {
            _ = try await web.search(query: "anything", limit: 5)
        }
    }

    @Test("search stops on a non-throttle error and rethrows")
    func testSearch_nonThrottleError() async throws {
        let underlying = NSError(domain: "test", code: 42)
        let web = WebSearch(ring: KeylessRing(providers: [
            WebSearchFailingProvider(name: "failer", error: underlying)
        ]))
        await #expect(throws: NSError.self) {
            _ = try await web.search(query: "anything", limit: 5)
        }
    }

    @Test("research returns a populated report without an LLM call")
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
        let web = WebSearch(ring: KeylessRing(providers: [
            WebSearchStubProvider(name: "ok", results: results)
        ]))
        let report = try await web.research(query: "research-test", limit: 5)
        #expect(report.query == "research-test")
        #expect(report.sources.count == 2)
        #expect(report.summary.contains("Research summary"))
        #expect(report.summary.contains("First"))
    }

    @Test("summarize with no results returns the sentinel")
    func testSummarize_noResults() {
        let text = WebSearch.summarize(query: "no-results", sources: [])
        #expect(text == "No results for 'no-results'.")
    }

    @Test("summarize with one result uses singular 'source'")
    func testSummarize_singular() {
        let source = WebSearchResult(
            title: "One",
            snippet: "x",
            url: URL(string: "https://example.com/1")!
        )
        let text = WebSearch.summarize(query: "q", sources: [source])
        #expect(text.contains("1 source"))
    }

    @Test("summarize with multiple results uses plural 'sources'")
    func testSummarize_plural() {
        let results = [
            WebSearchResult(title: "A", snippet: "x", url: URL(string: "https://example.com/a")!),
            WebSearchResult(title: "B", snippet: "y", url: URL(string: "https://example.com/b")!),
        ]
        let text = WebSearch.summarize(query: "q", sources: results)
        #expect(text.contains("2 sources"))
    }

    @Test("WebSearch.shared has a canonical keyless ring")
    func testSharedSingleton() async {
        let canonical = KeylessRing.defaultProviders().map(\.name)
        let ring = await WebSearch.shared.ringSnapshot()
        let ringNames = await ring.providerNames()
        #expect(ringNames == canonical)
    }
}