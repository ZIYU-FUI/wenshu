//
//  ModelMetadataErrorParsingHermesGapPortTests.swift · Wenshu · P7-MODEL-METADATA-HERMES-PORT (2026-09-19)
//
//  Verifies the 3 new hermes port additions to
//  `Core/Agent/Connector/ModelMetadata.swift` (= hermes
//  `agent/model_metadata.py` 2434 LOC Python).
//
//  Hermes pure helpers ported:
//    - parseContextLimitFromError(_:) (= hermes
//      `parse_context_limit_from_error` at L1068-L1096)
//    - getContextLengthFromProviderError(_:currentContextLength:)
//      (= hermes `get_context_length_from_provider_error`
//      at L1098-L1116)
//    - parseAvailableOutputTokensFromError(_:)
//      (= hermes `parse_available_output_tokens_from_error`
//      at L1118-L1140)
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure helper port; =
//  no provider URL detection / Codex OAuth / Nous portal
//  (= those live in LLMConnector layer per the
//  wenshu-side-wins pattern).
//
//  Filename note: P7 uses a distinct filename from H7 to
//  avoid Q112 1-test-file-per-source-file collision (= H7's
//  ModelMetadataHermesGapPortTests.swift tests the chat-
//  completion-helpers port; = P7 tests the error-parsing
//  helpers port).

import XCTest
@testable import WenshuApp

final class ModelMetadataErrorParsingHermesGapPortTests: XCTestCase {

    // MARK: -- P7.1 parseContextLimitFromError tests (= hermes L1068-L1096)

    func testParseContextLimit_vllmMaxModelLen() {
        // vLLM format: "max_model_len 32768"
        XCTAssertEqual(
            WenshuModelCatalog.parseContextLimitFromError("max_model_len 32768"),
            32768
        )
    }

    func testParseContextLimit_vllmMaximumModelLength() {
        XCTAssertEqual(
            WenshuModelCatalog.parseContextLimitFromError("maximum model length 131072"),
            131072
        )
    }

    func testParseContextLimit_anthropicFormat() {
        // "maximum context length is 32768 tokens"
        XCTAssertEqual(
            WenshuModelCatalog.parseContextLimitFromError(
                "maximum context length is 32768 tokens"
            ),
            32768
        )
    }

    func testParseContextLimit_openAIFormat() {
        // "context_length_exceeded: 131072"
        XCTAssertEqual(
            WenshuModelCatalog.parseContextLimitFromError(
                "context_length_exceeded: 131072"
            ),
            131072
        )
    }

    func testParseContextLimit_contextSizeExceeded() {
        // "Maximum context size 32768 exceeded"
        XCTAssertEqual(
            WenshuModelCatalog.parseContextLimitFromError(
                "Maximum context size 32768 exceeded"
            ),
            32768
        )
    }

    func testParseContextLimit_returnsNilForUnparseable() {
        XCTAssertNil(WenshuModelCatalog.parseContextLimitFromError("random error"))
    }

    func testParseContextLimit_sanityRangeRejectsTooSmall() {
        // Below 1024 → dropped per hermes sanity check
        XCTAssertNil(WenshuModelCatalog.parseContextLimitFromError("max_model_len 100"))
    }

    func testParseContextLimit_sanityRangeRejectsTooLarge() {
        // Above 10M → dropped per hermes sanity check
        XCTAssertNil(WenshuModelCatalog.parseContextLimitFromError("max_model_len 99999999"))
    }

    func testParseContextLimit_caseInsensitive() {
        XCTAssertEqual(
            WenshuModelCatalog.parseContextLimitFromError("MAX_MODEL_LEN 65536"),
            65536
        )
    }

    // MARK: -- P7.2 getContextLengthFromProviderError tests (= hermes L1098-L1116)

    func testGetContextLength_lowerThanCurrent_returnsParsed() {
        let result = WenshuModelCatalog.getContextLengthFromProviderError(
            errorMessage: "max_model_len 32768",
            currentContextLength: 200000
        )
        XCTAssertEqual(result, 32768)
    }

    func testGetContextLength_higherThanCurrent_returnsNil() {
        // parsed > current → returns nil per hermes filter
        let result = WenshuModelCatalog.getContextLengthFromProviderError(
            errorMessage: "max_model_len 131072",
            currentContextLength: 32768
        )
        XCTAssertNil(result)
    }

    func testGetContextLength_unparseableError_returnsNil() {
        let result = WenshuModelCatalog.getContextLengthFromProviderError(
            errorMessage: "random error",
            currentContextLength: 100000
        )
        XCTAssertNil(result)
    }

    func testGetContextLength_noLimitInError_returnsNil() {
        // Error doesn't mention a specific limit → return nil
        let result = WenshuModelCatalog.getContextLengthFromProviderError(
            errorMessage: "context length exceeded",
            currentContextLength: 100000
        )
        XCTAssertNil(result)
    }

    // MARK: -- P7.3 parseAvailableOutputTokensFromError tests (= hermes L1118-L1140)

    func testParseOutputTokens_maxTokensLimit() {
        // "max_tokens ... must be <= 8192"
        XCTAssertEqual(
            WenshuModelCatalog.parseAvailableOutputTokensFromError(
                "max_tokens must be <= 8192"
            ),
            8192
        )
    }

    func testParseOutputTokens_maxOutputTokensExplicit() {
        // "max_output_tokens 4096"
        XCTAssertEqual(
            WenshuModelCatalog.parseAvailableOutputTokensFromError(
                "max_output_tokens 4096"
            ),
            4096
        )
    }

    func testParseOutputTokens_maxCompletionTokens() {
        // "max_completion_tokens ... 4096"
        XCTAssertEqual(
            WenshuModelCatalog.parseAvailableOutputTokensFromError(
                "max_completion_tokens 4096"
            ),
            4096
        )
    }

    func testParseOutputTokens_outputLimitGeneric() {
        // "output token limit 2048"
        XCTAssertEqual(
            WenshuModelCatalog.parseAvailableOutputTokensFromError(
                "output token limit 2048"
            ),
            2048
        )
    }

    func testParseOutputTokens_returnsNilForUnrelated() {
        XCTAssertNil(WenshuModelCatalog.parseAvailableOutputTokensFromError(
            "context length exceeded"
        ))
    }

    func testParseOutputTokens_sanityRangeRejectsTooSmall() {
        // Below 16 → dropped per hermes sanity check
        XCTAssertNil(WenshuModelCatalog.parseAvailableOutputTokensFromError(
            "max_tokens must be <= 5"
        ))
    }

    func testParseOutputTokens_caseInsensitive() {
        XCTAssertEqual(
            WenshuModelCatalog.parseAvailableOutputTokensFromError(
                "MAX_TOKENS MUST BE <= 4096"
            ),
            4096
        )
    }

    // MARK: -- Spec check

    func testSourceFile_documentedAsHermesPort() {
        // v1.57 stale-helper: per wenshu-stale-test-cleanup Class A recipe.
        guard let source = HermesGapPortTestHelpers.readSource(
            relativeToTest: #filePath,
            sourceFileName: "ModelMetadata.swift"
        ) else {
            XCTFail("HermesGapPortTestHelpers could not locate ModelMetadata.swift")
            return
        }
        XCTAssertTrue(source.contains("P7 Hermes-Python gap port"))
        XCTAssertTrue(source.contains("agent/model_metadata.py"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
        XCTAssertTrue(source.contains("parseContextLimitFromError"))
        XCTAssertTrue(source.contains("getContextLengthFromProviderError"))
        XCTAssertTrue(source.contains("parseAvailableOutputTokensFromError"))
    }
}
