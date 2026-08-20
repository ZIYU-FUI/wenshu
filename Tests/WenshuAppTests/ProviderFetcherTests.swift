//
//  ProviderFetcherTests.swift · v0.21 ticket 03
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ProviderFetcher (多 provider live fetch, Hermes probe_api_models 范式)")
struct ProviderFetcherTests {

    @Test("no key 返 fallback curated")
    func testEmptyKey() async {
        let models = await ProviderFetcher.loadModelIds(provider: .minimaxCn, apiKey: "")
        #expect(models == Provider.minimaxCn.defaultModels)
    }

    @Test("custom provider 无 base_url 返空")
    func testCustomProvider() async {
        let models = await ProviderFetcher.loadModelIds(provider: .custom, apiKey: "sk-test")
        #expect(models.isEmpty)
    }

    @Test("network fail 返 curated fallback")
    func testNetworkFallback() async {
        let models = await ProviderFetcher.loadModelIds(
            provider: .anthropic,
            apiKey: "sk-invalid-test"
        )
        // 网络请求会失败, 返 anthropic curated fallback (claude-opus-4...)
        #expect(models == Provider.anthropic.defaultModels)
    }

    @Test("Provider 都有 defaultModels curated")
    func testCuratedFallback() {
        for p in Provider.all where p.slug != "custom" {
            #expect(!p.defaultModels.isEmpty, "\\(p.slug) has empty curated")
        }
    }
}
