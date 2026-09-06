//
//  URLProtocolStub.swift · Wenshu · v0.36 ship packet
//                      · TICKET-HERMES-GAP-002 followup
//
//  Shared URLProtocol stub for HTTP interceptor tests (= OpenAIConnector,
//  GeminiNativeConnector, etc.).
//
//  v0.36 fix (= per 老板 cadence 'fix pre-existing tests'):
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
        // Mirror the registered stub's responseData / responseError /
        // responseStatusCode / responseHeaders onto this live instance so the
        // framework's URLSession receives the test's intended canned response
        // instead of the empty default.
        if let registered = URLProtocolStub.registeredSnapshot {
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