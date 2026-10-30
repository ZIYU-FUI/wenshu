import Foundation
import Network
import Observation
import os

private let companionLogger = Logger(subsystem: "com.wenshu", category: "companion")

// CompanionService.swift
//
// The Mac companion: the local service the phone talks to.
//
// The service binds one listener to the loopback interface, answers the
// two routes the phone needs to start, and refuses every other route
// without a valid credential. It runs inside the app process, so the
// port never outlives the app: the listener is cancelled when the app
// quits.
//
// Four rules shape the whole file:
//
//   1. The listener binds to 127.0.0.1 and to nothing else. The
//      `requiredLocalEndpoint` of the parameters is the bind address,
//      so the kernel never puts this socket on a LAN interface.
//   2. A request that carries no valid credential gets 401 and a body
//      with no detail in it. That holds for a path the service does not
//      have too, so the route table is not an inventory a caller can
//      read off the socket.
//   3. The device token lives in the Keychain. The service keeps a copy
//      for the session, because a Keychain read blocks, and it writes
//      every change straight back so the token survives a restart.
//   4. The device token never appears in a response body, a log line, or
//      an error the client can see. The pair route hands it over once,
//      to the phone that presented the pairing code.
//
// The service is one type so the next card adds a route rather than
// reshaping it: a route is a row in the table, a case in the handler
// switch, and a body type next to the others.

/// The Mac companion service.
///
/// The state the service publishes is what a view reads: whether it is
/// running, which port it holds, whether a device is paired, and the
/// pairing code the phone has to present.
@MainActor
@Observable
final class CompanionService {

    // MARK: - Published state

    /// The only address the listener binds.
    ///
    /// The address is a constant rather than a setting: the rule that
    /// the service is reachable from the loopback interface only is not
    /// the user's to change.
    static let bindHost = "127.0.0.1"

    /// The service the app runs.
    ///
    /// The app owns exactly one companion service, so the app delegate
    /// starts and stops this one.
    static let shared = CompanionService()

    /// Whether the listener is bound and accepting.
    private(set) var isRunning = false

    /// The port the listener holds.
    private(set) var boundPort: UInt16?

    /// Whether a device holds a token.
    private(set) var isPaired = false

    /// The pairing code a phone presents to `/v1/pair`.
    ///
    /// The code changes after every successful pairing, so a code that
    /// was read off a screen cannot be used twice.
    private(set) var pairingCode: String?

    // MARK: - Dependencies

    /// Where the device token is persisted.
    private let tokenStore: any CompanionTokenStoring

    /// The version the ping reports.
    private let version: String

    // MARK: - Session state

    /// The token of the paired device, held for the session.
    ///
    /// The Keychain is the persistence; this copy is what the request
    /// path compares against, so a request never blocks on a Keychain
    /// read.
    private var token: String?

    /// Whether the persisted token has been read into the session yet.
    private var tokenLoaded = false

    /// The read of the persisted token that is in flight, if any.
    ///
    /// A request that arrives while the Keychain is being read waits
    /// for that read instead of reading a cache that holds nothing yet.
    private var tokenRead: Task<String?, Never>?

    /// The listener.
    private var listener: NWListener?

    /// The open connections, by connection identity.
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    /// The bytes read so far on each connection.
    private var buffers: [ObjectIdentifier: Data] = [:]

    /// The connection each device holds, by token.
    ///
    /// One connection per device: a second connection that authenticates
    /// with the same token closes the first one, so a token that leaked
    /// cannot hold two doors open at once.
    private var deviceConnections: [String: ObjectIdentifier] = [:]

    /// The queue the listener and the connections run on.
    private let networkQueue = DispatchQueue(label: "com.wenshu.companion.network")

    /// The queue the blocking Keychain calls run on.
    private let keychainQueue = DispatchQueue(label: "com.wenshu.companion.keychain")

    // MARK: - Init

    /// The service.
    ///
    /// The token store and the version are injected so a test can prove
    /// the request path without the user's Keychain.
    init(
        tokenStore: any CompanionTokenStoring = KeychainCompanionTokenStore(),
        version: String = CompanionService.bundleVersion
    ) {
        self.tokenStore = tokenStore
        self.version = version
        self.pairingCode = CompanionTokenFactory.makePairingCode()
    }

    /// The app version the ping reports.
    static var bundleVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return short ?? "0.0.0"
    }

    // MARK: - Lifecycle

    /// Bind the listener and start answering.
    ///
    /// A failure to bind is logged and leaves the service stopped: the
    /// app keeps working, and the phone sees a closed port rather than
    /// a service that answers on an address it should not.
    func start() {
        guard listener == nil else { return }

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(Self.bindHost), port: 0)
        parameters.allowLocalEndpointReuse = true

        do {
            let listener = try NWListener(using: parameters)
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in self?.handleListenerState(state) }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            self.listener = listener
            listener.start(queue: networkQueue)
        } catch {
            companionLogger.error("the companion listener could not bind")
            self.listener = nil
        }
    }

    /// Unbind the listener and drop the open connections.
    ///
    /// The app calls this when it quits, so the port does not outlive
    /// the process.
    func stop() {
        listener?.cancel()
        listener = nil
        for connection in connections.values {
            connection.cancel()
        }
        connections.removeAll()
        buffers.removeAll()
        deviceConnections.removeAll()
        boundPort = nil
        isRunning = false
    }

    /// The state the listener reports when it is ready.
    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            boundPort = listener?.port?.rawValue
            isRunning = true
            companionLogger.info("the companion listener is ready")
        case .failed:
            isRunning = false
            boundPort = nil
            companionLogger.error("the companion listener failed")
        case .cancelled:
            isRunning = false
            boundPort = nil
        default:
            break
        }
    }

    // MARK: - Pairing

    /// Issue a new pairing code and return it.
    ///
    /// The old code stops working, so a code that was read off a screen
    /// is good for one pairing only.
    @discardableResult
    func rotatePairingCode() -> String {
        let code = CompanionTokenFactory.makePairingCode()
        pairingCode = code
        return code
    }

    /// Revoke the device token.
    ///
    /// The token leaves the Keychain and the session, so every route
    /// that needs one refuses the phone from here on.
    func revokeDeviceToken() async {
        let store = tokenStore
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            keychainQueue.async {
                try? store.revokeToken()
                continuation.resume()
            }
        }
        token = nil
        tokenLoaded = true
        isPaired = false
    }

    // MARK: - Connections

    /// Take a connection and read from it.
    private func accept(_ connection: NWConnection) {
        let identity = ObjectIdentifier(connection)
        connections[identity] = connection
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                Task { @MainActor in self?.close(connection) }
            }
        }
        connection.start(queue: networkQueue)
        read(connection)
    }

    /// Read one chunk from a connection.
    private func read(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] chunk, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                if error != nil {
                    self.close(connection)
                    return
                }
                await self.consume(chunk: chunk, isComplete: isComplete, on: connection)
            }
        }
    }

    /// Drop a connection and everything it owned.
    private func close(_ connection: NWConnection) {
        let identity = ObjectIdentifier(connection)
        connections.removeValue(forKey: identity)
        buffers.removeValue(forKey: identity)
        for (held, holder) in deviceConnections where holder == identity {
            deviceConnections.removeValue(forKey: held)
        }
        connection.cancel()
    }

    // MARK: - Request handling

    /// Fold a chunk into the connection's request and answer what is
    /// complete.
    private func consume(chunk: Data?, isComplete: Bool, on connection: NWConnection) async {
        let identity = ObjectIdentifier(connection)
        var buffer = buffers[identity] ?? Data()
        if let chunk {
            buffer.append(chunk)
        }

        while true {
            switch CompanionHTTPRequestParser.parse(buffer) {
            case .incomplete:
                buffers[identity] = buffer
                if isComplete {
                    close(connection)
                } else {
                    // The request has not arrived whole. TCP keeps no
                    // message boundaries, so the rest of it comes in a
                    // later segment: the read is armed again, because
                    // the one that brought this segment has delivered
                    // it and no read is pending now.
                    read(connection)
                }
                return
            case .complete(let request, let consumed):
                buffers[identity] = Data(buffer.dropFirst(consumed))
                let keepAlive = wantsKeepAlive(request)
                let response = await answer(request, on: connection)
                send(response, on: connection, keepAlive: keepAlive)
                if !keepAlive {
                    return
                }
                buffer = buffers[identity] ?? Data()
            }
        }
    }

    /// Whether the caller wants the connection kept open.
    private func wantsKeepAlive(_ request: CompanionHTTPRequest) -> Bool {
        guard let connection = request.header("connection") else { return true }
        return connection.lowercased() != "close"
    }

    /// Write a response on a connection.
    private func send(_ response: CompanionHTTPResponse, on connection: NWConnection, keepAlive: Bool) {
        connection.send(content: response.payload(keepAlive: keepAlive), completion: .contentProcessed { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if error != nil {
                    self.close(connection)
                    return
                }
                if !keepAlive {
                    self.close(connection)
                    return
                }
                self.read(connection)
            }
        })
    }

    /// Answer one request.
    ///
    /// The order is the rule: the credential is checked before the route
    /// is served, so a request without one cannot tell a route the
    /// service has from a route it does not.
    private func answer(_ request: CompanionHTTPRequest, on connection: NWConnection) async -> CompanionHTTPResponse {
        guard let route = CompanionRouteTable.spec(matching: request.method, path: request.path) else {
            // A path the service does not have. It still needs the
            // token, so the answer does not say which paths exist.
            guard await isAuthorized(request, on: connection) else { return unauthorized }
            return CompanionHTTPResponse.json(
                status: 404,
                reason: "Not Found",
                payload: CompanionErrorBody(error: "not_found")
            )
        }

        switch route.authorization {
        case .none:
            return answerPing()
        case .pairingCode:
            return await answerPair(request)
        case .deviceToken:
            guard await isAuthorized(request, on: connection) else { return unauthorized }
            return answerAuthorized(route: route)
        }
    }

    /// The ping: the server version and the capability flags.
    ///
    /// The body carries no token, no path, and no library content.
    private func answerPing() -> CompanionHTTPResponse {
        CompanionHTTPResponse.json(
            status: 200,
            reason: "OK",
            payload: CompanionPingBody(
                version: version,
                capabilities: CompanionRouteTable.implementedCapabilities
            )
        )
    }

    /// The pairing route: a pairing code in, a device token out.
    private func answerPair(_ request: CompanionHTTPRequest) async -> CompanionHTTPResponse {
        guard
            let expected = pairingCode,
            let body = try? JSONDecoder().decode(CompanionPairRequestBody.self, from: request.body),
            constantTimeEquals(body.code, expected)
        else {
            return unauthorized
        }

        let newToken = CompanionTokenFactory.makeDeviceToken()
        guard await saveToken(newToken) else {
            return CompanionHTTPResponse.json(
                status: 500,
                reason: "Internal Server Error",
                payload: CompanionErrorBody(error: "storage_unavailable")
            )
        }

        token = newToken
        tokenLoaded = true
        isPaired = true
        rotatePairingCode()
        return CompanionHTTPResponse.json(
            status: 200,
            reason: "OK",
            payload: CompanionPairResponseBody(token: newToken)
        )
    }

    /// A route that needs the device token.
    private func answerAuthorized(route: CompanionRouteSpec?) -> CompanionHTTPResponse {
        switch route?.id {
        case "ping":
            return answerPing()
        default:
            // The route is in the contract, and no card has written its
            // handler yet.
            return CompanionHTTPResponse.json(
                status: 501,
                reason: "Not Implemented",
                payload: CompanionErrorBody(error: "not_implemented")
            )
        }
    }

    /// The refusal: 401 and a body with no detail in it.
    private var unauthorized: CompanionHTTPResponse {
        CompanionHTTPResponse.json(
            status: 401,
            reason: "Unauthorized",
            payload: CompanionErrorBody(error: "unauthorized")
        )
    }

    // MARK: - Credentials

    /// Whether the request carries the device token.
    ///
    /// An authenticated connection becomes the device's connection, and
    /// the device's previous connection is closed: one device holds one
    /// connection.
    private func isAuthorized(_ request: CompanionHTTPRequest, on connection: NWConnection) async -> Bool {
        guard let presented = request.deviceToken, !presented.isEmpty else { return false }
        guard let expected = await currentToken(), !expected.isEmpty else { return false }
        guard constantTimeEquals(presented, expected) else { return false }

        let identity = ObjectIdentifier(connection)
        if let held = deviceConnections[presented], held != identity, let previous = connections[held] {
            close(previous)
        }
        deviceConnections[presented] = identity
        return true
    }

    /// The device token for this session.
    ///
    /// The first call reads the Keychain off the main actor, because the
    /// read blocks. Later calls use the copy the session holds.
    ///
    /// A request that arrives while that read is still running waits for
    /// it: the cache is published together with the value it holds, so
    /// no caller ever reads a cache that is empty.
    private func currentToken() async -> String? {
        if tokenLoaded { return token }
        return await (tokenRead ?? startTokenRead()).value
    }

    /// Start the read of the persisted token, if it is not running.
    ///
    /// The read is one task, so a request that arrives while it runs
    /// waits for that read instead of reading a cache that holds
    /// nothing yet. The cache is published by the task itself, so the
    /// value and the flag that says the cache is filled arrive
    /// together.
    private func startTokenRead() -> Task<String?, Never> {
        let store = tokenStore
        let queue = keychainQueue
        let read = Task { @MainActor [weak self] in
            let stored = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
                queue.async { continuation.resume(returning: store.loadToken()) }
            }
            guard let self else { return stored }
            if !self.tokenLoaded {
                // A pairing or a revoke that landed while the read was
                // running owns the session: this value is older than the
                // one the session holds, so it is not published.
                self.token = stored
                self.tokenLoaded = true
                self.isPaired = stored != nil
                self.tokenRead = nil
            }
            return self.token
        }
        tokenRead = read
        return read
    }

    /// Write the token to the Keychain, off the main actor.
    private func saveToken(_ newToken: String) async -> Bool {
        let store = tokenStore
        return await withCheckedContinuation { continuation in
            keychainQueue.async { continuation.resume(returning: (try? store.save(token: newToken)) != nil) }
        }
    }

    /// Compare two secrets without leaking their length through the
    /// time the comparison takes.
    private func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for index in left.indices {
            difference |= left[index] ^ right[index]
        }
        return difference == 0
    }
}
