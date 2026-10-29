import Darwin
import Foundation
import Network
import Testing
@testable import WenshuApp

// CompanionServiceTests.swift
//
// The companion service's own tests.
//
// The proofs the service owes the reviewer:
//
//   1. The listener binds to the loopback interface and to nothing else.
//   2. The ping carries the version and the capability flags, and no
//      path, no identifier, and no token.
//   3. Every route but the ping refuses an unauthenticated request with
//      401 and a body that carries no detail.
//   4. The device token lives in the Keychain, and in neither the
//      preferences nor a file.
//
// The tests drive the real listener over a real socket, because the
// claims are about the wire and not about the routing table.

// MARK: - The suite

@Suite("Companion service")
struct CompanionServiceTests {

    // MARK: - 1. The listener binds to the loopback interface only

    @Test("The listener binds to the loopback interface and to nothing else")
    func listenerBindsToLoopbackOnly() async throws {
        let service = await makeService()
        let port = try await waitForPort(service)

        // The loopback address answers.
        let ping = try await send(port: port, raw: rawRequest(method: "GET", path: "/v1/ping"))
        #expect(ping.status == 200, "the loopback address must answer")
        #expect(ping.bodyString.contains("9.9.9"), "the answer comes from the service under test")

        // The listening port is taken on the loopback address and free
        // on every other address of this machine. A listener on the
        // wildcard would hold the port on every address, so this is the
        // check that tells the two apart.
        //
        // The check is a local bind on the listening port, not a
        // connection to it. A connection cannot tell the two apart on
        // every machine: a tunnel can complete the handshake on a LAN
        // address without the service ever seeing the connection.
        for address in nonLoopbackIPv4Addresses() {
            let taken = portIsTaken(on: address, port: port)
            #expect(!taken, "the service must not hold the port on \(address)")
        }

        // The bind address is the loopback address, and the source names
        // no other one.
        let source = try SourceLocator.readSource(named: "CompanionService.swift")
        #expect(source.contains("requiredLocalEndpoint"), "the listener must name its bind address")
        #expect(source.contains("NWEndpoint.Host(Self.bindHost)"), "the bind address must be the loopback constant")
        #expect(source.contains("static let bindHost = \"127.0.0.1\""), "the bind host must be the loopback address")
        #expect(!source.contains("0.0.0.0"), "the service must never bind the wildcard address")
        #expect(!source.contains("host: nil"), "the service must never bind every address")

        await service.stop()
    }

    // MARK: - 2. The ping carries no path and no token

    @Test("The ping answers with the version and the capability flags, and with nothing else")
    func pingCarriesTheVersionAndTheCapabilities() async throws {
        let service = await makeService()
        let port = try await waitForPort(service)

        let ping = try await send(port: port, raw: rawRequest(method: "GET", path: "/v1/ping"))
        #expect(ping.status == 200)

        let fields = try decodeObject(ping.body)
        #expect(Array(fields.keys).sorted() == ["capabilities", "version"], "the ping carries the version and the flags, and no other field")
        #expect((fields["version"] as? String)?.isEmpty == false, "the ping reports a version")
        let capabilities = fields["capabilities"] as? [String] ?? []
        #expect(capabilities.contains("pair"), "the ping reports the pairing capability")

        await service.stop()
    }

    @Test("The ping body carries no path, no identifier, and no token")
    func pingBodyCarriesNoPathAndNoToken() async throws {
        let store = StubCompanionTokenStore()
        let service = await makeService(store: store)
        let port = try await waitForPort(service)

        // Pair first, so a token exists that the ping could leak.
        let pairing = try await pair(port: port, code: await service.pairingCode ?? "")
        let token = pairing.token
        #expect(!token.isEmpty, "the pairing hands over a token")

        let ping = try await send(port: port, raw: rawRequest(method: "GET", path: "/v1/ping"))
        #expect(ping.status == 200)

        let body = String(decoding: ping.body, as: UTF8.self)
        #expect(!body.contains(token), "the ping must not carry the device token")
        for secret in secretsThatMustNotLeak() {
            #expect(!body.contains(secret), "the ping must not carry \(secret)")
        }

        await service.stop()
    }

    // MARK: - 3. Every other route refuses an unauthenticated request

    @Test("Every route but the ping refuses an unauthenticated request with 401")
    func everyOtherRouteRefusesAnUnauthenticatedRequest() async throws {
        let service = await makeService()
        let port = try await waitForPort(service)

        for route in CompanionRouteTable.all where route.id != "ping" {
            let response = try await send(
                port: port,
                raw: rawRequest(method: route.method, path: path(for: route))
            )
            #expect(
                response.status == 401,
                "\(route.id) must refuse an anonymous caller with 401, not \(response.status)"
            )

            // The refusal carries no detail: one field, and it names the
            // refusal.
            let fields = try decodeObject(response.body)
            #expect(Array(fields.keys) == ["error"], "\(route.id) must answer with one field")
            #expect(fields["error"] as? String == "unauthorized")
            for secret in secretsThatMustNotLeak() {
                #expect(!response.bodyString.contains(secret), "\(route.id) must not leak \(secret)")
            }
        }

        await service.stop()
    }

    @Test("A path the service does not have refuses an unauthenticated request with 401 too")
    func unknownPathRefusesAnUnauthenticatedRequest() async throws {
        let service = await makeService()
        let port = try await waitForPort(service)

        let response = try await send(port: port, raw: rawRequest(method: "GET", path: "/v1/not-a-route"))
        #expect(response.status == 401, "an anonymous caller must not learn which paths exist")

        await service.stop()
    }

    @Test("A pairing request with the wrong code is refused with 401")
    func pairingWithTheWrongCodeIsRefused() async throws {
        let service = await makeService()
        let port = try await waitForPort(service)

        let response = try await send(
            port: port,
            raw: rawRequest(method: "POST", path: "/v1/pair", body: #"{"code":"not-the-code"}"#)
        )
        #expect(response.status == 401)
        let fields = try decodeObject(response.body)
        #expect(Array(fields.keys) == ["error"])

        await service.stop()
    }

    // MARK: - The two routes

    @Test("The pairing code exchanges for a device token, and the code is good once")
    func pairingCodeExchangesForADeviceToken() async throws {
        let store = StubCompanionTokenStore()
        let service = await makeService(store: store)
        let port = try await waitForPort(service)

        let code = try #require(await service.pairingCode)
        let pairing = try await pair(port: port, code: code)
        #expect(!pairing.token.isEmpty, "the pairing hands over a token")
        #expect(await store.loadToken() == pairing.token, "the token is stored where the service reads it")

        // The code is spent: the same code does not pair a second time.
        let replay = try await send(
            port: port,
            raw: rawRequest(method: "POST", path: "/v1/pair", body: #"{"code":"\#(code)"}"#)
        )
        #expect(replay.status == 401, "a pairing code is good once")

        await service.stop()
    }

    @Test("A request that carries the device token passes the credential check")
    func aRequestWithTheDeviceTokenPassesTheCredentialCheck() async throws {
        let store = StubCompanionTokenStore()
        let service = await makeService(store: store)
        let port = try await waitForPort(service)

        let pairing = try await pair(port: port, code: await service.pairingCode ?? "")
        let response = try await send(
            port: port,
            raw: rawRequest(
                method: "GET",
                path: "/v1/library",
                headers: ["Authorization": "Bearer \(pairing.token)"]
            )
        )
        #expect(response.status != 401, "the device token opens the protected routes")

        await service.stop()
    }

    @Test("A revoked device token stops working")
    func aRevokedDeviceTokenStopsWorking() async throws {
        let store = StubCompanionTokenStore()
        let service = await makeService(store: store)
        let port = try await waitForPort(service)

        let pairing = try await pair(port: port, code: await service.pairingCode ?? "")
        await service.revokeDeviceToken()

        let response = try await send(
            port: port,
            raw: rawRequest(
                method: "GET",
                path: "/v1/library",
                headers: ["Authorization": "Bearer \(pairing.token)"]
            )
        )
        #expect(response.status == 401, "a revoked token must not open anything")
        #expect(await store.loadToken() == nil, "the revoked token leaves the store")

        await service.stop()
    }

    // MARK: - 4. The token lives in the Keychain

    @Test("The device token is stored in the Keychain, and in neither the preferences nor a file")
    func theDeviceTokenLivesInTheKeychain() throws {
        let store = try codeOnly(try SourceLocator.readSource(named: "CompanionTokenStore.swift"))
        #expect(store.contains("KeychainOps.save"), "the token is written through the Keychain")
        #expect(store.contains("KeychainOps.load"), "the token is read through the Keychain")
        #expect(store.contains("KeychainOps.delete"), "the token is revoked through the Keychain")
        #expect(!store.contains("UserDefaults"), "the token must not go into the preferences")
        #expect(!store.contains("FileManager"), "the token must not go into a file")
        #expect(!store.contains("write(to:"), "the token must not go into a file")

        // The companion token has its own Keychain home, so a provider
        // key is never mistaken for a device token.
        #expect(store.contains("com.wenshu.app.companion"), "the companion token has its own Keychain service")
        #expect(!store.contains("com.wenshu.app.provider"), "the companion token does not live with the provider keys")
    }

    @Test("The service never writes the device token to the preferences")
    func theServiceNeverWritesTheTokenToThePreferences() async throws {
        let store = StubCompanionTokenStore()
        let service = await makeService(store: store)
        let port = try await waitForPort(service)

        let pairing = try await pair(port: port, code: await service.pairingCode ?? "")

        // The token is in the preferences of no domain.
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            let rendered = String(describing: value)
            #expect(!rendered.contains(pairing.token), "the token must not reach the preferences (\(key))")
        }

        await service.stop()
    }

    @Test("The service writes no file for the device token")
    func theServiceWritesNoFileForTheToken() throws {
        let service = try codeOnly(try SourceLocator.readSource(named: "CompanionService.swift"))
        #expect(!service.contains("UserDefaults"), "the service must not keep the token in the preferences")
        #expect(!service.contains("FileManager"), "the service must not keep the token in a file")
    }
}

// MARK: - The source, without its comments

/// A source file with its comments removed.
///
/// The comments of these files name the things the code must not do
/// (= "never written to UserDefaults"), so an assertion over the whole
/// text would read the rule as the crime. The assertion belongs to the
/// code.
private func codeOnly(_ source: String) -> String {
    var kept: [String] = []
    var insideBlockComment = false
    for line in source.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if insideBlockComment {
            if trimmed.contains("*/") { insideBlockComment = false }
            continue
        }
        if trimmed.hasPrefix("/*") {
            if !trimmed.contains("*/") { insideBlockComment = true }
            continue
        }
        if trimmed.hasPrefix("//") { continue }
        kept.append(line)
    }
    return kept.joined(separator: "\n")
}

// MARK: - Fixtures

/// A token store that keeps the token in memory, so a test never writes
/// to the developer's Keychain.
private final class StubCompanionTokenStore: CompanionTokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    func loadToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    func save(token: String) throws {
        lock.lock()
        defer { lock.unlock() }
        self.token = token
    }

    func revokeToken() throws {
        lock.lock()
        defer { lock.unlock() }
        token = nil
    }
}

// MARK: - The service under test

/// A service with a stub store and a known version, listening.
@MainActor
private func makeService(store: any CompanionTokenStoring = StubCompanionTokenStore()) async -> CompanionService {
    let service = CompanionService(tokenStore: store, version: "9.9.9")
    service.start()
    return service
}

/// The port the service holds, once it is ready.
@MainActor
private func waitForPort(_ service: CompanionService) async throws -> UInt16 {
    for _ in 0..<200 {
        if let port = service.boundPort { return port }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    throw CompanionTestError.listenerNeverBecameReady
}

/// The errors this suite raises.
private enum CompanionTestError: Error {
    case listenerNeverBecameReady
    case connectionFailed
    case malformedResponse
}

// MARK: - The wire

/// A parsed HTTP response.
private struct ParsedHTTPResponse {
    let status: Int
    let body: Data

    var bodyString: String { String(decoding: body, as: UTF8.self) }
}

/// A raw HTTP request.
private func rawRequest(
    method: String,
    path: String,
    headers: [String: String] = [:],
    body: String = ""
) -> String {
    var lines = ["\(method) \(path) HTTP/1.1", "Host: 127.0.0.1"]
    for (name, value) in headers {
        lines.append("\(name): \(value)")
    }
    if !body.isEmpty {
        lines.append("Content-Type: application/json")
        lines.append("Content-Length: \(body.utf8.count)")
    }
    lines.append("Connection: close")
    return lines.joined(separator: "\r\n") + "\r\n\r\n" + body
}

/// The request path of a route, with its placeholder filled in.
private func path(for route: CompanionRouteSpec) -> String {
    route.pathTemplate.replacingOccurrences(of: "{id}", with: "an-id")
}

/// Send a request to the service and read the response.
///
/// The service is on the loopback interface, so it always answers.
private func send(port: UInt16, raw: String) async throws -> ParsedHTTPResponse {
    let collector = RawHTTPCollector()
    let connection = NWConnection(
        host: NWEndpoint.Host("127.0.0.1"),
        port: NWEndpoint.Port(rawValue: port)!,
        using: .tcp
    )
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        collector.setContinuation(continuation)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: Data(raw.utf8), completion: .contentProcessed { error in
                    if let error {
                        collector.finish(error: error)
                        return
                    }
                    readResponse(from: connection, into: collector)
                })
            case .failed(let error):
                collector.finish(error: error)
            default:
                break
            }
        }
        connection.start(queue: DispatchQueue(label: "companion.test.client"))
    }
    guard let response = collector.response else {
        throw CompanionTestError.malformedResponse
    }
    return response
}

/// Read the response bytes and parse them once they are complete.
private func readResponse(from connection: NWConnection, into collector: RawHTTPCollector) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
        if let data {
            collector.append(data)
        }
        if collector.response != nil {
            collector.finish(error: nil)
            return
        }
        if isComplete || error != nil {
            collector.finish(error: error)
            return
        }
        readResponse(from: connection, into: collector)
    }
}

/// Collects the response bytes and hands back the parsed response.
private final class RawHTTPCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var continuation: CheckedContinuation<Void, Error>?

    func setContinuation(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func append(_ data: Data) {
        lock.lock()
        buffer.append(data)
        lock.unlock()
    }

    func finish(error: Error?) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }

    /// The parsed response, once the bytes carry one.
    var response: ParsedHTTPResponse? {
        lock.lock()
        defer { lock.unlock() }
        guard let terminator = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = String(decoding: buffer[..<terminator.lowerBound], as: UTF8.self)
        let lines = head.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else { return nil }
        let fields = statusLine.split(separator: " ")
        guard fields.count >= 2, let status = Int(fields[1]) else { return nil }

        var contentLength = 0
        for line in lines.dropFirst() {
            let lowercased = line.lowercased()
            guard lowercased.hasPrefix("content-length:") else { continue }
            contentLength = Int(lowercased.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) ?? 0
        }

        let bodyStart = buffer.distance(from: buffer.startIndex, to: terminator.upperBound)
        guard buffer.count - bodyStart >= contentLength else { return nil }
        let body = Data(buffer[(bodyStart)..<(bodyStart + contentLength)])
        return ParsedHTTPResponse(status: status, body: body)
    }
}

// MARK: - The addresses of this machine

/// Every IPv4 address of this machine that is not the loopback address.
private func nonLoopbackIPv4Addresses() -> [String] {
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else { return [] }
    defer { freeifaddrs(head) }

    var addresses: [String] = []
    var pointer: UnsafeMutablePointer<ifaddrs>? = first
    while let current = pointer {
        let flags = Int(current.pointee.ifa_flags)
        let isUp = (flags & Int(IFF_UP)) != 0
        let isLoopback = (flags & Int(IFF_LOOPBACK)) != 0
        let family = current.pointee.ifa_addr.pointee.sa_family
        if isUp && !isLoopback && family == UInt8(AF_INET) {
            var name = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length = socklen_t(current.pointee.ifa_addr.pointee.sa_len)
            if getnameinfo(
                current.pointee.ifa_addr,
                length,
                &name,
                socklen_t(name.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                addresses.append(String(cString: name))
            }
        }
        pointer = current.pointee.ifa_next
    }
    return addresses
}

/// Whether the port is already taken on the address.
///
/// A socket bound to the wildcard holds the port on every address of
/// the machine. A socket bound to the loopback address holds it on the
/// loopback address alone. So a local bind on the address tells the
/// two apart without opening a connection, which a tunnel on the
/// machine could answer in the service's place.
private func portIsTaken(on address: String, port: UInt16) -> Bool {
    let descriptor = socket(AF_INET, SOCK_STREAM, 0)
    guard descriptor >= 0 else { return false }
    defer { close(descriptor) }

    var socketAddress = sockaddr_in()
    socketAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    socketAddress.sin_family = sa_family_t(AF_INET)
    socketAddress.sin_port = port.bigEndian
    socketAddress.sin_addr.s_addr = inet_addr(address)

    let result = withUnsafePointer(to: &socketAddress) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
            bind(descriptor, rebound, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    return result != 0
}

// MARK: - The secrets

/// The strings that must never reach a response body.
private func secretsThatMustNotLeak() -> [String] {
    var secrets: [String] = []
    if let libraryPath = ActiveLibrary.path {
        secrets.append(libraryPath)
    }
    let home = NSHomeDirectory()
    if home != "/" {
        secrets.append(home)
    }
    return secrets.filter { !$0.isEmpty }
}

// MARK: - The bodies

/// The pairing result.
private struct PairingResult {
    let token: String
}

/// Pair with the code and read the token.
private func pair(port: UInt16, code: String) async throws -> PairingResult {
    let body = #"{"code":"\#(code)"}"#
    let response = try await send(
        port: port,
        raw: rawRequest(method: "POST", path: "/v1/pair", body: body)
    )
    guard response.status == 200 else {
        throw CompanionTestError.malformedResponse
    }
    let fields = try decodeObject(response.body)
    guard let token = fields["token"] as? String, !token.isEmpty else {
        throw CompanionTestError.malformedResponse
    }
    return PairingResult(token: token)
}

/// Decode a JSON object into its fields.
private func decodeObject(_ data: Data) throws -> [String: Any] {
    guard
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        throw CompanionTestError.malformedResponse
    }
    return object
}
