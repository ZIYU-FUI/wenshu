//
//  AgentInitHermesGapPortTests.swift · Wenshu · P9-AGENT-INIT-HERMES-PORT (2026-09-19)
//
//  Verifies the 3 new hermes port additions to
//  `Core/Agent/Conversation/AgentInit.swift` (= hermes
//  `agent/agent_init.py` 2103 LOC Python, focusing on the
//  pure helpers per Q112 = 1 ticket per file).
//
//  Hermes pure helpers ported:
//    - resolveCompressionThreshold(globalThreshold:modelThreshold:model:isCodexAutoraise:)
//      (= hermes `_resolve_compression_threshold` at L93-L120)
//    - normalizedCustomBaseURL(_:) (= hermes
//      `_normalized_custom_base_url` at L183-L187)
//    - customProviderModelMatches(agentModel:entry:)
//      (= hermes `_custom_provider_model_matches` at L189-L194)
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure helper port; = no
//  init_agent body (= 1840+ LOC; = out of scope for Q112
//  per Q46 stop-rule; = future split tickets per the
//  file-by-file rule).
//

import XCTest
@testable import WenshuApp

final class AgentInitHermesGapPortTests: XCTestCase {

    // MARK: -- P9.1 resolveCompressionThreshold tests (= hermes L93-L120)

    func testResolveCompressionThreshold_noModelThreshold_returnsGlobal() {
        let result = resolveCompressionThreshold(
            globalThreshold: 0.5,
            modelThreshold: nil
        )
        XCTAssertEqual(result.effectiveThreshold, 0.5)
        XCTAssertNil(result.autoraiseNotice)
    }

    func testResolveCompressionThreshold_nonCodexOverride_appliesOverride() {
        let result = resolveCompressionThreshold(
            globalThreshold: 0.5,
            modelThreshold: 0.8,
            isCodexAutoraise: false
        )
        XCTAssertEqual(result.effectiveThreshold, 0.8)
        XCTAssertNil(result.autoraiseNotice)
    }

    func testResolveCompressionThreshold_codexOverrideHigherThanGlobal_appliesAutoraise() {
        let result = resolveCompressionThreshold(
            globalThreshold: 0.5,
            modelThreshold: 0.8,
            model: "gpt-5.4",
            isCodexAutoraise: true
        )
        XCTAssertEqual(result.effectiveThreshold, 0.8)
        XCTAssertNotNil(result.autoraiseNotice)
        XCTAssertEqual(result.autoraiseNotice?.model, "gpt-5.4")
        XCTAssertEqual(result.autoraiseNotice?.from, 0.5)
        XCTAssertEqual(result.autoraiseNotice?.to, 0.8)
    }

    func testResolveCompressionThreshold_codexOverrideLowerThanGlobal_keepsGlobal() {
        // Codex autoraise never lowers (= hermes L110-L113).
        let result = resolveCompressionThreshold(
            globalThreshold: 0.5,
            modelThreshold: 0.3,
            model: "gpt-5.4",
            isCodexAutoraise: true
        )
        XCTAssertEqual(result.effectiveThreshold, 0.5)
        XCTAssertNil(result.autoraiseNotice)
    }

    func testResolveCompressionThreshold_codexOverrideEqualToGlobal_keepsGlobal() {
        // Floating-point epsilon tolerance (= hermes L110
        // `model_cthresh <= global_threshold + 1e-9`).
        let result = resolveCompressionThreshold(
            globalThreshold: 0.5,
            modelThreshold: 0.5000000001,
            isCodexAutoraise: true
        )
        XCTAssertEqual(result.effectiveThreshold, 0.5)
        XCTAssertNil(result.autoraiseNotice)
    }

    func testResolveCompressionThreshold_autoraiseNoticeHasCorrectShape() {
        let result = resolveCompressionThreshold(
            globalThreshold: 0.5,
            modelThreshold: 0.9,
            model: "gpt-5.3-codex-spark",
            isCodexAutoraise: true
        )
        XCTAssertNotNil(result.autoraiseNotice)
        XCTAssertEqual(result.autoraiseNotice?.model, "gpt-5.3-codex-spark")
    }

    // MARK: -- P9.2 normalizedCustomBaseURL tests (= hermes L183-L187)

    func testNormalizedCustomBaseURL_trimsTrailingSlash() {
        XCTAssertEqual(normalizedCustomBaseURL("https://api.example.com/"), "https://api.example.com")
    }

    func testNormalizedCustomBaseURL_trimsWhitespace() {
        XCTAssertEqual(normalizedCustomBaseURL("  https://api.example.com  "), "https://api.example.com")
    }

    func testNormalizedCustomBaseURL_trimsMultipleTrailingSlashes() {
        XCTAssertEqual(normalizedCustomBaseURL("https://api.example.com///"), "https://api.example.com")
    }

    func testNormalizedCustomBaseURL_nonStringReturnsEmpty() {
        XCTAssertEqual(normalizedCustomBaseURL(42), "")
        XCTAssertEqual(normalizedCustomBaseURL(nil as Any?), "")
        XCTAssertEqual(normalizedCustomBaseURL(["url"]), "")
    }

    func testNormalizedCustomBaseURL_emptyStringReturnsEmpty() {
        XCTAssertEqual(normalizedCustomBaseURL(""), "")
    }

    func testNormalizedCustomBaseURL_internalSlashesPreserved() {
        XCTAssertEqual(
            normalizedCustomBaseURL("https://api.example.com/v1/"),
            "https://api.example.com/v1"
        )
    }

    // MARK: -- P9.3 customProviderModelMatches tests (= hermes L189-L194)

    func testCustomProviderModelMatches_exactMatchCaseInsensitive() {
        let entry: [String: Any] = ["model": "GPT-5"]
        XCTAssertTrue(customProviderModelMatches(agentModel: "gpt-5", entry: entry))
    }

    func testCustomProviderModelMatches_noModelFieldIsWildcard() {
        let entry: [String: Any] = ["name": "anything"]
        XCTAssertTrue(customProviderModelMatches(agentModel: "gpt-5", entry: entry))
    }

    func testCustomProviderModelMatches_mismatchReturnsFalse() {
        let entry: [String: Any] = ["model": "claude-3-5-sonnet"]
        XCTAssertFalse(customProviderModelMatches(agentModel: "gpt-5", entry: entry))
    }

    func testCustomProviderModelMatches_trimsWhitespace() {
        let entry: [String: Any] = ["model": "  gpt-5  "]
        XCTAssertTrue(customProviderModelMatches(agentModel: "gpt-5", entry: entry))
    }

    func testCustomProviderModelMatches_emptyModelFieldIsWildcard() {
        let entry: [String: Any] = ["model": ""]
        XCTAssertTrue(customProviderModelMatches(agentModel: "gpt-5", entry: entry))
    }

    // MARK: -- Spec check

    func testSourceFile_documentedAsHermesPort() {
        let sourcePath = #file
            .replacingOccurrences(of: "AgentInitHermesGapPortTests.swift", with: "")
            + "AgentInit.swift"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            XCTFail("Could not read AgentInit.swift at \(sourcePath)")
            return
        }
        XCTAssertTrue(source.contains("P9-AGENT-INIT-HERMES-PORT"))
        XCTAssertTrue(source.contains("agent/agent_init.py"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
        XCTAssertTrue(source.contains("resolveCompressionThreshold"))
        XCTAssertTrue(source.contains("normalizedCustomBaseURL"))
        XCTAssertTrue(source.contains("customProviderModelMatches"))
    }
}
