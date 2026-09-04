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
    nonisolated(unsafe) public static var stub: URLProtocolStub?
    /// Snapshot of the registered instance's response fields, captured at
    // `register(_:)` time. URLSession instantiates a fresh URLProtocolStub
    // per request (= the test's local `let stub = URLProtocolStub()` is never
    // the instance the framework uses), so the live instance copies the test's
    // response fields from this snapshot in `startLoading`.
    nonisolated(unsafe) public static var registeredSnapshot: URLProtocolStub?
    public var responseData: Data = Data()
    public var responseStatusCode: Int = 200
    public var responseHeaders: [String: String] = ["Content-Type": "application/json"]
    public var responseError: Error?
    public var lastRequest: URLRequest?

    /// Convenience: assign both data + 200 status at once.
    public var response: Data {
        get { responseData }
        set { responseData = newValue }
    }

    public override class func canInit(with request: URLRequest) -> Bool { true }
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    public override func startLoading() {
        lastRequest = request
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