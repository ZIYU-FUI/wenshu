//
//  MockLLMServer.swift · Wenshu · v0.37 Batch 2.5 sub-step 1
//
//  Mock HTTP server that simulates all 7 LLM providers (= per ADR-0008
//  7-connector BYOK). Used for per-ticket X e2e tests (= ticket 018
//  sub-step 3 extension = per-ticket with real API simulation).
//
//  The mock server:
//  1. Listens on a local port (= localhost:0 = OS-assigned)
//  2. Routes requests by path to the appropriate provider simulator
//    - /v1/messages -> Anthropic simulator
//    - /v1/chat/completions -> OpenAI simulator (= covers OpenAI + DeepSeek
//      + Ollama + OpenRouter + minimax cn which are all OpenAI-compatible)
//    - /v1beta/models/... -> Gemini simulator
//  3. Returns scripted responses (= provider-specific JSON shape)
//  4. Captures request bodies (= for assertions in tests)
//
//  Per 老板 cadence 2026-09-03 '继续' + 'PO 全链路方法论执行,不要跳步骤'
//  + '翻译这个事做完一起验视觉和前端流程' + '1 RULE 1 commit'.
//

import Foundation
import Network

/// Mock LLM server simulating all 7 providers (= per ADR-0008).
public final class MockLLMServer: @unchecked Sendable {
    public struct ScriptedResponse {
        public let statusCode: Int
        public let headers: [String: String]
        public let body: Data
    }

    /// All captured requests across all paths.
    public private(set) var capturedRequests: [String: [(method: String, path: String, body: Data)]] = [:]

    /// Per-path scripted responses (= consumed in order).
    public var scriptedResponses: [String: [ScriptedResponse]] = [:]

    /// Default response when no scripted response is set.
    public var defaultResponse: ScriptedResponse = ScriptedResponse(
        statusCode: 200,
        headers: ["Content-Type": "application/json"],
        body: #"{"id":"mock","model":"mock-model","content":[{"type":"text","text":"Hello from mock server"}]}"#.data(using: .utf8)!
    )

    private var listener: NWListener?
    private var port: UInt16 = 0
    private let queue = DispatchQueue(label: "MockLLMServer")

    public init() {}

    /// Start the mock server on a random local port. Returns the port.
    @discardableResult
    public func start() throws -> UInt16 {
        let params = NWParameters.tcp
        let nwPort = NWEndpoint.Port(rawValue: 0)!  // OS-assigned
        let listener = try NWListener(using: params, on: nwPort)
        self.listener = listener

        let semaphore = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if let assignedPort = listener.port {
                    self.port = assignedPort.rawValue
                }
                semaphore.signal()
            case .failed:
                semaphore.signal()
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        listener.start(queue: queue)
        semaphore.wait()
        return port
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    public var baseURL: URL? {
        guard port > 0 else { return nil }
        return URL(string: "http://localhost:\(port)")
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(connection: connection)
    }

    private func receiveRequest(connection: NWConnection) {
        var requestData = Data()
        var requestHeaders: [String: String] = [:]
        var requestMethod = "GET"
        var requestPath = "/"

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let data = data, let self = self else { return }
            requestData.append(data)
            // Parse HTTP request line + headers
            if let requestString = String(data: data, encoding: .utf8) {
                let lines = requestString.split(separator: "\r\n", omittingEmptySubsequences: true)
                if let firstLine = lines.first {
                    let parts = firstLine.split(separator: " ")
                    if parts.count >= 2 {
                        requestMethod = String(parts[0])
                        requestPath = String(parts[1])
                    }
                }
                for line in lines.dropFirst() {
                    if let colonIndex = line.firstIndex(of: ":") {
                        let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                        let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        requestHeaders[key] = value
                    }
                }
            }

            // Capture request
            self.queue.async { [weak self] in
                self?.capturedRequests[requestPath, default: []].append(
                    (method: requestMethod, path: requestPath, body: requestData)
                )
            }

            // Find scripted response or default
            let response: ScriptedResponse
            if var scripted = self.scriptedResponses[requestPath], !scripted.isEmpty {
                response = scripted.removeFirst()
                self.scriptedResponses[requestPath] = scripted
            } else {
                response = self.defaultResponse
            }

            // Send HTTP response
            let statusText = response.statusCode == 200 ? "OK" : "Status \(response.statusCode)"
            var responseString = "HTTP/1.1 \(response.statusCode) \(statusText)\r\n"
            for (k, v) in response.headers {
                responseString += "\(k): \(v)\r\n"
            }
            responseString += "Content-Length: \(response.body.count)\r\n"
            responseString += "\r\n"
            var responseData = responseString.data(using: .utf8)!
            responseData.append(response.body)

            connection.send(content: responseData, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}