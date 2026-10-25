// SSEReader.swift
//
// Reads a server-sent-event stream without the callback race.
//
// The problem this replaces is not hypothetical. The EventSource library
// starts connecting from its initializer, on an unstructured task, and
// installs the message callback on another unstructured task:
//
//     public init(request: URLRequest, ...) {
//         Task { [weak self] in await self?.open() }          // connects
//     }
//     nonisolated public var onMessage: ... {
//         set { Task { await self.setOnMessageCallback(newValue) } }  // installs
//     }
//
// Nothing orders those two tasks. A provider that answers quickly — which
// is every fast model — delivers its whole response before the callback is
// installed, and the parser drops the events it has no callback for. The
// symptom is a stream that opens, produces nothing, and eventually looks
// like a hang.
//
// The fix is to own the byte loop here. The library's parser is public and
// does the wire-format work, so it is kept: the bytes are read, fed to the
// parser, and the events the parser produces are handed straight to the
// caller. The callback race cannot happen, because there is no callback to
// install — the consumer is the loop itself.
//
// This also drops a dependency from the streaming path, which matters for a
// tool whose users install one app and nothing else.

import Foundation
import EventSource

/// One event from a server-sent-event stream.
///
/// The library's own event type has an internal initializer, so the reader
/// carries its own. The fields are the ones the wire format defines.
public struct WenshuSSEEvent: Sendable, Equatable {
    /// The event name, when the server named it.
    public let name: String?
    /// The data payload.
    public let data: String

    public init(name: String?, data: String) {
        self.name = name
        self.data = data
    }
}

/// Turns a byte stream into events, without a socket.
///
/// The socket part of the reader is thin; the parsing is where the
/// behaviour lives, and keeping it separate means it can be exercised
/// without a server. The wire format is what the specification defines:
/// a field name, a colon, the value, and a blank line to end the event.
public struct SSEByteParser {
    /// The parser state.
    private var parser = EventSource.Parser()

    public init() {}

    /// Feed bytes and collect the events they complete.
    public mutating func consume(_ bytes: [UInt8]) async -> [WenshuSSEEvent] {
        var events: [WenshuSSEEvent] = []
        for byte in bytes {
            await parser.consume(byte)
            events.append(contentsOf: await drain())
        }
        return events
    }

    /// The events left over when the stream ends.
    ///
    /// The server may close without a trailing blank line, and the last
    /// event is then still held by the parser.
    public mutating func finish() async -> [WenshuSSEEvent] {
        await parser.finish()
        return await drain()
    }

    private func drain() async -> [WenshuSSEEvent] {
        var events: [WenshuSSEEvent] = []
        while let event = await parser.getNextEvent() {
            events.append(WenshuSSEEvent(name: event.event, data: event.data))
        }
        return events
    }
}

/// Reads an SSE stream and yields its events as they arrive.
public enum SSEReader {
    /// The events of the stream, in order.
    ///
    /// The stream ends when the server closes the connection. An error
    /// before the first event is delivered through the same channel, so a
    /// caller sees one consistent failure shape.
    public static func events(
        for request: URLRequest,
        session: URLSession = URLSession(configuration: .default)
    ) -> AsyncThrowingStream<WenshuSSEEvent, Error> {
        AsyncThrowingStream(WenshuSSEEvent.self, bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request, delegate: nil)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        // Read the provider's message (= the body says why
                        // it refused; = without it the failure is just a
                        // number, = and nobody can act on a number).
                        var errorBytes: [UInt8] = []
                        for try await byte in bytes {
                            errorBytes.append(byte)
                            if errorBytes.count > 4000 { break }
                        }
                        let body = String(data: Data(errorBytes), encoding: .utf8) ?? ""
                        continuation.finish(
                            throwing: SSEError.httpStatus(http.statusCode, body: body)
                        )
                        return
                    }
                    var parser = SSEByteParser()
                    var buffer: [UInt8] = []
                    for try await byte in bytes {
                        if Task.isCancelled { break }
                        buffer.append(byte)
                        // Parse in batches: one byte at a time would ask the
                        // parser for an event after every single byte.
                        if buffer.count >= 512 {
                            for event in await parser.consume(buffer) { continuation.yield(event) }
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty {
                        for event in await parser.consume(buffer) { continuation.yield(event) }
                    }
                    // The server closed the connection; the parser may still
                    // be holding a final event that had no trailing blank
                    // line.
                    for event in await parser.finish() { continuation.yield(event) }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                session.invalidateAndCancel()
            }
            continuation.onTermination = { (_: AsyncThrowingStream<WenshuSSEEvent, Error>.Continuation.Termination) in task.cancel() }
        }
    }
}

/// The failures the reader can report.
public enum SSEError: Error, LocalizedError {
    case httpStatus(Int, body: String?)
    public var errorDescription: String? {
        switch self {
        case .httpStatus(let code, let body):
            // The provider's own message says WHY (= a budget it will
            // not take, = a quota, = a model it does not know), = so it
            // travels with the failure.
            if let body, !body.isEmpty {
                return "The stream request failed with HTTP \(code): \(body)"
            }
            return "The stream request failed with HTTP \(code)."
        }
    }
}
