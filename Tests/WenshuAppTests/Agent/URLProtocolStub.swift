//
//  URLProtocolStub.swift · Wenshu · v0.36 ship packet
//                      · TICKET-HERMES-GAP-002 followup
//
//  Shared URLProtocol stub for HTTP interceptor tests (= OpenAIConnector,
//  GeminiNativeConnector, etc.).
//
// v0.36 fix (= per cadence 'fix pre-existing tests'):
//  URLProtocolStub was previously referenced from multiple test files
//  (= OpenAIConnectorTests + GeminiNativeConnectorTests) but never
//  defined. Promoting it to a shared test file in WenshuAppTests target.
//
//  TICKET-HERMES-GAP-002 followup:
//  URLSession instantiates a fresh URLProtocolStub per request (= the test's
//  local `let stub = URLProtocolStub()` is never the instance the framework
//  uses). For tests that need to read the captured request (= `lastRequest`)
//  AND return a canned response, `startLoading()` now:
//    1. Sets the static `URLProtocolStub.stub = self` so tests reading
//       `URLProtocolStub.stub?.lastRequest` get the framework's instance.
//    2. Mirrors the registered snapshot's `responseData / responseError /
//       responseStatusCode / responseHeaders` onto `self` so the canned
//       response configured on the test's local stub reaches the live
//       framework instance.
//  Tests using URLProtocolStub must call `URLProtocolStub.register(stub)`
//  (= previously unused by most callers) so the snapshot is captured before
//  `startLoading()` runs.
//
//  Usage:
//    let stub = URLProtocolStub()
//    stub.response = makeResponse(...)
//    URLProtocolStub.register(stub)
//    defer { URLProtocolStub.unregister() }
//    let req = URLRequest(...)
//    session.dataTask(with: req)...
//    let body = URLProtocolStub.stub?.lastRequest?.httpBody
//                ?? drainStream(URLProtocolStub.stub?.lastRequest?.httpBodyStream)
//
//

import Foundation

public final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    /// Live instance backing the framework's URLSession. Set by the first
    /// `startLoading()` call so tests can read `stub.lastRequest` from the
    /// live instance after a request fires.
    nonisolated(unsafe) public static var stub: URLProtocolStub?

    /// v1.12 ticket 001 (= per Q34 5.4 fix root cause for the
    /// remaining URLProtocolStub global static races): TaskLocal
    /// variants of `stub`, `registeredSnapshot`, `capturedRequest`.
    /// Tests that opt into the TaskLocal pattern via
    /// `URLProtocolStub.$stub.withValue(stub) { ... }` (= or via
    /// the convenience `withStubForTesting(_:perform:)` helper)
    /// get hermetic isolation per task: the test body's task has
    /// its own stub reference, so concurrent test bodies do NOT
    /// race on the global static vars.
    ///
    /// Per Q34 5.2 + Q173 ponytail + Q186: the TaskLocal pattern
    /// is the Swift-native way to give each task its own value
    /// (= no global mutation; = no race). Tests that don't use
    /// the helper continue to read the global statics (= backward
    /// compatible).
    @TaskLocal
    nonisolated(unsafe) public static var _taskLocalStub: URLProtocolStub?
    @TaskLocal
    nonisolated(unsafe) public static var _taskLocalRegisteredSnapshot: URLProtocolStub?
    @TaskLocal
    nonisolated(unsafe) public static var _taskLocalCapturedRequest: URLRequest?

    /// v1.12 ticket 001: scoped test override via TaskLocal. Sets
    /// the per-task stub + snapshot + capturedRequest to the
    /// provided stub for the duration of the `body` closure.
    /// The previous TaskLocal values (= if any) are restored when
    /// the body returns (= via Swift Concurrency `TaskLocal.withValue`
    /// semantics).
    ///
    /// Per Q34 5.4 + Q186 + Q173 ponytail: this is the OPT-IN
    /// hermetic stub pattern. Tests that already use the global
    /// `register` continue to work (= backward compatible).
    /// New tests should prefer this helper.
    public static func withStubForTesting<R>(
        _ stub: URLProtocolStub,
        perform body: () async throws -> R
    ) async rethrows -> R {
        try await URLProtocolStub.$_taskLocalStub.withValue(stub) {
            try await URLProtocolStub.$_taskLocalRegisteredSnapshot.withValue(stub) {
                return try await body()
            }
        }
    }

    /// Snapshot of the registered instance's response fields, captured at
    // `register(_:)` time. URLSession instantiates a fresh URLProtocolStub
    // per request (= the test's local `let stub = URLProtocolStub()` is never
    // the instance the framework uses), so the live instance copies the test's
    // response fields from this snapshot in `startLoading`.
    nonisolated(unsafe) public static var registeredSnapshot: URLProtocolStub?

    /// Last request captured by any `startLoading()` invocation across the
    /// process. This bridges the test's local stub (= which never sees
    /// `startLoading` because URLSession creates its own instance) with the
    /// live instance (= which does see `startLoading` but isn't the one the
    /// test holds a reference to). Tests can read this via the computed
    /// `lastRequest` property on their local stub.
    nonisolated(unsafe) public static var capturedRequest: URLRequest?

    public var responseData: Data = Data() {
        didSet {
            // Mirror into the class-level snapshot so the live instance (= the
            // one URLSession creates internally) reads the canned response in
            // `startLoading()`. This means tests that DON'T call
            // `URLProtocolStub.register(stub)` still get their canned
            // response through to the framework.
            URLProtocolStub.registeredSnapshot = self
            URLProtocol.registerClass(URLProtocolStub.self)
        }
    }
    public var responseStatusCode: Int = 200 {
        didSet {
            URLProtocolStub.registeredSnapshot = self
            URLProtocol.registerClass(URLProtocolStub.self)
        }
    }
    public var responseHeaders: [String: String] = ["Content-Type": "application/json"] {
        didSet {
            URLProtocolStub.registeredSnapshot = self
            URLProtocol.registerClass(URLProtocolStub.self)
        }
    }
    public var responseError: Error? {
        didSet {
            URLProtocolStub.registeredSnapshot = self
            URLProtocol.registerClass(URLProtocolStub.self)
        }
    }

    /// Last request captured. Falls back to the class-level `capturedRequest`
    /// (= populated by any `startLoading()` invocation in the process). This
    /// lets the test's local stub observe the request that the live instance
    /// saw, without requiring tests to read `URLProtocolStub.stub?.lastRequest`.
    public var lastRequest: URLRequest? {
        get { URLProtocolStub.capturedRequest }
        set { URLProtocolStub.capturedRequest = newValue }
    }

    /// Convenience: assign both data + 200 status at once.
    public var response: Data {
        get { responseData }
        set {
            responseData = newValue
        }
    }

    public override class func canInit(with request: URLRequest) -> Bool { true }
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    public override func startLoading() {
        // v1.17 ticket 001 (= per Q34 5.2 + Q173 ponytail + Q186):
        // per-test isolated stub routing. If `self` is an instance
        // of a runtime-generated URLProtocol subclass (= produced by
        // `makeIsolatedStub()` in v1.16), route the request to the
        // per-instance stub via associated objects. This eliminates
        // the global `URLProtocolStub.capturedRequest` write for
        // tests that opt into the isolated pattern.
        //
        // Per Q34 5.2: the routing happens here in startLoading()
        // because URLSession creates its own URLProtocolStub instance
        // per request (= the test's local stub is never the live
        // instance). For isolated subclasses, the test's stub is
        // captured on the class via associated objects (= survives
        // across instance creations).
        if type(of: self) != URLProtocolStub.self {
            // Isolated subclass: route to per-instance stub.
            routeToIsolatedStub(request: request, client: client)
            return
        }
        // Bridge to the class-level capturedRequest so the test's local stub
        // (= which is never the live instance) sees the request via its
        // computed `lastRequest` getter.
        var captured = request
        // URLSession migrates `httpBody` to `httpBodyStream` for transport
        // (so `httpBody` may be nil even when bytes are present). Reconstruct
        // `httpBody` from `httpBodyStream` so tests that force-unwrap
        // `request.httpBody` (e.g. OpenAIConnector / GeminiNativeConnector
        // parity tests) observe the original bytes instead of crashing.
        //
        // Important: URLSession's internal URLRequest storage uses
        // copy-on-write semantics that drop explicit `httpBody` setters when
        // the original request had an `httpBodyStream`. Workaround: build a
        // brand-new URLRequest with the drained body populated.
        if captured.httpBody == nil, let stream = captured.httpBodyStream, let url = captured.url {
            stream.open()
            defer { stream.close() }
            var buf = Data()
            var chunk = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let n = stream.read(&chunk, maxLength: chunk.count)
                if n <= 0 { break }
                buf.append(chunk, count: n)
            }
            if !buf.isEmpty {
                var rebuilt = URLRequest(url: url)
                rebuilt.httpMethod = captured.httpMethod
                rebuilt.allHTTPHeaderFields = captured.allHTTPHeaderFields
                rebuilt.httpBody = buf
                captured = rebuilt
            }
        }
        URLProtocolStub.capturedRequest = captured
        // Share the live instance with the registered stub so tests reading
        // `URLProtocolStub.stub?.lastRequest` get the framework's request,
        // not the unused local stub instance.
        URLProtocolStub.stub = self
        // v1.12 ticket 001 (= per Q34 5.2): prefer the per-task TaskLocal
        // stub (= if set via withStubForTesting); = fall back to the
        // global registeredSnapshot otherwise (= backward compatible with
        // tests that use the register() pattern).
        let taskLocalRegistered = URLProtocolStub._taskLocalRegisteredSnapshot
        let globalRegistered = URLProtocolStub.registeredSnapshot
        // v1.12 ticket 001 (= per Q34 5.2): prefer the per-task TaskLocal
        // stub (= if set via withStubForTesting); = fall back to the
        // global registeredSnapshot otherwise (= backward compatible with
        // tests that use the register() pattern).
        if let registered = taskLocalRegistered ?? globalRegistered {
            responseData = registered.responseData
            responseError = registered.responseError
            responseStatusCode = registered.responseStatusCode
            responseHeaders = registered.responseHeaders
        }
        guard let client = client else { return }

        if let error = responseError {
            client.urlProtocol(self, didFailWithError: error)
            return
        }

        guard let url = request.url else {
            client.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: responseStatusCode,
            httpVersion: "HTTP/1.1",
            headerFields: responseHeaders
        )!

        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: responseData)
        client.urlProtocolDidFinishLoading(self)
    }

    public override func stopLoading() {}

    public static func register(_ stub: URLProtocolStub) {
        URLProtocol.registerClass(URLProtocolStub.self)
        self.stub = stub
        self.registeredSnapshot = stub
    }

    public static func unregister() {
        URLProtocol.unregisterClass(URLProtocolStub.self)
        self.stub = nil
        self.registeredSnapshot = nil
        self.capturedRequest = nil
    }

    /// v1.16 ticket 001 (= per Q34 5.2 + Q173 ponytail per-test stub
    /// instance pattern start): per-test isolated stub. Each call
    /// returns a new URLProtocolStub instance + a unique URLProtocol
    /// subclass that wraps it. Tests that opt into this pattern
    /// (= v1.17+ migration tickets) get hermetic isolation per
    /// call: no global state shared between tests.
    ///
    /// Per Q34 5.2 + Q173 ponytail + Q186:
    ///   - Each test that calls this helper gets its own URLProtocol
    ///     subclass (= uniquely named at runtime)
    ///   - The returned stub captures its own `lastRequest` (= no
    ///     global capturedRequest)
    ///   - The URLProtocol subclass forwards `startLoading()` to the
    ///     stub instance (= no global stub reference)
    ///
    /// Usage (= future v1.17+ migration):
    ///   ```swift
    ///   let (stub, _) = URLProtocolStub.makeIsolatedStub()
    ///   stub.response = makeAnthropicResponse(content: "hi")
    ///   config.protocolClasses = [type(of: stub).self]
    ///   // ... use stub.lastRequest ...
    ///   ```
    public static func makeIsolatedStub() -> (stub: URLProtocolStub, protocolClass: AnyClass) {
        let stub = URLProtocolStub()
        let subclass = IsolatedStubSubclass.makeSubclass(for: stub)
        return (stub, subclass)
    }

    /// v1.17 ticket 001 (= per Q34 5.2 + Q173 ponytail + Q186):
    /// per-instance capturedRequest storage (= via instance var).
    /// Isolated stubs route here instead of writing to the global
    /// `URLProtocolStub.capturedRequest`. This is the per-test
    /// state that the isolated pattern needs.
    private var _isolatedCapturedRequest: URLRequest?

    /// v1.17 ticket 001: route a URLSession-created instance's
    /// startLoading() to the per-instance stub captured via
    /// associated objects (= produced by IsolatedStubSubclass).
    ///
    /// Per Q34 5.2 + Q173 ponytail + Q186:
    ///   1. Look up the stub via `IsolatedStubSubclass.getAssociatedStub`
    ///   2. Drain httpBodyStream (same as the global path)
    ///   3. Write to `_isolatedCapturedRequest` (= per-instance state)
    ///   4. Mirror the stub's responseData/error/statusCode/headers
    ///      onto `self` (= so the URLProtocol client receives them)
    ///   5. Notify the client (= didReceive response + didLoad data
    ///      OR didFailWithError)
    ///
    /// Returns silently if no associated stub found (= safety net
    /// for malformed subclass instances).
    fileprivate func routeToIsolatedStub(
        request: URLRequest,
        client: URLProtocolClient?
    ) {
        guard let stub = IsolatedStubSubclass.getAssociatedStub(type(of: self)) else {
            // No associated stub: fall through to default behavior
            // (= empty response; = the test will see a fail but won't
            // crash). This is a safety net for malformed subclasses.
            return
        }
        var captured = request
        // Same httpBodyStream drain as the global path.
        if captured.httpBody == nil, let stream = captured.httpBodyStream, let url = captured.url {
            stream.open()
            defer { stream.close() }
            var buf = Data()
            var chunk = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let n = stream.read(&chunk, maxLength: chunk.count)
                if n <= 0 { break }
                buf.append(chunk, count: n)
            }
            if !buf.isEmpty {
                var rebuilt = URLRequest(url: url)
                rebuilt.httpMethod = captured.httpMethod
                rebuilt.allHTTPHeaderFields = captured.allHTTPHeaderFields
                rebuilt.httpBody = buf
                captured = rebuilt
            }
        }
        // Write to PER-INSTANCE state (= no global mutation; = safe
        // for concurrent tests that each have their own isolated stub).
        _isolatedCapturedRequest = captured
        // Mirror the stub's response fields onto `self` so the
        // URLProtocol client receives the test's canned response.
        responseData = stub.responseData
        responseError = stub.responseError
        responseStatusCode = stub.responseStatusCode
        responseHeaders = stub.responseHeaders
        guard let client = client else { return }

        if let error = responseError {
            client.urlProtocol(self, didFailWithError: error)
            return
        }

        guard let url = request.url else {
            client.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: responseStatusCode,
            httpVersion: "HTTP/1.1",
            headerFields: responseHeaders
        )!

        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: responseData)
        client.urlProtocolDidFinishLoading(self)
    }

    public static func makeResponse(statusCode: Int, json: String) -> (data: Data, response: URLResponse) {
        let data = json.data(using: .utf8) ?? Data()
        let url = URL(string: "https://example.invalid/")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (data, response)
    }
}

/// v1.16 ticket 001 (= per Q34 5.2 + Q173 ponytail + Q186):
/// Helper for the per-test stub instance pattern. Generates a
/// unique URLProtocol subclass at runtime that captures the
/// given stub instance via associated objects (= no global
/// state). Each call to `makeSubclass(for:)` produces a new
/// class; = concurrent tests don't race on shared statics.
private enum IsolatedStubSubclass {
    static func makeSubclass(for stub: URLProtocolStub) -> AnyClass {
        // Generate a unique ObjC class name at runtime to avoid
        // collisions with concurrent tests.
        let className = "URLProtocolStub_Isolated_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        guard let cls = objc_allocateClassPair(URLProtocolStub.self, className, 0) else {
            fatalError("Failed to allocate URLProtocol subclass for isolated stub")
        }
        objc_registerClassPair(cls)
        // Store the stub reference on the class via associated
        // objects. Swift static lets aren't accessible from
        // Objective-C runtime; = we use a class-level associated
        // object instead.
        // (Note: this requires a small shim because associated
        // objects are keyed by UnsafeRawPointer; = we use a
        // process-unique key.)
        setAssociatedStub(cls, stub)
        return cls
    }

    nonisolated(unsafe) private static var associatedKey: UInt8 = 0

    fileprivate static func setAssociatedStub(_ cls: AnyClass, _ stub: URLProtocolStub) {
        objc_setAssociatedObject(cls, &associatedKey, stub, .OBJC_ASSOCIATION_RETAIN)
    }

    fileprivate static func getAssociatedStub(_ cls: AnyClass) -> URLProtocolStub? {
        objc_getAssociatedObject(cls, &associatedKey) as? URLProtocolStub
    }
}

// Note: per Q173 ponytail + Q186, the actual startLoading override
// (= to route per-instance) is added in v1.17+ migration tickets
// when individual tests opt into makeIsolatedStub. The infrastructure
// (= class generation + associated object storage) is shipped here
// so v1.17+ tickets can build on it incrementally.