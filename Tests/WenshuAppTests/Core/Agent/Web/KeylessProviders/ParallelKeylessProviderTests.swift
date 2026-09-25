//
//  ParallelKeylessProviderTests.swift · Wenshu
//
//  Tests for ParallelKeylessProvider (= vendor 1 of 3 in the keyless ring).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ParallelKeylessProvider", .serialized)
struct ParallelKeylessProviderTests {

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

    /// Build a `ParallelKeylessProvider` backed by `stub`.
    private static func makeProvider(for stub: URLProtocolStub, protocolClass: AnyClass) -> ParallelKeylessProvider {
        let session = makeSession(for: protocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://search.parallel.ai/mcp")!,
            session: session
        )
        return ParallelKeylessProvider(client: client, sessionID: "test-session-id")
    }

    // MARK: - Tests

    @Test("search parses the results array")
    func testSearchParsesResultsArray() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let parallelPayload: [String: Any] = [
            "results": [
                [
                    "url": "https://example.com/a",
                    "title": "Result A",
                    "excerpts": ["excerpt 1", "excerpt 2"]
                ]
            ]
        ]
        let payloadText = String(data: Self.jsonData(parallelPayload), encoding: .utf8) ?? ""
        stub.responseData = Self.jsonData(Self.makeMCPResponse(text: payloadText))
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        let results = try await provider.search(query: "test", limit: 5)

        #expect(results.count == 1)
        #expect(results[0].title == "Result A")
        #expect(results[0].url.absoluteString == "https://example.com/a")
        #expect(results[0].snippet == "excerpt 1 excerpt 2")
    }

    @Test("search caps results at limit")
    func testSearchCapsResultsAtLimit() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let parallelPayload: [String: Any] = [
            "results": [
                ["url": "https://example.com/a", "title": "A", "excerpts": ["a"]],
                ["url": "https://example.com/b", "title": "B", "excerpts": ["b"]],
                ["url": "https://example.com/c", "title": "C", "excerpts": ["c"]],
                ["url": "https://example.com/d", "title": "D", "excerpts": ["d"]],
                ["url": "https://example.com/e", "title": "E", "excerpts": ["e"]]
            ]
        ]
        let payloadText = String(data: Self.jsonData(parallelPayload), encoding: .utf8) ?? ""
        stub.responseData = Self.jsonData(Self.makeMCPResponse(text: payloadText))
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        let results = try await provider.search(query: "test", limit: 2)

        #expect(results.count == 2)
        #expect(results[0].title == "A")
        #expect(results[1].title == "B")
    }

    @Test("search skips results without a url")
    func testSearchSkipsResultsWithoutURL() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let parallelPayload: [String: Any] = [
            "results": [
                ["url": "https://example.com/a", "title": "A", "excerpts": ["a"]],
                ["title": "no-url", "excerpts": ["x"]],
                ["url": "https://example.com/c", "title": "C", "excerpts": ["c"]]
            ]
        ]
        let payloadText = String(data: Self.jsonData(parallelPayload), encoding: .utf8) ?? ""
        stub.responseData = Self.jsonData(Self.makeMCPResponse(text: payloadText))
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        let results = try await provider.search(query: "test", limit: 5)

        #expect(results.count == 2)
        #expect(results.map(\.title) == ["A", "C"])
    }

    @Test("search raises providerFailure on non-JSON payload")
    func testSearchRaisesOnBadJSON() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.responseData = Self.jsonData(Self.makeMCPResponse(text: "not json"))
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        await #expect(throws: WebSearchError.self) {
            _ = try await provider.search(query: "test", limit: 5)
        }
    }

    @Test("search sends session_id in arguments")
    func testSearchSendsSessionID() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let parallelPayload: [String: Any] = [
            "results": [["url": "https://example.com/a", "title": "A", "excerpts": ["a"]]]
        ]
        let payloadText = String(data: Self.jsonData(parallelPayload), encoding: .utf8) ?? ""
        stub.responseData = Self.jsonData(Self.makeMCPResponse(text: payloadText))
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        _ = try await provider.search(query: "test", limit: 5)

        let captured = stub.lastRequest
        let body = try JSONSerialization.jsonObject(
            with: captured!.httpBody ?? Data()
        ) as? [String: Any]
        let params = body?["params"] as? [String: Any]
        let args = params?["arguments"] as? [String: Any]
        #expect(args?["session_id"] as? String == "test-session-id")
        #expect(args?["objective"] as? String == "test")
        let queries = args?["search_queries"] as? [String]
        #expect(queries == ["test"])
    }

    @Test("search sends the correct tool name")
    func testSearchSendsToolName() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let parallelPayload: [String: Any] = [
            "results": [["url": "https://example.com/a", "title": "A", "excerpts": ["a"]]]
        ]
        let payloadText = String(data: Self.jsonData(parallelPayload), encoding: .utf8) ?? ""
        stub.responseData = Self.jsonData(Self.makeMCPResponse(text: payloadText))
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        _ = try await provider.search(query: "test", limit: 5)

        let captured = stub.lastRequest
        let body = try JSONSerialization.jsonObject(
            with: captured!.httpBody ?? Data()
        ) as? [String: Any]
        let params = body?["params"] as? [String: Any]
        #expect(params?["name"] as? String == "web_search")
    }
}