// SSEClient.swift
//
// Server-Sent Events (SSE) client for streaming LLM responses.
// Parses the W3C SSE wire format from `URLSession.bytes(for:)`.
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
struct SSEEvent: Sendable {
    /// Event name (= "message" for default / unnamed; "error" for
    /// stream-level errors; provider-specific names for tool calls
    /// etc.). Empty string if the server omitted `event:` line.
    let event: String

    /// Event data payload (= single-line or multi-line joined with
    /// '\n' per W3C SSE spec). Empty string if the server omitted
    /// `data:` line.
    let data: String
}

/// SSE client = URLSession.bytes consumer that parses the W3C SSE
/// wire format. Supports both Anthropic Messages API and OpenAI
/// Chat Completions streaming (= both use the same SSE envelope).
actor SSEClient {
    let url: URL
    var headers: [String: String]
    private var session: URLSession
    private var task: Task<Void, Never>?

    init(url: URL, headers: [String: String] = [:], session: URLSession = .shared) {
        self.url = url
        self.headers = headers
        self.session = session
    }

    /// Stream SSE events. Caller `break`s out of the loop to cancel
    /// (= partial events are dropped; URLSession.bytes task is
    /// automatically cancelled when the iterator is deallocated).
    /// Pass `body: Data?` to send a POST body (= the body is
    /// appended inside the URLSession bytes task; = the previous
    /// shape took only URL + headers and sent an empty body, which
    /// the Anthropic-compatible endpoint rejected with HTTP 400).
    /// When `body` is nil, the request sends an empty body (=
    /// matches the old behavior; = `WenshuVerifier` and any
    /// GET-shaped callers keep working).
    func stream(body: Data? = nil) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    for (k, v) in headers {
                        request.setValue(v, forHTTPHeaderField: k)
                    }
                    if let body {
                        request.httpBody = body
                    }
                    NSLog("WSStream: POST %@ bodyBytes=%d", url.absoluteString, body?.count ?? 0)
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    // Diagnostic: log status + content-type + first 200 chars
                    // of any readable body bytes (the body might be
                    // streamable but URLSession may not have read the
                    // first chunk by the time the diagnostic runs).
                    let ct = (http.value(forHTTPHeaderField: "content-type") ?? "nil") as String
                    let cl = (http.value(forHTTPHeaderField: "content-length") ?? "nil") as String
                    let ce = (http.value(forHTTPHeaderField: "content-encoding") ?? "nil") as String
                    try? "status=\(http.statusCode) ct=\(ct) cl=\(cl) ce=\(ce)\n---\n".write(toFile: "/tmp/wsstream-status-\(getpid()).log", atomically: true, encoding: .utf8)
                    guard (200..<300).contains(http.statusCode) else {
                        // Capture the body bytes so the caller can
                        // see the real reason (= minimax returns
                        // a JSON error with a `message` field;
                        // = the previous `throw NSError(domain: "SSEClient", ...)`
                        // dropped these bytes on the floor).
                        var errorBody = ""
                        if let errorBytes = try? await bytes.lines.reduce(into: "") { $0 += "\n" + $1 } {
                            errorBody = errorBytes
                        }
                        throw NSError(
                            domain: "SSEClient",
                            code: http.statusCode,
                            userInfo: [
                                NSLocalizedDescriptionKey: "HTTP \(http.statusCode)",
                                "responseBody": errorBody
                            ]
                        )
                    }
                    // Parse SSE: read byte-by-byte and split on
                    // \n (or \r\n), preserving empty lines (= the
                    // event boundary). The previous design used
                    // `for try await line in bytes.lines`, but
                    // URLSession.bytes.lines SKIPS empty lines
                    // (= the for-await never sees the boundary
                    // = pendingEvent + pendingData stuck on the
                    // first event = no yields ever).
                    //
                    // The replacement iterates the AsyncBytes
                    // byte-by-byte, accumulates into a
                    // currentLine, and yields on each \n (= with
                    // a trailing CR stripped). Empty lines are
                    // passed through (= this is what fires the
                    // `line.isEmpty` boundary check).
                    var pendingEvent = ""
                    var pendingData: [String] = []
                    var rawLineCount = 0
                    var firstRawLines = ""
                    var yieldCount = 0
                    var rawBoundaryCount = 0
                    // Build the current line as a byte array (= the
                    // String+Character approach was getting a
                    // type-inference error from the compiler on
                    // UnicodeScalar; = bytes-as-Data is the
                    // simpler path; = we convert to String at
                    // the \n boundary).
                    var currentLineBytes: [UInt8] = []
                    var byteCount = 0
                    for try await byte in bytes {
                        if Task.isCancelled { break }
                        byteCount += 1
                        if byte == 0x0A { // \n
                            // End of line: strip trailing CR
                            // (= handle \r\n).
                            if currentLineBytes.last == 0x0D {
                                currentLineBytes.removeLast()
                            }
                            // Convert the byte buffer to String for
                            // the SSE parser (= ASCII + UTF-8
                            // events; = never lossy here).
                            let lineOut = String(decoding: currentLineBytes, as: UTF8.self)
                            rawLineCount += 1
                            if rawLineCount <= 5 {
                                firstRawLines += "[\(rawLineCount)]len=\(lineOut.count)'\(lineOut.prefix(40))' "
                            }
                            if lineOut.isEmpty {
                                // Event boundary: emit.
                                rawBoundaryCount += 1
                                if !pendingEvent.isEmpty || !pendingData.isEmpty {
                                    continuation.yield(SSEEvent(
                                        event: pendingEvent,
                                        data: pendingData.joined(separator: "\n")
                                    ))
                                    yieldCount += 1
                                    pendingEvent = ""
                                    pendingData = []
                                }
                            } else if lineOut.hasPrefix("event:") {
                                pendingEvent = String(lineOut.dropFirst("event:".count))
                                    .trimmingCharacters(in: .whitespaces)
                            } else if lineOut.hasPrefix("data:") {
                                var v = String(lineOut.dropFirst("data:".count))
                                // Strip leading single space (SSE convention).
                                if v.hasPrefix(" ") { v.removeFirst() }
                                pendingData.append(v)
                            } else if lineOut.hasPrefix("id:") || lineOut.hasPrefix(":") {
                                // id + comment lines: ignored
                                // (= comments are heartbeat lines).
                            }
                            currentLineBytes.removeAll(keepingCapacity: true)
                        } else {
                            currentLineBytes.append(byte)
                        }
                    }
                    // Handle the final line if the stream ended
                    // without a trailing \n (= edge case for
                    // the last event in a non-SSE response).
                    if !currentLineBytes.isEmpty {
                        if currentLineBytes.last == 0x0D {
                            currentLineBytes.removeLast()
                        }
                        let lineOut = String(decoding: currentLineBytes, as: UTF8.self)
                        rawLineCount += 1
                        if lineOut.isEmpty {
                            rawBoundaryCount += 1
                        } else if lineOut.hasPrefix("event:") {
                            pendingEvent = String(lineOut.dropFirst("event:".count))
                                .trimmingCharacters(in: .whitespaces)
                        } else if lineOut.hasPrefix("data:") {
                            var v = String(lineOut.dropFirst("data:".count))
                            if v.hasPrefix(" ") { v.removeFirst() }
                            pendingData.append(v)
                        }
                        if !pendingEvent.isEmpty || !pendingData.isEmpty {
                            continuation.yield(SSEEvent(
                                event: pendingEvent,
                                data: pendingData.joined(separator: "\n")
                            ))
                            yieldCount += 1
                        }
                    }
                    try? "rawLineCount=\(rawLineCount) yieldCount=\(yieldCount) rawBoundaryCount=\(rawBoundaryCount) byteCount=\(byteCount) firstLines=\(firstRawLines)\n---\n".write(toFile: "/tmp/wsstream-lines-\(getpid()).log", atomically: true, encoding: .utf8)
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
    func cancel() {
        task?.cancel()
    }
}
