//
//  KeenableKeylessProviderTests.swift · Wenshu
//
//  Tests for KeenableKeylessProvider (= vendor 3 of 3 in the keyless ring).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("KeenableKeylessProvider", .serialized)
struct KeenableKeylessProviderTests {

    // MARK: - Helpers

    private static func makeSession(for stubProtocolClass: AnyClass) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [stubProtocolClass]
        return URLSession(configuration: config)
    }

    private static func jsonData(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    private static func makeProvider(for stub: URLProtocolStub, protocolClass: AnyClass) -> KeenableKeylessProvider {
        let session = makeSession(for: protocolClass)
        return KeenableKeylessProvider(appTitle: "wenshu", session: session)
    }

    // MARK: - Tests

    @Test("search parses the results array")
    func testSearchParsesResultsArray() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let response: [String: Any] = [
            "results": [
                [
                    "url": "https://example.com/a",
                    "title": "Result A",
                    "snippet": "the snippet text"
                ]
            ]
        ]
        stub.responseData = Self.jsonData(response)
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        let results = try await provider.search(query: "test", limit: 5)

        #expect(results.count == 1)
        #expect(results[0].title == "Result A")
        #expect(results[0].url.absoluteString == "https://example.com/a")
        #expect(results[0].snippet == "the snippet text")
    }

    @Test("search falls back to description when snippet field is missing")
    func testSearchFallsBackToDescription() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let response: [String: Any] = [
            "results": [
                [
                    "url": "https://example.com/a",
                    "title": "A",
                    "description": "the description text"
                ]
            ]
        ]
        stub.responseData = Self.jsonData(response)
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        let results = try await provider.search(query: "test", limit: 5)

        #expect(results.count == 1)
        #expect(results[0].snippet == "the description text")
    }

    @Test("search sends the X-Keenable-Title header")
    func testSearchSendsAppTitleHeader() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let response: [String: Any] = ["results": []]
        stub.responseData = Self.jsonData(response)
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        _ = try await provider.search(query: "test", limit: 5)

        let captured = stub.lastRequest
        #expect(captured?.value(forHTTPHeaderField: "X-Keenable-Title") == "wenshu")
    }

    @Test("search uses the public path, not the keyed path")
    func testSearchUsesPublicPath() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let response: [String: Any] = ["results": []]
        stub.responseData = Self.jsonData(response)
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        _ = try await provider.search(query: "test", limit: 5)

        let captured = stub.lastRequest
        #expect(captured?.url?.path == "/v1/search/public")
    }

    @Test("search caps results at limit")
    func testSearchCapsResultsAtLimit() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        let response: [String: Any] = [
            "results": (1...5).map { i in
                [
                    "url": "https://example.com/\(i)",
                    "title": "R\(i)",
                    "snippet": "s\(i)"
                ]
            }
        ]
        stub.responseData = Self.jsonData(response)
        stub.responseStatusCode = 200
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        let results = try await provider.search(query: "test", limit: 2)

        #expect(results.count == 2)
        #expect(results.map(\.title) == ["R1", "R2"])
    }

    @Test("search raises providerFailure on 4xx")
    func testSearchRaisesOn4xx() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.responseData = Data("rate-limited".utf8)
        stub.responseStatusCode = 429
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        await #expect(throws: WebSearchError.self) {
            _ = try await provider.search(query: "test", limit: 5)
        }
    }

    @Test("search raises providerFailure when X-Keenable-Title is missing (= 400)")
    func testSearchRaisesOnMissingAppTitle() async throws {
        let (stub, stubProtocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.responseData = Data("Missing app identifier".utf8)
        stub.responseStatusCode = 400
        let provider = Self.makeProvider(for: stub, protocolClass: stubProtocolClass)

        await #expect(throws: WebSearchError.self) {
            _ = try await provider.search(query: "test", limit: 5)
        }
    }
}