// WebSearchToolTests.swift · Wenshu · v0.74 ticket 003-websearch-tool-wire
//
// Hermes-port validation tests for WebSearchTool.swift
// (= LLM-facing wrapper over WebSearch.swift + 5 provider classes shipped
// in HERMES-INTERNAL-001 + v0.74 ticket 001).
//
// Tests cover:
// - search rejects payload without query field
// - search returns noProvidersConfigured error when all providers empty
//   (= matches WebSearch.shared default behavior)
// - research rejects payload without query field
// - research returns noProvidersConfigured error when all providers empty
// - unknown action returns typed error
// - empty action returns missing-action error
// - search with mock provider returns the mock results (= proves delegation,
//   not stub-only)

import Foundation
import Testing
@testable import WenshuApp

@Suite("WebSearchTool (v0.74 ticket 003 — wire WebSearch into ToolRegistry)")
struct WebSearchToolTests {

    // MARK: - Helpers

    /// Mock provider that returns a fixed result set regardless of query.
    /// Lets us verify that WebSearchTool delegates to WebSearch actor
    /// (= not stub-only) without depending on real API keys.
    private struct MockProvider: WebSearchProvider, Sendable {
        let name: String = "mock"
        let fixedResults: [WebSearchResult]

        func search(query: String, limit: Int) async throws -> [WebSearchResult] {
            return Array(fixedResults.prefix(limit))
        }
    }

    /// Build a tool backed by a WebSearch actor with a single mock provider.
    private static func makeToolWithMock(_ results: [WebSearchResult]) -> WebSearchTool {
        let mock = MockProvider(fixedResults: results)
        let engine = WebSearch(providers: [mock])
        return WebSearchTool(engine: engine)
    }

    /// Build a tool backed by an empty WebSearch (= matches WebSearch.shared).
    private static func makeToolEmpty() -> WebSearchTool {
        let engine = WebSearch(providers: [])
        return WebSearchTool(engine: engine)
    }

    private static func decodeEnvelope(_ json: String) throws -> [String: Any] {
        let data = Data(json.utf8)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    // MARK: - search payload validation

    @Test("search rejects payload without query field")
    func searchMissingQuery() async throws {
        let tool = Self.makeToolEmpty()
        let result = try await tool.execute(input: #"{"action":"search"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == false)
        let error = env["error"] as? String ?? ""
        #expect(error.contains("query"))
    }

    @Test("search returns noProvidersConfigured when no providers wired")
    func searchEmptyProviders() async throws {
        let tool = Self.makeToolEmpty()
        let result = try await tool.execute(input: #"{"action":"search","query":"wenshu writing tool"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == false)
        let error = env["error"] as? String ?? ""
        #expect(error.contains("no search providers"))
    }

    // MARK: - search delegation (= proves we delegate, not stub)

    @Test("search with mock provider returns mock results")
    func searchWithMock() async throws {
        let mockResults = [
            WebSearchResult(
                title: "Wenshu — a writing tool for novelists",
                snippet: "Apple HIG macOS-only single platform.",
                url: URL(string: "https://example.com/wenshu")!
            )
        ]
        let tool = Self.makeToolWithMock(mockResults)
        let result = try await tool.execute(input: #"{"action":"search","query":"wenshu"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == true)
        let items = env["results"] as? [[String: Any]] ?? []
        #expect(items.count == 1)
        #expect(items.first?["title"] as? String == "Wenshu — a writing tool for novelists")
        #expect(items.first?["url"] as? String == "https://example.com/wenshu")
    }

    @Test("search respects the limit parameter")
    func searchRespectsLimit() async throws {
        let mockResults = (1...5).map { idx in
            WebSearchResult(
                title: "Result \(idx)",
                snippet: "Snippet \(idx)",
                url: URL(string: "https://example.com/\(idx)")!
            )
        }
        let tool = Self.makeToolWithMock(mockResults)
        let result = try await tool.execute(input: #"{"action":"search","query":"test","limit":2}"#)
        let env = try Self.decodeEnvelope(result)
        let items = env["results"] as? [[String: Any]] ?? []
        #expect(items.count == 2)
        #expect(env["count"] as? Int == 2)
    }

    // MARK: - research payload validation

    @Test("research rejects payload without query field")
    func researchMissingQuery() async throws {
        let tool = Self.makeToolEmpty()
        let result = try await tool.execute(input: #"{"action":"research"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == false)
        let error = env["error"] as? String ?? ""
        #expect(error.contains("query"))
    }

    @Test("research returns noProvidersConfigured when no providers wired")
    func researchEmptyProviders() async throws {
        let tool = Self.makeToolEmpty()
        let result = try await tool.execute(input: #"{"action":"research","query":"novel outline"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == false)
        let error = env["error"] as? String ?? ""
        #expect(error.contains("no search providers"))
    }

    @Test("research with mock provider returns synthesized report")
    func researchWithMock() async throws {
        let mockResults = [
            WebSearchResult(
                title: "Hero's Journey",
                snippet: "Monomyth structure for novelists.",
                url: URL(string: "https://example.com/hero")!
            )
        ]
        let tool = Self.makeToolWithMock(mockResults)
        let result = try await tool.execute(input: #"{"action":"research","query":"monomyth"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == true)
        let summary = env["summary"] as? String ?? ""
        #expect(summary.contains("monomyth"))
        let sources = env["sources"] as? [[String: Any]] ?? []
        #expect(sources.count == 1)
    }

    // MARK: - error envelopes

    @Test("unknown action returns typed error")
    func unknownAction() async throws {
        let tool = Self.makeToolEmpty()
        let result = try await tool.execute(input: #"{"action":"crawl"}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == false)
        let error = env["error"] as? String ?? ""
        #expect(error.contains("unknown action"))
        #expect(env["action"] as? String == "crawl")
    }

    @Test("empty action returns missing-action error")
    func missingAction() async throws {
        let tool = Self.makeToolEmpty()
        let result = try await tool.execute(input: #"{}"#)
        let env = try Self.decodeEnvelope(result)
        #expect(env["ok"] as? Bool == false)
        let error = env["error"] as? String ?? ""
        #expect(error.contains("action"))
    }
}