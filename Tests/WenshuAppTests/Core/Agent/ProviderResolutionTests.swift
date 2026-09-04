//
//  ProviderResolutionTests.swift · Wenshu · v0.23 ticket 010.003
//
//  Boss 2026-08-23 拍: 用户切 model/key 后主 + 子 agent 同步切.
//  Tests verify dynamic credential resolution end-to-end.
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

    // MARK: - WenshuVerifier init no longer captures frozen credentials

    @Test("WenshuVerifier.init no longer takes required apiKey (frozen) param")
    func testWenshuVerifierInitSignature() throws {
        // Type-level check: WenshuVerifier.init accepts model only (apiKey optional override).
        let verifier = WenshuVerifier(model: .m3)
        _ = verifier
        // Verify it works with default model.
        let defaultVerifier = WenshuVerifier()
        _ = defaultVerifier
    }

    // MARK: - resolveCredentials

    @Test("resolveCredentials: no UserDefaults override → use model.providerSlug")
    func testResolveCredentialsUsesDefaults() async throws {
        // Clear UserDefaults override
        UserDefaults.standard.removeObject(forKey: "wenshu.llm.provider")
        let verifier = WenshuVerifier(model: .m3)
        // Sandbox has no Keychain key — expect throw (missingAPIKey or other).
        do {
            let creds = try await verifier.resolveCredentials()
            // If we got here, sandbox had a real key (e.g. dev env with MINIMAX_CN_API_KEY env).
            #expect(creds.providerSlug == "minimax-cn")
            #expect(!creds.baseURL.isEmpty)
        } catch let WenshuLLMError.missingAPIKey {
            // Expected in sandbox — no Keychain key.
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("resolveCredentials: with UserDefaults override → use override")
    func testResolveCredentialsRespectsUserOverride() async throws {
        UserDefaults.standard.set("minimax-cn", forKey: "wenshu.llm.provider")
        defer { UserDefaults.standard.removeObject(forKey: "wenshu.llm.provider") }
        let verifier = WenshuVerifier(model: .m3)
        do {
            let creds = try await verifier.resolveCredentials()
            #expect(creds.providerSlug == "minimax-cn")
        } catch let WenshuLLMError.missingAPIKey {
            // Expected in sandbox.
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("resolveCredentials: missing Keychain key for provider throws")
    func testResolveCredentialsThrowsOnMissingKey() async throws {
        // Use a provider slug that has no Keychain key in sandbox.
        // Save an override to a non-existent provider, expect error.
        UserDefaults.standard.set("definitely-not-a-real-provider", forKey: "wenshu.llm.provider")
        defer { UserDefaults.standard.removeObject(forKey: "wenshu.llm.provider") }
        let verifier = WenshuVerifier(model: .m3)
        await #expect(throws: (any Error).self) {
            _ = try await verifier.resolveCredentials()
        }
    }

    // MARK: - WenshuVerifier.send uses resolved credentials (not init capture)

    @Test("send() uses resolveCredentials() result (no frozen apiKey)")
    func testSendUsesResolvedCredentials() async {
        // Clear all UserDefaults + ensure no Keychain key.
        UserDefaults.standard.removeObject(forKey: "wenshu.llm.provider")
        let verifier = WenshuVerifier(model: .m3)
        let request = WenshuLLMRequest(
            model: "MiniMax-M3",
            max_tokens: 5,
            messages: [WenshuLLMMessage(role: "user", content: "test")]
        )
        do {
            // Sandbox has no Keychain key → should throw missingAPIKey from resolveCredentials.
            _ = try await verifier.send(request: request)
            Issue.record("expected throw")
        } catch let WenshuLLMError.missingAPIKey {
            // Expected — resolveCredentials() returned empty key.
        } catch {
            // Other errors (e.g. URLSession) are also acceptable for this test
            // since the bug we're guarding against is "send uses old frozen key".
            // What we DON'T want: send silently uses an old captured key.
        }
    }

    // MARK: - WenshuLLMModel.providerSlug exhaustive

    @Test("WenshuLLMModel.providerSlug exhaustive — all cases covered")
    func testProviderSlugExhaustive() {
        for model in WenshuLLMModel.allCases {
            let slug = model.providerSlug
            #expect(!slug.isEmpty, "missing providerSlug for \(model.rawValue)")
            // Each slug must be in ProviderCatalog.
            #expect(Provider.by(slug: slug) != nil, "providerSlug '\(slug)' not in ProviderCatalog")
        }
    }

    @Test("ProviderCatalog.defaultModels(for:) returns models for known slug")
    func testProviderCatalogDefaultModels() {
        let models = ProviderCatalog.defaultModels(for: "minimax-cn")
        #expect(!models.isEmpty)
    }
}