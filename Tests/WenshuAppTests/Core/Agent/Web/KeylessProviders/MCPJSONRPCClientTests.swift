//
//  MCPJSONRPCClientTests.swift · Wenshu
//
//  Tests for MCPJSONRPCClient (= the shared MCP Streamable HTTP JSON-RPC 2.0
//  transport primitive used by ParallelKeylessProvider and
//  ExaKeylessProvider).
//
//  Uses URLProtocolStub.makeIsolatedStub() for hermetic per-test isolation
//  (= the v1.17 pattern; = no global state race).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("MCPJSONRPCClient", .serialized)
struct MCPJSONRPCClientTests {

    // MARK: - Helpers

    /// Build a session whose URLProtocol routing is captured by `stub`.
    private static func makeSession(for stubProtocolClass: AnyClass) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [stubProtocolClass]
        return URLSession(configuration: config)
    }

    /// Encode a JSON object to Data for stub responseData.
    private static func jsonData(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    // MARK: - Tests

    @Test("call sends a correct JSON-RPC envelope")
    func testCallSendsCorrectJSONRPCEnvelope() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let responseJSON: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "result": [
                "content": [["type": "text", "text": "hello"]]
            ]
        ]
        stub.responseData = Self.jsonData(responseJSON)
        stub.responseStatusCode = 200
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            session: session
        )

        _ = try await client.call(
            tool: "web_search",
            arguments: ["query": "test", "limit": 5]
        )

        let captured = stub.lastRequest
        #expect(captured?.httpMethod == "POST")
        #expect(captured?.url?.absoluteString == "https://mcp.example.com/mcp")
        let body = try JSONSerialization.jsonObject(
            with: captured!.httpBody ?? Data()
        ) as? [String: Any]
        #expect(body?["jsonrpc"] as? String == "2.0")
        #expect(body?["id"] as? Int == 1)
        #expect(body?["method"] as? String == "tools/call")
        let params = body?["params"] as? [String: Any]
        #expect(params?["name"] as? String == "web_search")
        let args = params?["arguments"] as? [String: Any]
        #expect(args?["query"] as? String == "test")
        #expect(args?["limit"] as? Int == 5)
    }

    @Test("call returns the first text content from result.content")
    func testCallReturnsFirstTextContent() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let responseJSON: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "result": [
                "content": [
                    ["type": "text", "text": "first text payload"]
                ]
            ]
        ]
        stub.responseData = Self.jsonData(responseJSON)
        stub.responseStatusCode = 200
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            session: session
        )

        let text = try await client.call(tool: "any_tool", arguments: [:])
        #expect(text == "first text payload")
    }

    @Test("call throws jsonRPC on error envelope")
    func testCallThrowsOnJSONRPCError() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let responseJSON: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "error": ["code": -32600, "message": "method not found"]
        ]
        stub.responseData = Self.jsonData(responseJSON)
        stub.responseStatusCode = 200
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            session: session
        )

        await #expect(throws: MCPJSONRPCClient.MCPError.self) {
            _ = try await client.call(tool: "any_tool", arguments: [:])
        }
    }

    @Test("call throws toolError on isError=true result")
    func testCallThrowsOnToolError() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let responseJSON: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "result": [
                "isError": true,
                "content": [
                    ["type": "text", "text": "rate-limited; try again later"]
                ]
            ]
        ]
        stub.responseData = Self.jsonData(responseJSON)
        stub.responseStatusCode = 200
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            session: session
        )

        await #expect(throws: MCPJSONRPCClient.MCPError.self) {
            _ = try await client.call(tool: "any_tool", arguments: [:])
        }
    }

    @Test("call throws emptyContent when content has no text")
    func testCallThrowsOnEmptyContent() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let responseJSON: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "result": [
                "content": []
            ]
        ]
        stub.responseData = Self.jsonData(responseJSON)
        stub.responseStatusCode = 200
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            session: session
        )

        await #expect(throws: MCPJSONRPCClient.MCPError.self) {
            _ = try await client.call(tool: "any_tool", arguments: [:])
        }
    }

    @Test("call throws http on non-2xx response")
    func testCallThrowsOn4xx() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.responseData = Data("rate-limited".utf8)
        stub.responseStatusCode = 429
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            session: session
        )

        await #expect(throws: MCPJSONRPCClient.MCPError.self) {
            _ = try await client.call(tool: "any_tool", arguments: [:])
        }
    }

    @Test("call throws badResponse on non-JSON body")
    func testCallThrowsOnNonJSONBody() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.responseData = Data("<html>not json</html>".utf8)
        stub.responseStatusCode = 200
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            session: session
        )

        await #expect(throws: MCPJSONRPCClient.MCPError.self) {
            _ = try await client.call(tool: "any_tool", arguments: [:])
        }
    }

    @Test("call sets the userAgent header")
    func testCallSetsUserAgentHeader() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let responseJSON: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "result": ["content": [["type": "text", "text": "x"]]]
        ]
        stub.responseData = Self.jsonData(responseJSON)
        stub.responseStatusCode = 200
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            userAgent: "wenshu-test",
            session: session
        )

        _ = try await client.call(tool: "any_tool", arguments: [:])

        let captured = stub.lastRequest
        #expect(captured?.value(forHTTPHeaderField: "User-Agent") == "wenshu-test")
        #expect(captured?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(captured?.value(forHTTPHeaderField: "Accept")?.contains("application/json") == true)
    }

    @Test("call parses SSE-framed JSON-RPC response (= Exa MCP wire format)")
    func callParsesSSEFramedResponse() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        // SSE format: event: message\ndata: {json}\n\n
        // The data payload is a single JSON-RPC envelope with a result
        // containing a content[0].text string (= the Exa MCP wire shape).
        let envelope = """
        {"jsonrpc":"2.0","id":1,"result":{"content":[{"type":"text","text":"Title: Foo\\nURL: https://foo.example/\\nHighlights: hello"}],"isError":false}}
        """
        stub.responseData = Data("event: message\ndata: \(envelope)\n\n".utf8)
        stub.responseStatusCode = 200
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            userAgent: "wenshu-test",
            session: session
        )

        let text = try await client.call(tool: "web_search_exa", arguments: ["q": "test"])

        #expect(text.contains("Title: Foo"))
        #expect(text.contains("URL: https://foo.example/"))
    }

    @Test("call parses the first JSON-RPC result envelope when multiple are present")
    func callParsesMultipleSSEFrames() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        // Two SSE result frames in one response. wenshu parses the
        // first JSON-RPC envelope (= later frames are silently ignored;
        // = matches the hermes `walk_ring` pattern of taking the first
        // usable payload).
        let first = #"{"jsonrpc":"2.0","id":1,"result":{"content":[{"type":"text","text":"first frame wins"}],"isError":false}}"#
        let second = #"{"jsonrpc":"2.0","id":2,"result":{"content":[{"type":"text","text":"second frame"}],"isError":false}}"#
        let body = "event: message\ndata: \(first)\n\nevent: message\ndata: \(second)\n\n"
        stub.responseData = Data(body.utf8)
        stub.responseStatusCode = 200
        let session = Self.makeSession(for: stubProtocolClass)
        let client = MCPJSONRPCClient(
            endpoint: URL(string: "https://mcp.example.com/mcp")!,
            userAgent: "wenshu-test",
            session: session
        )

        let text = try await client.call(tool: "any", arguments: [:])
        #expect(text == "first frame wins")
    }
}