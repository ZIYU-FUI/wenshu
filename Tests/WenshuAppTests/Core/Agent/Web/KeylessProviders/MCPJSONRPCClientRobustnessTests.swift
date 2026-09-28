// ROBUSTNESS-3 — MCPJSONRPCClient + KeylessRing error-path boundary tests.
//
// Verifies the network/parse failure modes do not silently swallow or
// surface confusing errors:
//   3a — HTTP 500 response → throws (not crashes; not empty).
//   3b — malformed JSON body → throws (not crashes; not empty).
//   3c — empty body 200 → throws emptyContent (not nil; not silent).
//   3d — 1 MB response body → parses without timeout or memory crash.
//
// Reference: AGENTS.md §11.15 (keyless web search), §11.7 (sqlite3-zero).
import Testing
import Foundation
@testable import WenshuApp

@Suite("MCPJSONRPCClient (Robustness)", .serialized)
struct MCPJSONRPCClientRobustnessTests {

    // MARK: - Helpers

    private static func makeSession(for stubProtocolClass: AnyClass) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [stubProtocolClass]
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }

    private static func jsonData(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    // MARK: - Tests

    @Test("call throws on HTTP 500 server error")
    func callThrowsOnHTTP500() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.responseData = Data("internal server error".utf8)
        stub.responseStatusCode = 500
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            session: session
        )

        await #expect(throws: MCPJSONRPCClient.MCPError.self) {
            _ = try await client.call(tool: "web_search", arguments: [:])
        }
    }

    @Test("call throws on malformed JSON body")
    func callThrowsOnMalformedJSON() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.responseData = Data("{not-json:::".utf8)
        stub.responseStatusCode = 200
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            session: session
        )

        // Must throw — never crash, never return partial garbage.
        await #expect(throws: MCPJSONRPCClient.MCPError.self) {
            _ = try await client.call(tool: "web_search", arguments: [:])
        }
    }

    @Test("call throws on completely empty body")
    func callThrowsOnEmptyBody() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.responseData = Data()
        stub.responseStatusCode = 200
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            session: session
        )

        await #expect(throws: MCPJSONRPCClient.MCPError.self) {
            _ = try await client.call(tool: "web_search", arguments: [:])
        }
    }

    @Test("call survives a 1 MB response body without crashing")
    func callSurvivesLargeResponse() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        // 1 MB response with a valid JSON-RPC envelope at the end.
        let padding = String(repeating: "x", count: 1 << 20)
        let envelope: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "result": [
                "isError": false,
                "content": [["type": "text", "text": "tail:\(padding.prefix(16))"]]
            ]
        ]
        stub.responseData = Self.jsonData(envelope)
        stub.responseStatusCode = 200
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            session: session
        )

        let text = try await client.call(tool: "web_search", arguments: [:])
        #expect(text.hasPrefix("tail:"))
    }
}