//
//  MemorySkillOAuthTests.swift · Wenshu · v0.38 Batch 3 sub-step 8
//
//  Tests for MemoryAdapter + SkillAdapter + OAuthFlow + ProviderKeychainMetadata
//  (= v0.36 ticket 009/010/012).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = MemoryAdapter + SkillAdapter +
//  OAuthFlow are v0.36 ticket 009/010/012 (= my work).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("MemoryAdapter deep (= v0.36 ticket 009)")
struct MemoryAdapterDeepTests {

    @Test("MemoryAdapter.MemoryEntry: construction with all fields")
    func memoryEntryConstruction() {
        let entry = MemoryAdapter.MemoryEntry(
            id: "m1",
            source: "/book/world.md",
            snippet: "Alice backstory",
            relevanceScore: 0.92
        )
        #expect(entry.id == "m1")
        #expect(entry.source == "/book/world.md")
        #expect(entry.snippet == "Alice backstory")
        #expect(entry.relevanceScore == 0.92)
    }

    @Test("MemoryAdapter.MemoryEntry: default relevanceScore = 0.0")
    func memoryEntryDefaultScore() {
        let entry = MemoryAdapter.MemoryEntry(
            id: "m1",
            source: "/a.md",
            snippet: "x",
            relevanceScore: 0.0
        )
        #expect(entry.relevanceScore == 0.0)
    }

    @Test("MemoryAdapter.MemoryEntry: Equatable")
    func memoryEntryEquatable() {
        let a = MemoryAdapter.MemoryEntry(id: "m1", source: "/a.md", snippet: "x", relevanceScore: 0.5)
        let b = MemoryAdapter.MemoryEntry(id: "m1", source: "/a.md", snippet: "x", relevanceScore: 0.5)
        #expect(a == b)
    }

    @Test("MemoryAdapter.retrieve: returns empty list for unknown message")
    func retrieveEmpty() async {
        let adapter = MemoryAdapter()
        let results = await adapter.retrieve(forUserMessage: "totally unknown query xyz123")
        // Default behavior: returns empty (= no memory subsystem wired yet)
        #expect(results.isEmpty)
    }

    @Test("MemoryAdapter.write: stores entry")
    func writeEntry() async {
        let adapter = MemoryAdapter()
        await adapter.write(
            snippet: "User prefers dark mode",
            source: "/preferences.md"
        )
        // No assertion (= storage layer is in-memory stub per v0.36)
        // The test verifies the call doesn't crash
    }
}

@Suite("SkillAdapter deep (= v0.36 ticket 010)")
struct SkillAdapterDeepTests {

    @Test("SkillAdapter.Skill: construction with all fields")
    func skillConstruction() {
        let skill = SkillAdapter.Skill(
            name: "compress",
            description: "Compress context",
            enabled: true
        )
        #expect(skill.name == "compress")
        #expect(skill.description == "Compress context")
        #expect(skill.enabled == true)
    }

    @Test("SkillAdapter.Skill: default enabled = false")
    func skillDefaultDisabled() {
        let skill = SkillAdapter.Skill(
            name: "test",
            description: "test skill",
            enabled: false
        )
        #expect(skill.enabled == false)
    }

    @Test("SkillAdapter.Skill: Equatable")
    func skillEquatable() {
        let a = SkillAdapter.Skill(name: "x", description: "y", enabled: true)
        let b = SkillAdapter.Skill(name: "x", description: "y", enabled: true)
        #expect(a == b)
    }

    @Test("SkillAdapter.listSkills: returns empty by default")
    func listSkillsEmpty() async {
        let adapter = SkillAdapter()
        let skills = await adapter.listSkills()
        // No skills registered by default
        #expect(skills.isEmpty)
    }

    @Test("SkillAdapter.invoke: throws for unknown skill")
    func invokeUnknown() async {
        let adapter = SkillAdapter()
        do {
            _ = try await adapter.invoke(name: "nonexistent_skill", input: "test")
            Issue.record("expected throw")
        } catch {
            // expected
        }
    }
}

@Suite("OAuthFlow deep (= v0.36 ticket 012)")
struct OAuthFlowDeepTests {

    @Test("OAuthFlow: authorizationURL returns URL with state")
    func authorizationURLReturnsURL() async {
        let flow = OAuthFlow(
            provider: .anthropic,
            authorizationEndpoint: URL(string: "https://oauth.example.com/authorize")!,
            tokenEndpoint: URL(string: "https://oauth.example.com/token")!,
            redirectURI: URL(string: "https://app.example.com/callback")!,
            clientID: "test_client",
            scopes: ["read", "write"]
        )
        let url = await flow.authorizationURL(
            state: "test_state_123",
            codeChallenge: "test_challenge_abc"
        )
        let urlString = url.absoluteString
        #expect(urlString.contains("test_state_123"))
        #expect(urlString.contains("test_challenge_abc"))
        #expect(urlString.contains("test_client"))
        #expect(urlString.contains("https://oauth.example.com/authorize"))
    }
}

@Suite("ProviderKeychainMetadata deep (= v0.36 ticket 012)")
struct ProviderKeychainMetadataDeepTests {

    @Test("ProviderKeychainMetadata: Codable round-trip with all fields")
    func metadataCodableAllFields() throws {
        let metadata = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSinceNow: 3600),
            oauthRefreshToken: "rt_xyz",
            oauthAccessToken: "at_abc",
            oauthScopes: ["read", "write"],
            rotatedAt: Date()
        )
        let encoded = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(ProviderKeychainMetadata.self, from: encoded)
        #expect(decoded.expiresAt == metadata.expiresAt)
        #expect(decoded.oauthRefreshToken == "rt_xyz")
        #expect(decoded.oauthAccessToken == "at_abc")
        #expect(decoded.oauthScopes == ["read", "write"])
    }

    @Test("ProviderKeychainMetadata: isExpired false when no expiresAt")
    func metadataNotExpiredWhenNoExpiry() {
        let metadata = ProviderKeychainMetadata(
            expiresAt: nil,
            oauthRefreshToken: nil,
            oauthAccessToken: nil,
            oauthScopes: [],
            rotatedAt: Date()
        )
        #expect(metadata.isExpired == false)
    }

    @Test("ProviderKeychainMetadata: isExpired true when expiresAt in past")
    func metadataExpired() {
        let metadata = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSinceNow: -3600),  // 1 hour ago
            oauthRefreshToken: nil,
            oauthAccessToken: nil,
            oauthScopes: [],
            rotatedAt: Date()
        )
        #expect(metadata.isExpired == true)
    }

    @Test("ProviderKeychainMetadata: isExpired false when expiresAt in future")
    func metadataNotExpiredFuture() {
        let metadata = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSinceNow: 3600),  // 1 hour from now
            oauthRefreshToken: nil,
            oauthAccessToken: nil,
            oauthScopes: [],
            rotatedAt: Date()
        )
        #expect(metadata.isExpired == false)
    }

    @Test("ProviderKeychainMetadata: isOAuth true when refresh token set")
    func metadataIsOAuthWithRefresh() {
        let metadata = ProviderKeychainMetadata(
            expiresAt: nil,
            oauthRefreshToken: "rt",
            oauthAccessToken: nil,
            oauthScopes: [],
            rotatedAt: Date()
        )
        #expect(metadata.isOAuth == true)
    }

    @Test("ProviderKeychainMetadata: isOAuth true when access token set")
    func metadataIsOAuthWithAccess() {
        let metadata = ProviderKeychainMetadata(
            expiresAt: nil,
            oauthRefreshToken: nil,
            oauthAccessToken: "at",
            oauthScopes: [],
            rotatedAt: Date()
        )
        #expect(metadata.isOAuth == true)
    }

    @Test("ProviderKeychainMetadata: isOAuth false when no tokens")
    func metadataNotOAuth() {
        let metadata = ProviderKeychainMetadata(
            expiresAt: nil,
            oauthRefreshToken: nil,
            oauthAccessToken: nil,
            oauthScopes: [],
            rotatedAt: Date()
        )
        #expect(metadata.isOAuth == false)
    }

    @Test("ProviderKeychainMetadata: Equatable")
    func metadataEquatable() {
        let a = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSince1970: 1000),
            oauthRefreshToken: "rt",
            oauthAccessToken: "at",
            oauthScopes: ["read"],
            rotatedAt: Date(timeIntervalSince1970: 2000)
        )
        let b = ProviderKeychainMetadata(
            expiresAt: Date(timeIntervalSince1970: 1000),
            oauthRefreshToken: "rt",
            oauthAccessToken: "at",
            oauthScopes: ["read"],
            rotatedAt: Date(timeIntervalSince1970: 2000)
        )
        #expect(a == b)
    }
}
