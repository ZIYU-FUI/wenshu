//
//  WAProviderRegistryTests.swift · Wenshu · WenshuAgent unit test for WAProviderRegistry
//
//  Verifies the provider registry (= hermes provider_registry.py
//  port). Tests:
//   - register / unregister
//   - provider(slug:) lookup
//   - snapshot returns the slugs
//   - replaceAll (test-only) replaces the entire set
//
//  Created: 2026-10-16 (WenshuAgent P3.6 unit tests)
//

import Testing
import Foundation
import WenshuAgent

@testable import WenshuApp

private struct MockProvider: WABaseProvider {
    let slug: String
    let displayName: String
    let defaultBaseURL: String = "https://mock.test"
    let defaultContextWindowTokens: Int = 32_000
    let defaultModels: [String] = ["mock-1", "mock-2"]
    let wireFormat: WireFormat = .anthropic
    let authHeader: ProviderAuthMode = .bearer
    let requiresOAuth: Bool = false
    let modelListURL: URL? = URL(string: "https://mock.test/v1/models")
}

@Suite("WAProviderRegistry")
struct WAProviderRegistryTests {

    @Test("register + lookup + unregister")
    func testBasic() async {
        let registry = WAProviderRegistry()
        let provider = MockProvider(slug: "mock", displayName: "Mock")
        await registry.register(provider)
        let lookedUp = await registry.provider(slug: "mock")
        #expect(lookedUp?.slug == "mock")
        #expect(lookedUp?.displayName == "Mock")
        await registry.unregister(slug: "mock")
        let afterUnregister = await registry.provider(slug: "mock")
        #expect(afterUnregister == nil)
    }

    @Test("snapshot returns the current slugs")
    func testSnapshot() async {
        let registry = WAProviderRegistry()
        await registry.replaceAll([
            MockProvider(slug: "a", displayName: "A"),
            MockProvider(slug: "b", displayName: "B"),
            MockProvider(slug: "c", displayName: "C")
        ])
        let snapshot = await registry.snapshot()
        #expect(snapshot.count == 3)
        #expect(snapshot.contains("a"))
        #expect(snapshot.contains("b"))
        #expect(snapshot.contains("c"))
    }

    @Test("all returns every registered provider")
    func testAll() async {
        let registry = WAProviderRegistry()
        await registry.replaceAll([
            MockProvider(slug: "x", displayName: "X"),
            MockProvider(slug: "y", displayName: "Y")
        ])
        let all = await registry.all
        #expect(all.count == 2)
    }
}
