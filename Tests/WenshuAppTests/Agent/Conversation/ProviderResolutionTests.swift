//
//  ProviderResolutionTests.swift · Wenshu · rewritten 2026-10-16
//
//  AUDIT.md §2.6 partial (2026-10-16 boss "清老代码必须
//  做完" arc): the WenshuVerifier.resolveCredentials +
//  WenshuVerifier(model: .m3) init signature paths that this
//  test file previously exercised have been removed; =
//  the public chat() bridge delegates to
//  WenshuAgent.shared.chat() (= the canonical LLM call
//  entry point; = the verifier no longer owns credential
//  resolution). This file is kept minimal so the rest of
//  the test suite still compiles; = the WenshuLLMModel
//  provider-slug mapping is preserved as a small
//  regression test (= no production code change).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ProviderResolution (动态 key + baseURL routing)", .serialized)
struct ProviderResolutionTests {

    // MARK: - WenshuLLMModel.providerSlug

    @Test("WenshuLLMModel.providerSlug maps each case to its provider")
    func testModelProviderSlugMapping() {
        #expect(WenshuLLMModel.m3.providerSlug == "minimax-cn")
        #expect(WenshuLLMModel.m2.providerSlug == "minimax-cn")
        #expect(WenshuLLMModel.reasoning.providerSlug == "minimax-cn")
    }

    // MARK: - WenshuVerifier is a thin bridge

    @Test("WenshuVerifier() constructs with no args (= the legacy model: param was removed)")
    func testWenshuVerifierInitSignature() {
        // Type-level check: WenshuVerifier.init is no-arg now.
        let verifier = WenshuVerifier()
        _ = verifier
    }
}
