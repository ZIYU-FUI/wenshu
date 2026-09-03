// SSEClient.swift · Wenshu (文枢) · v0.34
//
// v0.34 boss 2026-09-02 OOB '其他工程上的机制我不太懂, 你看着定':
// Server-Sent Events (SSE) client for streaming LLM responses
// (= port of Card-master `src/ai/infrastructure/responses-api-client.ts`
// SSE parsing logic).
//
// SSE wire format (= W3C spec):
//   event: <event-name>\n
//   data: <single-line data>\n
//   \n
// (= each event ends with a blank line; data may span multiple
// "data:" lines which the consumer must concatenate with '\n'.)
//
// Apple-API-first check: `URLSession.bytes(for:)` (= macOS 12+;
// async stream of URLSession bytes = Apple canonical SSE
// transport; no third-party HTTP client needed).
//
// Use:
//   let sse = SSEClient(url: url)
//   for try await event in sse.stream() {
//     // event.event = "message" / "error" / etc.
//     // event.data = "incremental response chunk"
//   }
//
// Cancellation:
//   Call `sse.cancel()` from outside the for-loop (= breaks the
//   URLSession bytes task; partial events are dropped).

import Foundation

/// A single Server-Sent Event parsed from a streaming HTTP response.
public struct SSEEvent: Sendable {
    /// Event name (= "message" for default / unnamed; "error" for
    /// stream-level errors; provider-specific names for tool calls
    /// etc.). Empty string if the server omitted `event:` line.
    public let event: String

    /// Event data payload (= single-line or multi-line joined with
    /// '\n' per W3C SSE spec). Empty string if the server omitted
    /// `data:` line.
    public let data: String
}

/// SSE client = URLSession.bytes consumer that parses the W3C SSE
/// wire format. Supports both Anthropic Messages API and OpenAI
/// Chat Completions streaming (= both use the same SSE envelope).
public actor SSEClient {
    let url: URL
    var headers: [String: String]
    private var session: URLSession
    private var task: Task<Void, Never>?

    public init(url: URL, headers: [String: String] = [:], session: URLSession = .shared) {
        self.url = url
        self.headers = headers
        self.session = session
    }

    /// Stream SSE events. Caller `break`s out of the loop to cancel
    /// (= partial events are dropped; URLSession.bytes task is
    /// automatically cancelled when the iterator is deallocated).
    public func stream() -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    for (k, v) in headers {
                        request.setValue(v, forHTTPHeaderField: k)
                    }
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        throw NSError(
                            domain: "SSEClient",
                            code: http.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
                        )
                    }
                    // Parse SSE: read line by line, accumulate
                    // event: + data: until blank line.
                    var pendingEvent = ""
                    var pendingData: [String] = []
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if line.isEmpty {
                            // Event boundary: emit.
                            if !pendingEvent.isEmpty || !pendingData.isEmpty {
                                continuation.yield(SSEEvent(
                                    event: pendingEvent,
                                    data: pendingData.joined(separator: "\n")
                                ))
                                pendingEvent = ""
                                pendingData = []
                            }
                            continue
                        }
                        if line.hasPrefix("event:") {
                            pendingEvent = String(line.dropFirst("event:".count))
                                .trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            var v = String(line.dropFirst("data:".count))
                            // Strip leading single space (SSE convention).
                            if v.hasPrefix(" ") { v.removeFirst() }
                            pendingData.append(v)
                        } else if line.hasPrefix("id:") || line.hasPrefix(":") {
                            // id + comment lines: ignored (= Last-Event-ID
                            // resumption not needed for v0.34 chat; comments
                            // are heartbeat lines).
                            continue
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            self.task = task
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Cancel the current stream (= closes the URLSession bytes
    /// task + finishes the continuation).
    public func cancel() {
        task?.cancel()
    }
}