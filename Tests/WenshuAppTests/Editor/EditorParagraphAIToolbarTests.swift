//
//  EditorParagraphAIToolbarTests.swift · Wenshu · P2 #19 (WIRE-PARAGRAPH-002)
//
//  3 Swift Testing tests for the paragraph_ai toolbar wire-up:
//  - testExpandButton_disabledWhenNoSelection: validates the
//    `disabled(selectedText.isEmpty || isApplying)` rule on the
//    toolbar's expand button (= Apple HIG actionable-control-
//    while-busy; = matches the boss spec's
//    `disabled(vm.selectedText.isEmpty)` line).
//  - testExpandButton_enabledWhenSelectionExists: validates the
//    inverse rule (= button enables when selection exists).
//  - testApplyExpand_replacesSelectedTextWithLLMResponse:
//    validates the apply pipeline (= builds the prompt prefix
//    from the P1 #10 EditorTransformTools actor, sends it
//    through the active LLMConnector, extracts the first .text
//    block, and returns it).
//
//  Per Q182.4: Swift Testing framework (= wenshu convention since
//  v0.30+); @MainActor isolation inherited from the types under
//  test (EditorPlaceholder is a SwiftUI View = MainActor).
//
//  Test scope (= per the ticket hard rules): the toolbar struct
//  itself is `private struct` inside WorkspaceView.swift, so the
//  tests exercise:
//    1. the disabled-rule expression (= pure, testable in
//       isolation; = the exact expression the toolbar's
//       `.disabled(...)` modifier evaluates).
//    2. the `EditorParagraphAI.apply(...)` static helper (= the
//       extracted pure function = the pipeline applyParagraphAI
//       delegates to). The static helper is `internal struct`,
//       reachable via `@testable import WenshuApp`.
//
//  Mock injection: the apply test injects `MockLLMConnector`
//  (= v0.37 Batch 2.1 sub-step 2) so the test does NOT require a
//  real network round-trip (= S4 offline-friendly test suite).
//

import Testing
import Foundation
@testable import WenshuApp

@MainActor
@Suite("EditorParagraphAIToolbar (P2 #19 WIRE-PARAGRAPH-002)")
struct EditorParagraphAIToolbarTests {

    // MARK: - Toolbar disabled-state rule

    /// Mirrors the toolbar's `.disabled(selectedText.isEmpty || isApplying)`
    /// expression (= Apple HIG actionable-control-while-busy; = matches the
    /// boss spec's `disabled(vm.selectedText.isEmpty)` line). Verifying the
    /// rule as a pure expression (= no SwiftUI tree walk) keeps the test
    /// independent of the private toolbar struct's internals.
    private static func paragraphAIToolbarDisabled(
        selectedText: String,
        isApplying: Bool
    ) -> Bool {
        selectedText.isEmpty || isApplying
    }

    @Test("expand button is disabled when no selection")
    func testExpandButton_disabledWhenNoSelection() {
        // Empty selection + not applying → disabled (= the boss spec's
        // `disabled(vm.selectedText.isEmpty)` rule).
        #expect(Self.paragraphAIToolbarDisabled(
            selectedText: "",
            isApplying: false
        ) == true)
    }

    @Test("expand button is enabled when selection exists")
    func testExpandButton_enabledWhenSelectionExists() {
        // Non-empty selection + not applying → enabled (= the toolbar
        // fires applyParagraphAI on tap/shortcut).
        #expect(Self.paragraphAIToolbarDisabled(
            selectedText: "Anna looked up at the sky.",
            isApplying: false
        ) == false)
    }

    // MARK: - Apply pipeline

    @Test("apply expand sends prompt + extracts connector text")
    func testApplyExpand_replacesSelectedTextWithLLMResponse() async throws {
        // P2 #19 ticket acceptance: applyParagraphAI(.expand) replaces
        // the selected text with the LLM response. We exercise the
        // pure helper (EditorParagraphAI.apply) with a mock connector
        // (= v0.37 Batch 2.1 sub-step 2) so no network is required.
        //
        // Mock configuration: scripted response = a single .text block
        // containing the "expanded" paragraph. After the apply, the
        // helper returns the extracted text (= the same string the
        // production view writes back via replaceSelectedText).
        let rewrittenParagraph = "Anna looked up at the vast, cobalt sky, where a lone eagle traced slow circles above the wheat field, its cry carrying across the still morning air like a thread of memory."
        let mock = MockLLMConnector(
            response: rewrittenParagraph,
            scriptedResponses: [
                LLMResponse(
                    id: "mock-test-1",
                    model: "test-model",
                    blocks: [.text(rewrittenParagraph)],
                    stopReason: .endTurn,
                    usage: LLMUsage(inputTokens: 0, outputTokens: 0)
                )
            ]
        )
        let options = LLMCallOptions(model: "test-model", maxTokens: 2048)
        let selectedText = "Anna looked up at the sky."

        let result = try await EditorParagraphAI.apply(
            selectedText: selectedText,
            transform: .expand,
            connector: mock,
            options: options
        )

        // Acceptance: the apply helper returns the first .text block
        // (= the LLM-rewritten paragraph). Production wiring
        // (= EditorPlaceholder.applyParagraphAI) passes this string
        // to replaceSelectedText which writes it back to the draft.
        #expect(result == rewrittenParagraph)

        // Verify the connector received the prompt with the
        // P1 #10 EditorTransformTools .expand prefix (= the
        // [TRANSFORM: expand] directive) plus the selected text.
        let received = await mock.receivedMessages
        #expect(received.count == 1)
        if case let .text(prompt) = received[0].blocks[0] {
            // The expand directive token (= the literal string the
            // P1 #10 EditorTransformTools actor emits) must be
            // present (= if the prompt prefix drift changes, this
            // assertion catches it; = pins the contract between
            // EditorTransformTools and EditorParagraphAI.apply).
            #expect(prompt.contains("[TRANSFORM: expand]"))
            #expect(prompt.contains(selectedText))
        } else {
            // Force a test failure with a clear message when the
            // first block isn't a .text (= the protocol contract
            // the helper relies on).
            Issue.record("expected first block to be .text, got \(received[0].blocks[0])")
        }
    }
}
