import Foundation

// CompanionRoutes.swift
//
// The local API contract: the route table and the wire shapes.
//
// The rule that shapes this file: the only route that answers without a
// credential is the ping. Every other path requires a credential, so a
// request that names a path the server does not have gets the same
// refusal a request to a real route gets. The route table therefore
// never tells a caller what exists.
//
// The table also carries the routes the later cards implement. A route
// that is declared but not implemented yet still refuses an anonymous
// caller, so the authorization rule has the same shape from the first
// day.

// MARK: - Authorization

/// How a route decides whether a request may proceed.
enum CompanionAuthorization: Sendable, Equatable {
    /// The route is public. Only the ping is.
    case none
    /// The route needs the one-time pairing code.
    case pairingCode
    /// The route needs the device token.
    case deviceToken
}

// MARK: - Route table

/// One entry of the local API contract.
struct CompanionRouteSpec: Sendable, Equatable {
    /// The stable identifier of the route (= the log and metric name).
    let id: String
    /// The HTTP method (= uppercase).
    let method: String
    /// The path template (= `/v1/chapter/{id}` carries one placeholder).
    let pathTemplate: String
    /// The credential the route demands.
    let authorization: CompanionAuthorization
    /// The capability flag the ping reports for this route.
    let capability: String
    /// Whether a handler exists yet.
    let isImplemented: Bool

    init(
        id: String,
        method: String,
        pathTemplate: String,
        authorization: CompanionAuthorization,
        capability: String,
        isImplemented: Bool
    ) {
        self.id = id
        self.method = method
        self.pathTemplate = pathTemplate
        self.authorization = authorization
        self.capability = capability
        self.isImplemented = isImplemented
    }

    /// Whether the request path matches this route's template.
    ///
    /// A `{name}` placeholder matches exactly one non-empty segment.
    /// The comparison is exact otherwise: no prefix match, so
    /// `/v1/ping/extra` is not the ping.
    func matches(path: String) -> Bool {
        let template = pathTemplate.split(separator: "/")
        let actual = path.split(separator: "/")
        guard template.count == actual.count else { return false }
        for (left, right) in zip(template, actual) {
            if left.hasPrefix("{") && left.hasSuffix("}") {
                guard !right.isEmpty else { return false }
                continue
            }
            guard left == right else { return false }
        }
        return true
    }
}

/// The routes the local API exposes.
enum CompanionRouteTable {

    /// The whole table, in contract order.
    ///
    /// The two implemented routes are the ones the phone needs to start.
    /// The rest are declared so the authorization rule has the same shape
    /// for them, and so a later card adds a handler instead of
    /// reshaping the service.
    static let all: [CompanionRouteSpec] = [
        CompanionRouteSpec(
            id: "ping",
            method: "GET",
            pathTemplate: "/v1/ping",
            authorization: .none,
            capability: "ping",
            isImplemented: true
        ),
        CompanionRouteSpec(
            id: "pair",
            method: "POST",
            pathTemplate: "/v1/pair",
            authorization: .pairingCode,
            capability: "pair",
            isImplemented: true
        ),
        CompanionRouteSpec(
            id: "library",
            method: "GET",
            pathTemplate: "/v1/library",
            authorization: .deviceToken,
            capability: "library",
            isImplemented: false
        ),
        CompanionRouteSpec(
            id: "chapter.read",
            method: "GET",
            pathTemplate: "/v1/chapter/{id}",
            authorization: .deviceToken,
            capability: "chapter",
            isImplemented: false
        ),
        CompanionRouteSpec(
            id: "chapter.write",
            method: "PUT",
            pathTemplate: "/v1/chapter/{id}",
            authorization: .deviceToken,
            capability: "chapter",
            isImplemented: false
        ),
        CompanionRouteSpec(
            id: "references",
            method: "GET",
            pathTemplate: "/v1/references",
            authorization: .deviceToken,
            capability: "references",
            isImplemented: false
        ),
        CompanionRouteSpec(
            id: "events",
            method: "GET",
            pathTemplate: "/v1/events",
            authorization: .deviceToken,
            capability: "events",
            isImplemented: false
        )
    ]

    /// The route a request addresses, or nil when no route does.
    static func spec(matching method: String, path: String) -> CompanionRouteSpec? {
        let uppercased = method.uppercased()
        return all.first { $0.method == uppercased && $0.matches(path: path) }
    }

    /// The capability flags the ping reports.
    ///
    /// A flag appears when a handler exists, so the phone never reads a
    /// capability the server cannot serve.
    static var implementedCapabilities: [String] {
        var seen = Set<String>()
        var flags: [String] = []
        for route in all where route.isImplemented {
            if seen.insert(route.capability).inserted {
                flags.append(route.capability)
            }
        }
        return flags.sorted()
    }
}

// MARK: - HTTP

/// A request the service parsed off one connection.
struct CompanionHTTPRequest: Sendable, Equatable {
    /// The HTTP method (= uppercase).
    let method: String
    /// The request path, without the query string.
    let path: String
    /// The headers, keyed by lowercase name.
    let headers: [String: String]
    /// The request body.
    let body: Data

    init(method: String, path: String, headers: [String: String], body: Data) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }

    /// The value of one header, matched case-insensitively.
    func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }

    /// The device token the caller presented, if any.
    ///
    /// The canonical carrier is `Authorization: Bearer <token>`.
    var deviceToken: String? {
        guard let value = header("authorization") else { return nil }
        let parts = value.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 2, parts[0].lowercased() == "bearer" else { return nil }
        let token = String(parts[1])
        return token.isEmpty ? nil : token
    }
}

/// A response the service writes back on one connection.
struct CompanionHTTPResponse: Sendable, Equatable {
    /// The HTTP status code.
    let status: Int
    /// The HTTP reason phrase.
    let reason: String
    /// The response body.
    let body: Data

    init(status: Int, reason: String, body: Data) {
        self.status = status
        self.reason = reason
        self.body = body
    }

    /// A JSON response.
    ///
    /// The body carries only what the contract names. An error body
    /// carries the error name and nothing else: no path, no identifier,
    /// and no hint about what the server holds.
    static func json(
        status: Int,
        reason: String,
        payload: some Encodable & Sendable
    ) -> CompanionHTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = (try? encoder.encode(payload)) ?? Data()
        return CompanionHTTPResponse(status: status, reason: reason, body: encoded)
    }

    /// The whole response: the status line, the headers, and the body.
    ///
    /// The body is JSON, and the length header matches it, so a client
    /// reads exactly the bytes the server wrote.
    func payload(keepAlive: Bool) -> Data {
        let head = "HTTP/1.1 \(status) \(reason)\r\n"
            + "Content-Type: application/json\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Connection: \(keepAlive ? "keep-alive" : "close")\r\n"
            + "\r\n"
        return Data(head.utf8) + body
    }
}

/// The result of parsing a connection's bytes.
enum CompanionHTTPParsing: Sendable, Equatable {
    /// The bytes so far do not carry a whole request yet.
    case incomplete
    /// The bytes carry a whole request, and how many bytes it took.
    case complete(request: CompanionHTTPRequest, consumed: Int)
}

/// The HTTP reader.
///
/// The subset is the one the local API needs: a request line, headers,
/// and a body sized by `Content-Length`. Nothing else is accepted, so a
/// malformed request never reaches a handler.
enum CompanionHTTPRequestParser {

    /// The header terminator.
    private static let headerTerminator = Data("\r\n\r\n".utf8)

    /// Parse the buffer into a request, if the buffer holds one.
    ///
    /// The parser is deliberately strict: a request line without a
    /// method and a target is a malformed request, not a route.
    static func parse(_ buffer: Data) -> CompanionHTTPParsing {
        guard let terminator = buffer.range(of: headerTerminator) else {
            return .incomplete
        }
        let head = buffer[..<terminator.lowerBound]
        let bodyStart = terminator.upperBound
        guard let headText = String(data: head, encoding: .utf8) else {
            return .incomplete
        }
        var lines = headText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return .incomplete }
        lines.removeFirst()

        let fields = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard fields.count >= 2 else { return .incomplete }
        let method = String(fields[0]).uppercased()
        var target = String(fields[1])
        if let query = target.firstIndex(of: "?") {
            target = String(target[target.startIndex..<query])
        }
        guard !method.isEmpty, !target.isEmpty else { return .incomplete }

        var headers: [String: String] = [:]
        for line in lines {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            headers[name] = value
        }

        var expectedBody = 0
        if let lengthText = headers["content-length"], let length = Int(lengthText), length > 0 {
            expectedBody = length
        }
        // The body is the bytes the header block does not cover. The
        // count that matters is the body count, not the header count:
        // a header block is longer than most bodies, so comparing the
        // header length against the body length reads a request whose
        // body has not arrived yet as a whole one, and the slice below
        // then runs past the end of the buffer.
        let headerLength = buffer.distance(from: buffer.startIndex, to: bodyStart)
        let availableBody = buffer.distance(from: bodyStart, to: buffer.endIndex)
        guard availableBody >= expectedBody else { return .incomplete }
        let body = Data(buffer[bodyStart..<(bodyStart + expectedBody)])
        let request = CompanionHTTPRequest(method: method, path: target, headers: headers, body: body)
        return .complete(request: request, consumed: headerLength + expectedBody)
    }
}

// MARK: - Bodies

/// The body of the ping.
struct CompanionPingBody: Codable, Sendable, Equatable {
    /// The server version.
    let version: String
    /// The capability flags the server serves.
    let capabilities: [String]
}

/// The body the phone sends to pair.
struct CompanionPairRequestBody: Codable, Sendable, Equatable {
    /// The pairing code the user confirmed.
    let code: String
}

/// The body the pair route answers with.
struct CompanionPairResponseBody: Codable, Sendable, Equatable {
    /// The device token the phone keeps.
    let token: String
}

/// The body of every refusal and every failure.
///
/// One field, and it names the refusal. It carries no path, no
/// identifier, and no reason beyond the status code the caller already
/// has.
struct CompanionErrorBody: Codable, Sendable, Equatable {
    /// The error name.
    let error: String
}
