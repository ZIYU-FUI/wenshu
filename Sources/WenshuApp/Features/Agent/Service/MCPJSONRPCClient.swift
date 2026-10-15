//
//  MCPJSONRPCClient.swift · Wenshu
//
//  Minimal MCP Streamable HTTP JSON-RPC 2.0 client built on URLSession.
//  Returns the first `text` payload from a `tools/call` response.
//
//  1:1 port of hermes plugins/web/keyless_mcp.py `mcp_call` (= the shared
//  transport layer for Parallel MCP and Exa MCP). Keenable uses plain
//  REST instead, so it does not go through this client.
//
//  MCPJSONRPCClient is a `struct` (= NOT an `actor`):
//
//  - The only async work is the URLSession call (= inherently async).
//  - Holding the client as an actor would add an unnecessary isolation
//    hop: callers must `await` across the actor boundary even though
//    the only async work is the URLSession call itself. The actor + URLSession
//    callback interleaving is the §11.5 Minimax-style combined-run
//    flake pattern (= Swift Testing runs multiple connector suites
//    concurrently; = the actor continuations from one suite interleave
//    with URLSession callbacks from another).
//  - All fields are `Sendable` (URL, String, TimeInterval, URLSession),
//    so the struct conforms to `Sendable` automatically.
//  - Cross-test isolation in Swift Testing is provided by
//    `URLProtocolStub.makeIsolatedStub()` (= per-test URLProtocol
//    subclass with associated stub); no global URLProtocolStub state
//    is shared.
//

import Foundation

struct MCPJSONRPCClient: Sendable {

    let endpoint: URL
    let userAgent: String
    let timeout: TimeInterval
    let session: URLSession

    init(
        endpoint: URL,
        userAgent: String = "wenshu",
        timeout: TimeInterval = 30,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.userAgent = userAgent
        self.timeout = timeout
        self.session = session
    }

    enum MCPError: Error, LocalizedError, Equatable {
        case http(status: Int, body: String)
        case jsonRPC(String)
        case toolError(String)
        case emptyContent
        case badResponse
        case transport(String)

        var errorDescription: String? {
            switch self {
            case .http(let status, let body):
                let preview = String(body.prefix(200))
                return "MCP HTTP \(status): \(preview)"
            case .jsonRPC(let message):
                return "MCP JSON-RPC error: \(message)"
            case .toolError(let message):
                return "MCP tool error: \(message)"
            case .emptyContent:
                return "MCP response had no text content"
            case .badResponse:
                return "MCP response shape unrecognized"
            case .transport(let message):
                return "MCP transport failure: \(message)"
            }
        }
    }

    /// POST a JSON-RPC `tools/call` envelope and return the first text payload
    /// from `result.content[*].text`.
    ///
    /// - Parameters:
    ///   - tool: MCP tool name (= the `params.name` field).
    ///   - arguments: arguments object (= the `params.arguments` field).
    /// - Throws: `MCPError.http` / `.jsonRPC` / `.toolError` / `.emptyContent` / `.badResponse` / `.transport`.
    func call(tool: String, arguments: [String: Any]) async throws -> String {
        let envelope: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": [
                "name": tool,
                "arguments": arguments
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: envelope)
        } catch {
            throw MCPError.transport("failed to encode JSON-RPC envelope: \(error)")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MCPError.transport(String(describing: error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw MCPError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw MCPError.http(status: http.statusCode, body: body)
        }

        // MCP Streamable HTTP servers may respond with one of:
        //   - application/json: a single JSON-RPC envelope (= e.g. Parallel MCP).
        //   - text/event-stream: SSE format with "event: message\ndata: {json}\n\n"
        //     (= e.g. Exa MCP). Multiple frames may arrive in one response.
        // We parse both shapes uniformly by extracting every JSON
        // payload from the SSE stream first (= if any), then falling
        // back to a direct JSONSerialization on the raw bytes.
        let candidateBodies = Self.extractSSEJSONPayloads(from: data)
        let jsonPayload: Data = candidateBodies.first ?? data

        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: jsonPayload)
        } catch {
            throw MCPError.badResponse
        }
        guard let json = parsed as? [String: Any] else {
            throw MCPError.badResponse
        }

        if let err = json["error"] as? [String: Any] {
            let message = (err["message"] as? String) ?? String(describing: err)
            throw MCPError.jsonRPC(message)
        }

        guard let result = json["result"] as? [String: Any] else {
            throw MCPError.badResponse
        }

        if (result["isError"] as? Bool) == true {
            let texts = (result["content"] as? [[String: Any]] ?? [])
                .compactMap { $0["text"] as? String }
            throw MCPError.toolError(texts.joined(separator: " "))
        }

        let texts = (result["content"] as? [[String: Any]] ?? [])
            .compactMap { $0["text"] as? String }
            .filter { !$0.isEmpty }
        guard let first = texts.first else {
            throw MCPError.emptyContent
        }
        return first
    }

    /// Extract the JSON payload(s) from an MCP Streamable HTTP SSE response.
    /// Returns the bytes between `data: ` and the next `\n` for every
    /// frame (= one per line that starts with `data: `). Returns empty
    /// when the response is not SSE.
    ///
    /// Sample SSE response:
    ///
    ///     event: message
    ///     data: {"jsonrpc":"2.0","id":1,"result":{...}}
    ///
    /// This produces one frame (`{"jsonrpc":"2.0","id":1,"result":{...}}`).
    private static func extractSSEJSONPayloads(from data: Data) -> [Data] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        // Fast bail: if the body does not contain the SSE "data: " prefix,
        // treat the whole body as a JSON payload (= non-SSE case).
        guard text.contains("data: ") else { return [] }
        var payloads: [Data] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data: ") else { continue }
            let jsonText = String(trimmed.dropFirst("data: ".count))
            if let payload = jsonText.data(using: .utf8) {
                payloads.append(payload)
            }
        }
        return payloads
    }
}