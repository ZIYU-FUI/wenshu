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

    override func setUp() {
        super.setUp()
        CredentialSources.removeAll()
        CredentialSourceSuppression.removeAll()
    }

    override func tearDown() {
        CredentialSources.removeAll()
        CredentialSourceSuppression.removeAll()
        super.tearDown()
    }

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

    func testRegister_addsStep() {
        let step = RemovalStep(
            provider: "anthropic",
            sourceID: "x",
            removeFn: { _, _ in RemovalResult() }
        )
        let returned = CredentialSources.register(step)
        XCTAssertEqual(returned.provider, step.provider)
        XCTAssertEqual(CredentialSources.all().count, 1)
    }

    func testRegister_returnsSameStep() {
        let step = RemovalStep(
            provider: "anthropic",
            sourceID: "x",
            removeFn: { _, _ in RemovalResult() }
        )
        let returned = CredentialSources.register(step)
        XCTAssertEqual(returned.sourceID, step.sourceID)
    }

    func testFindRemovalStep_returnsRegisteredStep() {
        let step = RemovalStep(
            provider: "anthropic",
            sourceID: "claude_code",
            removeFn: { _, _ in RemovalResult() }
        )
        CredentialSources.register(step)
        let found = CredentialSources.findRemovalStep(provider: "anthropic", source: "claude_code")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.provider, "anthropic")
        XCTAssertEqual(found?.sourceID, "claude_code")
    }

    func testFindRemovalStep_returnsNilForUnregistered() {
        XCTAssertNil(CredentialSources.findRemovalStep(provider: "anthropic", source: "missing"))
    }

    func testFindRemovalStep_returnsFirstMatch() {
        let first = RemovalStep(
            provider: "anthropic",
            sourceID: "x",
            removeFn: { _, _ in RemovalResult(suppress: true) }
        )
        let second = RemovalStep(
            provider: "anthropic",
            sourceID: "x",
            removeFn: { _, _ in RemovalResult(suppress: false) }
        )
        CredentialSources.register(first)
        CredentialSources.register(second)
        let found = CredentialSources.findRemovalStep(provider: "anthropic", source: "x")
        XCTAssertNotNil(found)
        XCTAssertTrue(found?.removeFn("anthropic", RemovedEntry(provider: "anthropic", source: "x", value: "")).suppress ?? false)
    }

    func testRemoveAll_clearsRegistry() {
        CredentialSources.register(RemovalStep(
            provider: "x", sourceID: "y",
            removeFn: { _, _ in RemovalResult() }
        ))
        CredentialSources.removeAll()
        XCTAssertEqual(CredentialSources.all().count, 0)
    }

    func testAll_returnsAllRegisteredSteps() {
        CredentialSources.register(RemovalStep(
            provider: "x", sourceID: "a",
            removeFn: { _, _ in RemovalResult() }
        ))
        CredentialSources.register(RemovalStep(
            provider: "y", sourceID: "b",
            removeFn: { _, _ in RemovalResult() }
        ))
        XCTAssertEqual(CredentialSources.all().count, 2)
    }

    // MARK: -- Suppression tests

    func testSuppression_defaultNotSuppressed() {
        XCTAssertFalse(CredentialSourceSuppression.isSuppressed(provider: "x", sourceID: "y"))
    }

    func testSuppression_suppressThenCheck() {
        CredentialSourceSuppression.suppress(provider: "anthropic", sourceID: "claude_code")
        XCTAssertTrue(CredentialSourceSuppression.isSuppressed(provider: "anthropic", sourceID: "claude_code"))
    }

    func testSuppression_unsuppressRemoves() {
        CredentialSourceSuppression.suppress(provider: "x", sourceID: "y")
        CredentialSourceSuppression.unsuppress(provider: "x", sourceID: "y")
        XCTAssertFalse(CredentialSourceSuppression.isSuppressed(provider: "x", sourceID: "y"))
    }

    func testSuppression_differentKeysAreIndependent() {
        CredentialSourceSuppression.suppress(provider: "a", sourceID: "x")
        XCTAssertFalse(CredentialSourceSuppression.isSuppressed(provider: "b", sourceID: "x"))
        XCTAssertFalse(CredentialSourceSuppression.isSuppressed(provider: "a", sourceID: "y"))
    }

    func testSuppression_removeAllClearsAll() {
        CredentialSourceSuppression.suppress(provider: "a", sourceID: "x")
        CredentialSourceSuppression.suppress(provider: "b", sourceID: "y")
        CredentialSourceSuppression.removeAll()
        XCTAssertFalse(CredentialSourceSuppression.isSuppressed(provider: "a", sourceID: "x"))
        XCTAssertFalse(CredentialSourceSuppression.isSuppressed(provider: "b", sourceID: "y"))
    }

    // MARK: -- Integration test

    func testEndToEnd_registerSuppressFlow() {
        let step = RemovalStep(
            provider: "anthropic",
            sourceID: "claude_code",
            removeFn: { _, _ in RemovalResult(cleaned: ["Cleared"], suppress: true) },
            description: "Clear Claude Code credentials"
        )
        CredentialSources.register(step)
        let found = CredentialSources.findRemovalStep(provider: "anthropic", source: "claude_code")
        XCTAssertNotNil(found)
        let result = found!.removeFn(
            "anthropic",
            RemovedEntry(provider: "anthropic", source: "claude_code", value: "secret")
        )
        XCTAssertEqual(result.cleaned, ["Cleared"])
        XCTAssertTrue(result.suppress)
        if result.suppress {
            CredentialSourceSuppression.suppress(provider: "anthropic", sourceID: "claude_code")
        }
        XCTAssertTrue(CredentialSourceSuppression.isSuppressed(provider: "anthropic", sourceID: "claude_code"))
    }

    // MARK: -- Spec check

    func testSourceFile_documentedAsHermesPort() {
        // v1.57 stale-helper: per wenshu-stale-test-cleanup Class A recipe.
        guard let source = HermesGapPortTestHelpers.readSource(
            relativeToTest: #filePath,
            sourceFileName: "CredentialSources.swift"
        ) else {
            XCTFail("HermesGapPortTestHelpers could not locate CredentialSources.swift")
            return
        }
        XCTAssertTrue(source.contains("P1-CREDENTIAL-SOURCES-HERMES-PORT"))
        XCTAssertTrue(source.contains("agent/credential_sources.py"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
        XCTAssertTrue(source.contains("RemovalResult"))
        XCTAssertTrue(source.contains("RemovalStep"))
    }
}
