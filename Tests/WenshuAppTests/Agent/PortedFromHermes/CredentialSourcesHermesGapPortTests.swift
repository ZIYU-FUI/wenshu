//
//  CredentialSourcesHermesGapPortTests.swift · Wenshu · P1-CREDENTIAL-SOURCES-HERMES-PORT (2026-09-19)
//
//  Verifies the new hermes port addition to
//  `Core/Provider/CredentialSources.swift` (= hermes
//  `agent/credential_sources.py` 250+ LOC Python).
//
//  Hermes-side registry + suppression ported (= the foundation
//  pattern; = the per-source `remove_fn` implementations are
//  future tickets per the wenshu-side-wins pattern in the file
//  header).
//
//  Per AGENTS.md §11.3 wenshu-side wins: registry + suppression
//  layer (= ProviderKeychain already owns the macOS Keychain
//  storage layer per AGENTS.md §11).

import XCTest
@testable import WenshuApp

final class CredentialSourcesHermesGapPortTests: XCTestCase {

    // MARK: -- RemovalResult tests

    func testRemovalResult_defaultValues() {
        let result = RemovalResult()
        XCTAssertTrue(result.cleaned.isEmpty)
        XCTAssertTrue(result.hints.isEmpty)
        XCTAssertTrue(result.suppress)
    }

    func testRemovalResult_customValues() {
        let result = RemovalResult(
            cleaned: ["Cleared env var"],
            hints: ["Shell profile still has it"],
            suppress: false
        )
        XCTAssertEqual(result.cleaned, ["Cleared env var"])
        XCTAssertEqual(result.hints, ["Shell profile still has it"])
        XCTAssertFalse(result.suppress)
    }

    func testRemovalResult_identity() {
        XCTAssertEqual(RemovalResult.identity.cleaned, RemovalResult().cleaned)
    }

    // MARK: -- RemovalStep tests

    func testRemovalStep_exactMatch() {
        let step = RemovalStep(
            provider: "anthropic",
            sourceID: "claude_code",
            removeFn: { _, _ in RemovalResult() },
            description: "Test"
        )
        XCTAssertTrue(step.matches(provider: "anthropic", source: "claude_code"))
        XCTAssertFalse(step.matches(provider: "anthropic", source: "manual"))
        XCTAssertFalse(step.matches(provider: "openai", source: "claude_code"))
    }

    func testRemovalStep_wildcardProvider() {
        let step = RemovalStep(
            provider: "*",
            sourceID: "manual",
            removeFn: { _, _ in RemovalResult() }
        )
        XCTAssertTrue(step.matches(provider: "anthropic", source: "manual"))
        XCTAssertTrue(step.matches(provider: "openai", source: "manual"))
    }

    func testRemovalStep_matchFnOverridesLiteral() {
        let step = RemovalStep(
            provider: "anthropic",
            sourceID: "env",
            removeFn: { _, _ in RemovalResult() },
            matchFn: { source in source.hasPrefix("env:") }
        )
        XCTAssertTrue(step.matches(provider: "anthropic", source: "env:ANTHROPIC_API_KEY"))
        XCTAssertTrue(step.matches(provider: "anthropic", source: "env:"))
        XCTAssertFalse(step.matches(provider: "anthropic", source: "manual"))
    }

    func testRemovalStep_descriptionIsStored() {
        let step = RemovalStep(
            provider: "x",
            sourceID: "y",
            removeFn: { _, _ in RemovalResult() },
            description: "Custom step"
        )
        XCTAssertEqual(step.description, "Custom step")
    }

    // MARK: -- Registry tests

    // MARK: -- Suppression tests

    // MARK: -- Integration test

    // MARK: -- Spec check

}
