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
                let attemptId = UUID()
                do {
                    try await WAStreamWatchdog.shared.watch(attemptId: attemptId, timeout: 30) {
                        await self.runStream(
                            attemptId: attemptId,
                            body: body,
                            continuation: continuation
                        )
                    }
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

    /// Internal helper that performs the actual SSE work (= the body
    /// inside the WAStreamWatchdog race). The watchdog throws
    /// `WAStreamTimeoutError` if the entire stream takes longer than
    /// 30s (= the user sees "AI 暂时不可用" instead of "(no reply)").
    private func runStream(
        attemptId: UUID,
        body: Data?,
        continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation
    ) async {
        let diag = WAStreamDiag(attemptId: attemptId)
        let diagBox = MutableWAStreamDiag(diag)
        WALogger.network.debug("SSE stream attempt=\(diagBox.diag.attemptId.uuidString.prefix(8), privacy: .public) url=\(self.url, privacy: .public) bodyBytes=\(body?.count ?? 0)")
        do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    for (k, v) in headers {
                        request.setValue(v, forHTTPHeaderField: k)
                    }
                    if let body {
                        request.httpBody = body
                    }
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        WALogger.network.error("SSE stream attempt=\(diagBox.diag.attemptId.uuidString.prefix(8), privacy: .public) no HTTPURLResponse")
                        throw URLError(.badServerResponse)
                    }
                    diagBox.diag.httpStatus = http.statusCode
                    WALogger.network.info("SSE stream attempt=\(diagBox.diag.attemptId.uuidString.prefix(8), privacy: .public) HTTP \(http.statusCode)")
                    guard (200..<300).contains(http.statusCode) else {
                        var errorBody = ""
                        if let errorBytes = try? await bytes.lines.reduce(into: "", { $0 += "\n" + $1 }) {
                            errorBody = errorBytes
                        }
                        diagBox.diag.lastError = "HTTP \(http.statusCode)"
                        WALogger.network.error("SSE stream attempt=\(diagBox.diag.attemptId.uuidString.prefix(8), privacy: .public) \(diagBox.diag.summary, privacy: .public) body=\(errorBody, privacy: .private)")
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
                    // Build the current line as a byte array
                    // (= the String+Character approach was getting
                    // a type-inference error from the compiler on
                    // UnicodeScalar; = bytes-as-Data is the
                    // simpler path; = we convert to String at
                    // the \n boundary).
                    var currentLineBytes: [UInt8] = []
                    for try await byte in bytes {
                        if Task.isCancelled { break }
                        diagBox.diag.bytes += 1
                        if byte == 0x0A { // \n
                            // End of line: strip trailing CR
                            // (= handle \r\n).
                            if currentLineBytes.last == 0x0D {
                                currentLineBytes.removeLast()
                            }
                            let lineOut = String(decoding: currentLineBytes, as: UTF8.self)
                            if lineOut.isEmpty {
                                // Event boundary: emit.
                                if !pendingEvent.isEmpty || !pendingData.isEmpty {
                                    if diagBox.diag.firstChunkAt == nil {
                                        diagBox.diag.firstChunkAt = Date()
                                    }
                                    diagBox.diag.chunks += 1
                                    continuation.yield(SSEEvent(
                                        event: pendingEvent,
                                        data: pendingData.joined(separator: "\n")
                                    ))
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
                        if lineOut.isEmpty {
                            // Trailing empty line: emit any pending event.
                            if !pendingEvent.isEmpty || !pendingData.isEmpty {
                                if diagBox.diag.firstChunkAt == nil {
                                    diagBox.diag.firstChunkAt = Date()
                                }
                                diagBox.diag.chunks += 1
                                continuation.yield(SSEEvent(
                                    event: pendingEvent,
                                    data: pendingData.joined(separator: "\n")
                                ))
                                pendingEvent = ""
                                pendingData = []
                            }
                        } else if lineOut.hasPrefix("event:") {
                            pendingEvent = String(lineOut.dropFirst("event:".count))
                                .trimmingCharacters(in: .whitespaces)
                        } else if lineOut.hasPrefix("data:") {
                            var v = String(lineOut.dropFirst("data:".count))
                            if v.hasPrefix(" ") { v.removeFirst() }
                            pendingData.append(v)
                        }
                        // Emit any pending event (= the stream
                        // ended with data but no trailing blank
                        // line; = some Anthropic-compatible
                        // endpoints do this on the last event).
                        if !pendingEvent.isEmpty || !pendingData.isEmpty {
                            if diagBox.diag.firstChunkAt == nil {
                                diagBox.diag.firstChunkAt = Date()
                            }
                            diagBox.diag.chunks += 1
                            continuation.yield(SSEEvent(
                                event: pendingEvent,
                                data: pendingData.joined(separator: "\n")
                            ))
                            pendingEvent = ""
                            pendingData = []
                        }
                    }
                    diagBox.diag.finishReasonSeen = true
                    WALogger.network.info("SSE stream attempt=\(diagBox.diag.attemptId.uuidString.prefix(8), privacy: .public) finished \(diagBox.diag.summary, privacy: .public)")
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
    }

    /// Cancel the current stream (= closes the URLSession bytes
    /// task + finishes the continuation).
    func cancel() {
        task?.cancel()
    }

    /// Public byte-level SSE parser (= extracted from the runStream
    /// byte loop). Exposed so unit tests can verify the parser
    /// independently of the URLSession transport (= the original
    /// "URLSession.bytes.lines skips empty lines" bug was a parser
    /// regression, not a transport one; = hermes `stream_diag.py`
    /// style = separate the parser from the transport).
    ///
    /// Canonical W3C SSE wire format:
    ///   event: <name>\n
    ///   data: <data>\n
    ///   \n                  <- empty line = event boundary
    static func parseSSEBytes(_ bytes: [UInt8]) -> [SSEEvent] {
        var events: [SSEEvent] = []
        var currentLineBytes: [UInt8] = []
        var pendingEvent = ""
        var pendingData: [String] = []

        func emitPendingIfAny() {
            if !pendingEvent.isEmpty || !pendingData.isEmpty {
                events.append(SSEEvent(
                    event: pendingEvent,
                    data: pendingData.joined(separator: "\n")
                ))
                pendingEvent = ""
                pendingData = []
            }
        }

        for byte in bytes {
            if byte == 0x0A { // \n
                if currentLineBytes.last == 0x0D {
                    currentLineBytes.removeLast()
                }
                let lineOut = String(decoding: currentLineBytes, as: UTF8.self)
                if lineOut.isEmpty {
                    emitPendingIfAny()
                } else if lineOut.hasPrefix("event:") {
                    pendingEvent = String(lineOut.dropFirst("event:".count))
                        .trimmingCharacters(in: .whitespaces)
                } else if lineOut.hasPrefix("data:") {
                    var v = String(lineOut.dropFirst("data:".count))
                    if v.hasPrefix(" ") { v.removeFirst() }
                    pendingData.append(v)
                }
                // id: and :comment lines: ignored
                currentLineBytes.removeAll(keepingCapacity: true)
            } else {
                currentLineBytes.append(byte)
            }
        }
        // Trailing line without \n
        if !currentLineBytes.isEmpty {
            if currentLineBytes.last == 0x0D {
                currentLineBytes.removeLast()
            }
            let lineOut = String(decoding: currentLineBytes, as: UTF8.self)
            if !lineOut.isEmpty {
                if lineOut.hasPrefix("event:") {
                    pendingEvent = String(lineOut.dropFirst("event:".count))
                        .trimmingCharacters(in: .whitespaces)
                } else if lineOut.hasPrefix("data:") {
                    var v = String(lineOut.dropFirst("data:".count))
                    if v.hasPrefix(" ") { v.removeFirst() }
                    pendingData.append(v)
                }
            }
        }
        emitPendingIfAny()
        return events
    }
}
