//
//  URLProtocolStub.swift · Wenshu · v0.36 ship packet
//
//  Shared URLProtocol stub for HTTP interceptor tests (= OpenAIConnector,
//  GeminiNativeConnector, etc.).
//
//  v0.36 fix (= per 老板 cadence 'fix pre-existing test files'):
//  URLProtocolStub was previously referenced from multiple test files
//  (= OpenAIConnectorTests + GeminiNativeConnectorTests) but never
//  defined. Promoting it to a shared test file in WenshuAppTests target.
//
//  Usage:
//    let stub = URLProtocolStub()
//    stub.response = URLProtocolStub.makeResponse(
//        statusCode: 200,
//        json: #"{"text": "hello"}"#
//    )
//    URLProtocolStub.register(stub)
//    defer { URLProtocolStub.unregister() }
//
//  Then in tests:
//    XCTAssertEqual(stub.lastRequest?.value(forHTTPHeaderField: "Authorization"),
//                   "Bearer test-key")
//

import Foundation

public final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) public static var stub: URLProtocolStub?
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
    }

    public static func unregister() {
        URLProtocol.unregisterClass(URLProtocolStub.self)
        self.stub = nil
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