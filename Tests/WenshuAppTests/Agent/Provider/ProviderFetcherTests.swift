//
//  ProviderFetcherTests.swift · Wenshu
//
//  The model ids offered for a provider: the live list when the
//  source has one, the curated list otherwise.
//
//  Every case runs against an injected source that answers on purpose
//  (= no network), so both branches of the fetcher are covered the
//  same way on every run, whatever the network's reachability is.
//

import Testing
import Foundation
import WenshuAgent
@testable import WenshuApp

@Suite("ProviderFetcher (live model ids vs curated fallback)")
struct ProviderFetcherTests {

    @Test("no key returns the curated list and never asks the source")
    func testEmptyKey() async {
        let source = RecordingSource(answer: ["live-model-id"])
        let models = await ProviderFetcher.loadModelIds(
            provider: .minimaxCn,
            apiKey: "",
            source: source
        )
        #expect(models == Provider.minimaxCn.defaultModels)
        #expect(await source.callCount == 0)
    }

    @Test("custom provider has no endpoint, so the list stays empty")
    func testCustomProvider() async {
        let source = RecordingSource(answer: ["live-model-id"])
        let models = await ProviderFetcher.loadModelIds(
            provider: .custom,
            apiKey: "test-key-not-a-credential",
            source: source
        )
        #expect(models.isEmpty)
        #expect(await source.callCount == 0)
    }

    @Test("a failing source returns the curated fallback")
    func testSourceFailureFallsBackToCurated() async {
        let source = RecordingSource(answer: nil)
        let models = await ProviderFetcher.loadModelIds(
            provider: .anthropic,
            apiKey: "test-key-not-a-credential",
            source: source
        )
        #expect(models == Provider.anthropic.defaultModels)
        #expect(await source.callCount == 1)
    }

    @Test("a live source returns its model ids unchanged")
    func testLiveSourceReturnsLiveList() async {
        let live = ["claude-live-a", "claude-live-b"]
        let source = RecordingSource(answer: live)
        let models = await ProviderFetcher.loadModelIds(
            provider: .anthropic,
            apiKey: "test-key-not-a-credential",
            source: source
        )
        #expect(models == live)
        #expect(await source.callCount == 1)
    }

    @Test("every provider has a curated list")
    func testCuratedFallback() {
        for p in Provider.all where p.slug != "custom" {
            #expect(!p.defaultModels.isEmpty, "\(p.slug) has empty curated")
        }
    }
}

/// A source that answers on purpose: `answer` is what it hands back
/// (nil = the fetch failed), and it counts how often it was asked.
private actor RecordingSource: ProviderModelIdsSource {
    private let answer: [String]?
    private(set) var callCount = 0

    init(answer: [String]?) {
        self.answer = answer
    }

    func fetchLiveModelIds(provider: Provider, apiKey: String) async -> [String]? {
        callCount += 1
        return answer
    }
}
