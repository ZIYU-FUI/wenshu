//
//  RuntimeHelpersHermesGapPortTests.swift · Wenshu · H6-AGENT-RUNTIME-HELPERS-HERMES-PORT (2026-09-19)
//
//  Verifies the 1 new hermes port addition to
//  `Core/Agent/Runtime/RuntimeHelpers.swift` (= hermes
//  `agent/agent_runtime_helpers.py` 3,209 LOC Python).
//
//  Hermes pure helper ported:
//    - stripThinkBlocks(_:) (= hermes `strip_think_blocks` at L600-L696)
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure-function port; = no
//  message-sequence repair / trajectory conversion / credential-pool
//  rotation (= those live in ConversationLoop / WenshuConductor /
//  PromptCaching per the wenshu-side-wins pattern; = per Q112 = one
//  ticket per file = the remaining 27 hermes functions deferred).

import XCTest
@testable import WenshuApp

final class RuntimeHelpersHermesGapPortTests: XCTestCase {

    // MARK: -- H6.1 stripThinkBlocks tests (= hermes L600-L696)

    func testStripThinkBlocks_emptyString_returnsEmpty() {
        XCTAssertEqual(RuntimeHelpers.stripThinkBlocks(""), "")
    }

    func testStripThinkBlocks_removesClosedThinkPair() {
        let input = "Hello <think>secret reasoning</think> world"
        XCTAssertEqual(
            RuntimeHelpers.stripThinkBlocks(input),
            "Hello  world"
        )
    }

    func testStripThinkBlocks_removesThinkingVariant() {
        let input = "A <thinking>thoughts</thinking> B"
        XCTAssertEqual(RuntimeHelpers.stripThinkBlocks(input), "A  B")
    }

    func testStripThinkBlocks_removesReasoningVariant() {
        let input = "X <reasoning>r</reasoning> Y"
        XCTAssertEqual(RuntimeHelpers.stripThinkBlocks(input), "X  Y")
    }

    func testStripThinkBlocks_removesThoughtVariant() {
        let input = "X <thought>t</thought> Y"
        XCTAssertEqual(RuntimeHelpers.stripThinkBlocks(input), "X  Y")
    }

    func testStripThinkBlocks_removesReasoningScratchpadVariant() {
        let input = "X <REASONING_SCRATCHPAD>r</REASONING_SCRATCHPAD> Y"
        XCTAssertEqual(RuntimeHelpers.stripThinkBlocks(input), "X  Y")
    }

    func testStripThinkBlocks_caseInsensitive() {
        let input = "Hello <THINK>secret</THINK> world"
        XCTAssertEqual(
            RuntimeHelpers.stripThinkBlocks(input),
            "Hello  world"
        )
    }

    func testStripThinkBlocks_multilineContent() {
        let input = """
        Before
        <think>
        multi-line
        reasoning
        </think>
        After
        """
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertTrue(result.contains("Before"))
        XCTAssertTrue(result.contains("After"))
        XCTAssertFalse(result.contains("multi-line"))
    }

    func testStripThinkBlocks_unterminatedOpenTagAtStart_stripsToEnd() {
        let input = "<think>never closed reasoning"
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertFalse(result.contains("never closed"))
    }

    func testStripThinkBlocks_unterminatedOpenTagAfterNewline_stripsToEnd() {
        let input = "Hello\n<think>never closed reasoning"
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertTrue(result.contains("Hello"))
        XCTAssertFalse(result.contains("never closed"))
    }

    func testStripThinkBlocks_preservesPlainText() {
        let input = "This is normal text without any tags"
        XCTAssertEqual(
            RuntimeHelpers.stripThinkBlocks(input),
            "This is normal text without any tags"
        )
    }

    func testStripThinkBlocks_stripsToolCallXML() {
        let input = #"Before <tool_call>{"name":"x"}</tool_call> After"#
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertFalse(result.contains("tool_call"))
        XCTAssertFalse(result.contains("name"))
    }

    func testStripThinkBlocks_stripsToolCallsPlural() {
        let input = #"<tool_calls>block</tool_calls>text"#
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertFalse(result.contains("tool_calls"))
        XCTAssertTrue(result.contains("text"))
    }

    func testStripThinkBlocks_stripsToolResultXML() {
        let input = #"<tool_result>{"ok":true}</tool_result>done"#
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertFalse(result.contains("tool_result"))
        XCTAssertTrue(result.contains("done"))
    }

    func testStripThinkBlocks_stripsFunctionCallXML() {
        let input = #"<function_call>{"name":"x"}</function_call>end"#
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertFalse(result.contains("function_call"))
        XCTAssertTrue(result.contains("end"))
    }

    func testStripThinkBlocks_stripsFunctionCallsPlural() {
        let input = #"<function_calls>data</function_calls>after"#
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertFalse(result.contains("function_calls"))
        XCTAssertTrue(result.contains("after"))
    }

    func testStripThinkBlocks_stripsGemmaStyleFunctionBlock() {
        let input = "Before\n<function name=\"foo\">body</function>\nAfter"
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertTrue(result.contains("Before"))
        XCTAssertTrue(result.contains("After"))
        XCTAssertFalse(result.contains("body"))
    }

    func testStripThinkBlocks_preservesFunctionMentionInProse() {
        let input = "Use <function> in JavaScript"
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertTrue(result.contains("Use <function> in JavaScript"))
    }

    func testStripThinkBlocks_stripsStrayOrphanTags() {
        let input = "Before </think> think Orphans </think> After"
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertFalse(result.contains("think"))
        XCTAssertTrue(result.contains("Before"))
        XCTAssertTrue(result.contains("After"))
    }

    func testStripThinkBlocks_multilineThinkWithNewlines() {
        let input = "X\n<think>line1\nline2\nline3</think>\nY"
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertFalse(result.contains("line1"))
        XCTAssertFalse(result.contains("line2"))
        XCTAssertFalse(result.contains("line3"))
        XCTAssertTrue(result.contains("X"))
        XCTAssertTrue(result.contains("Y"))
    }

    func testStripThinkBlocks_multipleClosedThinkPairs() {
        let input = "<think>a</think> middle <think>b</think> end"
        let result = RuntimeHelpers.stripThinkBlocks(input)
        XCTAssertFalse(result.contains("a"))
        XCTAssertFalse(result.contains("b"))
        XCTAssertTrue(result.contains("middle"))
        XCTAssertTrue(result.contains("end"))
    }

    // MARK: -- H6.2 spec check (= hermes line-range citations in source)

    func testStripThinkBlocks_documentedAsHermesPort() {
        // Pure spec check: the source file MUST contain the
        // hermes-port marker + line-range citation per the
        // spec §3.1 contract.
        let sourcePath = #file
            .replacingOccurrences(of: "RuntimeHelpersHermesGapPortTests.swift", with: "")
            + "RuntimeHelpers.swift"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            XCTFail("Could not read RuntimeHelpers.swift at \(sourcePath)")
            return
        }
        XCTAssertTrue(source.contains("H6 Hermes-Python gap port"))
        XCTAssertTrue(source.contains("L600-L696"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
    }
}
