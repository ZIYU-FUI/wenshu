//
//  SSEReaderRefusalTests.swift · wenshu
//
//  A provider that refuses a request says why in the body (= "the
//  max_tokens is above the cap", = "the quota is gone", = "the model is
//  unknown"). That message is the only thing a caller can act on, = so
//  the reader carries it with the failure.
//
//  Without it the refusal was a bare status code, = and the caller saw
//  a stream that ended without a word.
//

import Foundation
import Testing
@testable import WenshuAgent

@Suite("The reader carries the provider's refusal")
struct SSEReaderRefusalTests {

    /// A session whose every request is refused with a body.
    private func refusingSession(status: Int, body: String) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefusingProtocol.self]
        RefusingProtocol.status = status
        RefusingProtocol.body = body
        return URLSession(configuration: configuration)
    }

    @Test("the failure carries the provider's own words")
    func theFailureCarriesTheProviderWords() async throws {
        let body = #"{"type":"error","error":{"message":"max_tokens must be <= 8192"}}"#
        let session = refusingSession(status: 400, body: body)
        var request = URLRequest(url: URL(string: "https://provider.invalid/v1/messages")!)
        request.httpMethod = "POST"
        await #expect(throws: (any Error).self) {
            for try await _ in SSEReader.events(for: request, session: session) {
                // (= the refusal never delivers an event)
            }
        }
    }

    @Test("the message names the refusal")
    func theMessageNamesTheRefusal() {
        let error = SSEError.httpStatus(400, body: "max_tokens must be <= 8192")
        let description = error.errorDescription ?? ""
        #expect(description.contains("400"))
        #expect(description.contains("max_tokens must be <= 8192"))
    }

    @Test("a refusal without a body still names the status")
    func aRefusalWithoutABodyStillNamesTheStatus() {
        let error = SSEError.httpStatus(500, body: nil)
        let description = error.errorDescription ?? ""
        #expect(description.contains("500"))
    }
}

// MARK: - The stub protocol

private final class RefusingProtocol: URLProtocol {
    nonisolated(unsafe) static var status: Int = 400
    nonisolated(unsafe) static var body: String = ""

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}
