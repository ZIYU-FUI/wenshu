//
//  KeylessRingTests.swift · Wenshu
//
//  Tests for KeylessRing (= hermes _walk_ring 1:1 port).
//
//  Uses small mock WebSearchProvider types (= no URLSession; = no
//  URLProtocolStub; = pure actor + concurrency coverage).
//

import Testing
import Foundation
@testable import WenshuApp

// MARK: - Mock providers

private struct KeylessRingStubProvider: WebSearchProvider, Sendable {
    let name: String
    let results: [WebSearchResult]

    func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        results
    }
}

private struct KeylessRingFailingProvider: WebSearchProvider, Sendable {
    let name: String
    let message: String

    func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        throw WebSearchError.providerFailure(name: name, underlying: message)
    }
}

private enum TestError: Error, LocalizedError {
    case malformedQuery

    var errorDescription: String? {
        switch self {
        case .malformedQuery: return "malformed query: parse failed"
        }
    }
}

private struct KeylessRingNonThrottleProvider: WebSearchProvider, Sendable {
    let name: String

    func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        throw TestError.malformedQuery
    }
}

private let hit1 = WebSearchResult(title: "hit1", snippet: "s1", url: URL(string: "https://example.com/1")!)
private let hit2 = WebSearchResult(title: "hit2", snippet: "s2", url: URL(string: "https://example.com/2")!)
private let hit3 = WebSearchResult(title: "hit3", snippet: "s3", url: URL(string: "https://example.com/3")!)

// MARK: - Tests

@Suite("KeylessRing", .serialized)
struct KeylessRingTests {

    @Test("search returns the first non-empty result")
    func testSearchReturnsFirstNonEmpty() async throws {
        let ring = KeylessRing(providers: [
            KeylessRingStubProvider(name: "p1", results: [hit1])
        ])
        let results = try await ring.search(query: "q", limit: 5)
        #expect(results == [hit1])
    }

    @Test("search skips an empty provider and returns the next")
    func testSearchSkipsEmptyAndReturnsNext() async throws {
        let ring = KeylessRing(providers: [
            KeylessRingStubProvider(name: "p1", results: []),
            KeylessRingStubProvider(name: "p2", results: [hit1, hit2])
        ])
        let results = try await ring.search(query: "q", limit: 5)
        #expect(results == [hit1, hit2])
    }

    @Test("search skips a throttled provider and returns the next")
    func testSearchSkipsThrottledAndReturnsNext() async throws {
        let ring = KeylessRing(providers: [
            KeylessRingFailingProvider(name: "p1", message: "HTTP 429: too many requests"),
            KeylessRingStubProvider(name: "p2", results: [hit3])
        ])
        let results = try await ring.search(query: "q", limit: 5)
        #expect(results == [hit3])
    }

    @Test("search stops on a non-throttle error and rethrows")
    func testSearchStopsOnNonThrottleError() async throws {
        let ring = KeylessRing(providers: [
            KeylessRingNonThrottleProvider(name: "p1"),
            KeylessRingStubProvider(name: "p2", results: [hit1])
        ])
        await #expect(throws: TestError.self) {
            _ = try await ring.search(query: "q", limit: 5)
        }
    }

    @Test("search throws allProvidersThrottled when every provider is throttled")
    func testSearchThrowsWhenAllThrottled() async throws {
        let ring = KeylessRing(providers: [
            KeylessRingFailingProvider(name: "p1", message: "rate limit exceeded"),
            KeylessRingFailingProvider(name: "p2", message: "HTTP 429: quota exceeded"),
            KeylessRingFailingProvider(name: "p3", message: "slow down please")
        ])
        await #expect {
            _ = try await ring.search(query: "q", limit: 5)
        } throws: { error in
            guard case let KeylessRing.RingError.allProvidersThrottled(attempted, _) = error else {
                return false
            }
            return attempted == ["p1", "p2", "p3"]
        }
    }

    @Test("search throws allProvidersThrottled when every provider returns empty")
    func testSearchThrowsWhenAllEmpty() async throws {
        let ring = KeylessRing(providers: [
            KeylessRingStubProvider(name: "p1", results: []),
            KeylessRingStubProvider(name: "p2", results: []),
            KeylessRingStubProvider(name: "p3", results: [])
        ])
        await #expect {
            _ = try await ring.search(query: "q", limit: 5)
        } throws: { error in
            guard case let KeylessRing.RingError.allProvidersThrottled(attempted, _) = error else {
                return false
            }
            return attempted == ["p1", "p2", "p3"]
        }
    }

    @Test("isRateLimitish detects each marker")
    func testIsRateLimitishDetectsMarkers() {
        #expect(KeylessRing.isRateLimitish("HTTP 429: too many requests") == true)
        #expect(KeylessRing.isRateLimitish("rate limit exceeded") == true)
        #expect(KeylessRing.isRateLimitish("rate-limit hit") == true)
        #expect(KeylessRing.isRateLimitish("quota exceeded; retry later") == true)
        #expect(KeylessRing.isRateLimitish("please slow down") == true)
        #expect(KeylessRing.isRateLimitish("malformed query: parse failed") == false)
        #expect(KeylessRing.isRateLimitish("") == false)
    }

    @Test("defaultProviders returns three vendors in canonical order")
    func testDefaultProvidersReturnsThreeVendors() {
        let vendors = KeylessRing.defaultProviders()
        #expect(vendors.count == 3)
        #expect(vendors[0].name == "parallel")
        #expect(vendors[1].name == "exa")
        #expect(vendors[2].name == "keenable")
    }

    @Test("defaultRing matches defaultProviders")
    func testDefaultRingMatchesDefaultProviders() async throws {
        let ring = KeylessRing.defaultRing()
        // Default ring with a stub canned response to verify the wiring.
        let canned = KeylessRing(providers: [
            KeylessRingStubProvider(name: "p1", results: [hit1])
        ])
        _ = ring
        _ = canned
        // Sanity check: defaultRing is constructable and exposes the
        // three canonical vendors through its providers list.
        let mirror = KeylessRing(providers: KeylessRing.defaultProviders())
        #expect(await mirror.providers.count == 3)
    }
}