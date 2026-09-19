//
//  ChatPartViewToolUseFadeInTests.swift · Wenshu · T41-TOOL-USE-FADEIN (2026-09-18)
//
//  Verifies that the tool-use + tool-result cases in ChatPartRow
//  ALSO use the wenshuThinkingAppear transition (= T40 only
//  applied it to reasoning; = T41 extends it to the rest of the
//  streamed parts).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatPartView tool-use fade-in (T41)")
struct ChatPartViewToolUseFadeInTests {

    /// T41 contract: ChatPartRow's .toolUse case applies
    /// .transition(.wenshuThinkingAppear()).
    @Test func toolUse_case_applies_transition() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        // Locate the toolUse case in ChatPartRow.body's switch.
        let toolUseIdx = src.range(of: "case .toolUse(let tu):")!
        // Find the next "case" keyword (= the .toolResult case)
        // and verify the transition is between them.
        let nextCaseIdx = src.range(of: "case .toolResult(let tr):",
                                    range: toolUseIdx.upperBound..<src.endIndex)!
        let toolUseBlock = src[toolUseIdx.lowerBound..<nextCaseIdx.lowerBound]
        #expect(toolUseBlock.contains(".transition(.wenshuThinkingAppear())"))
    }

    /// T41 contract: ChatPartRow's .toolResult case ALSO applies
    /// the transition (= both halves of the tool lifecycle fade in).
    @Test func toolResult_case_applies_transition() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        let toolResultIdx = src.range(of: "case .toolResult(let tr):")!
        let nextCaseIdx = src.range(of: "case .plan(let p):",
                                    range: toolResultIdx.upperBound..<src.endIndex)!
        let toolResultBlock = src[toolResultIdx.lowerBound..<nextCaseIdx.lowerBound]
        #expect(toolResultBlock.contains(".transition(.wenshuThinkingAppear())"))
    }

    /// T41 contract: the .reasoning case still applies the
    /// transition (= T40 not regressed).
    @Test func reasoning_case_still_applies_transition() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        let reasoningIdx = src.range(of: "case .reasoning(let s):")!
        let nextCaseIdx = src.range(of: "case .toolUse(let tu):",
                                    range: reasoningIdx.upperBound..<src.endIndex)!
        let reasoningBlock = src[reasoningIdx.lowerBound..<nextCaseIdx.lowerBound]
        #expect(reasoningBlock.contains(".transition(.wenshuThinkingAppear())"))
    }

    /// T41 contract: the count of .transition(.wenshuThinkingAppear())
    /// calls in ChatPartRow is 3 (= reasoning + toolUse + toolResult).
    @Test func transition_applied_to_three_cases() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        // Count occurrences INSIDE the switch in ChatPartRow.body
        // (skip the AnyTransition definition itself).
        let rowBodyStart = src.range(of: "switch part.kind {")!
        let rowBodyEnd = src.range(of: "    }", range: rowBodyStart.upperBound..<src.endIndex)
        guard let rowBodyEnd else {
            Issue.record("could not find switch end")
            return
        }
        let rowBody = src[rowBodyStart.lowerBound..<rowBodyEnd.lowerBound]
        let count = rowBody.components(separatedBy: ".transition(.wenshuThinkingAppear())").count - 1
        #expect(count == 3, "expected 3 transitions in ChatPartRow switch (= reasoning + toolUse + toolResult); got \(count)")
    }

    /// T41 contract: .plan + .text cases do NOT apply the
    /// transition (= only streaming-event parts animate).
    @Test func plan_and_text_cases_dont_apply_transition() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        let rowBodyStart = src.range(of: "switch part.kind {")!
        let rowBodyEnd = src.range(of: "    }", range: rowBodyStart.upperBound..<src.endIndex)
        guard let rowBodyEnd else { return }
        let rowBody = src[rowBodyStart.lowerBound..<rowBodyEnd.lowerBound]
        // Count occurrences in the rowBody.
        let count = rowBody.components(separatedBy: ".transition(.wenshuThinkingAppear())").count - 1
        #expect(count == 3, "exactly 3 transitions expected (= reasoning + toolUse + toolResult); got \(count)")
    }
}