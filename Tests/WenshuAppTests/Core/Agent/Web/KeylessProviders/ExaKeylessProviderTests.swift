//
//  ExaKeylessProviderTests.swift · Wenshu
//
//  Tests for ExaKeylessProvider (= vendor 2 of 3 in the keyless ring).
//
//  Exa returns PLAIN TEXT (= not JSON); = the parser walks the
//  Title:/URL:/Highlights:/Published:/Author: blocks separated by
//  '\n---\n'.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ExaKeylessProvider", .serialized)
struct ExaKeylessProviderTests {

    // MARK: - Helpers

    private static func makeSession(for stubProtocolClass: AnyClass) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [stubProtocolClass]
        return URLSession(configuration: config)
    }

    private static func jsonData(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    private static func makeMCPResponse(text: String) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": 1,
            "result": [
                "content": [["type": "text", "text": text]]
            ]
        ]
    }

    private static func makeProvider(for stub: URLProtocolStub, protocolClass: AnyClass) -> ExaKeylessProvider {
        let session = makeSession(for: protocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.exa.ai/mcp")!,
            session: session
        )
        return ExaKeylessProvider(client: client)
    }

    // MARK: - Tests

    @Test("search parses a single block")
    func testSearchParsesSingleBlock() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let text = """
        Title: Result A
        URL: https://example.com/a
        Published: 2026-09-25
        Author: Alice
        Highlights:
        excerpt line one
        excerpt line two
        """
        stub.responseData = Self.jsonData(Self.makeMCPResponse(text: text))
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        let results = try await provider.search(query: "test", limit: 5)

        #expect(results.count == 1)
        #expect(results[0].title == "Result A")
        #expect(results[0].url.absoluteString == "https://example.com/a")
        #expect(results[0].snippet == "excerpt line one excerpt line two")
    }

    @Test("search parses multiple blocks separated by dashes")
    func testSearchParsesMultipleBlocks() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let text = """
        Title: A
        URL: https://example.com/a
        Highlights:
        a-highlight
        ---
        Title: B
        URL: https://example.com/b
        Highlights:
        b-highlight
        ---
        Title: C
        URL: https://example.com/c
        Highlights:
        c-highlight
        """
        stub.responseData = Self.jsonData(Self.makeMCPResponse(text: text))
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        let results = try await provider.search(query: "test", limit: 10)

        #expect(results.count == 3)
        #expect(results.map(\.title) == ["A", "B", "C"])
        #expect(results.map(\.url.absoluteString) == [
            "https://example.com/a",
            "https://example.com/b",
            "https://example.com/c"
        ])
        #expect(results.map(\.snippet) == ["a-highlight", "b-highlight", "c-highlight"])
    }

    @Test("search respects the limit cap")
    func testSearchRespectsLimit() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let text = """
        Title: A
        URL: https://example.com/a
        Highlights: a
        ---
        Title: B
        URL: https://example.com/b
        Highlights: b
        ---
        Title: C
        URL: https://example.com/c
        Highlights: c
        ---
        Title: D
        URL: https://example.com/d
        Highlights: d
        ---
        Title: E
        URL: https://example.com/e
        Highlights: e
        """
        stub.responseData = Self.jsonData(Self.makeMCPResponse(text: text))
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        let results = try await provider.search(query: "test", limit: 2)

        #expect(results.count == 2)
        #expect(results.map(\.title) == ["A", "B"])
    }

    @Test("search extracts highlights only inside the Highlights block")
    func testSearchExtractsHighlightsInsideBlock() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        // The label-line "Author: Alice" should NOT be appended to highlights;
        // the body line after Author: should NOT be appended either.
        let text = """
        Title: A
        URL: https://example.com/a
        Highlights:
        highlight-1
        highlight-2
        Author: Alice
        not-a-highlight
        """
        stub.responseData = Self.jsonData(Self.makeMCPResponse(text: text))
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        let results = try await provider.search(query: "test", limit: 5)

        #expect(results.count == 1)
        #expect(results[0].snippet == "highlight-1 highlight-2")
    }

    @Test("search skips blocks without a URL")
    func testSearchSkipsBlocksWithoutURL() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let text = """
        Title: A
        URL: https://example.com/a
        Highlights: a
        ---
        Title: no-url-block
        Highlights: x
        ---
        Title: C
        URL: https://example.com/c
        Highlights: c
        """
        stub.responseData = Self.jsonData(Self.makeMCPResponse(text: text))
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        let results = try await provider.search(query: "test", limit: 5)

        #expect(results.count == 2)
        #expect(results.map(\.title) == ["A", "C"])
    }

    @Test("search sends numResults argument")
    func testSearchSendsNumResults() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let text = """
        Title: A
        URL: https://example.com/a
        Highlights: a
        """
        stub.responseData = Self.jsonData(Self.makeMCPResponse(text: text))
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        _ = try await provider.search(query: "test", limit: 5)

        let captured = stub.lastRequest
        let body = try JSONSerialization.jsonObject(
            with: captured!.httpBody ?? Data()
        ) as? [String: Any]
        let params = body?["params"] as? [String: Any]
        let args = params?["arguments"] as? [String: Any]
        #expect(args?["numResults"] as? Int == 5)
        #expect(args?["query"] as? String == "test")
        #expect(params?["name"] as? String == "web_search_exa")
    }
}